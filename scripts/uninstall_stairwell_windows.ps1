<#
    Use this script to uninstall the Stairwell forwarder on Windows OS machines.
    This script requires your forwarder maintenance token https://docs.stairwell.com/docs/find-a-maintenance-token
    IMPORTANT NOTE: for 1.4.0 and 1.4.1 uninstalls this will cause a machine reboot!
    Visit https://docs.stairwell.com for further assistance.

    PS .\stairwell_uninstall.ps1 -mainttoken <MAINTENANCE TOKEN>

#>

param(
    [Parameter(Mandatory=$False)]
    [string]$MaintToken
)

# Test for previous forwarder versions
$Inception = Test-Path "C:\Program Files\Stairwell\Inception"
if($Inception -eq $True) {
    try {
        Get-Package "Inception Forwarder" | Uninstall-Package -AllVersions
        Write-Output "Stairwell Forwarder Uninstalled"
        Exit
    }
    catch {
        Write-Output "An Error Occurred:"
        Write-Output $_
    }
    
}

# Test for forwarder versions 1.4.0 and 1.4.1
$PgmDir = Test-Path "C:\Program Files\Stairwell"
if($PgmDir -eq $True) {
    if($Null -eq $MaintToken) {
        Write-Output "This requires a forwarder maintenance token from your environment"
        Write-Output "Visit https://docs.stairwell.com/docs/find-a-maintenance-token for details"
        $MaintToken = Read-Host -Prompt "Please enter your Stairwell Maintenance Token"
    }

    
    try {
        # Find the MSI system GUID
        $Product = Get-CimInstance -Class Win32_Product | Where-Object Name -eq "Stairwell Forwarder"
        $Bundle = Get-package "Stairwell Forwarder" | % { $_.metadata['BundleCachePath'] } | Split-Path -Parent
        $BundleDir = Test-Path $Bundle

        # Call msiexec with the uninstall command, package GUID, the maintenance token, quiet uninstall, no reboot
        # The reboot is still required to complete the uninstall, but did not want it to happen automatically
        Start-Process "C:\Windows\System32\msiexec.exe" -ArgumentList /x, $($Product.IdentifyingNumber), MAINTENANCE_TOKEN=$MaintToken, /quiet, /norestart
    }
    catch {
        Write-Output "An Error Occurred:"
        Write-Output $_
    }
}

# Update ACL so we can delete the folder
$acl = Get-Acl "C:\Program Files\Stairwell"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("everyone","FullControl","ContainerInherit,ObjectInherit","None","Allow")
$acl.SetAccessRule($accessRule)
$acl | Set-Acl "C:\Program Files\Stairwell"

# Lastly we clean up any files left behind
if($PgmDir -eq $True) {
   Remove-Item "C:\Program Files\Stairwell" -Recurse -Force -ErrorAction SilentlyContinue
}
if($BundleDir -eq $True) {
    Remove-Item $Bundle -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Output "Uninstall script completed. Program Directory and Bundle Cache have been removed."
Write-Output "Please schedule a reboot to complete the uninstall."
