Include "AppVeyor.Functions.ps1"

function Get-BuildVersion {
    $BuildVersion = Get-AppVeyorBuildVersion

    if (-not $BuildVersion) {
        $BuildVersion = "0.0.0.0"
    }

    Write-Output $BuildVersion
}

function Update-AssemblyInfoVersion {
    Param(
        $Path,
        $Version
    )

    Write-Host "Updating $Path with $Version..." -NoNewline

    $AssemblyInfoContent = Get-Content $Path -Encoding UTF8

    $AssemblyInfoContent = $AssemblyInfoContent -replace 'AssemblyVersion\(".*"\)', "AssemblyVersion(""$Version"")"

    Set-Content $Path $AssemblyInfoContent -Encoding UTF8

    Write-Host "done!"
}

function Assert-HttpStatusCode {
    Param(
        $GetUri,
        $ExpectedStatusCode
    )

    $response   = Invoke-WebRequest $GetUri -UseBasicParsing
    $statusCode = $response.StatusCode
    
    if ($statusCode -ne $ExpectedStatusCode) {
        throw "Unexpected status code: $response"
    }
}

function Write-EnvironmentSecrets {
    Param(
        $SecretsPath,
        $ServiceBusConnectionString
    )

    Write-Host "Saving secrets to $SecretsPath..." -NoNewline

    Set-Content $SecretsPath `
        -Value "<?xml version='1.0' encoding='utf-8'?>
<appSettings>
  <add 
    key=""Microsoft.ServiceBus.ConnectionString""
    value=""$ServiceBusConnectionString""
  />
</appSettings>" `
        -Force

    Write-Host "done!"
}

# Executes tests found in the specified DLLs.
function Run-Tests {
    Param(
        $PackagesPath,
        $ArtifactsPath,
        $TestDlls,
        $CodeCoveragePercentageRequired
    )

    $xUnitPath           = Join-Path $PackagesPath 'xunit.runner.console.2.1.0\tools\xunit.console.exe'
    $openCoverPath       = Join-Path $PackagesPath 'OpenCover.4.6.166\tools\OpenCover.Console.exe'
    $openCoverOutputPath = Join-Path $ArtifactsPath "coverage.xml"

    $currentDir = Get-Location
    Set-Location $ArtifactsPath
    exec {
		. $openCoverPath `
			-target:$xUnitPath `
			-targetargs:$TestDlls `
			-returntargetcode `
			-register:user `
			-output:$openCoverOutputPath `
			-filter:'+[Slinqy.Core]*' `
			-mergebyhash  
	}
    Set-Location $currentDir

    if ($CodeCoveragePercentageRequired) {
        $reportGeneratorPath       = Join-Path $PackagesPath 'ReportGenerator.2.3.5.0\tools\ReportGenerator.exe'
        $reportGeneratorOutputPath = Join-Path $ArtifactsPath 'CoverageReport'

        exec { . $reportGeneratorPath $openCoverOutputPath $reportGeneratorOutputPath }

        $coverallsPath = Join-Path $PackagesPath 'coveralls.io.1.3.4\tools\coveralls.net.exe'

        exec { . $coverallsPath --opencover $openCoverOutputPath }

        # Check the percentage:
        $totalSequencePoints = (Select-Xml `
            -Path  $openCoverOutputPath `
            -XPath '//SequencePoint').Count

        $visitedSequencePoints = (Select-Xml `
            -Path  $openCoverOutputPath `
            -XPath "//SequencePoint[@vc!='0']").Count

        $coveragePercentage = ($visitedSequencePoints / $totalSequencePoints) * 100

        Write-Host "$visitedSequencePoints out of $totalSequencePoints sequence points covered: $coveragePercentage %"

        if ($coveragePercentage -lt $CodeCoveragePercentageRequired) {
            Write-Error "$coveragePercentage% is not sufficient, $CodeCoveragePercentageRequired% must be covered."
        }
    }
}