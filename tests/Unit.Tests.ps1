Describe "CHECK CONFIGURATION FILES ARE PRESENT" {
	# Core configuration files that must exist (excludes IntuneWinAppUtil.exe which is downloaded at runtime)
	$RequiredCoreFiles = @(
		'intunewin-Box-icon.ico',
		'IntuneWinAppUtilDecoder.exe',
		'Invoke-IntunewinUtil.ps1',
		'Invoke-Test.ps1',
		'New-LogonScriptContent.ps1',
		'New-PreLogonScriptContent.ps1',
		'New-ToastNotification.ps1',
		'New-WSBConfig.ps1',
		'sandbox.ico',
		'toast.xml'
	)

	foreach ($item in $RequiredCoreFiles) {
		It "Checking for configuration file: $item" {
			Test-Path .\Intune-App-Sandbox\Configuration\$item | Should -Be $true
		}
	}
}