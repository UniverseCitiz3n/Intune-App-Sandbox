New-PSDrive HKU Registry HKEY_USERS
Get-ItemProperty -Path 'HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
'HKU:\*\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
'HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
'HKU:\*\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction Ignore |
Where-Object DisplayName |
Select-Object -Property DisplayName, DisplayVersion, UninstallString, InstallDate |
Sort-Object -Property DisplayName