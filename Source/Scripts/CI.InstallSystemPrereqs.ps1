# Taken from psake https://github.com/psake/psake
<#
.SYNOPSIS
  This is a helper function that runs a scriptblock and checks the PS variable $lastexitcode
  to see if an error occcured. If an error is detected then an exception is thrown.
  This function allows you to run command-line programs without having to
  explicitly check the $lastexitcode variable.
.EXAMPLE
  exec { svn info $repository_trunk } "Error executing SVN. Please verify SVN command-line client is installed"
#>
function Exec
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][scriptblock]$cmd,
        [Parameter(Position=1,Mandatory=0)][string]$errorMessage = ($msgs.error_bad_command -f $cmd)
    )
    & $cmd
    if ($lastexitcode -ne 0) {
        throw ("Exec: " + $errorMessage)
    }
}

# Make sure all the system level prerequisites that require Admin rights are installed.

$rootPath           = Join-Path $PSScriptRoot '..\..\'
$toolsPath          = Join-Path $rootPath     'Tools'
$nugetPath          = Join-Path $toolsPath    'nuget.exe'
$packagesConfigPath = Join-Path $toolsPath    'packages.config'
$packagesDirectory  = Join-Path $toolsPath    'packages'

exec { . $nugetPath restore $packagesConfigPath -packagesDirectory $packagesDirectory }

Write-Host "PowerShell:   $($PSVersionTable.PSVersion)"
Write-Host "PSModulePath: ${env:PSModulePath}"
Write-Host
Write-Host "Available Modules:"

foreach ($module in Get-Module -ListAvailable) {
	Write-Host $module.Name $module.Version
}