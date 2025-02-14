param (
    [string]$Environment
)

# Environment-specific parameters
switch ($Environment) {
    "Prod" {
        $resourceGroupName = "transparent-infra"
    }
    default {
        Write-Error "Invalid environment specified. Please choose 'Prod'."
        exit 1
    }
}

# Fetch Azure credentials from environment variables
$clientId = [System.Environment]::GetEnvironmentVariable("AZURE_CLIENT_ID")
$clientSecret = [System.Environment]::GetEnvironmentVariable("AZURE_CLIENT_SECRET")
$tenantId = [System.Environment]::GetEnvironmentVariable("AZURE_TENANT_ID")
$subscriptionId = [System.Environment]::GetEnvironmentVariable("AZURE_SUBSCRIPTION_ID")

if (-not $clientId -or -not $clientSecret -or -not $tenantId -or -not $subscriptionId) {
    Write-Error "Azure credentials are not set. Ensure AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID, and AZURE_SUBSCRIPTION_ID are set."
    exit 1
} else {
    Write-Output "Azure credentials are set."
}

# Authenticate to Azure
Connect-AzAccount -ServicePrincipal -TenantId $tenantId -Credential (New-Object System.Management.Automation.PSCredential($clientId, (ConvertTo-SecureString $clientSecret -AsPlainText -Force))) -SubscriptionId $subscriptionId
Set-AzContext -SubscriptionId $subscriptionId

# Fetch all VMs in the specified resource group
$vms = Get-AzVM -ResourceGroupName $resourceGroupName

# List of VMs to exclude from the installation
$excludeVMs = @("rxtsec-dyna-vm1-cus-yre", "arrrrrwdsfs") # Add more VM names as needed

# Define the script to install IIS and components
$installScript = @"
# Check if the feature is not already installed before installing
if (-not (Get-WindowsFeature -Name Web-Server).Installed) { Install-WindowsFeature Web-Server }
if (-not (Get-WindowsFeature -Name Web-Dir-Browsing).Installed) { Install-WindowsFeature Web-Dir-Browsing }
if (-not (Get-WindowsFeature -Name Web-Http-Errors).Installed) { Install-WindowsFeature Web-Http-Errors }
if (-not (Get-WindowsFeature -Name Web-Static-Content).Installed) { Install-WindowsFeature Web-Static-Content }
if (-not (Get-WindowsFeature -Name Web-Http-Redirect).Installed) { Install-WindowsFeature Web-Http-Redirect }
if (-not (Get-WindowsFeature -Name Web-Http-Logging).Installed) { Install-WindowsFeature Web-Http-Logging }
if (-not (Get-WindowsFeature -Name Web-Custom-Logging).Installed) { Install-WindowsFeature Web-Custom-Logging }
if (-not (Get-WindowsFeature -Name Web-Request-Monitor).Installed) { Install-WindowsFeature Web-Request-Monitor }
if (-not (Get-WindowsFeature -Name Web-Http-Tracing).Installed) { Install-WindowsFeature Web-Http-Tracing }
if (-not (Get-WindowsFeature -Name Web-Filtering).Installed) { Install-WindowsFeature Web-Filtering }
if (-not (Get-WindowsFeature -Name Web-Scripting-Tools).Installed) { Install-WindowsFeature Web-Scripting-Tools }
if (-not (Get-WindowsFeature -Name Web-Mgmt-Service).Installed) { Install-WindowsFeature Web-Mgmt-Service }
if (-not (Get-WindowsFeature -Name Web-Mgmt-Console).Installed) { Install-WindowsFeature Web-Mgmt-Console }
if (-not (Get-WindowsFeature -Name Web-Asp-Net45).Installed) { Install-WindowsFeature Web-Asp-Net45 }
if (-not (Get-WindowsFeature -Name Web-Basic-Auth).Installed) { Install-WindowsFeature Web-Basic-Auth }

# Example of adding a new feature in future
if (-not (Get-WindowsFeature -Name Web-Some-New-Feature).Installed) { Install-WindowsFeature Web-Some-New-Feature }
"@

# Run the installation script on each VM
foreach ($vm in $vms) {
    $vmName = $vm.Name
    if ($excludeVMs -contains $vmName) {
        Write-Output "Skipping VM: $vmName"
        continue
    }

    Write-Output "Processing VM: $vmName"
    
    try {
        $result = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName $vmName -CommandId 'RunPowerShellScript' -ScriptString $installScript
        Write-Output "Result: $result"
    } catch {
        Write-Error "Error running script on VM $($vmName): $_"
    }
}
