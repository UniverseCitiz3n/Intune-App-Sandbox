function Restart-WindowsExplorer {
    [CmdletBinding()]
    param ()

    Write-Host 'Restarting Windows Explorer...' -ForegroundColor Yellow

    $explorerProcesses = Get-Process -Name explorer -ErrorAction SilentlyContinue
    if ($explorerProcesses) {
        foreach ($process in $explorerProcesses) {
            try {
                Stop-Process -Id $process.Id -Force -ErrorAction Stop
            } catch {
                Write-Verbose "Unable to stop process $($process.Id): $_"
            }
        }
        Start-Sleep -Seconds 2
    }

    try {
        Start-Process -FilePath explorer.exe | Out-Null
    } catch {
        Write-Warning "Failed to start explorer.exe: $_"
    }
}
