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
	exit
}

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