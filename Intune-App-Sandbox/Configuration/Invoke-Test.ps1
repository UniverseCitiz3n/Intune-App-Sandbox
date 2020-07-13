#params
param(
    [String]$PackagePath
)

$SandboxOperatingFolder = 'C:\SandboxEnvironment'
$SandboxFile = "$((get-item $PackagePath).BaseName).wsb"
$FolderPath = Split-Path (Split-Path "$PackagePath" -Parent) -Leaf
$FileName = (Get-Item $PackagePath).Name
$FileNameZIP = $($FileName -replace '.intunewin', '.zip')

$SandboxDesktopPath = "C:\Users\WDAGUtilityAccount\Desktop"
$SandboxTempFolder = 'C:\Temp'
$SandboxSharedPath = "$SandboxDesktopPath\$FolderPath"
$FullStartupPath = "$SandboxSharedPath\$FileName"
$FullStartupPath = """$FullStartupPath"""
#endregion

If (!(Test-Path -Path $SandboxOperatingFolder -PathType Container)) {
    New-Item -Path $SandboxOperatingFolder -ItemType Directory
}
Function New-WSB {
    Param
    (
        [String]$CommandtoRun
    )

    New-Item -Path $SandboxOperatingFolder -Name $SandboxFile -type file -force | Out-Null
    $Config = @"
<Configuration>
<VGpu>Enable</VGpu>
<Networking>Enable</Networking>
<MappedFolders>
<MappedFolder>
<HostFolder>$((get-item $PackagePath).Directory)</HostFolder>
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
If (!(Test-Path -Path $SandboxTempFolder -PathType Container))
{
	New-Item -Path $SandboxTempFolder -ItemType Directory
}
Copy-Item -Path $FullStartupPath -Destination $SandboxTempFolder
`$Decoder = Start-Process -FilePath $SandboxDesktopPath\bin\IntuneWinAppUtilDecoder.exe -ArgumentList "$SandboxTempFolder\$FileName /s" -NoNewWindow -PassThru -Wait

Rename-Item -Path "$SandboxTempFolder\$FileName.decoded" -NewName `'$FileNameZIP`' -Force;
Expand-Archive -Path "$SandboxTempFolder\$FileNameZIP" -Destination $SandboxTempFolder -Force;
Remove-Item -Path "$SandboxTempFolder\$FileNameZIP" -Force;

# register script as scheduled task
`$Trigger = New-ScheduledTaskTrigger -Once -At `$(Get-Date).AddMinutes(1)
`$User = "SYSTEM"
`$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-ex bypass -command "$SandboxTempFolder\$($FileName -replace '.intunewin','.ps1')" -NoNewWindow -NonInteractive'
`$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit "01:00" -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName "Install App" -Trigger `$Trigger -User `$User -Action `$Action -Settings `$Settings -Force
"@

New-Item -Path $SandboxOperatingFolder\bin -Name "$((get-item $PackagePath).BaseName)_LogonCommand.ps1" -ItemType File -Value $ScriptBlock -Force | Out-Null

$Startup_Command = "powershell.exe -WindowStyle Hidden -noprofile -executionpolicy bypass -Command $SandboxDesktopPath\bin\$((get-item $PackagePath).BaseName)_LogonCommand.ps1"

New-WSB -CommandtoRun $Startup_Command

Start-Process $SandboxOperatingFolder\$SandboxFile