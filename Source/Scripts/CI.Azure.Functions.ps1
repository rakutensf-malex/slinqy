# Ensure the Azure PowerShell cmdlets are available
Remove-Module Azure -Force -ErrorAction SilentlyContinue
Import-Module Azure -RequiredVersion 1.0.4 -Force | Out-Null
Import-Module AzureRM -RequiredVersion 1.0.4 -Force
Import-AzureRM

function Check-AzureResourceGroupExists {
    Param(
        $ResourceGroupName
    )
	
    $resourceGroups = Get-AzureRmResourceGroup
    $appGroup = $resourceGroups | where {$_.ResourceGroupName -eq $ResourceGroupName}

    if ($appGroup) {
        Write-Output $True
    }
}

# Gets the existing context, or logs in with the specified credentials.
function GetOrLogin-AzureRmContext {
    Param(
        $AzureDeployUser,
        $AzureDeployPass
    )

    try {
        $context = Get-AzureRmContext
    }
    catch
    {
        if ($_.Exception.Message -ne 'Run Login-AzureRmAccount to login.') {
            throw
        }

        $context = Login-AzureResourceManager `
            -AzureDeployUser $AzureDeployUser `
            -AzureDeployPass $AzureDeployPass
    }

    Write-Output $context
}

# Authenticates with the Azure Resource Manager either by specifying the credentials as parameters,
# or the console user will be prompted for them if they are not specified.
# Returns an AzureRmContext.
function Login-AzureResourceManager {
    Param(
        $AzureDeployUser,
        $AzureDeployPass
    )

    if ($AzureDeployUser -and $AzureDeployPass) {
        $AzureDeployPassSecure = $AzureDeployPass | ConvertTo-SecureString -AsPlainText -Force
        $AzureCredential       = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AzureDeployUser,$AzureDeployPassSecure

        $profile = Login-AzureRmAccount -Credential $AzureCredential
    } else {
        Write-Host "Could not find any Azure credentials on the local machine, prompting console user..."

        # Prompt the console user for credentials
        $profile = Login-AzureRmAccount
    }

    if (-not $profile){
        throw 'No Azure account found or specified!'
    }

    # TODO: Ask user about multiple subscriptions, which to use...?

    Write-Output (Get-AzureRmContext)
}

function Upload-FileToBlob {
    Param(
        $storageContext,
        $localFilePath,
        $containerName
    )

    $containers = Get-AzureStorageContainer `
        -Context $storageContext

    $container =  $containers | Where-Object {
        $_.Name -eq $containerName
    }

    if (-not $container) {
        $container = New-AzureStorageContainer `
            -Name       $containerName `
            -Context    $storageContext `
            -Permission Off
    }

    $fileName = Split-Path `
        -Path $localFilePath `
        -Leaf

    Set-AzureStorageBlobContent `
        -File      $localFilePath `
        -Container $containerName `
        -Blob      $fileName `
        -Context   $storageContext `
        -Force |
            Out-Null

    Write-Output ($container.CloudBlobContainer.Uri.ToString() + '/' + $fileName)
}