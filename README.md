# Intune-App-Sandbox

This tool is for testing Powershell Script which is packed using [Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) for installing software using Win32 Deployment profile in Intune.

# Installing

Project is published to `PSGallery`.
```powershell
Install-Module -Name Intune-App-Sandbox
```
To configure tool on your device run `Add-SandboxShell`.

It will create folder - `C:\SandboxEnvironment` where all neccessary items will be stored.
You will be also prompt to choose which context menu items you wish to apply.
1. Run test in Sandbox
1. Pack with IntunewinUtil
1. Both

# Updating

```powershell
Update-Module -Name Intune-App-Sandbox
```
Run `Update-SandboxShell`

# How to use
Packing script and all neccessary executables is as simple as creating parent folder which is named exacly the same as `.ps1` script inside.<br>
Then right-click on folder and pick `Pack with IntunewinUtil`.
<br><br>
![Pack](packintuneutil.gif)
<br><br><br><br><br><br><br>
To test your package just right-click on `.intunewin` file and choose
`Run test in Sandbox`
![Test](testsandbox.gif)

# New feature - Run test with detection
With version 1.3.0 I've introduced new feature that allows to test your installation and test your custom detection script.
To do that you need to have script file in package location and its name must follow the same principal as installation script name but with `_Detection` and the end:

**Install-ProgramScriptTemplate_Detection.ps1**

Detection script must end with exit code **1** if app is not found and **0** if found.
To use this new feature click on orange/gold item in cotext menu - you will know which one 😉

# Technical details
## Template script
At `SandboxEnvironment` location you will find my template installation script.
It's creation helped me to reduce time spent on every installation package.
Now most of the times it comes down to changing Parameters region.

```powershell
# Parameters
$FileName = "VSCodeSetup-x64-1.50.0.exe"
$Tag = 'VSCode'
$OperatingFolder = 'C:\Program Files (x86)\Microsoft\Temp'
$ArgumentListInstallation = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL /SP- /LOG="{0}\{1}Install.log" /MERGETASKS=!runcode' -f $OperatingFolder, $Tag
$InstallFailCode = 1707
$InstallSuccessCode = 1641

# Log
$LogFile = "$OperatingFolder\IntuneSoftwareInstall.log"
$LogFileError = "$OperatingFolder\IntuneSoftwareInstallError.log"

#Info
. $PSScriptRoot\Write-FileLog.ps1

#Custom exit
function Exit-WithCode {
	param
	(
		$exitcode
	)

	$host.SetShouldExit($exitcode)
}
#######################################################################
#Check for folder
If (Test-Path -Path $OperatingFolder -PathType Container) {
	Write-FileLog -FunctionStart -LogFile $LogFile
} Else {
	New-Item -Path $OperatingFolder -ItemType Directory
	Write-FileLog -Message "$OperatingFolder created" -LogFile $LogFile
}

#Install
Write-FileLog -FunctionStart -LogFile $LogFile
Write-FileLog -Message "Installation with arguments: $ArgumentListInstallation" -LogFile $LogFile
Try {
	$Process = Start-Process $PSScriptRoot\$FileName -ArgumentList $ArgumentListInstallation -NoNewWindow -PassThru -Wait -ErrorAction Stop
	Write-FileLog -Message "Installation exit code: $($Process.ExitCode)" -LogFile $LogFile

	If ($Process.ExitCode -ne 0) {
		Write-FileLog -Type Error -Message "Installation failed. Please check $OperatingFolder\${Tag}Install.log" -LogFileError $LogFileError
		Exit-WithCode -exitcode $InstallFailCode
	} else {
		Write-FileLog -Message "Installation $FileName SUCCESS" -LogFile $LogFile
		Exit-WithCode -exitcode $InstallSuccessCode
	}
} Catch {
	Write-FileLog -Type Error -Message "Script ERROR" -LogFileError $LogFileError
	$_ | Out-File -FilePath $LogFileError -Append -Encoding ASCII
	Write-FileLog -Type Warn -Message "Script TERMINATION" -LogFileError $LogFileError
	Write-FileLog -Type Warn -Message "Exitcode $InstallFailCode" -LogFileError $LogFileError
	Exit-WithCode -exitcode $InstallFailCode
}
```

## Host part
Windows Sandbox file is created at location `C:\SandboxEnvironment`.
This file contains configuration details about Sandbox.

Eg.
```xml
<Configuration>
<VGpu>Enable</VGpu>
<Networking>Enable</Networking>
<MappedFolders>
<MappedFolder>
<HostFolder>C:\Intune\Client apps - Apps\Restart-Device</HostFolder>
<ReadOnly>true</ReadOnly>
</MappedFolder>
<MappedFolder>
<HostFolder>C:\SandboxEnvironment\bin</HostFolder>
<ReadOnly>true</ReadOnly>
</MappedFolder>
</MappedFolders>
<LogonCommand>
<Command>powershell.exe -WindowStyle Hidden -noprofile -executionpolicy bypass -Command C:\Users\WDAGUtilityAccount\Desktop\bin\Restart-Device_LogonCommand.ps1</Command>
</LogonCommand>
</Configuration>
```

Core eleement is Logon Command.
This script is run after Sandbox environment starts.

## Sandbox part
Eg. you have Restart-Device.intune, then logon command will be as below
```powershell
If (!(Test-Path -Path C:\Temp -PathType Container))
{
	New-Item -Path C:\Temp -ItemType Directory
}
Copy-Item -Path "C:\Users\WDAGUtilityAccount\Desktop\Restart-Device\Restart-Device.intunewin" -Destination C:\Temp
$Decoder = Start-Process -FilePath C:\Users\WDAGUtilityAccount\Desktop\bin\IntuneWinAppUtilDecoder.exe -ArgumentList "C:\Temp\Restart-Device.intunewin /s" -NoNewWindow -PassThru -Wait

Rename-Item -Path "C:\Temp\Restart-Device.intunewin.decoded" -NewName 'Restart-Device.zip' -Force;
Expand-Archive -Path "C:\Temp\Restart-Device.zip" -Destination C:\Temp -Force;
Remove-Item -Path "C:\Temp\Restart-Device.zip" -Force;

# register script as scheduled task
$Trigger = New-ScheduledTaskTrigger -Once -At $(Get-Date).AddMinutes(1)
$User = "SYSTEM"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-ex bypass "powershell {& C:\Temp\Restart-Device.ps1};New-Item C:\Temp\$Lastexitcode.code -force"'
$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit "01:00" -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName "Install App" -Trigger $Trigger -User $User -Action $Action -Settings $Settings -Force
```
This package is decoded within Sandbox environment.
Decoded contents are then expanded and to path `C:\Temp`.
Then Scheduled Task is created which will start `Powershell` within `Powershell` to run script contents.
Thanks to nesting `Powershell` runspaces after script ends, `$LASTEXITCODE` is saved in form of file at script location.
