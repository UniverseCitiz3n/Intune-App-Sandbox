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

    @"
New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title '$ToastTitle' -Body 'Pre-configurations and file decoding initiated'
If (!(Test-Path -Path $SandboxTempFolder -PathType Container))
{
	New-Item -Path $SandboxTempFolder -ItemType Directory
}
Copy-Item -Path $FullStartupPath -Destination $SandboxTempFolder
`$Decoder = Start-Process -FilePath $SandboxDesktopPath\bin\IntuneWinAppUtilDecoder.exe -ArgumentList "$SandboxTempFolder\$FileName /s" -NoNewWindow -PassThru -Wait

Rename-Item -Path "$SandboxTempFolder\$FileName.decoded" -NewName `'$FileNameZIP`' -Force;
Expand-Archive -Path "$SandboxTempFolder\$FileNameZIP" -Destination $SandboxTempFolder -Force;
Remove-Item -Path "$SandboxTempFolder\$FileNameZIP" -Force;
New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title '$ToastTitle' -Body 'Decoding finished!'
# register script as scheduled task
`$TaskActionArgument = '-ex bypass "powershell {New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title {$ToastTitle} -Body {Installing software};`
& $SandboxTempFolder\$FileNameRun};`
New-Item $SandboxTempFolder\`$Lastexitcode.code -force;`
Copy-Item -Path $SandboxTempFolder\`$Lastexitcode.code -Destination $SandboxDesktopPath\$PackageFolderName\ -Force;`
if(`$LASTEXITCODE -eq 0){`
    Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*,HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction Ignore | Where-Object DisplayName | Select-Object -Property DisplayName, DisplayVersion, UninstallString, InstallDate | Sort-Object -Property DisplayName | Export-Csv -Path $SandboxDesktopPath\$PackageFolderName\detection.csv -NoTypeInformation -Force`
};`
New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title {$ToastTitle} -Body """Installation completed with code: `$LASTEXITCODE""""'
`$Trigger = New-ScheduledTaskTrigger -Once -At `$(Get-Date).AddSeconds(15)
`$Trigger.EndBoundary = `$(Get-Date).AddSeconds(20).ToString('s')
`$User = "SYSTEM"
`$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument `$TaskActionArgument
`$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit "01:00" -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName "Install App" -Trigger `$Trigger -User `$User -Action `$Action -Settings `$Settings -Force
"@
}
