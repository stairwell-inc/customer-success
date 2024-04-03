<#
    Use this script to uninstall the Stairwell forwarder on Windows OS machines.
    If uninstalling 1.4.x this script requires your forwarder maintenance token https://docs.stairwell.com/docs/find-a-maintenance-token
    IMPORTANT NOTE: For 1.4.x uninstalls, this will require a machine reboot!
    ALSO: We use the Environment Id and Forwarder Token here to ensure the uninstall goes smoothly by "reparing" the install first (1.4.x only)

    Visit https://docs.stairwell.com for further assistance.

    PS .\stairwell_uninstall_windows.ps1 -MaintToken <MAINTENANCE TOKEN> -Env_Id <ENV_ID> -Verbose

#>

param(
    [Parameter(Mandatory=$False)]
    [string]$MaintToken,

    [Parameter(Mandatory=$False)]
    [string]$env_id,

    [Parameter(Mandatory=$False)]
    [string]$Forwarder_Token,

    [Parameter(Mandatory=$False)]
    [string]$Installer
)

Write-Output "Uninstalling and/or reparing a broken uninstall, please wait for confirmation this is complete..."
$ServiceDetails = Get-Process SwellService -FileVersionInfo -ErrorAction SilentlyContinue
if($ServiceDetails) {
    $ProductVersion = $ServiceDetails.ProductVersion
    $FileVersion = $ServiceDetails.FileVersion
    Write-Verbose "Running instance of Stairwell Forwarder found. Version $($ProductVersion)"
}

# Test for previous forwarder versions (Inception versions)
$Inception = Test-Path "C:\Program Files\Stairwell\Inception"
if($Inception -eq $True) {
    Write-Verbose "Found an Inception version forwarder, begining uninstall"
    try {
        Remove-CimInstance -Query "SELECT * from Win32_Product WHERE name LIKE 'Inception%'"
        Write-Output "Stairwell Forwarder Uninstalled"
        Exit
    }
    catch {
        Write-Output "An Error Occurred:"
        Write-Output $_
    }
    
}

# We test for specific 1.4.x versions, these require several specific things to uninstall successfully.
# First we need to determine which version is installed then download the installer bundle.
# Uninstallation w/the installer package is highly recommended, lots of problems otherwise.

# If this is a 1.4.x uninstall, ensure we have the required tokens
if($FileVersion -eq "1.4.0.886" -or $FileVersion -eq "1.4.1.896") {
    # Check for needed creds
    if([string]::IsNullOrEmpty($MaintToken)) {
        Write-Verbose "Maintenance token not supplied, prompting user for value."
        $MaintToken = Read-Host -Prompt "Please enter your forwarder maintenance token. Visit https://docs.stairwell.com for details."
    }
    if([string]::IsNullOrEmpty($env_id)) {
        Write-Verbose "Environment Id not supplied, prompting user for value."
        $env_id = Read-Host -Prompt "Please enter your Environment Id. Visit https://docs.stairwell.com for details."
    }
    if([string]::IsNullOrEmpty($Forwarder_Token)) {
        Write-Verbose "File Forwarder token not supplied, prompting user for value."
        $Forwarder_Token = Read-Host -Prompt "Please enter your File Forwarder Token. Visit https://docs.stairwell.com for details."
    }

    Start-Sleep -Milliseconds 5
    if([string]::IsNullOrEmpty($MaintToken) -or [string]::IsNullOrEmpty($env_id) -or [string]::IsNullOrEmpty($Forwarder_Token)) {
        Write-Error "Missing required value(s). Please supply the Maintenance Token, Environment Id, and the File Forwarder Token to ensure the install completes."
        Exit
    }
}

# Begin the 1.4.x uninstall process...
if([string]::IsNullOrEmpty($Installer)) {
    # Requesting the installer package to perform the uninstall right the first time even in the event of a previous borked uninstall
    if($FileVersion -eq "1.4.0.886") {        
        Write-Verbose "Found installed version 1.4.0, downloading bundled installer..."
        Invoke-WebRequest -Uri "https://downloads.stairwell.com/windows/1.4.0/StairwellForwarderBundle-1.4.0.886.exe" -OutFile "C:\Windows\Temp\StairwellForwarderBundle.exe"
    } elseif($FileVersion -eq "1.4.1.896") {
        Write-Verbose "Found installed version 1.4.1, downloading bundled installer..."
        Invoke-WebRequest -Uri "https://downloads.stairwell.com/windows/1.4.1/StairwellForwarderBundle-1.4.1.896.exe" -OutFile "C:\Windows\Temp\StairwellForwarderBundle.exe"
    } else {
        Write-Output "Previous installation of Stairwell forwarder not found. Please check the machine and try again or contact Stairwell support."
        Exit
    }

    try {
        # Repair the install as a precaution. Ensures the uninstall completes correctly.
        Write-Verbose "Attempting repair of installation (precautionary step)."
        Start-Process "C:\Windows\Temp\StairwellForwarderBundle.exe" -ArgumentList /repair, ENVIRONMENT_ID=$env_id, TOKEN=$Forwarder_Token, /quiet, /norestart
        Write-Verbose "Short pause for slower systems to ensure the service is stopped."
        Start-Sleep -Milliseconds 800
        # Perform the full uninstall.
        Write-Verbose "Performing the uninstallation using the downloaded installer bundle located at C:\Windows\Temp\StairwellForwarderBundle.exe"
        Start-Process "C:\Windows\Temp\StairwellForwarderBundle.exe" -ArgumentList /uninstall, MAINTENANCE_TOKEN=$MaintToken, /quiet, /norestart
        Write-Output "Please schedule a reboot to complete the uninstall."
    }
    catch {
        Write-Output "An Error Occurred:"
        Write-Output $_
    }
    
} else {
    # Attempt the uninstallation if the installer bundle is supplied as an argument.
    try {
        # Repair the install as a precaution. Ensures the uninstall completes correctly.
        Write-Verbose "Attempting repair of installation (precautionary step)."
        Start-Process $Installer -ArgumentList /repair, ENVIRONMENT_ID=$env_id, TOKEN=$Forwarder_Token, /quiet, /norestart
        Write-Verbose "Short pause for slower systems to ensure the service is stopped."
        Start-Sleep -Milliseconds 800
        # Perform the full uninstall.
        Write-Verbose "Performing the uninstallation using the downloaded installer bundle located at $($Installer)"
        Start-Process $Installer -ArgumentList /uninstall, MAINTENANCE_TOKEN=$MaintToken, /quiet, /norestart
        Write-Output "Please schedule a reboot to complete the uninstall."
    }
    catch {
        Write-Output "An Error Occurred:"
        Write-Output $_
    }
    
    
}
