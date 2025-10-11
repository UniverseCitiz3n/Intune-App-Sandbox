Describe "CHECK CONFIGURATION FILES ARE PRESENT" {
	$configurationRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\Intune-App-Sandbox\Configuration'
        $expectedItems = @(
                'Install-Winget.ps1',
                'IntuneSandboxCmd.dll',
                'intunewin-Box-icon.ico',
                'IntuneWinAppUtil.exe',
                'IntuneWinAppUtilDecoder.exe',
		'Invoke-IntunewinUtil.ps1',
		'Invoke-Test.ps1',
		'Invoke-Winget.ps1',
		'New-ToastNotification.ps1',
		'sandbox.ico',
		'toast.xml'
	)

	It "Configuration root exists" {
		Test-Path -LiteralPath $configurationRoot | Should Be $true
	}

	foreach ($item in $expectedItems) {
		It "Contains $item" {
			$target = Join-Path -Path $configurationRoot -ChildPath $item
			Test-Path -LiteralPath $target | Should Be $true
		}
	}
}