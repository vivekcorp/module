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
        $username = "localhost\transparentst"
    }
    default {
        Write-Error "Invalid environment specified. Please choose 'Prod', 'Dev', or 'Stage'."
        exit 1
    }
}

# Fetch the storage key from environment variable
$nasPassword = [System.Environment]::GetEnvironmentVariable("NAS_MAPDRIVE")

# Validate the secret
if (-not $nasPassword) {
    Write-Error "NAS_MAPDRIVE secret is not set. Ensure it's added to GitHub Secrets."
    exit 1
} else {
    Write-Output "NAS_MAPDRIVE secret is set."
}

# Authenticate to Azure using Service Principal
$clientId = [System.Environment]::GetEnvironmentVariable("AZURE_CLIENT_ID")
$clientSecret = [System.Environment]::GetEnvironmentVariable("AZURE_CLIENT_SECRET")
$tenantId = [System.Environment]::GetEnvironmentVariable("AZURE_TENANT_ID")
$subscriptionId = [System.Environment]::GetEnvironmentVariable("AZURE_SUBSCRIPTION_ID")

# Ensure all Azure environment variables are set
if (-not $clientId -or -not $clientSecret -or -not $tenantId -or -not $subscriptionId) {
    Write-Error "Azure credentials are not set. Ensure AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID, and AZURE_SUBSCRIPTION_ID are set."
    exit 1
} else {
    Write-Output "Azure credentials are set."
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

    # Execute remote commands within VM context
    try {
        $result = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName $vmName -CommandId 'RunPowerShellScript' -ScriptString @"
            Write-Output 'Testing connection to Azure Storage on port 445...'
            \$pingTestResult = Test-Connection -ComputerName 'transparentst.file.core.windows.net' -Count 2 -Quiet
            if (\$pingTestResult) {
                Write-Output 'Connection to Azure Storage is successful for VM: $vmName'
                Write-Output 'Saving credentials...'
                cmd.exe /C 'cmdkey /add:`"transparentst.file.core.windows.net`" /user:`"localhost\transparentst`" /pass:`"$nasPassword`"'
                Write-Output 'Mapping network drive...'
                New-PSDrive -Name 'Z' -PSProvider FileSystem -Root '$networkPath' -Credential (New-Object System.Management.Automation.PSCredential('$username', (ConvertTo-SecureString '$nasPassword' -AsPlainText -Force))) -Persist

                # Check if the drive is mapped
                \$drive = Get-PSDrive -Name 'Z'
                if (\$drive) {
                    Write-Output 'Network drive mapped successfully on VM: $vmName'
                } else {
                    Write-Error 'Network drive not mapped on VM: $vmName'
                }
            } else {
                Write-Error 'Unable to reach the Azure storage account. Check to make sure your organization or ISP is not blocking the connection, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port.'
            }
"@
        Write-Output "Result: $result"
        Write-Output "Network drive mapped successfully for VM: $vmName"
    } catch {
        Write-Error "Error mapping network drive on VM $($vmName): $_"
    }
}
