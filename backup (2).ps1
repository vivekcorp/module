param (
    [Parameter(Mandatory=$true)]
    $ParameterPath
)

$ParameterValues = Get-Content $ParameterPath | ConvertFrom-Json

$RGName = $ParameterValues.ResourceGroupName
$VaultName = $ParameterValues.VaultName
$VMName = $ParameterValues.VMName

# Fetch the Recovery Services Vault
$RecoveryServiceVault = Get-AzRecoveryServicesVault -ResourceGroupName $RGName -Name $VaultName

# Print the Recovery Services Vault to verify it
Write-Output "RecoveryServiceVault: $RecoveryServiceVault"

# Set the context if the vault is not null
if ($RecoveryServiceVault) {
    Set-AzRecoveryServicesVaultContext -Vault $RecoveryServiceVault
} else {
    Write-Error "Recovery Services Vault not found."
    exit 1
}

# Fetch Backup Containers
$BackupContainers = Get-AzRecoveryServicesBackupContainer -VaultId $RecoveryServiceVault.ID -ContainerType "AzureVM" | Where-Object Status -eq "Registered"

# Print the Backup Containers to verify it
if ($BackupContainers) {
    $BackupContainers | ForEach-Object {
        Write-Host "VMName: $($_.FriendlyName)"
        $namedContainer = Get-AzRecoveryServicesBackupContainer -ContainerType "AzureVM" -FriendlyName $_.FriendlyName -VaultId $RecoveryServiceVault.ID
        Write-Output "Named Container: $namedContainer"
        $item = Get-AzRecoveryServicesBackupItem -Container $namedContainer -WorkloadType "AzureVM" -VaultId $RecoveryServiceVault.ID
        Write-Output "Backup Item: $item"
        $endDate = (Get-Date).AddDays(60).ToUniversalTime()
        $job = Backup-AzRecoveryServicesBackupItem -Item $item -VaultId $RecoveryServiceVault.ID -ExpiryDateTimeUTC $endDate
        $jobid = $job.JobID
        Write-Output "JobID: $jobid"
        [array]$combine += $jobid
    }
} else {
    Write-Error "No Backup Containers found."
    exit 1
}

# Combine Array Print
Write-Output "Combine Array: $combine"

$combine | ForEach-Object {
    $JobDetails = Get-AzRecoveryServicesBackupJobDetail -JobId $_ -VaultId $RecoveryServiceVault.ID
    while ($JobDetails.Status -eq "InProgress") {
        Write-Host "Still Backup is in process $($_)"
        Start-Sleep -Seconds 30
        $JobDetails = Get-AzRecoveryServicesBackupJobDetail -JobId $_ -VaultId $RecoveryServiceVault.ID
    }
    Write-Output "JobDetails: $JobDetails"
}
