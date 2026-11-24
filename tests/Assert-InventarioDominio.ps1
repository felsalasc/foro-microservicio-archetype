[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$SourceDirectory,[Parameter(Mandatory=$true)][string]$GeneratedDirectory)
$ErrorActionPreference = 'Stop'
# Inventario obtenido del origen de forma independiente del manifiesto generado.
$taskExpected = @(git -C $SourceDirectory -c core.quotepath=false ls-files -- src database docker scripts postman Dockerfile .dockerignore .gitattributes README.md | Sort-Object)
if ($LASTEXITCODE -ne 0 -or -not $taskExpected.Count) { throw 'Inventario fuente no disponible.' }
$taskManifest = Get-Content -LiteralPath (Join-Path $GeneratedDirectory '.arquetipo/origen.json') -Raw | ConvertFrom-Json
$taskDeclared = @($taskManifest.archivosDominio | ForEach-Object {$_.ruta} | Sort-Object)
if (@(Compare-Object -ReferenceObject $taskExpected -DifferenceObject $taskDeclared).Count -or $taskExpected.Count -ne $taskDeclared.Count) {
    throw 'Inventario incompleto o alterado respecto al origen Git.'
}
foreach ($taskPath in $taskExpected) {
    if (-not (Test-Path -LiteralPath (Join-Path $GeneratedDirectory $taskPath) -PathType Leaf)) { throw ('Falta archivo de dominio: '+$taskPath) }
}
