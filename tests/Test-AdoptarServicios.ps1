[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputRoot, [string]$SourceRoot, [string]$JavaHome)
$ErrorActionPreference = 'Stop'
if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '../../..' }
$SourceRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SourceRoot)
$OutputRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputRoot)
$taskScript = Join-Path $PSScriptRoot '../scripts/Adoptar-Servicios.ps1'
if (-not (Test-Path -LiteralPath $taskScript)) { throw 'Falta el generador de adopcion real de los tres servicios.' }
& $taskScript -SourceRoot $SourceRoot -OutputRoot $OutputRoot -JavaHome $JavaHome
$taskServices = @(
    @{Name='foro-usuarios';Folder='SEMANA 2/foro-usuarios';Port=8081;Main='ForoUsuariosApplication.java'},
    @{Name='foro-contenido';Folder='SEMANA 2/foro-contenido';Port=8082;Main='ForoContenidoApplication.java'},
    @{Name='foro-moderacion';Folder='SEMANA 5/foro-moderacion';Port=8083;Main='ForoModeracionApplication.java'}
)
foreach ($taskService in $taskServices) {
    $taskSource = Join-Path $SourceRoot $taskService.Folder
    $taskTarget = Join-Path $OutputRoot $taskService.Name
    & (Join-Path $PSScriptRoot 'Assert-InventarioDominio.ps1') -SourceDirectory $taskSource -GeneratedDirectory $taskTarget
    $taskProof = Get-Content -LiteralPath (Join-Path $taskTarget '.arquetipo/origen.json') -Raw | ConvertFrom-Json
    if ($taskProof.arquetipo -ne 'cl.duoc:foro-microservicio-archetype:1.0.0') { throw 'Arquetipo incorrecto.' }
    if ($taskProof.puerto -ne $taskService.Port -or $taskProof.commitDominio -notmatch '^[0-9a-f]{40}$') { throw 'Procedencia incompleta.' }
    foreach ($taskFile in $taskProof.archivosDominio) {
        $taskOriginal = Get-FileHash -LiteralPath (Join-Path $taskSource $taskFile.ruta) -Algorithm SHA256
        $taskAdapted = Get-FileHash -LiteralPath (Join-Path $taskTarget $taskFile.ruta) -Algorithm SHA256
        if ($taskAdapted.Hash -ne $taskOriginal.Hash -or $taskAdapted.Hash -ne $taskFile.sha256) { throw ('Cambio de dominio: '+$taskFile.ruta) }
    }
    $taskJavaFiles = @(Get-ChildItem -LiteralPath (Join-Path $taskTarget 'src/main/java') -Filter '*.java' -Recurse)
    if (-not ($taskJavaFiles.Name -contains $taskService.Main)) { throw 'Falta la aplicacion real.' }
    if ($taskJavaFiles.Name -contains 'RecursoController.java' -or $taskJavaFiles.Name -contains 'InfoController.java') { throw 'Quedo expuesto el dominio de ejemplo.' }
    [xml]$taskPom = Get-Content -LiteralPath (Join-Path $taskTarget 'pom.xml') -Raw
    if ($taskPom.project.artifactId -ne $taskService.Name -or $taskPom.project.properties.'foro.archetype' -ne $taskProof.arquetipo) { throw 'El POM no acredita la base generada.' }
    if ($taskService.Name -eq 'foro-usuarios' -and -not ($taskPom.project.dependencies.dependency.artifactId -contains 'spring-security-oauth2-jose')) { throw 'Falta JWT en Usuarios.' }
    if (Test-Path -LiteralPath (Join-Path $taskTarget '.git')) { throw 'No debe copiarse Git.' }
    if (Get-ChildItem -LiteralPath $taskTarget -Recurse -File | Where-Object {$_.Extension -in @('.key','.pem','.sso','.p12','.jks')}) { throw 'Se copiaron archivos privados.' }
}
# Mutacion negativa: una omision del manifiesto no debe pasar inadvertida.
$taskMutationTarget = Join-Path $OutputRoot 'foro-contenido'
$taskMutationPath = Join-Path $taskMutationTarget '.arquetipo/origen.json'
$taskOriginalManifest = [IO.File]::ReadAllText($taskMutationPath)
$taskOmissionRejected = $false
try {
    $taskIncomplete = $taskOriginalManifest | ConvertFrom-Json
    $taskIncomplete.archivosDominio = @($taskIncomplete.archivosDominio | Select-Object -Skip 1)
    [IO.File]::WriteAllText($taskMutationPath,($taskIncomplete | ConvertTo-Json -Depth 8))
    try { & (Join-Path $PSScriptRoot 'Assert-InventarioDominio.ps1') -SourceDirectory (Join-Path $SourceRoot 'SEMANA 2/foro-contenido') -GeneratedDirectory $taskMutationTarget }
    catch { $taskOmissionRejected = $_.Exception.Message -match 'Inventario incompleto' }
} finally { [IO.File]::WriteAllText($taskMutationPath,$taskOriginalManifest) }
if (-not $taskOmissionRejected) { throw 'La prueba no detecto la omision deliberada del manifiesto.' }
$taskRejected = $false
try { & $taskScript -SourceRoot $SourceRoot -OutputRoot $OutputRoot -JavaHome $JavaHome } catch { $taskRejected = $_.Exception.Message -match 'existe' }
if (-not $taskRejected) { throw 'No rechazo el destino existente.' }
$taskNestedRejected = $false
try { & $taskScript -SourceRoot $SourceRoot -OutputRoot (Join-Path $SourceRoot 'SEMANA 2/foro-usuarios/adopcion-prohibida') -JavaHome $JavaHome } catch { $taskNestedRejected = $_.Exception.Message -match 'solap|fuente' }
if (-not $taskNestedRejected) { throw 'No rechazo destino dentro del codigo fuente.' }
$taskFixture = Join-Path $OutputRoot '.test-fixture'
$taskDirtySource = Join-Path $taskFixture 'SEMANA 2/foro-usuarios'
New-Item -ItemType Directory -Path $taskDirtySource -Force | Out-Null
git -C $taskDirtySource init -b main | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar el repositorio de prueba.' }
$taskCanary = Join-Path $taskDirtySource 'cambio-sin-commit.txt'
[IO.File]::WriteAllText($taskCanary,'TEST-NO-SECRET')
$taskDirtyRejected = $false
try { & $taskScript -SourceRoot $taskFixture -OutputRoot (Join-Path $taskFixture 'salida') -JavaHome $JavaHome } catch { $taskDirtyRejected = $_.Exception.Message -match 'cambios sin commit' }
if (-not $taskDirtyRejected -or (Test-Path -LiteralPath (Join-Path $taskFixture 'salida')) -or [IO.File]::ReadAllText($taskCanary) -ne 'TEST-NO-SECRET') { throw 'La fuente sucia no se rechazo sin modificaciones.' }
Write-Output 'PASS: tres generaciones reales, procedencia, fuentes identicas, JWT, destinos protegidos y fuente sucia rechazada.'
