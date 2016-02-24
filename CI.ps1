$psakePath = Join-Path $PSScriptRoot Tools\packages\psake.4.4.2\tools\psake
$ciTasksPath = Join-Path $PSScriptRoot Source\Scripts\CI.Tasks.ps1

. $psakePath $ciTasksPath $args -parameters @{BasePath=$PSScriptRoot} -nologo -framework 4.6

if ($LASTEXITCODE -ne 0) {
    Write-Error "PSake failed with exit code $LASTEXITCODE.  See previous errors for details."
}