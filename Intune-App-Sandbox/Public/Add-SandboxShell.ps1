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
    Write-Host 'Thanks for using this tool!' -ForegroundColor Green
    Write-Host 'Starting configuration process...' -ForegroundColor Yellow
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
        Copy-Item -Path $PathModule\Configuration\* -Recurse -Destination $SandboxOperatingFolder -Force
        Write-Host "Copying helpers files to C:\SandboxEnvironment" -ForegroundColor Yellow
        Copy-Item -Path $PathModule\Helpers\* -Recurse -Destination 'C:\SandboxEnvironment' -Force
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
                New-Item -Path HKCR_SD:\ -Name '.intunewin'
                New-Item -Path HKCR_SD:\.intunewin -Name 'Shell'
                Set-Item -Path HKCR_SD:\.intunewin\Shell -Value Open
                New-Item -Path HKCR_SD:\.intunewin\Shell -Name 'Run test in Sandbox'
                New-ItemProperty -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name icon -PropertyType 'String' -Value "$SandboxOperatingFolder\sandbox.ico"
                New-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox\Command' -Value "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -command $SandboxOperatingFolder\Invoke-Test.ps1 -PackagePath `"%V`""
            } else {
                Write-Host 'Context menu item already present!' -ForegroundColor Yellow
            }
            If (!(Test-Path -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox with Detection\Command')) {
                Write-Host 'Context menu item not present.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\ -Name '.intunewin'
                New-Item -Path HKCR_SD:\.intunewin -Name 'Shell'
                Set-Item -Path HKCR_SD:\.intunewin\Shell -Value Open
                New-Item -Path HKCR_SD:\.intunewin\Shell -Name 'Run test in Sandbox with Detection'
                New-ItemProperty -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox with Detection' -Name icon -PropertyType 'String' -Value "$SandboxOperatingFolder\sandbox_detection.ico"
                New-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox with Detection' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox with Detection\Command' -Value "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -command $SandboxOperatingFolder\Invoke-Test.ps1 -PackagePath `"%V`" -DetectionScript `$true"
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
                New-Item -Path HKCR_SD:\ -Name '.intunewin'
                New-Item -Path HKCR_SD:\.intunewin -Name 'Shell'
                Set-Item -Path HKCR_SD:\.intunewin\Shell -Value Open
                New-Item -Path HKCR_SD:\.intunewin\Shell -Name 'Run test in Sandbox'
                New-ItemProperty -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name icon -PropertyType 'String' -Value "$SandboxOperatingFolder\sandbox.ico"
                New-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox\Command' -Value "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -command $SandboxOperatingFolder\Invoke-Test.ps1 -PackagePath `"%V`""
            } else {
                Write-Host 'Context menu item already present!' -ForegroundColor Yellow
            }
            If (!(Test-Path -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox with Detection\Command')) {
                Write-Host 'Context menu item not present.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\ -Name '.intunewin'
                New-Item -Path HKCR_SD:\.intunewin -Name 'Shell'
                Set-Item -Path HKCR_SD:\.intunewin\Shell -Value Open
                New-Item -Path HKCR_SD:\.intunewin\Shell -Name 'Run test in Sandbox with Detection'
                New-ItemProperty -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox with Detection' -Name icon -PropertyType 'String' -Value "$SandboxOperatingFolder\sandbox_detection.ico"
                New-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox with Detection' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox with Detection\Command' -Value "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -command $SandboxOperatingFolder\Invoke-Test.ps1 -PackagePath `"%V`" -DetectionScript `$true"
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