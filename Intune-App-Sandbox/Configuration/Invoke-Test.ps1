#params
param(
    [String] $PackagePath,
    [Bool] $DetectionScript = $false
)

$PackageFolderName = Split-Path (Split-Path "$PackagePath" -Parent) -Leaf
$FileName = (Get-Item $PackagePath).Name
$SandboxRootFolder = 'C:\SandboxEnvironment'
$SandboxCoreFolder = "$SandboxRootFolder\core"
$SandboxAppRoot = "$SandboxRootFolder\apps"
$AppFolder = Join-Path $SandboxAppRoot $PackageFolderName
$SandboxFile = "$PackageFolderName.wsb"
$SandboxFilePath = Join-Path $AppFolder $SandboxFile
$DetectionScriptFile = "$((Get-Item $PackagePath).Name.Replace('.intunewin',''))_Detection.ps1"
$FileNameZIP = $($FileName -replace '.intunewin', '.zip')
if ($FileName -like 'Deploy-Application*'){

    $FileNameRun = 'Deploy-Application.exe'
} else {
    $FileNameRun = $($FileName -replace '.intunewin', '.ps1')
}

$SandboxDesktopPath = 'C:\Users\WDAGUtilityAccount\Desktop'
$SandboxTempFolder = 'C:\Temp'
$SandboxSharedPath = "$SandboxDesktopPath\$PackageFolderName"
$FullStartupPath = "$SandboxSharedPath\$FileName"
$FullStartupPath = """$FullStartupPath"""
$ToastNotificationPath = "$SandboxDesktopPath\core"
$SandboxAppDesktopPath = "$SandboxDesktopPath\$PackageFolderName"
$ToastTitle = 'Intune App Sandbox'
#endregion

If (!(Test-Path -Path $AppFolder -PathType Container)) {
    New-Item -Path $AppFolder -ItemType Directory -Force | Out-Null
}
Function New-WSB {
    Param
    (
        [String]$CommandtoRun
    )

    New-Item -Path $SandboxFilePath -Type File -Force | Out-Null
    $Config = @"
<Configuration>
<VGpu>Enable</VGpu>
<Networking>Enable</Networking>
<MappedFolders>
<MappedFolder>
<HostFolder>$((Get-Item $PackagePath).Directory)</HostFolder>
<ReadOnly>false</ReadOnly>
</MappedFolder>
<MappedFolder>
<HostFolder>$SandboxCoreFolder</HostFolder>
<ReadOnly>true</ReadOnly>
</MappedFolder>
<MappedFolder>
<HostFolder>$AppFolder</HostFolder>
<ReadOnly>true</ReadOnly>
</MappedFolder>
</MappedFolders>
<LogonCommand>
<Command>$CommandtoRun</Command>
</LogonCommand>
</Configuration>
"@
    Set-Content -Path $SandboxFilePath -Value $Config
}


