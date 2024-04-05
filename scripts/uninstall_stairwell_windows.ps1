<#
    Use this script to uninstall the Stairwell forwarder on Windows OS machines.
    If uninstalling 1.4.x this script requires your forwarder maintenance token https://docs.stairwell.com/docs/find-a-maintenance-token
    IMPORTANT NOTE: For 1.4.x uninstalls, this will require a machine reboot!
    ALSO: We use the Environment Id and Forwarder Token here to ensure the uninstall goes smoothly by "reparing" the install first (1.4.x only)

    Visit https://docs.stairwell.com for further assistance.

    PS .\stairwell_uninstall_windows.ps1 -MaintToken <MAINTENANCE TOKEN> -Verbose

#>

param(
    [Parameter(Mandatory=$False,
    HelpMessage="Your forwarder maintenance token, details: https://docs.stairwell.com/docs/find-a-maintenance-token")]
    [string]$MaintToken,

    [Parameter(Mandatory=$False,
    HelpMessage="Your environment id, details: https://docs.stairwell.com/docs/how-to-find-the-environment-id")]
    [string]$env_id,

    [Parameter(Mandatory=$False,
    HelpMessage="Your file forwarder token, details: https://docs.stairwell.com/docs/create-an-authentication-token")]
    [string]$Forwarder_Token,

    [Parameter(Mandatory=$False,
    HelpMessage="Use this if you are supplying a local path to an installer bundle, if not the installer is downloaded to Temp")]
    [string]$Installer,

    [Parameter(Mandatory=$False,
    HelpMessage="Use this switch to replace the previous forwarder with the latest version and attempt to register with the same asset id to prevent duplicate assets")]
    [switch]$Replace

)

$LogFile = "$($env:Temp)\Stairwell_Uninstall.log"

Write-Output "Uninstalling and/or repairing a broken uninstall, please wait for confirmation this is complete..."
"$([datetime]::Now) : Beginning Uninstallation of Stairwell Forwarder" | Out-File -FilePath $LogFile -append
$ServiceDetails = Get-Process SwellService -FileVersionInfo -ErrorAction SilentlyContinue
if($ServiceDetails) {
    $ProductVersion = $ServiceDetails.ProductVersion
    $FileVersion = $ServiceDetails.FileVersion
    Write-Verbose "Running instance of Stairwell Forwarder found. Version: $($ProductVersion)"
    "$([datetime]::Now) : Active Forwarder version found $($ProductVersion)" | Out-File -FilePath $LogFile -append
}

