# Certificate details
$certPath = "C:\Users\Vivek\Documents\vivektripathi.com.pfx"  # Ensure correct file name and path
$certPassword = "12345"

# Convert password to secure string
$securePassword = ConvertTo-SecureString -String $certPassword -AsPlainText -Force

# Check if certificate file exists
if (Test-Path -Path $certPath) {
    # Import the PFX certificate to the local machine store
    $cert = Import-PfxCertificate -FilePath $certPath -CertStoreLocation "Cert:\LocalMachine\My" -Password $securePassword

    # Ensure WebAdministration module is loaded
    Import-Module "C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules\WebAdministration\WebAdministration.psd1" -ErrorAction Stop

    # Verify module import
    if (Get-Module -ListAvailable | where {$_.Name -eq "WebAdministration"}) {
        # Get the IIS site
        $siteName = "Default Web Site"
        $site = Get-Website -Name $siteName

        if ($site -ne $null) {
            # Get the SSL binding
            $binding = Get-WebBinding -Name $siteName -Protocol "https"

            if ($binding -ne $null) {
                # Get existing certificate details
                $existingCertThumbprint = $binding.certificateHash

                # Get details of all certificates in the local machine store with matching name
                $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "My", "LocalMachine"
                $store.Open("ReadOnly")
                $certs = $store.Certificates | Where-Object { $_.FriendlyName -eq "vivektripathi.com" }

                if ($certs.Count -gt 0) {
                    $latestCert = $certs | Sort-Object NotAfter -Descending | Select-Object -First 1

                    if ($latestCert -ne $null -and $latestCert.Thumbprint -ne $existingCertThumbprint) {
                        # Assign the latest certificate to the binding
                        $binding.AddSslCertificate($latestCert.Thumbprint, "My")

                        # Save the changes
                        Set-WebConfiguration -Filter "system.applicationHost/sites/site[@name='$siteName']/bindings/binding[@protocol='https']" -Value $binding
                        Write-Host "Latest certificate bound to the site successfully."
                    } else {
                        Write-Host "The latest certificate is already bound to the site."
                    }
                } else {
                    Write-Error "Certificate not found in the store: $certPath"
                }
                $store.Close()
            } else {
                Write-Error "SSL binding not found for the site: $siteName"
            }
        } else {
            Write-Error "Site not found: $siteName"
        }
    } else {
        Write-Error "WebAdministration module is not loaded."
    }
} else {
    Write-Error "Certificate file not found: $certPath"
}
