param (
    [string]$Environment, 
    [string]$ConfigFilePath
)

# Function to read and parse JSON file
function Get-ConfigValue {
    param (
        [string]$configFilePath
    )
    $json = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json
    return $json
}

# Read resource group name and exclude VMs from JSON file
$configValues = Get-ConfigValue -configFilePath $ConfigFilePath
# Debug output
Write-Output "Config Values: $($configValues | ConvertTo-Json)"

$resourceGroupName = $configValues.ResourceGroupName
$excludeVMs = $configValues.excludeVMs

if (-not $resourceGroupName) {
    Write-Error "Invalid environment specified in the JSON file. Please ensure the JSON file has the correct structure and environment."
    exit 1
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
Connect-AzAccount -ServicePrincipal -TenantId $tenantId -Credential (New-Object System.Management.Automation.PSCredential ($clientId, (ConvertTo-SecureString $clientSecret -AsPlainText -Force))) -SubscriptionId $subscriptionId
Set-AzContext -SubscriptionId $subscriptionId

# Fetch all VMs in the specified resource group
$vms = Get-AzVM -ResourceGroupName $resourceGroupName

# Define the script to install SQL Native Client, Request Router, and URL Rewrite
$installScript = @"
if (Test-Path "C:\CognosTemp\sqlncli.msi") {
    Start-Process "C:\Windows\System32\msiexec.exe" -ArgumentList '/i', "C:\CognosTemp\sqlncli.msi", 'ADDLOCAL=ALL', '/qn', 'IACCEPTSQLNCLILICENSETERMS=YES' -Wait
} else {
    Write-Error "Installer file not found at C:\CognosTemp\sqlncli.msi"
}

if (Test-Path "C:\CognosTemp\requestRouter_amd64.msi") {
    Start-Process "C:\Windows\System32\msiexec.exe" -ArgumentList '/i', "C:\CognosTemp\requestRouter_amd64.msi", '/quiet', '/norestart' -Wait
} else {
    Write-Error "Installer file not found at C:\CognosTemp\requestRouter_amd64.msi"
}

if (Test-Path "C:\CognosTemp\rewrite_amd64_en-US.msi") {
    Start-Process "C:\Windows\System32\msiexec.exe" -ArgumentList '/i', "C:\CognosTemp\rewrite_amd64_en-US.msi", '/quiet', '/norestart' -Wait
} else {
    Write-Error "Installer file not found at C:\CognosTemp\rewrite_amd64_en-US.msi"
}
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
        Write-Output "Running script on VM: $vmName"
        $result = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName $vmName -CommandId 'RunPowerShellScript' -ScriptString $installScript
        Write-Output "Result for VM ${$vmName}: $result"
    } catch {
        Write-Error "Error running script on VM ${$vmName}: $_"
    }
}
