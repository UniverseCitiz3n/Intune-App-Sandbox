Describe "CHECK CONFIGURATION FILES ARE PRESENT" {
	It "Check configuration files are present" {
		(Get-ChildItem /tests/ -Recurse | Measure-Object).Count | Should Be 8
	}
	$Files = ('intunewin-Box-icon.ico', 'IntuneWinAppUtil.exe', 'IntuneWinAppUtilDecoder.exe', 'Invoke-IntunewinUtil.ps1', 'Invoke-Test.ps1', 'New-ToastNotification.ps1', 'sandbox.ico', 'toast.xml')
	foreach ($item in $Files) {
		It "Checking for $item" {
			Test-Path /tests/$item | Should Be $true
		}
	}
}