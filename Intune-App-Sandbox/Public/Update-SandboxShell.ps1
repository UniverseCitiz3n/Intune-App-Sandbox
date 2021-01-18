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

	If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
		Write-Output "This function needs to be run As Admin"
		Break
	}
	Clear-Host
	Write-Host 'Thanks for using this tool!' -ForegroundColor Green
	Write-Host 'Starting update process...' -ForegroundColor Yellow
	Write-Host 'Checking for operating folder...' -ForegroundColor Yellow -NoNewline
	$SandboxOperatingFolder = 'C:\SandboxEnvironment\bin'
	[string] $module = (Get-Command -Name $MyInvocation.MyCommand -All).Source
	$PathModule = (Get-Module -Name $module.Trim() | Select-Object ModuleBase -First 1).ModuleBase
	If (!(Test-Path -Path $SandboxOperatingFolder -PathType Container)) {
		Write-Host 'Folder found!' -ForegroundColor Green
		Write-Host "Copying crucial files to $SandboxOperatingFolder" -ForegroundColor Yellow
		Copy-Item -Path $PathModule\Configuration\* -Recurse -Destination $SandboxOperatingFolder -Force
		Write-Host "Copying helpers files to C:\SandboxEnvironment" -ForegroundColor Yellow
		Copy-Item -Path $PathModule\Helpers\* -Recurse -Destination 'C:\SandboxEnvironment' -Force
	}
	Write-Host 'All done!' -ForegroundColor Green
	Pause
}