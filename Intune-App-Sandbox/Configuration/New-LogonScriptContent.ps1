function New-LogonScriptContent {
    <#
    .SYNOPSIS
        Generates the main logon script content for sandbox execution.
    .DESCRIPTION
        Creates the PowerShell script that decodes the .intunewin, runs the installer
        via scheduled task as SYSTEM or as the current user (WDAGUtilityAccount), and captures the exit code.
    .PARAMETER Params
        Hashtable containing all required parameters for script generation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Params
    )

    $ToastNotificationPath = $Params.ToastNotificationPath
    $ToastTitle = $Params.ToastTitle
    $SandboxTempFolder = $Params.SandboxTempFolder
    $FullStartupPath = $Params.FullStartupPath
    $SandboxDesktopPath = $Params.SandboxDesktopPath
    $FileName = $Params.FileName
    $FileNameZIP = $Params.FileNameZIP
    $FileNameRun = $Params.FileNameRun
    $PackageFolderName = $Params.PackageFolderName
    $RunAsUser = $Params.RunAsUser
    $ScheduledTaskUser = if ($RunAsUser) { 'WDAGUtilityAccount' } else { 'SYSTEM' }
    $TaskRunnerPathLiteral = "$SandboxTempFolder\${PackageFolderName}-TaskRunner.ps1".Replace("'", "''")
    $ResultFolderLiteral = "$SandboxDesktopPath\$PackageFolderName".Replace("'", "''")
    $ToastScriptLiteral = "$ToastNotificationPath\New-ToastNotification.ps1".Replace("'", "''")

    @"
New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title '$ToastTitle' -Body 'Pre-configurations and file decoding initiated'
If (!(Test-Path -Path $SandboxTempFolder -PathType Container))
{
    New-Item -Path $SandboxTempFolder -ItemType Directory
}
Copy-Item -Path $FullStartupPath -Destination $SandboxTempFolder
`$Decoder = Start-Process -FilePath $SandboxDesktopPath\bin\IntuneWinAppUtilDecoder.exe -ArgumentList "$SandboxTempFolder\$FileName /s" -NoNewWindow -PassThru -Wait

Rename-Item -Path "$SandboxTempFolder\$FileName.decoded" -NewName `'$FileNameZIP`' -Force
Expand-Archive -Path "$SandboxTempFolder\$FileNameZIP" -Destination $SandboxTempFolder -Force
Remove-Item -Path "$SandboxTempFolder\$FileNameZIP" -Force
New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title '$ToastTitle' -Body 'Decoding finished!'
# register script as scheduled task
`$TaskRunnerPath = '$TaskRunnerPathLiteral'
`$TaskRunnerContent = @'
`$ResultFolder = '$ResultFolderLiteral'
`$ToastScript = '$ToastScriptLiteral'
if (Test-Path -LiteralPath `$ToastScript -PathType Leaf) {
    . `$ToastScript
}

if (Get-Command -Name New-ToastNotification -ErrorAction SilentlyContinue) {
    New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title "$ToastTitle" -Body "Installing software"
}

try {
    `$ToolkitExitCode = 1
    & "$SandboxTempFolder\$FileNameRun"
    `$InstallerSucceeded = `$?
    if (`$LASTEXITCODE -ne `$null) {
        `$ToolkitExitCode = [int]`$LASTEXITCODE
    } elseif (`$InstallerSucceeded) {
        `$ToolkitExitCode = 0
    }
}
catch {
    `$ToolkitExitCode = 1
    Write-Error "Installer execution failed: `$_" -ErrorAction Continue
}

New-Item -Path "$SandboxTempFolder\`$ToolkitExitCode.code" -Force | Out-Null
Copy-Item -LiteralPath "$SandboxTempFolder\`$ToolkitExitCode.code" -Destination `$ResultFolder -Force

try {
    Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*,HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction Ignore |
        Where-Object DisplayName |
        Select-Object -Property DisplayName, DisplayVersion, UninstallString, InstallDate |
        Sort-Object -Property DisplayName |
        Export-Csv -LiteralPath (Join-Path `$ResultFolder 'detection.csv') -NoTypeInformation -Force -ErrorAction Stop
}
catch {
    Write-Error "Could not write detection.csv to '`$ResultFolder': `$_" -ErrorAction Continue
}

if (Get-Command -Name New-ToastNotification -ErrorAction SilentlyContinue) {
    New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title "$ToastTitle" -Body "Installation completed with code: `$ToolkitExitCode"
}

exit `$ToolkitExitCode
'@
Set-Content -Path `$TaskRunnerPath -Value `$TaskRunnerContent -Encoding UTF8 -Force

`$TaskActionArgument = '-ExecutionPolicy Bypass -File "' + `$TaskRunnerPath + '"'
`$Trigger = New-ScheduledTaskTrigger -Once -At `$(Get-Date).AddSeconds(15)
`$Trigger.EndBoundary = `$(Get-Date).AddSeconds(20).ToString('s')
`$User = "$ScheduledTaskUser"
`$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument `$TaskActionArgument
`$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit "01:00" -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName "Install App" -Trigger `$Trigger -User `$User -Action `$Action -Settings `$Settings -Force
"@
}
