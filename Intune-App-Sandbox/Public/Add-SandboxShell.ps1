function Add-SandboxShell {
    [CmdletBinding()]
    param ()

    Clear-Host
    Write-Host 'Thanks for using this tool!' -ForegroundColor Green
    Write-Host 'Starting configuration process...' -ForegroundColor Yellow

    try {
        $sandboxFeature = Get-WindowsOptionalFeature -FeatureName 'Containers-DisposableClientVM' -Online -ErrorAction Stop
        if ($sandboxFeature.State -ne 'Enabled') {
            Write-Warning 'Windows Sandbox is currently disabled. Enable it from Windows Features to use the Sandbox workflows.'
        }
    } catch {
        Write-Verbose "Unable to query the Windows Sandbox feature: $_"
    }

    try {
        $result = Invoke-SandboxShellDeployment -Operation 'Add'
    } catch {
        Write-Error $_
        return
    }

    try {
        Restart-WindowsExplorer
    } catch {
        Write-Warning "Failed to restart Windows Explorer automatically: $_"
    }

    Write-Host "Explorer command handler registered (CLSID $($result.Clsid))." -ForegroundColor Green
    Write-Host "Core files copied to $($result.DllPath | Split-Path)." -ForegroundColor Green
    Write-Host 'All done!' -ForegroundColor Green
}
