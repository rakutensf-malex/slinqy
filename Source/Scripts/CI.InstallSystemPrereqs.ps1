# This script is meant to be run once to provision the local
# machine for performing continuous integration tasks.

# Make sure the script stops if a command fails.
$ErrorActionPreference = "Stop"

# Include additional scripts.
. (Join-Path $PSScriptRoot "CI.Functions.ps1")

# First, perform validation for issues the script cannot resolve on its own.
#requires -RunAsAdministrator
Validate-WinOSVersion      -RequiredMajor 6
Validate-PowerShellVersion -MajorAtLeast 4

# Configure paths
$repoRootPath       = Resolve-Path (Join-Path $PSScriptRoot '..\..\')
$ciToolsPath        = Join-Path $repoRootPath 'Tools'
$nugetPath          = Join-Path $ciToolsPath  'nuget.exe'
$packagesConfigPath = Join-Path $ciToolsPath  'packages.config'
$packagesPath       = Join-Path $ciToolsPath  'packages'

# Install CI dependencies that require Admin rights
$packageManagementInstalled = Is-ModuleInstalled `
	-Name    'PackageManagement' `
	-Version '1.0.0.0'

# PowerShell Package Management
if (-not $packageManagementInstalled) {
	exec { & $ciToolsPath\PackageManagement_x64.msi /passive /norestart }
}

$azureCmdletsInstalled = Is-ModuleInstalled `
	-Name    'Azure' `
	-Version '1.0.4'

if (-not $azureCmdletsInstalled) {
	Write-Host 'Installing Azure 1.0.4...' -NoNewline

	Install-Module `
		-Name            'Azure' `
		-RequiredVersion '1.0.4' `
		-Force

	Write-Host 'done!'
}

# Install CI dependencies that don't require Admin rights
exec { . $nugetPath restore $packagesConfigPath -packagesDirectory $packagesPath }

Write-EnvInfo