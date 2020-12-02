#params
param(
    [String]$PackagePath
)

$SandboxOperatingFolder = 'C:\SandboxEnvironment'
$SandboxFile = "$((Get-Item $PackagePath).BaseName).wsb"
$FolderPath = Split-Path (Split-Path "$PackagePath" -Parent) -Leaf
$FileName = (Get-Item $PackagePath).Name
$FileNameZIP = $($FileName -replace '.intunewin', '.zip')

$SandboxDesktopPath = "C:\Users\WDAGUtilityAccount\Desktop"
$SandboxTempFolder = 'C:\Temp'
$SandboxSharedPath = "$SandboxDesktopPath\$FolderPath"
$FullStartupPath = "$SandboxSharedPath\$FileName"
$FullStartupPath = """$FullStartupPath"""
$ToastNotificationPath = "$SandboxDesktopPath\bin\"
$ToastTitle = 'Intune App Sandbox'
#endregion

If (!(Test-Path -Path $SandboxOperatingFolder -PathType Container)) {
    New-Item -Path $SandboxOperatingFolder -ItemType Directory
}
Function New-WSB {
    Param
    (
        [String]$CommandtoRun
    )

    New-Item -Path $SandboxOperatingFolder -Name $SandboxFile -type file -Force | Out-Null
    $Config = @"
<Configuration>
<VGpu>Enable</VGpu>
<Networking>Enable</Networking>
<MappedFolders>
<MappedFolder>
<HostFolder>$((Get-Item $PackagePath).Directory)</HostFolder>
<ReadOnly>true</ReadOnly>
</MappedFolder>
<MappedFolder>
<HostFolder>C:\SandboxEnvironment\bin</HostFolder>
<ReadOnly>true</ReadOnly>
</MappedFolder>
</MappedFolders>
<LogonCommand>
<Command>$CommandtoRun</Command>
</LogonCommand>
</Configuration>
"@
    Set-Content -Path "$SandboxOperatingFolder\$SandboxFile" -Value $Config
}


$ScriptBlock = @"
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
`$Trigger = New-ScheduledTaskTrigger -Once -At `$(Get-Date).AddSeconds(15)
`$User = "SYSTEM"
`$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-ex bypass "powershell {New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title {$ToastTitle} -Body {Installing software};& $SandboxTempFolder\$($FileName -replace '.intunewin','.ps1')};New-Item $SandboxTempFolder\`$Lastexitcode.code -force;New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title {$ToastTitle} -Body """Installation completed with code: `$LASTEXITCODE""""'
`$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit "01:00" -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName "Install App" -Trigger `$Trigger -User `$User -Action `$Action -Settings `$Settings -Force
"@

New-Item -Path $SandboxOperatingFolder\bin -Name "$((Get-Item $PackagePath).BaseName)_LogonCommand.ps1" -ItemType File -Value $ScriptBlock -Force | Out-Null

$Scriptblock = @"
Set-ExecutionPolicy Bypass -Force;
new-item $PSHOME\Profile.ps1;
Set-Content -Path $PSHOME\Profile.ps1 -Value '. C:\Users\WDAGUtilityAccount\Desktop\bin\New-ToastNotification.ps1';
powershell -file '$SandboxDesktopPath\bin\$((Get-Item $PackagePath).BaseName)_LogonCommand.ps1'
"@

New-Item -Path $SandboxOperatingFolder\bin -Name "$((Get-Item $PackagePath).BaseName)_PreLogonCommand.ps1" -ItemType File -Value $ScriptBlock -Force | Out-Null

$Startup_Command = "powershell.exe -WindowStyle Hidden -executionpolicy bypass -command $SandboxDesktopPath\bin\$((Get-Item $PackagePath).BaseName)_PreLogonCommand.ps1"

New-WSB -CommandtoRun $Startup_Command

Start-Process $SandboxOperatingFolder\$SandboxFile