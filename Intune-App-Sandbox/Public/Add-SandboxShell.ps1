function Add-SandboxShell {
    <#
.SYNOPSIS
This tool is for testing Powershell Script which is packed using Win32 Content Prep Tool for installing software using Win32 Deployment profile in Intune.

.DESCRIPTION
This is a configuration script which will create
folder at location C:\Sandbox for storing binaries, icons, scripts and wsb files.

It also adds options to system context menu for packing intuewin and testing
such package.

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

    # Display ASCII Art Banner
    Write-Host @"

    ██╗███╗   ██╗████████╗██╗   ██╗███╗   ██╗███████╗
    ██║████╗  ██║╚══██╔══╝██║   ██║████╗  ██║██╔════╝
    ██║██╔██╗ ██║   ██║   ██║   ██║██╔██╗ ██║█████╗
    ██║██║╚██╗██║   ██║   ██║   ██║██║╚██╗██║██╔══╝
    ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚████║███████╗
    ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚══════╝

    ███████╗ █████╗ ███╗   ██╗██████╗ ██████╗  ██████╗ ██╗  ██╗
    ██╔════╝██╔══██╗████╗  ██║██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝
    ███████╗███████║██╔██╗ ██║██║  ██║██████╔╝██║   ██║ ╚███╔╝
    ╚════██║██╔══██║██║╚██╗██║██║  ██║██╔══██╗██║   ██║ ██╔██╗
    ███████║██║  ██║██║ ╚████║██████╔╝██████╔╝╚██████╔╝██╔╝ ██╗
    ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝

                🧪 Win32 App Testing Framework 🧪

                  Test Intune packages locally
                  before production deployment!

"@ -ForegroundColor Cyan

    Write-Host "`n" -NoNewline
    Write-Host "  © 2021-2026 Maciej Horbacz" -ForegroundColor DarkGray
    Write-Host "`n" -NoNewline

    # Pre-start menu
    Write-Host "`n" -NoNewline
    Write-Host "                     SETUP WIZARD" -ForegroundColor Yellow
    Write-Host "                     ============`n" -ForegroundColor Yellow
    Write-Host "  This wizard will configure your system for testing" -ForegroundColor White
    Write-Host "  Intune Win32 app packages using Windows Sandbox.`n" -ForegroundColor White
    Write-Host "  What will be installed:" -ForegroundColor White
    Write-Host "    ✓ Windows Sandbox feature (if needed)" -ForegroundColor Green
    Write-Host "    ✓ Context menu integration`n" -ForegroundColor Green
    Write-Host "Press any key to continue or Ctrl+C to cancel..." -ForegroundColor Cyan -NoNewline
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Write-Host "`n`n"

    Write-Host '🚀 Starting configuration process...' -ForegroundColor Yellow
    Write-Host 'Checking for Sandbox feature...' -ForegroundColor Yellow
    $SandboxFeature = Get-WindowsOptionalFeature -FeatureName 'Containers-DisposableClientVM' -Online
    if($SandboxFeature.state -ne 'Enabled'){
        Write-Host 'Sandbox feature is disabled!! Enabling feature' -ForegroundColor Red
        $sandboxfeature | Enable-WindowsOptionalFeature -Online
    }
    Write-Host 'Checking for operating folder...' -ForegroundColor Yellow -NoNewline
    $SandboxOperatingFolder = 'C:\SandboxEnvironment\bin'
    [string] $module = (Get-Command -Name $MyInvocation.MyCommand -All).Source
    $PathModule = (Get-Module -Name $module.Trim() | Select-Object ModuleBase -First 1).ModuleBase
    If (!(Test-Path -Path $SandboxOperatingFolder -PathType Container)) {
        Start-Sleep 2
        Write-Host 'Not found!' -ForegroundColor Red
        Write-Host 'Adding operating folder...' -ForegroundColor Yellow
        New-Item -Path $SandboxOperatingFolder -ItemType Directory | Out-Null
        Start-Sleep 1
        Write-Host 'Folder found!' -ForegroundColor Green
        Write-Host "Copying crucial files to $SandboxOperatingFolder" -ForegroundColor Yellow
        # Copy all files except IntuneWinAppUtil.exe (will be downloaded)
        Get-ChildItem -Path $PathModule\Configuration\* -Exclude 'IntuneWinAppUtil.exe' | Copy-Item -Destination $SandboxOperatingFolder -Recurse -Force

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
    Write-Host "
Contex menu options:
1 - Only 'Run test in Sandbox'
2 - Only 'Pack with IntunewinUtil'
3 - Both
" -ForegroundColor Yellow
    Write-Host 'Please specify your choice: ' -ForegroundColor Yellow -NoNewline
    $Option = Read-Host
    New-PSDrive -PSProvider registry -Root HKEY_CLASSES_ROOT -Name HKCR_SD | Out-Null
    switch ($Option) {
        1 {
            If (!(Test-Path -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox\Command')) {
                Write-Host 'Context menu item not present.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\ -Name '.intunewin' -ErrorAction SilentlyContinue
                New-Item -Path HKCR_SD:\.intunewin -Name 'Shell' -ErrorAction SilentlyContinue
                Set-Item -Path HKCR_SD:\.intunewin\Shell -Value Open
                New-Item -Path HKCR_SD:\.intunewin\Shell -Name 'Run test in Sandbox'
                New-ItemProperty -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name icon -PropertyType 'String' -Value "$SandboxOperatingFolder\sandbox.ico"
                New-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox\Command' -Value "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -command $SandboxOperatingFolder\Invoke-Test.ps1 -PackagePath `"%V`""
            } else {
                Write-Host 'Context menu item already present!' -ForegroundColor Yellow
            }
        }
        2 {
            If (!(Test-Path -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil\Command')) {
                Write-Host 'Context menu item not present.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\Directory\Shell\ -Name 'Pack with IntunewinUtil'
                New-ItemProperty -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil' -Name icon -PropertyType 'String' -Value "$SandboxOperatingFolder\intunewin-Box-icon.ico"
                New-Item -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil\Command' -Value "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -file $SandboxOperatingFolder\Invoke-IntunewinUtil.ps1 -PackagePath `"%V`""
            } else {
                Write-Host 'Context menu item already present!' -ForegroundColor Yellow
            }
        }
        3 {
            If (!(Test-Path -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox\Command')) {
                Write-Host 'Context menu item not present.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\ -Name '.intunewin' -ErrorAction SilentlyContinue
                New-Item -Path HKCR_SD:\.intunewin -Name 'Shell' -ErrorAction SilentlyContinue
                Set-Item -Path HKCR_SD:\.intunewin\Shell -Value Open
                New-Item -Path HKCR_SD:\.intunewin\Shell -Name 'Run test in Sandbox'
                New-ItemProperty -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name icon -PropertyType 'String' -Value "$SandboxOperatingFolder\sandbox.ico"
                New-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox\Command' -Value "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -command $SandboxOperatingFolder\Invoke-Test.ps1 -PackagePath `"%V`""
            } else {
                Write-Host 'Context menu item already present!' -ForegroundColor Yellow
            }
            If (!(Test-Path -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil\Command')) {
                Write-Host 'Context menu item not present.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\Directory\Shell\ -Name 'Pack with IntunewinUtil'
                New-ItemProperty -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil' -Name icon -PropertyType 'String' -Value "$SandboxOperatingFolder\intunewin-Box-icon.ico"
                New-Item -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil\Command' -Value "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -file $SandboxOperatingFolder\Invoke-IntunewinUtil.ps1 -PackagePath `"%V`""
            } else {
                Write-Host 'Context menu item already present!' -ForegroundColor Yellow
            }
        }
        Default {
            Write-Host 'Wrong option! Try again...' -ForegroundColor Red
            Break
        }
    }
    Write-Host 'All done!' -ForegroundColor Green
    Pause
}