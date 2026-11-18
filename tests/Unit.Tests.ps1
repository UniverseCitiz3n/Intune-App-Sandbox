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
		$ScriptContent | Should -Match 'Installer execution failed'
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

Describe "WINDOWS SANDBOX STARTUP" {
	BeforeAll {
		$ConfigFolder = Join-Path $PSScriptRoot '..\Intune-App-Sandbox\Configuration'
		. (Join-Path $ConfigFolder 'New-WSBConfig.ps1')
		. (Join-Path $ConfigFolder 'New-PreLogonScriptContent.ps1')
	}

	It "launches the bootstrap for a package folder containing spaces and punctuation" {
		$FolderName = 'Install Bob''s App & Tools [QA]'
		$BinFolder = Join-Path $TestDrive 'bin'
		$PackageFolder = Join-Path $TestDrive $FolderName
		New-Item -Path $BinFolder, $PackageFolder -ItemType Directory | Out-Null
		$PreLogonPath = Join-Path $BinFolder "${FolderName}_PreLogonCommand.ps1"
		$LogonPath = Join-Path $BinFolder "${FolderName}_LogonCommand.ps1"

		$WsbPath = Join-Path $TestDrive "$FolderName.wsb"
		New-WSBConfig -OutputPath $WsbPath -HostFolder $PackageFolder -BinFolder $BinFolder -PreLogonScriptPath $PreLogonPath | Out-Null
		$Config = [xml](Get-Content -LiteralPath $WsbPath -Raw)
		$PreLogonCommand = $Config.Configuration.LogonCommand.Command

		# Run the generated launcher with harmless stand-ins for the guest-only commands.
		$PreLogon = New-PreLogonScriptContent -SandboxDesktopPath $TestDrive -PackageFolderName $FolderName
		Set-Content -LiteralPath $PreLogonPath -Value $PreLogon -Encoding UTF8
		Set-Content -LiteralPath (Join-Path $BinFolder 'New-ToastNotification.ps1') -Value 'function New-ToastNotification { Write-Host "toast helper reached" }'
		Set-Content -LiteralPath $LogonPath -Value 'New-ToastNotification; throw "logon error recorded"'

		$Process = [System.Diagnostics.ProcessStartInfo]::new()
		$Process.FileName = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
		$Process.Arguments = $PreLogonCommand -replace '^powershell\.exe ', ''
		$Process.UseShellExecute = $false
		$Process.RedirectStandardError = $true
		$Process.RedirectStandardOutput = $true
		$Child = [System.Diagnostics.Process]::Start($Process)
		try {
			if (!$Child.WaitForExit(15000)) {
				Stop-Process -Id $Child.Id
				throw 'The generated launcher did not finish within 15 seconds.'
			}
			$Child.ExitCode | Should -Not -Be 0
			$Child.StandardError.ReadToEnd() | Should -Match 'logon error recorded'
		}
		finally {
			$Child.Dispose()
		}

		$Transcript = Get-Content -LiteralPath (Join-Path $TestDrive 'Intune-App-Sandbox-startup.log') -Raw
		$Transcript | Should -Match 'toast helper reached'
		$Transcript | Should -Match 'logon error recorded'
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