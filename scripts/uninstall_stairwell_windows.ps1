<#
    Use this script to uninstall the Stairwell forwarder on Windows OS machines.
    This script requires your forwarder maintenance token https://docs.stairwell.com/docs/find-a-maintenance-token
    IMPORTANT NOTE: for 1.4.0 and 1.4.1 uninstalls this will cause a machine reboot!
    Visit https://docs.stairwell.com for further assistance.

    PS .\stairwell_uninstall.ps1 -mainttoken <MAINTENANCE TOKEN>

#>

param(
    [Parameter(Mandatory=$True)]
    [string]$MaintToken
)

# Find the MSI system GUID
$Product = Get-CimInstance -Class Win32_Product | Where-Object Name -eq "Stairwell Forwarder"
$Bundle = Get-package "Stairwell Forwarder" | % { $_.metadata['BundleCachePath'] } | Split-Path -Parent

# Call msiexec with the uninstall command, package GUID, the maintenance token, quiet uninstall, no reboot
# The reboot is still required to complete the uninstall, did not want it to happen automatically
Start-Process "C:\Windows\System32\msiexec.exe" -ArgumentList /x, $($Product.IdentifyingNumber), MAINTENANCE_TOKEN=$MaintToken, /quiet, /norestart

# Lastly we clean up any files left behind
$PgmDir = Test-Path "C:\Program Files\Stairwell"
$BundleDir = Test-Path $Bundle
if($PgmDir -eq $True) {
   Remove-Item "C:\Program Files\Stairwell" -Recurse -Force
}
if($BundleDir -eq $True) {
    Remove-Item $Bundle -Recurse -Force
}
Write-Output "Uninstall script completed. Program Directory and Bundle Cache have been removed."
