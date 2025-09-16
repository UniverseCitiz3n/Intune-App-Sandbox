#params
param(
    [String] $PackagePath
)

$PackageName = (Get-Item $PackagePath).BaseName
$ConfigFileName = (Get-Item $PackagePath).Name
$SandboxRootFolder = 'C:\SandboxEnvironment'
$SandboxCoreFolder = "$SandboxRootFolder\core"
$SandboxAppRoot = "$SandboxRootFolder\apps"
$AppFolder = Join-Path $SandboxAppRoot $PackageName
$SandboxFile = "$PackageName.wsb"
$SandboxFilePath = Join-Path $AppFolder $SandboxFile

if (!(Test-Path -Path $AppFolder -PathType Container)) {
    New-Item -Path $AppFolder -ItemType Directory -Force | Out-Null
}

Copy-Item -Path $PackagePath -Destination $AppFolder -Force

$SandboxDesktopPath = 'C:\Users\WDAGUtilityAccount\Desktop'
$SandboxAppDesktopPath = "$SandboxDesktopPath\$PackageName"
$ToastNotificationPath = "$SandboxDesktopPath\core"
$ToastTitle = 'Intune App Sandbox'

$ScriptBlock = @"
New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title '$ToastTitle' -Body 'Installing via winget';
`$proc = Start-Process -FilePath winget.exe -ArgumentList \"import -i $SandboxAppDesktopPath\$ConfigFileName --accept-package-agreements --accept-source-agreements --disable-interactivity\" -PassThru -Wait;
New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title '$ToastTitle' -Body ('Installation completed with code: ' + `$proc.ExitCode);
"@

New-Item -Path $AppFolder -Name "$PackageName`_LogonCommand.ps1" -ItemType File -Value $ScriptBlock -Force | Out-Null

$Scriptblock = @"
Set-ExecutionPolicy Bypass -Force;
New-Item -Path $PSHOME\Profile.ps1 -ItemType File -Force | Out-Null;
Set-Content -Path $PSHOME\Profile.ps1 -Value '. C:\Users\WDAGUtilityAccount\Desktop\core\New-ToastNotification.ps1';
& 'C:\Users\WDAGUtilityAccount\Desktop\core\Install-Winget.ps1';
powershell -file '$SandboxAppDesktopPath\$PackageName`_LogonCommand.ps1'
"@

New-Item -Path $AppFolder -Name "$PackageName`_PreLogonCommand.ps1" -ItemType File -Value $Scriptblock -Force | Out-Null

$Startup_Command = "powershell.exe -WindowStyle Hidden -executionpolicy bypass -command $SandboxAppDesktopPath\$PackageName`_PreLogonCommand.ps1"

$WSBConfig = @"
<Configuration>
<VGpu>Enable</VGpu>
<Networking>Enable</Networking>
<MappedFolders>
<MappedFolder>
<HostFolder>$((Get-Item $PackagePath).DirectoryName)</HostFolder>
<ReadOnly>true</ReadOnly>
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
<Command>$Startup_Command</Command>
</LogonCommand>
</Configuration>
"@

Set-Content -Path $SandboxFilePath -Value $WSBConfig

Start-Process $SandboxFilePath