$ScriptBlock = @"
New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title '$ToastTitle' -Body 'Pre-configurations and file decoding initiated'
If (!(Test-Path -Path $SandboxTempFolder -PathType Container))
{
	New-Item -Path $SandboxTempFolder -ItemType Directory
}
Copy-Item -Path $FullStartupPath -Destination $SandboxTempFolder
`$Decoder = Start-Process -FilePath $SandboxDesktopPath\core\IntuneWinAppUtilDecoder.exe -ArgumentList "$SandboxTempFolder\$FileName /s" -NoNewWindow -PassThru -Wait

Rename-Item -Path "$SandboxTempFolder\$FileName.decoded" -NewName `'$FileNameZIP`' -Force;
Expand-Archive -Path "$SandboxTempFolder\$FileNameZIP" -Destination $SandboxTempFolder -Force;
Remove-Item -Path "$SandboxTempFolder\$FileNameZIP" -Force;
New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title '$ToastTitle' -Body 'Decoding finished!'
# register detection script as scheduled task
if(`$$DetectionScript)
{
    # register script as scheduled task
    `$TaskActionArgument = '-ex bypass "powershell {New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title {$ToastTitle} -Body {Installing software};`
    & $SandboxTempFolder\$FileNameRun};`
    New-Item $SandboxTempFolder\`$Lastexitcode.code -force;`
    New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title {$ToastTitle} -Body """Installation completed with code: `$LASTEXITCODE""";`
    Start-ScheduledTask -TaskName {Detect App}; Unregister-ScheduledTask -TaskName {Install App} -Confirm:$false"'
    `$User = "SYSTEM"
    `$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument `$TaskActionArgument
    `$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit "01:00" -AllowStartIfOnBatteries -StartWhenAvailable:`$false
    Register-ScheduledTask -TaskName "Install App" -User `$User -Action `$Action -Settings `$Settings -Force
    `$TaskActionArgument = '-ex bypass "powershell {New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title {$ToastTitle} -Body {Detecting software};`
    & $SandboxTempFolder\$DetectionScriptFile};`
    New-Item $SandboxTempFolder\`$LastExitcode.detectioncode -force;`
    New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title {$ToastTitle} -Body """Detection completed with code: `$LASTEXITCODE"""`
    if(`$LASTEXITCODE -eq 1){Start-ScheduledTask -TaskName {Install app}}; Unregister-ScheduledTask -TaskName {Detect App} -Confirm:$false"'
    `$Trigger = New-ScheduledTaskTrigger -Once -At `$(Get-Date).AddSeconds(15)
    `$User = "SYSTEM"
    `$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument `$TaskActionArgument
    `$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit "01:00" -AllowStartIfOnBatteries -StartWhenAvailable:`$false
    Register-ScheduledTask -TaskName "Detect App" -Trigger `$Trigger -User `$User -Action `$Action -Settings `$Settings -Force

}else{
    `$TaskActionArgument = '-ex bypass "powershell {New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title {$ToastTitle} -Body {Installing software};`
    & $SandboxTempFolder\$FileNameRun};`
    New-Item $SandboxTempFolder\`$Lastexitcode.code -force;`
    New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title {$ToastTitle} -Body """Installation completed with code: `$LASTEXITCODE"""; Unregister-ScheduledTask -TaskName {Install App} -Confirm:$false"'
    `$Trigger = New-ScheduledTaskTrigger -Once -At `$(Get-Date).AddSeconds(15)
    `$User = "SYSTEM"
    `$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument `$TaskActionArgument
    `$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit "01:00" -AllowStartIfOnBatteries -StartWhenAvailable:`$false
    Register-ScheduledTask -TaskName "Install App" -Trigger `$Trigger -User `$User -Action `$Action -Settings `$Settings -Force
}
"@

New-Item -Path $AppFolder -Name "$PackageFolderName`_LogonCommand.ps1" -ItemType File -Value $ScriptBlock -Force | Out-Null

$Scriptblock = @"
Set-ExecutionPolicy Bypass -Force;
New-Item -Path $PSHOME\Profile.ps1 -ItemType File -Force | Out-Null;
Set-Content -Path $PSHOME\Profile.ps1 -Value '. C:\Users\WDAGUtilityAccount\Desktop\core\New-ToastNotification.ps1';
& 'C:\Users\WDAGUtilityAccount\Desktop\core\Install-Winget.ps1';
powershell -file '$SandboxDesktopPath\$PackageFolderName\$PackageFolderName`_LogonCommand.ps1'
"@

New-Item -Path $AppFolder -Name "$PackageFolderName`_PreLogonCommand.ps1" -ItemType File -Value $ScriptBlock -Force | Out-Null

$Startup_Command = "powershell.exe -WindowStyle Hidden -executionpolicy bypass -command $SandboxDesktopPath\$PackageFolderName\$PackageFolderName`_PreLogonCommand.ps1"

New-WSB -CommandtoRun $Startup_Command

Start-Process $SandboxFilePath
