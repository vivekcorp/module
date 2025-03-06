param (
    [Parameter(Mandatory=$true)]
    $Environment,
    [Parameter(Mandatory=$true)]
    $ConfigFilePath
)

$ParameterValues = Get-Content $ConfigFilePath | ConvertFrom-Json
$RGName = "$($ParameterValues.ResourceGroupName)"
$detachedDataDisks = @()  # List to store detached data disk names

# Authenticate to Azure
Connect-AzAccount -ServicePrincipal -TenantId $env:AZURE_TENANT_ID -Credential (New-Object -TypeName 'System.Management.Automation.PSCredential' -ArgumentList $env:AZURE_CLIENT_ID, (ConvertTo-SecureString $env:AZURE_CLIENT_SECRET -AsPlainText -Force))
Set-AzContext -SubscriptionId $env:AZURE_SUBSCRIPTION_ID

# Retrieve all VMs in the specified Resource Group, excluding specified VMs
Get-AzVM -ResourceGroupName $RGName | Where-Object { $_.Name -notin $ParameterValues.excludeVMs } | ForEach-Object {
    Write-Host "Disabling Maintenance Configuration for VM $($_.Name)"
    $MaintenanceConfig = Get-AzMaintenanceConfiguration -ResourceGroupName $RGName
    if ($MaintenanceConfig) {
        $MGName = $MaintenanceConfig.Name
        Remove-AzConfigurationAssignment -ResourceGroupName $RGName -ProviderName Microsoft.Compute -ResourceType virtualmachines -ResourceName $_.Name -ConfigurationAssignmentName $MGName -Force
    } else {
        Write-Host "No Maintenance Configuration found for VM $($_.Name)"
    }

    # Detach Data Disks
    Write-Host "Detaching Data Disks for VM $($_.Name)"
    $vm = Get-AzVM -ResourceGroupName $RGName -Name $_.Name
    foreach ($DataDisk in $vm.StorageProfile.DataDisks) {
        Write-Host "Detaching Data Disk $($DataDisk.Name) from VM $($_.Name)"
        $detachedDataDisks += $DataDisk.Name
    }
    $vm.StorageProfile.DataDisks.Clear()

    # Apply changes to the VM
    Update-AzVM -ResourceGroupName $RGName -VM $vm

    Write-Host "Deleting VM $($_.Name)"
    Remove-AzVM -ResourceGroupName $RGName -Name $_.Name -Force

    Write-Host "Deleting OS Disk $($_.StorageProfile.OsDisk.Name)"
    Remove-AzDisk -ResourceGroupName $RGName -DiskName $_.StorageProfile.OsDisk.Name -Force
}

# Check if all VMs were deleted
$VMCount = (Get-AzVM -ResourceGroupName $RGName).Count
if ($VMCount -eq 0) {
    Write-Host "All VMs Deleted"
} elseif ($VMCount -ne 0) {
    Write-Host "Some VMs not Deleted, Check those in Azure Portal"
}

# Delete unattached disks, excluding detached data disks
$DiskNames = Get-AzDisk -ResourceGroupName $RGName | Where-Object {
    $_.DiskState -eq "Unattached" -and -not $_.ManagedBy -and ($_.Name -notin $detachedDataDisks)
} | Select-Object -ExpandProperty Name

$DiskNames | ForEach-Object {
    Write-Host "Deleting Unattached Disk $($_)"
    Remove-AzDisk -ResourceGroupName $RGName -DiskName $_ -Force
}
