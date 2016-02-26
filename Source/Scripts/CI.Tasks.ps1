# Include additional scripts
Include "CI.Settings.ps1"
Include "CI.Functions.ps1"
Include "CI.Azure.Functions.ps1"

# Define path parameters
$BasePath = "Uninitialized" # Caller must specify.

# Define the input properties and their default values.
properties {
    $ProductName           = "Slinqy"
    $SourcePath            = Join-Path $BasePath "Source"
    $ArtifactsPath         = Join-Path $BasePath "Artifacts"
	$ToolsPath             = Join-Path $BasePath "Tools"
    $LogsPath              = Join-Path $ArtifactsPath "Logs"
    $ScriptsPath           = Join-Path $ArtifactsPath "Scripts"
    $PublishedWebsitesPath = Join-Path $ArtifactsPath "_PublishedWebsites"
    $SolutionFileName      = "$ProductName.sln"
    $SolutionPath          = Join-Path $SourcePath $SolutionFileName
	$CiPackagesPath        = Join-Path $ToolsPath "packages"
}

# Define the Task to call when none was specified by the caller.
Task Default -depends Build

Task InstallDependencies -description "Installs all dependencies required to execute the tasks in this script." {

}

Task Clean -depends InstallDependencies -description "Removes any artifacts that may be present from prior runs of the CI script." {
    if (Test-Path $ArtifactsPath) {
        Write-Host "Deleting $ArtifactsPath..." -NoNewline
        Remove-Item $ArtifactsPath -Recurse -Force
        Write-Host "done!"
    }

    Write-Host "Cleaning solution $SolutionPath..." -NoNewline

    exec { msbuild $SolutionPath /t:Clean /verbosity:minimal /m /nologo }
    
    Write-Host "done!"
}

Task LoadSettings -description "Loads the environment specific settings." {
    # Search for a settings file
    $TemplateParametersFileName = 'environment-settings.json'
    $TemplateParametersFilePath = Join-Path $BasePath $TemplateParametersFileName
    
    $Script:Settings = Get-EnvironmentSettings `
        -ProductName      $ProductName `
        -SettingsFilePath $TemplateParametersFilePath
}

Task Build -depends Clean -description "Compiles all source code." {
    $BuildVersion = Get-BuildVersion
	$NuGetPath = Join-Path $ToolsPath 'nuget.exe'
    exec { . $NuGetPath restore $SolutionPath }

    Write-Host "Building $ProductName $BuildVersion from $SolutionPath"
    
    # Make sure the path exists, or the logs won't be written.
    New-Item `
        -ItemType Directory `
        -Path $LogsPath |
            Out-Null

    # Update the AssemblyInfo file with the version #.
    $AssemblyInfoFilePath = Join-Path $SourcePath 'AssemblyInfo.cs'
    Update-AssemblyInfoVersion `
        -Path    $AssemblyInfoFilePath `
        -Version $BuildVersion

    Write-Host "Compiling solution $SolutionPath..."

    # Compile the whole solution according to how the solution file is configured.
    exec { msbuild $SolutionPath /p:OutDir=$ArtifactsPath\ /verbosity:minimal /m /nologo }

    Write-Host "done!"

    # Unit test the built code
    $TestDlls = @(
        (Join-Path $ArtifactsPath 'Slinqy.Core.Test.Unit.dll')
    )

    Write-Host
    Write-Host "Unit testing $TestDlls..."

    Run-Tests `
        -PackagesPath  $CiPackagesPath `
        -ArtifactsPath $ArtifactsPath `
        -TestDlls      $TestDlls `
        -CodeCoveragePercentageRequired 100

    Write-Host "done!"
    Write-Host
    Write-Host "Packaging..."

    # Package up deployables
    $WebProjectFileName = "ExampleApp.Web.csproj"
    $WebProjectPath     = Join-Path $SourcePath "ExampleApp.Web\$WebProjectFileName"

    exec { msbuild $WebProjectPath /p:OutDir=$ArtifactsPath\ /t:Package /verbosity:minimal /m /nologo }

    Write-Host "done!"
}

