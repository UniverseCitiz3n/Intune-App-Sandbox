function Invoke-SandboxShellDeployment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Add', 'Update')]
        [string]$Operation
    )

    $sandboxRootFolder = 'C:\SandboxEnvironment'
    $sandboxCoreFolder = Join-Path $sandboxRootFolder 'core'
    $sandboxAppsFolder = Join-Path $sandboxRootFolder 'apps'
    $commandClsid = '{E6A6A7E5-6C7C-4E3F-AAC4-2D47FBCF08F8}'

    Write-Host "Preparing Sandbox folders..." -ForegroundColor Yellow

    try {
        $pathModule = Resolve-SandboxModuleRoot -InvocationInfo $MyInvocation -ScriptRoot $PSScriptRoot
    } catch {
        throw
    }

    $configurationSource = Join-Path -Path $pathModule -ChildPath 'Configuration'
    $helpersSource = Join-Path -Path $pathModule -ChildPath 'Helpers'

    if (-not (Test-Path -Path $configurationSource -PathType Container)) {
        throw "Configuration source folder not found at '$configurationSource'."
    }

    if (-not (Test-Path -Path $helpersSource -PathType Container)) {
        throw "Helpers source folder not found at '$helpersSource'."
    }

    foreach ($folder in @($sandboxRootFolder, $sandboxCoreFolder, $sandboxAppsFolder)) {
        if (-not (Test-Path -Path $folder -PathType Container)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }
    }

    Write-Host "Copying core files to $sandboxCoreFolder" -ForegroundColor Yellow
    Copy-Item -Path (Join-Path -Path $configurationSource -ChildPath '*') -Destination $sandboxCoreFolder -Recurse -Force

    Write-Host "Copying helper files to $sandboxRootFolder" -ForegroundColor Yellow
    Copy-Item -Path (Join-Path -Path $helpersSource -ChildPath '*') -Destination $sandboxRootFolder -Recurse -Force

    $dllPath = Join-Path -Path $sandboxCoreFolder -ChildPath 'IntuneSandboxCmd.dll'
    if (-not (Test-Path -Path $dllPath -PathType Leaf)) {
        throw "COM server not found at '$dllPath'. Build the IntuneSandboxCmd project and copy the DLL to the module's Configuration folder."
    }

    $iconPath = Join-Path -Path $sandboxCoreFolder -ChildPath 'intunewin-Box-icon.ico'

    Write-Host 'Refreshing Explorer command registration...' -ForegroundColor Yellow

    $obsoleteKeys = @(
        'HKCU:\Software\Classes\.intunewin\shell\Run test in Sandbox',
        'HKCU:\Software\Classes\.intunewin\shell\Run test in Sandbox (WinGet enabled)',
        'HKCU:\Software\Classes\Directory\shell\Pack with IntunewinUtil'
    )

    foreach ($key in $obsoleteKeys) {
        if (Test-Path -Path $key) {
            Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $legacyHkcrKeys = @(
        'HKCR:\.intunewin\Shell\Run test in Sandbox',
        'HKCR:\.intunewin\Shell\Run test in Sandbox (WinGet enabled)',
        'HKCR:\Directory\Shell\Pack with IntunewinUtil'
    )

    foreach ($key in $legacyHkcrKeys) {
        try {
            if (Test-Path -Path $key) {
                Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Verbose "Skipping legacy key '$key': $_"
        }
    }

    $clsidKey = "HKCU:\Software\Classes\CLSID\$commandClsid"
    $inprocKey = Join-Path -Path $clsidKey -ChildPath 'InprocServer32'

    New-Item -Path $clsidKey -Force | Out-Null
    Set-Item -Path $clsidKey -Value 'Intune-App-Sandbox'

    New-Item -Path $inprocKey -Force | Out-Null
    Set-Item -Path $inprocKey -Value $dllPath
    New-ItemProperty -Path $inprocKey -Name 'ThreadingModel' -PropertyType String -Value 'Apartment' -Force | Out-Null

    $intuneWinShellKey = 'HKCU:\Software\Classes\.intunewin\shell'
    $intuneWinCommandKey = Join-Path -Path $intuneWinShellKey -ChildPath 'Intune-App-Sandbox'

    New-Item -Path $intuneWinShellKey -Force | Out-Null

    New-Item -Path $intuneWinCommandKey -Force | Out-Null
    Set-Item -Path $intuneWinCommandKey -Value 'Intune-App-Sandbox'
    New-ItemProperty -Path $intuneWinCommandKey -Name 'Icon' -PropertyType String -Value $iconPath -Force | Out-Null
    New-ItemProperty -Path $intuneWinCommandKey -Name 'ExplorerCommandHandler' -PropertyType String -Value $commandClsid -Force | Out-Null

    $directoryShellKey = 'HKCU:\Software\Classes\Directory\shell'
    $directoryCommandKey = Join-Path -Path $directoryShellKey -ChildPath 'Intune-App-Sandbox'

    New-Item -Path $directoryShellKey -Force | Out-Null

    New-Item -Path $directoryCommandKey -Force | Out-Null
    Set-Item -Path $directoryCommandKey -Value 'Intune-App-Sandbox'
    New-ItemProperty -Path $directoryCommandKey -Name 'Icon' -PropertyType String -Value $iconPath -Force | Out-Null
    New-ItemProperty -Path $directoryCommandKey -Name 'ExplorerCommandHandler' -PropertyType String -Value $commandClsid -Force | Out-Null

    [PSCustomObject]@{
        Clsid    = $commandClsid
        DllPath  = $dllPath
        IconPath = $iconPath
        Operation = $Operation
    }
}
