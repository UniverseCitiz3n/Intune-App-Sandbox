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
    $PowerShellExecutable = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $InvokeTestPath = Join-Path -Path $SandboxCoreFolder -ChildPath 'Invoke-Test.ps1'
    $InvokeIntuneWinPath = Join-Path -Path $SandboxCoreFolder -ChildPath 'Invoke-IntunewinUtil.ps1'
    $InvokeTestCommand = '{0} -executionpolicy bypass -command {1} -PackagePath "%V"' -f $PowerShellExecutable, $InvokeTestPath
    $InvokeTestWingetCommand = '{0} -executionpolicy bypass -command {1} -PackagePath "%V" -EnableWinget' -f $PowerShellExecutable, $InvokeTestPath
    $InvokeIntuneWinCommand = '{0} -executionpolicy bypass -file {1} -PackagePath "%V"' -f $PowerShellExecutable, $InvokeIntuneWinPath
    $coreExists = Test-Path -Path $SandboxCoreFolder -PathType Container
    if (-not $coreExists) {
        Start-Sleep 2
        Write-Host 'Not found!' -ForegroundColor Red
        Write-Host 'Adding operating folders...' -ForegroundColor Yellow
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

    if (-not $coreExists) {
        Start-Sleep 1
        Write-Host 'Folders found!' -ForegroundColor Green
    } else {
        Write-Host 'Folders ready.' -ForegroundColor Green
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
    Write-Host "
Context menu options:
1 - Add '.intunewin' test entries (standard + WinGet enabled)
2 - Add 'Pack with IntunewinUtil'
3 - Add test and pack entries
" -ForegroundColor Yellow
    Write-Host 'Please specify your choice: ' -ForegroundColor Yellow -NoNewline
    $Option = Read-Host
    New-PSDrive -PSProvider registry -Root HKEY_CLASSES_ROOT -Name HKCR_SD | Out-Null
    if (Test-Path -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox with Detection') {
        Write-Host "Removing legacy 'Run test in Sandbox with Detection' entry" -ForegroundColor Yellow
        Remove-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox with Detection' -Recurse -Force -ErrorAction SilentlyContinue
    }
    switch ($Option) {
        3 {
            If (!(Test-Path -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox\Command')) {
                Write-Host 'Context menu item not present.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\ -Name '.intunewin'
                New-Item -Path HKCR_SD:\.intunewin -Name 'Shell'
                Set-Item -Path HKCR_SD:\.intunewin\Shell -Value Open
                New-Item -Path HKCR_SD:\.intunewin\Shell -Name 'Run test in Sandbox'
                New-ItemProperty -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name icon -PropertyType 'String' -Value "$SandboxCoreFolder\sandbox.ico"
                New-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox\Command' -Value $InvokeTestCommand
            } else {
                Write-Host 'Context menu item already present!' -ForegroundColor Yellow
            }
            If (!(Test-Path -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)\Command')) {
                Write-Host 'Context menu item not present.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\ -Name '.intunewin'
                New-Item -Path HKCR_SD:\.intunewin -Name 'Shell'
                Set-Item -Path HKCR_SD:\.intunewin\Shell -Value Open
                New-Item -Path HKCR_SD:\.intunewin\Shell -Name 'Run test in Sandbox (WinGet enabled)'
                New-ItemProperty -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)' -Name icon -PropertyType 'String' -Value "$SandboxCoreFolder\sandbox.ico"
                New-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)\Command' -Value $InvokeTestWingetCommand
            } else {
                Write-Host 'WinGet-enabled context menu item already present!' -ForegroundColor Yellow
            }
        }
        2 {
            If (!(Test-Path -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil\Command')) {
                Write-Host 'Context menu item not present.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\Directory\Shell\ -Name 'Pack with IntunewinUtil'
                New-ItemProperty -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil' -Name icon -PropertyType 'String' -Value "$SandboxCoreFolder\intunewin-Box-icon.ico"
                New-Item -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil\Command' -Value $InvokeIntuneWinCommand
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
                New-ItemProperty -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name icon -PropertyType 'String' -Value "$SandboxCoreFolder\sandbox.ico"
                New-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox\Command' -Value $InvokeTestCommand
            } else {
                Write-Host 'Context menu item already present!' -ForegroundColor Yellow
            }
            If (!(Test-Path -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)\Command')) {
                Write-Host 'Context menu item not present.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\ -Name '.intunewin'
                New-Item -Path HKCR_SD:\.intunewin -Name 'Shell'
                Set-Item -Path HKCR_SD:\.intunewin\Shell -Value Open
                New-Item -Path HKCR_SD:\.intunewin\Shell -Name 'Run test in Sandbox (WinGet enabled)'
                New-ItemProperty -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)' -Name icon -PropertyType 'String' -Value "$SandboxCoreFolder\sandbox.ico"
                New-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)\Command' -Value $InvokeTestWingetCommand
            } else {
                Write-Host 'WinGet-enabled context menu item already present!' -ForegroundColor Yellow
            }
            If (!(Test-Path -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil\Command')) {
                Write-Host 'Context menu item not present.' -ForegroundColor Green
                New-Item -Path HKCR_SD:\Directory\Shell\ -Name 'Pack with IntunewinUtil'
                New-ItemProperty -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil' -Name icon -PropertyType 'String' -Value "$SandboxCoreFolder\intunewin-Box-icon.ico"
                New-Item -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil' -Name 'Command'
                Set-Item -Path 'HKCR_SD:\Directory\Shell\Pack with IntunewinUtil\Command' -Value $InvokeIntuneWinCommand
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