Task Deploy -depends LoadSettings -description "Deploys the physical infrastructure, configuration settings and application code required to operate." {
    # Make sure we're authenticated with Azure so the script can deploy.
    $context = GetOrLogin-AzureRmContext `
        -AzureDeployUser $env:AzureDeployUser `
        -AzureDeployPass $env:AzureDeployPass

    Write-Host "Provisioning Resource Group $($Settings.ResourceGroupName) in $($Settings.EnvironmentName) ($($Settings.EnvironmentLocation)) in Azure Subscription $($context.Subscription.SubscriptionName)"

    # Set up paths to the Resource Manager template
    $TemplatesPath	               = Join-Path $ArtifactsPath "Templates"
    $DeployStorageTemplateFilePath = Join-Path $TemplatesPath "DeploymentStorage.json"
    $appTemplateFilePath           = Join-Path $TemplatesPath "ExampleApp.json"

    if (-not (Check-AzureResourceGroupExists $Settings.ResourceGroupName)) {
        Write-Host "Creating resource group $($Settings.ResourceGroupName)..." -NoNewline

        New-AzureRmResourceGroup `
            -Name			            $Settings.ResourceGroupName `
            -Location                   $Settings.EnvironmentLocation |
                Out-Null

        Write-Host "done!"
    }

    Write-Host "Provisioning application package deployment storage..." -NoNewline

    $result = New-AzureRmResourceGroupDeployment `
        -ResourceGroupName			$Settings.ResourceGroupName `
        -TemplateFile               $DeployStorageTemplateFilePath `
        -Force

    Write-Host "done!"

    # Upload the application package to storage
    $deployContainerName = "packages"
    $storageCtx = New-AzureStorageContext `
        -ConnectionString $result.Outputs['deployStorageConnectionString'].Value

    $exampleAppPackagePath = Join-Path $PublishedWebsitesPath "ExampleApp.Web_Package\ExampleApp.Web.zip"

    Write-Host "Uploading package $exampleAppPackagePath to container '$deployContainerName'..." -NoNewline
    
    [string]$uploadedPackageUri = Upload-FileToBlob `
        -StorageContext $storageCtx `
        -LocalFilePath  $exampleAppPackagePath `
        -ContainerName  $deployContainerName

    Write-Host "done!"
    Write-Host "Updating application resources..." -NoNewline

    $sasToken = ConvertTo-SecureString(
        New-AzureStorageContainerSASToken `
            -Container  $deployContainerName `
            -Context    $storageCtx `
            -Permission r
    ) -AsPlainText -Force

    $result = New-AzureRmResourceGroupDeployment `
        -ResourceGroupName			$Settings.ResourceGroupName `
        -TemplateFile               $appTemplateFilePath `
        -environmentName            $Settings.EnvironmentName `
        -environmentLocation        $Settings.EnvironmentLocation `
        -exampleAppSiteName         $Settings.ExampleAppSiteName `
        -deployPackageUri           $uploadedPackageUri `
        -deployPackageSasToken      $sasToken

    Write-Host "done!"

    # Save connection strings locally so that the app can also be run locally.
    $environmentSecretsPath     = Join-Path $BasePath "environment-secrets.config"
    $serviceBusConnectionString = $result.Outputs["serviceBusConnectionString"].Value    
    
    Write-EnvironmentSecrets `
        -SecretsPath                $environmentSecretsPath `
        -ServiceBusConnectionString $serviceBusConnectionString

    # Hit the Example App website to make sure it's alive
    $exampleWebsiteHostName = (Get-AzureRmWebApp -Name $Settings.ExampleAppSiteName -ResourceGroupName $Settings.ResourceGroupName).HostNames

    Write-Host "Checking $exampleWebsiteHostName..." -NoNewline

    Assert-HttpStatusCode `
        -GetUri             $exampleWebsiteHostName `
        -ExpectedStatusCode 200

    Write-Host "OK!"
}

Task FunctionalTest -depends LoadSettings -description 'Tests that the required features and use cases are working in the target environment.' {
    Write-Host 'Getting Base URI...' -NoNewline

    $exampleWebsiteHostName = (Get-AzureRmWebApp -Name $Settings.ExampleAppSiteName).HostNames
    $ExampleWebsiteBaseUri = "http://$exampleWebsiteHostName"

    Write-Host $ExampleWebsiteBaseUri

    ${env:ExampleApp.BaseUri} = $ExampleWebsiteBaseUri

    $TestDlls = @(
        (Join-Path $ArtifactsPath 'Slinqy.Test.Functional.dll')
    )
    
    Write-Host "Running tests in $TestDlls"

    Run-Tests `
        -PackagesPath  $CiPackagesPath `
        -ArtifactsPath $ArtifactsPath `
        -TestDlls      $TestDlls
}

Task DestroyEnvironment -depends LoadSettings -description "Permanently deletes and removes all services and data from the target environment." {
    # Make sure we're authenticated with Azure.
    $context = GetOrLogin-AzureRmContext `
        -AzureDeployUser $env:AzureDeployUser `
        -AzureDeployPass $env:AzureDeployPass

    $subscriptionName = $context.Subscription.SubscriptionName

    if (-not (Check-AzureResourceGroupExists $Settings.ResourceGroupName)) {
        Write-Host "The resource group $($Settings.ResourceGroupName) doesn't exist in Azure Subscription $subscriptionName, nothing to delete..."
        return
    }

    Write-Host
    Write-Warning "You are about to permanently delete all services and data from"
    Write-Host
    Write-Warning "Environment:`t`t`t`t`t`t`t`t$($Settings.EnvironmentName)"
    Write-Warning "Azure Subscription:`t${subscriptionName}"
    Write-Host

    $answer = Read-Host `
        -Prompt "ARE YOU SURE? (y/n)"

    if ($answer -eq 'y') {
        Write-Host
        Write-Host "Deleting resource group $($Settings.ResourceGroupName)..." -NoNewline
        Remove-AzureRmResourceGroup `
            -Name $Settings.ResourceGroupName `
            -Force
        Write-Host "done!"
    }
}

Task Pull -description "Pulls the latest source from master to the local repo." {
    exec { git pull origin master }
}

Task Push -depends Pull,Full -description "Performs pre-push actions before actually pushing to the remote repo." {
    exec { git push }
}

Task Full -depends DestroyEnvironment,Build,Deploy,FunctionalTest -description "Runs all pertinent CI tasks." {
}