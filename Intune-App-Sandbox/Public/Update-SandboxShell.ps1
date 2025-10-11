function Update-SandboxShell {
    [CmdletBinding()]
    param ()

    Clear-Host
    Write-Host 'Thanks for using this tool!' -ForegroundColor Green
    Write-Host 'Starting update process...' -ForegroundColor Yellow

    try {
        $result = Invoke-SandboxShellDeployment -Operation 'Update'
    } catch {
        Write-Error $_
        return
    }

    try {
        Restart-WindowsExplorer
    } catch {
        Write-Warning "Failed to restart Windows Explorer automatically: $_"
    }

    Write-Host "Explorer command handler refreshed (CLSID $($result.Clsid))." -ForegroundColor Green
    Write-Host "Core files refreshed at $($result.DllPath | Split-Path)." -ForegroundColor Green
    Write-Host 'All done!' -ForegroundColor Green
}
