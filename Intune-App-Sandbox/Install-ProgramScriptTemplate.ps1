$global:ErrorActionPreference = "Stop"
# Parameters
$FileName = "VSCodeUserSetup-x64-1.47.0.exe"
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
	exit
}

#Check for folder
If (Test-Path -Path $OperatingFolder -PathType Container) {
	Write-FileLog -FunctionStart -LogFile $LogFile -LogOverWrite
} Else {
	Write-FileLog -FunctionStart -LogFile $LogFile -LogOverWrite
	New-Item -Path $OperatingFolder -ItemType Directory
	Write-FileLog -Message "$OperatingFolder created"  -LogFile $LogFile -LogOverWrite
}

#Install
Write-FileLog -Message "Installation with arguments: $ArgumentListInstallation"  -LogFile $LogFile -LogOverWrite
Try {
	$Process = Start-Process $PSScriptRoot\$FileName -ArgumentList $ArgumentListInstallation -NoNewWindow -PassThru -Wait
	Write-FileLog -Message "Installation exit code: $($Process.ExitCode)"  -LogFile $LogFile -LogOverWrite

	If ($Process.ExitCode -ne 0) {
		Write-FileLog -Type e -Message "Installation failed. Please check $OperatingFolder\${Tag}Install.log" -LogFileError $LogFileError -LogOverWrite
		Exit-WithCode -exitcode $InstallFailCode
	} else {
		Write-FileLog -Type i -Message "Installation $FileName SUCCESS"
		Exit-WithCode -exitcode $InstallSuccessCode
	}
} Catch {
	Write-FileLog -Type e -Message "Script ERROR" -LogFileError $LogFileError -LogOverWrite
	$_ | Out-File -FilePath $LogFileError -Append -Encoding ASCII
	Exit-WithCode -exitcode $InstallFailCode
}