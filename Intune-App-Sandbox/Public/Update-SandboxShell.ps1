function Update-SandboxShell {
	<#
.SYNOPSIS
This tool is for testing Powershell Script which is packed using Win32 Content Prep Tool for installing software using Win32 Deployment profile in Intune.

.DESCRIPTION
This is a configuration script which will update
folder at location C:\Sandbox for storing binaries, icons, scripts and wsb files.

Such package should contain Install-Script.ps1 and all the neccessary binaries, executables.
To correctly create intunewin package, please name parent folder as the same as *.ps1 script within!

.NOTES
© 2021 Maciej Horbacz
#>

	If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
		Write-Output 'This function needs to be run As Admin'
		Break
	}
	Clear-Host
	Write-Host 'Thanks for using this tool!' -ForegroundColor Green
        Write-Host 'Starting update process...' -ForegroundColor Yellow
        $SandboxRootFolder = 'C:\SandboxEnvironment'
        $SandboxCoreFolder = Join-Path $SandboxRootFolder 'core'
        $PowerShellExecutable = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $InvokeTestPath = Join-Path -Path $SandboxCoreFolder -ChildPath 'Invoke-Test.ps1'
        $InvokeTestCommand = '{0} -executionpolicy bypass -command {1} -PackagePath "%V"' -f $PowerShellExecutable, $InvokeTestPath
        $InvokeTestWingetCommand = '{0} -executionpolicy bypass -command {1} -PackagePath "%V" -EnableWinget' -f $PowerShellExecutable, $InvokeTestPath

        $removeSandboxDrive = $false
        if (-not (Get-PSDrive -Name HKCR_SD -ErrorAction SilentlyContinue)) {
                New-PSDrive -PSProvider Registry -Root HKEY_CLASSES_ROOT -Name HKCR_SD | Out-Null
                $removeSandboxDrive = $true
        }

        if (Test-Path -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox with Detection') {
                Write-Host "Removing legacy 'Run test in Sandbox with Detection' entry" -ForegroundColor Yellow
                Remove-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox with Detection' -Recurse -Force -ErrorAction SilentlyContinue
        }

        if (!(Test-Path -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox\Command')) {
                Write-Host 'Adding standard .intunewin sandbox test entry.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\ -Name '.intunewin' -ErrorAction SilentlyContinue
                New-Item -Path HKCR_SD:\.intunewin -Name 'Shell' -ErrorAction SilentlyContinue
                Set-Item -Path HKCR_SD:\.intunewin\Shell -Value Open
                New-Item -Path HKCR_SD:\.intunewin\Shell -Name 'Run test in Sandbox' -ErrorAction SilentlyContinue
                New-ItemProperty -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name icon -PropertyType 'String' -Value "$SandboxCoreFolder\sandbox.ico" -Force
                New-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name 'Command' -ErrorAction SilentlyContinue
                Set-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox\Command' -Value $InvokeTestCommand
        } else {
                Write-Host 'Standard .intunewin sandbox test entry already present.' -ForegroundColor Yellow
        }

        if (!(Test-Path -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)\Command')) {
                Write-Host 'Adding WinGet-enabled .intunewin sandbox test entry.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\ -Name '.intunewin' -ErrorAction SilentlyContinue
                New-Item -Path HKCR_SD:\.intunewin -Name 'Shell' -ErrorAction SilentlyContinue
                Set-Item -Path HKCR_SD:\.intunewin\Shell -Value Open
                New-Item -Path HKCR_SD:\.intunewin\Shell -Name 'Run test in Sandbox (WinGet enabled)' -ErrorAction SilentlyContinue
                New-ItemProperty -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)' -Name icon -PropertyType 'String' -Value "$SandboxCoreFolder\sandbox.ico" -Force
                New-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)' -Name 'Command' -ErrorAction SilentlyContinue
                Set-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)\Command' -Value $InvokeTestWingetCommand
        } else {
                Write-Host 'WinGet-enabled sandbox test entry already present.' -ForegroundColor Yellow
        }
        Write-Host 'Checking for operating folders...' -ForegroundColor Yellow -NoNewline
        $SandboxRootFolder = 'C:\SandboxEnvironment'
        $SandboxCoreFolder = Join-Path $SandboxRootFolder 'core'
        $SandboxAppsFolder = Join-Path $SandboxRootFolder 'apps'
        try {
                $PathModule = Resolve-SandboxModuleRoot -InvocationInfo $MyInvocation -ScriptRoot $PSScriptRoot
        } catch {
                Write-Error $_
                return
        }
        $ConfigurationSource = Join-Path -Path $PathModule -ChildPath 'Configuration'
        $HelpersSource = Join-Path -Path $PathModule -ChildPath 'Helpers'

        $coreExists = Test-Path -Path $SandboxCoreFolder -PathType Container
        if (-not $coreExists) {
                Write-Host 'Core folder missing. Creating required structure...' -ForegroundColor Yellow
        } else {
                Write-Host 'Folder found!' -ForegroundColor Green
        }

        if (-not (Test-Path -Path $SandboxRootFolder -PathType Container)) {
                New-Item -Path $SandboxRootFolder -ItemType Directory -Force | Out-Null
        }

        if (-not $coreExists) {
                New-Item -Path $SandboxCoreFolder -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -Path $SandboxAppsFolder -PathType Container)) {
                New-Item -Path $SandboxAppsFolder -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -Path $ConfigurationSource -PathType Container)) {
                Write-Error "Configuration source folder not found at '$ConfigurationSource'."
                return
        }

        if (-not (Test-Path -Path $HelpersSource -PathType Container)) {
                Write-Error "Helpers source folder not found at '$HelpersSource'."
                return
        }

        Write-Host "Copying crucial files to $SandboxCoreFolder" -ForegroundColor Yellow
        Copy-Item -Path (Join-Path -Path $ConfigurationSource -ChildPath '*') -Recurse -Destination $SandboxCoreFolder -Force

        Write-Host "Copying helpers files to $SandboxRootFolder" -ForegroundColor Yellow
        Copy-Item -Path (Join-Path -Path $HelpersSource -ChildPath '*') -Recurse -Destination $SandboxRootFolder -Force
	Write-Host 'All done!' -ForegroundColor Green
        if ($removeSandboxDrive) {
                Remove-PSDrive -Name HKCR_SD -Force -ErrorAction SilentlyContinue
        }
	Pause
}
