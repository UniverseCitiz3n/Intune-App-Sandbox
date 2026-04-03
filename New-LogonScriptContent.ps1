function New-LogonScriptContent {
    <#
    .SYNOPSIS
        Generates the main logon script content for sandbox execution.
    .DESCRIPTION
        Creates the PowerShell script that decodes the .intunewin, runs the installer
        as SYSTEM via scheduled task, and captures the exit code.
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
`$TaskRunnerPath = '$SandboxTempFolder\${PackageFolderName}-TaskRunner.ps1'
`$TaskRunnerContent = @'
if (Test-Path -Path ''$SandboxDesktopPath\bin\New-ToastNotification.ps1'' -PathType Leaf) {
    . ''$SandboxDesktopPath\bin\New-ToastNotification.ps1''
}

if (Get-Command -Name New-ToastNotification -ErrorAction SilentlyContinue) {
    New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title "$ToastTitle" -Body "Installing software"
}

try {
    `$ToolkitExitCode = 1
    & $SandboxTempFolder\$FileNameRun
    if (`$LASTEXITCODE -ne `$null) {
        `$ToolkitExitCode = [int]`$LASTEXITCODE
    }
}
catch {
    `$ToolkitExitCode = 1
}

New-Item -Path "$SandboxTempFolder\`$ToolkitExitCode.code" -Force | Out-Null
Copy-Item -Path "$SandboxTempFolder\`$ToolkitExitCode.code" -Destination $SandboxDesktopPath\$PackageFolderName\ -Force

try {
    Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*,HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction Ignore |
        Where-Object DisplayName |
        Select-Object -Property DisplayName, DisplayVersion, UninstallString, InstallDate |
        Sort-Object -Property DisplayName |
        Export-Csv -Path $SandboxDesktopPath\$PackageFolderName\detection.csv -NoTypeInformation -Force
}
catch {
}

if (Get-Command -Name New-ToastNotification -ErrorAction SilentlyContinue) {
    New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title "$ToastTitle" -Body "Installation completed with code: `$ToolkitExitCode"
}

exit `$ToolkitExitCode
'@
Set-Content -Path `$TaskRunnerPath -Value `$TaskRunnerContent -Encoding ASCII -Force

`$TaskActionArgument = '-ExecutionPolicy Bypass -File "' + `$TaskRunnerPath + '"'
`$Trigger = New-ScheduledTaskTrigger -Once -At `$(Get-Date).AddSeconds(15)
`$Trigger.EndBoundary = `$(Get-Date).AddSeconds(20).ToString('s')
`$User = "$(if ($RunAsUser) { 'WDAGUtilityAccount' } else { 'SYSTEM' })"
`$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument `$TaskActionArgument
`$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit "01:00" -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName "Install App" -Trigger `$Trigger -User `$User -Action `$Action -Settings `$Settings -Force
"@
}