# Test for previous forwarder versions (Inception versions)
$InceptionDir = Test-Path "C:\Program Files\Stairwell\Inception"
$PowerSwell = Test-Path (${env:ProgramFiles(x86)} + '\Stairwell\Forwarder\powerswell.ps1') -Type Leaf
if($InceptionDir -eq $True) {
    Write-Verbose "Found an Inception version forwarder, beginning uninstall"
    $RegValues = Get-ChildItem -Path HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -match 'Inception' } | Select-Object -Property QuietUninstallString
    
    "$([datetime]::Now) : Inception forwarder path found" | Out-File -FilePath $LogFile -append
    "$([datetime]::Now) : Quiet Uninstall string: $($RegValues)" | Out-File -FilePath $LogFile -append
    
    $Uninstall_Strings = $RegValues.QuietUninstallString.Split()
    $asset_id = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\Stairwell\Inception -Name "AssetId" -ErrorAction SilentlyContinue
    if($Null -ne $asset_id) {
        "$([datetime]::Now) : Previous Asset Id found: $($asset_id)" | Out-File -FilePath $LogFile -append
    }
    
    try {
        Start-Process ($Uninstall_Strings[0] + ' ' + $Uninstall_Strings[1]) -ArgumentList $Uninstall_Strings[2], $Uninstall_Strings[3]
        Write-Output "Stairwell Forwarder Uninstalled"
        "$([datetime]::Now) : Stairwell Inception Forwarder Uninstalled" | Out-File -FilePath $LogFile -append
    }
    catch {
        Write-Output "An Error Occurred:"
        Write-Output $_
        "$([datetime]::Now) : Error $($_)" | Out-File -FilePath $LogFile -append
        Exit
    }
} elseif($PowerSwell -eq $True) {
    # Uninstall PowerSwell
    Write-Verbose "Found a PowerSwell version forwarder, beginning uninstall"
    "$([datetime]::Now) : PowerSwell version forwarder found" | Out-File -FilePath $LogFile -append
    try {
        # Identify directories and asset details
        $install_dir = ${env:ProgramFiles(x86)} + '\Stairwell\Forwarder\'
        $temp_dir = $env:TEMP
        $snapshot = $temp_dir + '\snapshot'
        $asset_id_filename = $install_dir + "asset_id"
        $asset_id_test = Test-Path -Path $asset_id_filename -PathType Leaf
        # Try to get the existing asset id if available
        if($asset_id_test) {
            $asset_id = Get-Content $asset_id_filename
            Write-Verbose "Existing Asset_Id located $($asset_id)"
            "$([datetime]::Now) : Previous Asset Id found: $($asset_id)" | Out-File -FilePath $LogFile -append
        }

        # Remove scheduled task
        Unregister-ScheduledTask -TaskName 'Stairwell Forwarder' -Confirm:$false
        "$([datetime]::Now) : Removing Scheduled Task: Stairwell Forwarder" | Out-File -FilePath $LogFile -append

        # Remove items that may have been left over
        Remove-Item $install_dir -Recurse
        "$([datetime]::Now) : Removing install dir: $($install_dir)" | Out-File -FilePath $LogFile -append
        Remove-Item $snapshot -Recurse
        "$([datetime]::Now) : Removing snapshot dir: $($snapshot)" | Out-File -FilePath $LogFile -append
        Write-Verbose "PowerSwell has been removed."
        "$([datetime]::Now) : Stairwell PowerSwell Forwarder Uninstalled" | Out-File -FilePath $LogFile -append

    }
    catch {
        Write-Output "An Error Occurred:"
        Write-Output $_
        "$([datetime]::Now) : Error $($_)" | Out-File -FilePath $LogFile -append
    }
} else {
    if($FileVersion -eq "1.4.0.886" -or $FileVersion -eq "1.4.1.896") {
        # Get the previous asset id if one exists
        $asset_id = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\Stairwell\SwellService -Name "AssetId" -ErrorAction SilentlyContinue
        if($Null -ne $asset_id) {
            "$([datetime]::Now) : Previous Asset Id found: $($asset_id)" | Out-File -FilePath $LogFile -append
        }
        
        # Check for needed maintenance token
        if([string]::IsNullOrEmpty($MaintToken)) {
            Write-Verbose "Maintenance token not supplied, exiting..."
            "$([datetime]::Now) : Maintenance token needed, exiting..." | Out-File -FilePath $LogFile -append
            Exit
        }
    
        # Begin the 1.4.x uninstall process...
        # First try to locate the MSI bundle and use it to uninstall
        $RegValues = Get-ChildItem -Path HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -match 'Stairwell' } | Select-Object -Property QuietUninstallString
        if($Null -ne $RegValues) {
            "$([datetime]::Now) : 1.4.x ver forwarder found" | Out-File -FilePath $LogFile -append
            "$([datetime]::Now) : Quiet Uninstall string: $($RegValues)" | Out-File -FilePath $LogFile -append
            
            $Uninstall_Strings = $RegValues.QuietUninstallString.Split()
            $MsiCheck = Test-Path ($Uninstall_Strings[0] + ' ' + $Uninstall_Strings[1])
            if($MsiCheck) {
                try {
                    Start-Process ($Uninstall_Strings[0] + ' ' + $Uninstall_Strings[1]) -ArgumentList MAINTENANCE_TOKEN=$MaintToken, $Uninstall_Strings[2], $Uninstall_Strings[3], /norestart
                }
                catch {
                    Write-Output "An Error Occurred:"
                    Write-Output $_
                    "$([datetime]::Now) : Error $($_)" | Out-File -FilePath $LogFile -append
                }
            }
    
        }
    
        if([string]::IsNullOrEmpty($Installer)) {
            # Requesting the installer package to perform the uninstall right the first time even in the event of a previous borked uninstall
            "$([datetime]::Now) : No installer supplied" | Out-File -FilePath $LogFile -append
    
            # Check for additional required creds
            if([string]::IsNullOrEmpty($env_id)) {
                Write-Verbose "Environment Id not supplied, exiting..."
                "$([datetime]::Now) : Environment Id needed, exiting..." | Out-File -FilePath $LogFile -append
                Exit
            }
            if([string]::IsNullOrEmpty($Forwarder_Token)) {
                Write-Verbose "File Forwarder token not supplied, exiting..."
                "$([datetime]::Now) : File Forwarder token needed, exiting..." | Out-File -FilePath $LogFile -append
                Exit
            }
    
            # Obtaining the correct installer package for really messed up uninstalls
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
                "$([datetime]::Now) : Error $($_)" | Out-File -FilePath $LogFile -append
            }
            
        } else {
            # Attempt the uninstallation if the installer bundle is supplied as an argument.
            "$([datetime]::Now) : Using supplied installer at $($Installer)" | Out-File -FilePath $LogFile -append
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
                "$([datetime]::Now) : Error $($_)" | Out-File -FilePath $LogFile -append
            }
        }
        
    }
}

