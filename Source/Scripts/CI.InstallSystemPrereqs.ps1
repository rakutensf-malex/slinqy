# Include additional scripts
Include "CI.Functions.ps1"

# Make sure all the system level prerequisites that require Admin rights are installed.

$rootPath           = Join-Path $PSScriptRoot '..\..\'
$toolsPath          = Join-Path $rootPath     'Tools'
$nugetPath          = Join-Path $toolsPath    'nuget.exe'
$packagesConfigPath = Join-Path $toolsPath    'packages.config'
$packagesDirectory  = Join-Path $toolsPath    'packages'

exec { . $nugetPath restore $packagesConfigPath -packagesDirectory $packagesDirectory }

Write-EnvInfo