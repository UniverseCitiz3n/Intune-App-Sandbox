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
	Write-Host 'Checking for operating folder...' -ForegroundColor Yellow -NoNewline
	$SandboxOperatingFolder = 'C:\SandboxEnvironment\bin'
	[string] $module = (Get-Command -Name $MyInvocation.MyCommand -All).Source
	$PathModule = (Get-Module -Name $module.Trim() | Select-Object ModuleBase -First 1).ModuleBase
	If ((Test-Path -Path $SandboxOperatingFolder -PathType Container)) {
		Write-Host 'Folder found!' -ForegroundColor Green
		Write-Host "Copying crucial files to $SandboxOperatingFolder" -ForegroundColor Yellow
		# Copy all files except IntuneWinAppUtil.exe (will be downloaded)
		Get-ChildItem -Path $PathModule\Configuration\* -Exclude 'IntuneWinAppUtil.exe' | Copy-Item -Destination $SandboxOperatingFolder -Recurse -Force
		Write-Host 'Copying helpers files to C:\SandboxEnvironment' -ForegroundColor Yellow
		Copy-Item -Path $PathModule\Helpers\* -Recurse -Destination 'C:\SandboxEnvironment' -Force

		# Download latest IntuneWinAppUtil.exe from GitHub
		Write-Host 'Downloading latest IntuneWinAppUtil.exe from GitHub...' -ForegroundColor Yellow
		try {
			$ProgressPreference = 'SilentlyContinue'
			$downloadUrl = 'https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe'
			Invoke-WebRequest -Uri $downloadUrl -OutFile "$SandboxOperatingFolder\IntuneWinAppUtil.exe" -UseBasicParsing
			Write-Host 'IntuneWinAppUtil.exe downloaded successfully!' -ForegroundColor Green
		} catch {
			Write-Host "ERROR: Failed to download IntuneWinAppUtil.exe. Error: $_" -ForegroundColor Red
			Write-Host "Please download IntuneWinAppUtil.exe manually from:" -ForegroundColor Yellow
			Write-Host "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/blob/master/IntuneWinAppUtil.exe" -ForegroundColor Cyan
			Write-Host "And place it in: $SandboxOperatingFolder" -ForegroundColor Yellow
			Break
		}
	}
	Write-Host 'All done!' -ForegroundColor Green
	Pause
}
