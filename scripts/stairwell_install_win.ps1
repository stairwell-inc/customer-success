<#
    Use this script to install the Stairwell forwarder on Windows OS machines.
    This script requires your Forwarder Token and your Environment Id
    Visit https://docs.stairwell.com for further assistance to locate these.

    The script can download the latest installer automatically using -Download
    OR if the installer is on the local machine, set that path with -InstallerPath

    Lastly, use -NoBackScan if you wish to prevent the forwarder from doing a full
    scan of the physical drives. While we advise against skipping this, it may be
    neccessary on machines sensetive to resource utilization during business hours.

    PS .\stairwell_install.ps1 -EnvironmentId <ENVIRONMENT_ID> -ForwarderToken <FORWARDER_TOKEN> -Download

    PS .\stairwell_install.ps1 -EnvironmentId <ENVIRONMENT_ID> -ForwarderToken <FORWARDER_TOKEN> -InstallerPath 'C:\Windows\Temp\StairwellForwarderBundle.exe' -NoBackScan

#>


[CmdletBinding()]
    param(
        [Parameter(Mandatory,
        HelpMessage="Enter the EnvironmentId the forwarder with be associated with.")]
        [ValidatePattern("\w{6}\-\w{6}\-\w{6}\-\w{8}")]
        [string]$EnvironmentId,

        [Parameter(Mandatory,
        HelpMessage="Enter the Stairwell file forwarder token for your environment.")]
        [string]$ForwarderToken,

        [Parameter(Mandatory=$False,
        HelpMessage="(optional) Enter the full path of the installer package on the local machine.")]
        [string]$InstallerPath,

        [Parameter(Mandatory=$False,
        HelpMessage="Use this switch to have the script, download the installer on the local machine.")]
        [switch]$Download,

        [Parameter(Mandatory=$False,
        HelpMessage="Use this switch to disable the full disk scan upon install.")]
        [switch]$NoBackscan
    )

    begin {
        Write-Verbose 'Checking for previous installs...'
        $SWCheck = Test-Path 'C:\Program Files\Stairwell'
        if($SWCheck) {
            Write-Verbose 'Previous install detected in C:\Program Files\Stairwell'
            Write-Verbose 'Please verify the previous version was uninstalled correctly'
            Write-Verbose 'by using the installer to repair, then uninstall fully before proceeding.'
            Exit
        }
    }

    process{
        Write-Output "Starting Stairwell forwarder install process..."

        # Regardless if the user downloads the installer or supplys it, the full path will be assigned to $BundleDir

        # Downloading the installer
        if($Download -eq $True) {
            # Check to see if Windows\Temp directory exists
            $TempChk = Test-Path 'C:\Windows\Temp'
            if($TempChk) {
                Write-Verbose "Checking for C:\Windows\Temp to download the installer to: success"
                try {
                    Write-Verbose "Downloading latest installer bundle to C:\Windows\Temp\StairwellForwarderBundle.exe"
                    Invoke-WebRequest -Uri "https://downloads.stairwell.com/windows/latest/InceptionForwarderBundle.exe" -OutFile 'C:\Windows\Temp\StairwellForwarderBundle.exe' -ErrorAction Stop
                } catch {
                    Write-Error "Error downloading the Stairwell forwarder installer. Error $($PSItem)"
                    Exit
                }
                $BundleDir = 'C:\Windows\Temp\StairwellForwarderBundle.exe'

            } else {
                # Ask the user to supply a path to the installer
                $envInput = Read-Host -Prompt "C:\Windows\Temp not found. Please enter the location of where the installer should be downloaded to."
                try {
                    $InputChk = Test-Path $envInput
                    if($InputChk -eq $True) {
                        Write-Verbose "Downloading latest installer bundle to $($envInput)\StairwellForwarderBundle.exe"
                        Invoke-WebRequest -Uri "https://downloads.stairwell.com/windows/latest/InceptionForwarderBundle.exe" -OutFile "$($envInput)\StairwellForwarderBundle.exe" -ErrorAction Stop
                    }
                    $BundleDir = "$($envInput)\StairwellForwarderBundle.exe"
                } catch {
                    Write-Error "Error downloading the Stairwell forwarder installer. Error $($PSItem)"
                    Exit
                }
            }
        }
        else {
            # The user did not supply the download switch but the installer path is null
            if([string]::IsNullOrEmpty($InstallerPath)) {
                Write-Error "No path to the installer supplied. Either use -Download or supply the path to the installer package."
                Exit
            }
            # Test the installer path
            $InstallerChk = Test-Path $InstallerPath
            if($InstallerChk -eq $True) {
                $BundleDir = $InstallerPath
            }
            else {
                Write-Error "Cannot find file specified in -InstallerPath, please verify and try again or use -Download"
            }
        }


        #Install forwarder from where $BundleDir points to
        Write-Verbose "Installing Forwarder from $($BundleDir)"
        if($NoBackscan) {
            Write-Verbose "Backscan is disabled"
            Start-Process -FilePath $BundleDir -Wait -NoNewWindow -ArgumentList /install, ENVIRONMENT_ID=$EnvironmentId, TOKEN=$ForwarderToken, DOSCAN=0, /log C:\\stairwell.log, /quiet, /norestart
        }
        else {
            Write-Verbose "Backscan enabled"
            Start-Process -FilePath $BundleDir -Wait -NoNewWindow -ArgumentList /install, ENVIRONMENT_ID=$EnvironmentId, TOKEN=$ForwarderToken, /log C:\\stairwell.log, /quiet, /norestart
        }

        # Quick pause to ensure the service is started on slower systems
        Start-Sleep -Seconds 3

        # Verify install by looking for the service with status = Running
        $SFServChk = Get-Service -Name "Stairwell Forwarder" -ErrorAction SilentlyContinue
        $IFServChk = Get-Service -Name "Inception Forwarder" -ErrorAction SilentlyContinue

        if([string]::IsNullOrEmpty($SFServChk.Status) -and [string]::IsNullOrEmpty($IFServChk.Status)) {
            Write-Error "Stairwell forwarder service not started yet. Please check to see if the service has started in a few moments. If not, try to reinstall again."
        }
        else {
            if($SFServChk.Status -eq "Running" -or $IFServChk.Status -eq "Running") {
                Write-Output "Stairwell forwarder installed and running. Exiting now."
                Exit
            }
        }
    }
