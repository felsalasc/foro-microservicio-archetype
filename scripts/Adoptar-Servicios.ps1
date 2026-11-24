# Genera bases reales y migra dominios versionados; nunca modifica las fuentes.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [string]$SourceRoot,
    [string]$JavaHome
)
$ErrorActionPreference = 'Stop'
if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '../../..' }
$SourceRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SourceRoot)
$OutputRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputRoot)
$taskServices = @(
    @{Name='foro-usuarios';Folder='SEMANA 2/foro-usuarios';Package='cl.duoc.forousuarios';Port=8081},
    @{Name='foro-contenido';Folder='SEMANA 2/foro-contenido';Package='cl.duoc.forocontenido';Port=8082},
    @{Name='foro-moderacion';Folder='SEMANA 5/foro-moderacion';Package='cl.duoc.foromoderacion';Port=8083}
)
$taskArchetype = 'cl.duoc:foro-microservicio-archetype:1.0.0'
$taskUtf8 = [Text.UTF8Encoding]::new($false)
function Assert-CleanSource([string]$Path) {
    $taskState = @(git -C $Path status --porcelain)
    if ($LASTEXITCODE -ne 0) { throw ('No se puede leer el repositorio fuente: '+$Path) }
    if ($taskState.Count) { throw ('La fuente tiene cambios sin commit; no se importara: '+$Path) }
}
function Write-Utf8([string]$Path,[string]$Content) {
    [IO.File]::WriteAllText($Path,($Content.Replace("`r`n","`n").TrimEnd()+"`n"),$taskUtf8)
}
# Validar todos los origenes antes de crear el primer archivo.
foreach ($taskService in $taskServices) {
    $taskSource = [IO.Path]::GetFullPath((Join-Path $SourceRoot $taskService.Folder))
    $taskSourcePrefix = $taskSource.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if ($OutputRoot.Equals($taskSource,[StringComparison]::OrdinalIgnoreCase) -or $OutputRoot.StartsWith($taskSourcePrefix,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'El destino se solapa con una fuente; utiliza una carpeta nueva separada.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $taskSource '.git'))) { throw ('Falta la fuente Git: '+$taskSource) }
    Assert-CleanSource $taskSource
    [xml]$taskSourcePom = Get-Content -LiteralPath (Join-Path $taskSource 'pom.xml') -Raw
    if ($taskSourcePom.project.artifactId -ne $taskService.Name -or $taskSourcePom.project.properties.'java.version' -ne '17') { throw 'Fuente Maven inesperada.' }
    $taskService.Source = $taskSource
    $taskService.Commit = (git -C $taskSource rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo obtener el commit de dominio.' }
    $taskService.GroupId = [string]$taskSourcePom.project.groupId
    $taskService.Version = [string]$taskSourcePom.project.version
}
if (Test-Path -LiteralPath $OutputRoot) { throw ('Ya existe el destino; se conserva sin cambios: '+$OutputRoot) }
New-Item -ItemType Directory -Path $OutputRoot | Out-Null
foreach ($taskService in $taskServices) {
    $taskSource = $taskService.Source
    & (Join-Path $PSScriptRoot 'Generar-Servicio.ps1') -ArtifactId $taskService.Name -GroupId $taskService.GroupId -Package $taskService.Package -Version $taskService.Version -Port $taskService.Port -OutputRoot $OutputRoot -JavaHome $JavaHome
    $taskTarget = [IO.Path]::GetFullPath((Join-Path $OutputRoot $taskService.Name))
    $taskTargetPrefix = $taskTarget.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    $taskBasePomHash = (Get-FileHash -LiteralPath (Join-Path $taskTarget 'pom.xml') -Algorithm SHA256).Hash
    $taskGeneratedIgnore = [IO.File]::ReadAllText((Join-Path $taskTarget '.gitignore'))
    [xml]$taskPom = Get-Content -LiteralPath (Join-Path $taskTarget 'pom.xml') -Raw
    if ($taskPom.project.artifactId -ne $taskService.Name) { throw 'Maven no genero el proyecto esperado.' }
    # Retirar solo el ejemplo dentro del proyecto recien generado, nunca origenes.
    foreach ($taskExample in @('src','database','postman')) {
        $taskExamplePath = Join-Path $taskTarget $taskExample
        if (Test-Path -LiteralPath $taskExamplePath) {
            $taskResolved = (Resolve-Path -LiteralPath $taskExamplePath).Path
            if (-not $taskResolved.StartsWith($taskTargetPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Ruta de ejemplo fuera del destino generado.' }
            Remove-Item -LiteralPath $taskResolved -Recurse -Force
        }
    }
    $taskFiles = @(git -C $taskSource -c core.quotepath=false ls-files -- src database docker scripts postman Dockerfile .dockerignore .gitattributes README.md)
    if ($LASTEXITCODE -ne 0 -or -not $taskFiles.Count) { throw 'No se encontraron archivos de dominio versionados.' }
    $taskImported = [Collections.Generic.List[object]]::new()
    foreach ($taskFile in $taskFiles) {
        if ($taskFile -match '(?i)(^|/)(runtime|secrets|credentials|target|node_modules|\.git)/|\.(key|pem|sso|p12|pfx|jks|keystore|log)$|wallet|(^|/)\.env($|\.)|application-(secrets|private|credentials)\.|tnsnames\.ora|sqlnet\.ora|ojdbc\.properties') { throw ('Archivo privado o generado rechazado: '+$taskFile) }
        $taskFrom = [IO.Path]::GetFullPath((Join-Path $taskSource $taskFile))
        $taskTo = [IO.Path]::GetFullPath((Join-Path $taskTarget $taskFile))
        $taskSourcePrefix = $taskSource.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
        if (-not $taskFrom.StartsWith($taskSourcePrefix,[StringComparison]::OrdinalIgnoreCase) -or -not $taskTo.StartsWith($taskTargetPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Ruta de importacion fuera de proyecto.' }
        $taskSourceFile = Get-Item -LiteralPath $taskFrom
        if ($taskSourceFile.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'No se importan enlaces del sistema de archivos.' }
        New-Item -ItemType Directory -Path (Split-Path -Parent $taskTo) -Force | Out-Null
        Copy-Item -LiteralPath $taskFrom -Destination $taskTo
        $taskImported.Add([pscustomobject]@{ruta=$taskFile;sha256=(Get-FileHash -LiteralPath $taskTo -Algorithm SHA256).Hash})
    }
    # Conservar el POM generado y agregar exclusivamente dependencias faltantes.
    [xml]$taskDomainPom = Get-Content -LiteralPath (Join-Path $taskSource 'pom.xml') -Raw
    $taskNs = [Xml.XmlNamespaceManager]::new($taskPom.NameTable)
    $taskNs.AddNamespace('m','http://maven.apache.org/POM/4.0.0')
    $taskDeps = $taskPom.SelectSingleNode('/m:project/m:dependencies',$taskNs)
    foreach ($taskDep in $taskDomainPom.project.dependencies.dependency) {
        $taskExisting = @($taskPom.project.dependencies.dependency | Where-Object {$_.groupId -eq $taskDep.groupId -and $_.artifactId -eq $taskDep.artifactId})
        if (-not $taskExisting.Count) { $null = $taskDeps.AppendChild($taskPom.ImportNode($taskDep,$true)) }
    }
    $taskProps = $taskPom.SelectSingleNode('/m:project/m:properties',$taskNs)
    foreach ($taskProperty in @(@{Name='foro.archetype';Value=$taskArchetype},@{Name='foro.domain.source.commit';Value=$taskService.Commit})) {
        $taskElement = $taskPom.CreateElement($taskProperty.Name,'http://maven.apache.org/POM/4.0.0')
        $taskElement.InnerText = $taskProperty.Value
        $null = $taskProps.AppendChild($taskElement)
    }
    $taskSettings = [Xml.XmlWriterSettings]::new()
    $taskSettings.Indent = $true
    $taskSettings.Encoding = $taskUtf8
    $taskSettings.NewLineChars = "`n"
    $taskWriter = [Xml.XmlWriter]::Create((Join-Path $taskTarget 'pom.xml'),$taskSettings)
    try { $taskPom.Save($taskWriter) } finally { $taskWriter.Dispose() }
    Write-Utf8 (Join-Path $taskTarget '.gitignore') ($taskGeneratedIgnore+"`n"+[IO.File]::ReadAllText((Join-Path $taskSource '.gitignore')))
    Assert-CleanSource $taskSource
    $taskProof = [ordered]@{
        arquetipo=$taskArchetype;servicio=$taskService.Name;puerto=$taskService.Port
        commitDominio=$taskService.Commit;sha256PomBaseGenerado=$taskBasePomHash
        descripcion='Base generada con Maven; dominio migrado del commit indicado. No atribuye generacion historica de Semana 2.'
        archivosDominio=$taskImported.ToArray()
    }
    New-Item -ItemType Directory -Path (Join-Path $taskTarget '.arquetipo') | Out-Null
    Write-Utf8 (Join-Path $taskTarget '.arquetipo/origen.json') ($taskProof | ConvertTo-Json -Depth 6)
    $taskNote = @"
# Adopcion del arquetipo

Este proyecto se reconstruyo desde la base Maven $taskArchetype y se adapto con el dominio de $($taskService.Name), commit $($taskService.Commit). La version anterior ya existia: esta es una migracion actual, no una atribucion retrospectiva.

Se conservaron el POM base, Maven Wrapper y estructura de la plantilla. El ejemplo Recurso se sustituyo por las clases, configuracion, SQL y pruebas reales. Se agregaron las dependencias de dominio faltantes (JWT en Usuarios). Las APIs, tablas y puerto $($taskService.Port) se conservan.

.arquetipo/origen.json registra el SHA256 del POM recien generado y de cada archivo importado. Para reproducir desde los seis clones descritos en foro-despliegue: instala el arquetipo con mvnw.cmd install y ejecuta scripts/Adoptar-Servicios.ps1 desde su repositorio, indicando -SourceRoot la carpeta que contiene SEMANA 2 y SEMANA 5, y -OutputRoot una carpeta NUEVA separada. Requiere Git y JDK 17; -JavaHome permite especificar el JDK. El comando no modifica las fuentes ni despliega servicios.

Antes de promover una nueva copia, ejecuta mvnw.cmd verify en cada servicio generado. Los manifiestos acreditan el proceso de generacion e importacion; las pruebas acreditan comportamiento, no una calificacion garantizada.
"@
    Write-Utf8 (Join-Path $taskTarget 'ARQUETIPO.md') $taskNote
    Write-Output ('ADOPTADO: '+$taskService.Name+' | archivos de dominio: '+$taskImported.Count)
}
Write-Output ('Tres proyectos generados y adaptados en '+$OutputRoot+'. Fuentes y despliegue sin modificar.')
