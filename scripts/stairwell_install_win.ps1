<#
    Use this script to install the Stairwell forwarder on Windows OS machines.
    This script requires your file forwarder token and environment id.
    Visit https://docs.stairwell.com for further assistance.

    Typically this would be used for remotely installing, such as in an Azure scale set
    ex. Set-AzVMCustomScriptExtension -ResourceGroupName "ResourceGroup11" -Location "Central US" -VMName "VirtualMachine07" -Name "StairwellScriptExt" -FileName "stairwell_install_win.ps1" -Argument 'ForwarderToken EnvironmentId' | Update-AzureVM
#>
param(
    [Parameter(Mandatory=$True)]
    [string]$ForwarderToken,

    [Parameter(Mandatory=$True)]
    [string]$EnvironmentId
)

# Check for C:\Temp directory
if (!(Test-Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp"
}

# Try to download forwarder
try {  
    $ProgressPreference = 'SilentlyContinue'  
    Invoke-WebRequest -Uri "https://downloads.stairwell.com/windows/latest/InceptionForwarderBundle.exe" -UseBasicParsing -OutFile "C:\Temp\InceptionForwarderBundle.exe"
}  
catch {  
    Write-Error "Error downloading the Stairwell forwarder installer. Error $($PSItem)"  
    exit 1  
}

# Install the forwarder
Start-Process -FilePath "C:\Temp\InceptionForwarderBundle.exe" -Wait -NoNewWindow -ArgumentList "/install", "ENVIRONMENT_ID=$($EnvironmentId)", "TOKEN=$($ForwarderToken)", "/quiet", "/norestart", "/log log.txt"

# Clean up
Remove-Item -Path "C:\Temp\InceptionForwarderBundle.exe" -Force
