$OperatingFolder = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$SoftwareName = 'VSCode'
$ArgumentListUninstallation = '/qn'
# Log
$LogFile = "$OperatingFolder\IntuneSoftwareInstall.log"
$LogFileError = "$OperatingFolder\IntuneSoftwareInstallError.log"
#Info
. $PSScriptRoot\Write-FileLog.ps1
$Software = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction Ignore |
Where-Object DisplayName |
Select-Object -Property DisplayName, DisplayVersion, UninstallString, InstallDate |
Sort-Object -Property DisplayName |
Where-Object { $PSItem.DisplayName -like "$SoftwareName*" }
#Install
Write-FileLog -FunctionStart -LogFile $LogFile
Write-FileLog -Message "Uninstall with arguments: $($Software.UninstallString)" -LogFile $LogFile
try {
	$Process = Start-Process -FilePath $(($Software.UninstallString -split ' ')[0]) -ArgumentList "$(($Software.UninstallString -split ' ')[1] -replace 'I','X') $ArgumentListUninstallation"  -NoNewWindow -PassThru -Wait -ErrorAction Stop
	Write-FileLog -Message "Exit code: $($Process.ExitCode)" -LogFile $LogFile
} catch {
	Write-FileLog -Type Error -Message "Script ERROR" -LogFileError $LogFileError
	$_ | Out-File -FilePath $LogFileError -Append -Encoding ASCII
	Write-FileLog -Type Warn -Message "Script TERMINATION" -LogFileError $LogFileError
}