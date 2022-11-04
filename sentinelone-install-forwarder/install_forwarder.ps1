function runfunc(
    [Parameter(Mandatory = $true)][string]$environment_id, 
    [Parameter(Mandatory = $true)][string]$token
) {    
    
    #Do your script actions here
    $TempFolder = ([io.path]::GetTempPath())
    $InceptionInstallerPath = Join-Path $TempFolder "InceptionForwarderBundle.exe"

    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "https://downloads.stairwell.com/windows/latest/InceptionForwarderBundle.exe" -OutFile $InceptionInstallerPath
    }
    catch {
        Write-Error "Error downloading the inception installer. Error $PSItem"
        exit 1
    }

    Start-Process -FilePath $InceptionInstallerPath -Wait -NoNewWindow -ArgumentList "/install", "ENVIRONMENT_ID=$($environment_id)", "TOKEN=$($token)", "/quiet", "/norestart"
    # optional - DOSCAN=0 to not backscan
}

runfunc @Args # kick off the script
