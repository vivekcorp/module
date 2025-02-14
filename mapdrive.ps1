param (
    [string]$Environment
)

# Environment-specific parameters
switch ($Environment) {
    "Prod" {
        $vaultName = "transinfra"
        $secretName = "vivekstoragekey"
        $resourceGroupName = "transparent-infra"
        $networkPath = "\\transparentst.file.core.windows.net\vivekshare"
        $username = "localhost\transparentst"  # Correct username format for Azure Storage
    }
    default {
        Write-Error "Invalid environment specified. Please choose 'Prod', 'Dev', or 'Stage'."
        exit 1
    }
}

# Fetch the storage key from GitHub Secrets
$nasPassword = $env:NAS_MAPDRIVE

# Validate the secret
if (-not $nasPassword) {
    Write-Error "NAS_MAPDRIVE secret is not set. Ensure it's added to GitHub Secrets."
    exit 1
}

# Authenticate to Azure using Service Principal
$clientId = $env:AZURE_CLIENT_ID
$clientSecret = $env:AZURE_CLIENT_SECRET
$tenantId = $env:AZURE_TENANT_ID
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID

# Ensure all Azure environment variables are set
if (-not $clientId -or -not $clientSecret -or -not $tenantId -or -not $subscriptionId) {
    Write-Error "Azure credentials are not set. Ensure AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID, and AZURE_SUBSCRIPTION_ID are set."
    exit 1
}

# Authenticate to Azure
Connect-AzAccount -ServicePrincipal -TenantId $tenantId -Credential (New-Object System.Management.Automation.PSCredential($clientId, (ConvertTo-SecureString $clientSecret -AsPlainText -Force))) -SubscriptionId $subscriptionId

# Set subscription context
Set-AzContext -SubscriptionId $subscriptionId

# Fetch all VMs in the resource group
$vms = Get-AzVM -ResourceGroupName $resourceGroupName
foreach ($vm in $vms) {
    $vmName = $vm.Name
    Write-Output "Processing VM: $vmName"

    # Test SMB connection using Test-Connection (works on Linux & Windows)
    $pingTest = Test-Connection -ComputerName "transparentst.file.core.windows.net" -Count 2 -Quiet
    if ($pingTest) {
        Write-Output "Connection to Azure Storage is successful for VM: $vmName"

        # Save credentials (Avoids password prompts)
        cmd.exe /C "cmdkey /add:`"transparentst.file.core.windows.net`" /user:`"localhost\transparentst`" /pass:`"$nasPassword`""

        # Run command on VM to map network drive
        try {
            Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName $vmName -CommandId 'RunPowerShellScript' -ScriptString @"
                New-PSDrive -Name "Z" -PSProvider FileSystem -Root "$networkPath" -Credential (New-Object System.Management.Automation.PSCredential("$username", (ConvertTo-SecureString "$nasPassword" -AsPlainText -Force))) -Persist
                Write-Output "Network drive mapped successfully on VM: $vmName"
"@
            Write-Output "Network drive mapped successfully for VM: $vmName"
        } catch {
            Write-Error "Error mapping network drive on VM $($vmName): $_"
        }
    } else {
        Write-Error "Unable to reach Azure Storage for VM: $vmName. Check firewall settings."
    }
}