# If the user wants to replace the forwarder with the latest version use the -Replace switch
if($Replace) {
    if($FileVersion -eq "1.4.0.886" -or $FileVersion -eq "1.4.1.896") {
        Write-Verbose "Cannot update in place. Machine requires a reboot."
        Write-Verbose "Please visit https://docs.stairwell.com/docs/stairwell-on-windows to download the latest version"
        Write-Verbose "If you want to keep the same asset id, run the install from the command line and add the argument: ASSET_ID=$($asset_id)"
    }

    Invoke-WebRequest -Uri "https://downloads.stairwell.com/windows/latest/InceptionForwarderBundle.exe" -OutFile "$($env:Temp)\InceptionForwarderBundle.exe"
    $NewInstaller = "$($env:Temp)\InceptionForwarderBundle.exe"
    $InstallerChk = Test-Path $NewInstaller -Type Leaf
    if($InstallerChk) {
        "$([datetime]::Now) : New installer downloaded to: $($NewInstaller)" | Out-File -FilePath $LogFile -append
        
        # Install with no Asset Id supplied
        if([string]::IsNullOrEmpty($asset_id)) {
            try {
                Start-Process -FilePath $NewInstaller -ArgumentList /install, ENVIRONMENT_ID=$env_id, TOKEN=$Forwarder_Token, /quiet, /norestart
            }
            catch {
                Write-Output "An Error Occurred:"
                Write-Output $_
                "$([datetime]::Now) : Error $($_)" | Out-File -FilePath $LogFile -append
            }           
        }
        # Install using previous Asset Id
        else {
            try {
                Start-Process -FilePath $NewInstaller -ArgumentList /install, ENVIRONMENT_ID=$env_id, TOKEN=$Forwarder_Token, $ASSET_ID=$asset_id, /quiet, /norestart
            }
            catch {
                Write-Output "An Error Occurred:"
                Write-Output $_
                "$([datetime]::Now) : Error $($_)" | Out-File -FilePath $LogFile -append
            }
        }
    }

    # Verify new forwarder is running
    $ProcCheck = Get-Process SwellService -FileVersionInfo -ErrorAction SilentlyContinue
    if($Null -ne $ProcCheck) {
        Write-Verbose "Forwarder updated and verified running version $($ProcCheck.FileVersion)"
        "$([datetime]::Now) : Forwarder verified running ver $($ProcCheck.FileVersion)" | Out-File -FilePath $LogFile -append
    } else {
        Write-Verbose "Cannot verify updated forwarder is running. Please $($LogFile) for details."
    }
}
