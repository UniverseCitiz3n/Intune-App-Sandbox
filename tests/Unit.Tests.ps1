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

Describe "GENERATED SANDBOX LOGON SCRIPT" {
	BeforeAll {
		. (Join-Path $PSScriptRoot '..\Intune-App-Sandbox\Configuration\New-LogonScriptContent.ps1')
		$BaseParams = @{
			ToastNotificationPath = 'C:\Users\WDAGUtilityAccount\Desktop\bin'
			ToastTitle            = 'Intune App Sandbox'
			SandboxTempFolder     = 'C:\Temp'
			FullStartupPath       = 'C:\Users\WDAGUtilityAccount\Desktop\Install-App\Install-App.intunewin'
			SandboxDesktopPath    = 'C:\Users\WDAGUtilityAccount\Desktop'
			FileName              = 'Install-App.intunewin'
			FileNameZIP           = 'Install-App.zip'
			FileNameRun           = 'Install-App.ps1'
			PackageFolderName     = 'Install-App'
		}
	}

	It "uses WDAGUtilityAccount for user-context tests and preserves install results" {
		$Params = $BaseParams + @{ RunAsUser = $true }
		$ScriptContent = New-LogonScriptContent -Params $Params

		$ScriptContent | Should -Match '\$User = "WDAGUtilityAccount"'
		$ScriptContent | Should -Match '\$ToolkitExitCode = 1'
		$ScriptContent | Should -Match 'detection\.csv'
		$ScriptContent | Should -Not -Match 'powershell \{'
	}

	It "keeps SYSTEM as the default execution context" {
		$Params = $BaseParams + @{ RunAsUser = $false }
		$ScriptContent = New-LogonScriptContent -Params $Params

		$ScriptContent | Should -Match '\$User = "SYSTEM"'
		$ScriptContent | Should -Match '\$TaskRunnerPath = '
	}
}

Describe "VS CODE EXTENSION COMPATIBILITY" {
	It "accepts the extension's package path and user-context arguments" {
		$ScriptPath = Join-Path $PSScriptRoot '..\Intune-App-Sandbox\Configuration\Invoke-Test.ps1'
		$Tokens = $null
		$ParseErrors = $null
		$Ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$Tokens, [ref]$ParseErrors)
		$ParseErrors | Should -BeNullOrEmpty

		$ParameterNames = @($Ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
		$ParameterNames | Should -Contain 'PackagePath'
		$ParameterNames | Should -Contain 'RunAsUser'
	}
}