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

function Add-Module 
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][string]$Path
    )

	#Save the current value in the $p variable.
	$p = [Environment]::GetEnvironmentVariable("PSModulePath")

	#Add the new path to the $p variable. Begin with a semi-colon separator.
	$p += ";$Path"

	#Add the paths in $p to the PSModulePath value.
	[Environment]::SetEnvironmentVariable("PSModulePath", $p)

	Write-Host "Added $Path to PSModulePath."
}

# Make sure all the system level prerequisites that require Admin rights are installed.

$rootPath           = Join-Path $PSScriptRoot '..\..\'
$toolsPath          = Join-Path $rootPath     'Tools'
$nugetPath          = Join-Path $toolsPath    'nuget.exe'
$packagesConfigPath = Join-Path $toolsPath    'packages.config'
$packagesDirectory  = Join-Path $toolsPath    'packages'
$modulesPath        = Join-Path $toolsPath    'PowerShellModules'

exec { . $nugetPath restore $packagesConfigPath -packagesDirectory $packagesDirectory }

Write-Host "Adding CI PowerShell modules to PSModulePath..."

Add-Module -Path $modulesPath\PackageManagement\1.0.0.0
Add-Module -Path $modulesPath\PowerShellGet

	# TODO: REMOVE
	Write-Host "PowerShell:"
	Write-Host $PSVersionTable.PSVersion
	Write-Host "PSModulePath: ${env:PSModulePath}"
	Write-Host "Available Modules:"
	foreach ($module in Get-Module -ListAvailable) {
		Write-Host $module.Name $module.Version
	}

Write-Host 'Loading PowerShell modules...'

Import-Module PackageManagement -RequiredVersion 1.0.0.0
Import-Module PowerShellGet     -RequiredVersion 1.0

$azureModulePath = Join-Path $modulesPath 'Azure'
if (-not (Test-Path $azureModulePath)) {
	Save-Module `
		-Name Azure `
		-RequiredVersion 1.0.4 `
		-Path $modulesPath `
		-MinimumVersionForce
}

Add-Module -Path $modulesPath\Azure\1.0.4