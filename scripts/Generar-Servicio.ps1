# Compatible con Windows PowerShell 5.1 y PowerShell 7.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[a-z][a-z0-9]*(-[a-z0-9]+)*$')]
    [string]$ArtifactId,
    [ValidatePattern('^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)*$')]
    [string]$GroupId = 'cl.duoc',
    [string]$Package = 'cl.duoc.foroejemplo',
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9]+([.-][A-Za-z0-9]+)*)?$')]
    [string]$Version = '0.0.1-SNAPSHOT',
    [ValidateRange(1,65535)]
    [int]$Port = 8084,
    [string]$OutputRoot,
    [string]$JavaHome,
    [switch]$ValidarSolamente
)
$ErrorActionPreference = 'Stop'
if (-not $OutputRoot) { $OutputRoot = Join-Path $PSScriptRoot '../../.verification/arquetipo/demo' }
if ($ArtifactId -cnotmatch '^[a-z][a-z0-9]*(-[a-z0-9]+)*$') { throw 'ArtifactId debe contener solo minusculas, numeros y guiones.' }
$taskKeywords = 'abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public return short static strictfp super switch synchronized this throw throws transient try void volatile while true false null _' -split ' '
$taskReservedPath = '^(con|prn|aux|nul|com[1-9]|lpt[1-9])$'
foreach ($taskPart in (@($ArtifactId) + ($GroupId -split '\.') + ($Package -split '\.'))) {
    if ($taskPart -match $taskReservedPath) { throw ('Nombre reservado como ruta de Windows: ' + $taskPart) }
}
if ($Package -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$') {
    throw 'Package debe ser un paquete Java valido, por ejemplo cl.duoc.nuevo.'
}
foreach ($taskSegment in ($Package -split '\.')) {
    if ($taskKeywords -ccontains $taskSegment) { throw ('Package contiene una palabra reservada de Java: ' + $taskSegment) }
}
$taskRoot = [IO.Path]::GetFullPath($OutputRoot)
$taskTarget = [IO.Path]::GetFullPath((Join-Path $taskRoot $ArtifactId))
if (Test-Path -LiteralPath $taskTarget) { throw ('Ya existe el destino; no se sobrescribira: ' + $taskTarget) }
if (Test-Path -LiteralPath (Join-Path $taskRoot 'pom.xml')) { throw 'Elige una carpeta de salida sin pom.xml para no alterar un proyecto Maven existente.' }
$taskWrapper = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../mvnw.cmd'))
if ($ValidarSolamente) {
    [pscustomobject]@{GroupId=$GroupId;ArtifactId=$ArtifactId;Version=$Version;Package=$Package;Port=$Port;Destino=$taskTarget}
    return
}
if (-not (Test-Path -LiteralPath $taskWrapper -PathType Leaf)) { throw 'No se encontro el Maven Wrapper del arquetipo.' }
$taskPreviousJava = $env:JAVA_HOME
try {
    if ($JavaHome) {
        if (-not (Test-Path -LiteralPath (Join-Path $JavaHome 'bin/java.exe') -PathType Leaf)) { throw 'JavaHome no contiene bin/java.exe.' }
        $env:JAVA_HOME = [IO.Path]::GetFullPath($JavaHome)
    }
    New-Item -ItemType Directory -Path $taskRoot -Force | Out-Null
    Push-Location -LiteralPath $taskRoot
    try {
        & $taskWrapper -B 'org.apache.maven.plugins:maven-archetype-plugin:3.4.1:generate' '-DarchetypeCatalog=local' '-DinteractiveMode=false' '-DarchetypeGroupId=cl.duoc' '-DarchetypeArtifactId=foro-microservicio-archetype' '-DarchetypeVersion=1.0.0' "-DgroupId=$GroupId" "-DartifactId=$ArtifactId" "-Dversion=$Version" "-Dpackage=$Package" "-Dport=$Port" "-DoutputDirectory=$taskRoot"
        if ($LASTEXITCODE -ne 0) { throw 'Maven no pudo generar el proyecto. Revisa el error anterior; no se sobrescribieron carpetas existentes.' }
    } finally { Pop-Location }
    Write-Host ('Servicio generado en: ' + $taskTarget)
} finally { $env:JAVA_HOME = $taskPreviousJava }
