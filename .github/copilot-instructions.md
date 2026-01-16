# Intune-App-Sandbox AI Coding Instructions

## Project Overview
PowerShell module for testing Intune Win32 app deployment packages locally using Windows Sandbox before deploying to production. Published to PSGallery as `Intune-App-Sandbox`.

## Architecture & Key Components

### Module Structure
- **Module Root**: [Intune-App-Sandbox/](Intune-App-Sandbox/) - Standard PowerShell module with `.psd1` manifest and `.psm1` loader
- **Public Functions**: [Intune-App-Sandbox/Public/](Intune-App-Sandbox/Public/) - Exported cmdlets (`Add-SandboxShell`, `Update-SandboxShell`)
- **Configuration Scripts**: [Intune-App-Sandbox/Configuration/](Intune-App-Sandbox/Configuration/) - Core logic for packing/testing (not exposed as cmdlets)
- **Helper Scripts**: [Intune-App-Sandbox/Helpers/](Intune-App-Sandbox/Helpers/) - Templates and utilities copied to `C:\SandboxEnvironment`

### Module Loading Pattern
The [Intune-App-Sandbox.psm1](Intune-App-Sandbox/Intune-App-Sandbox.psm1) uses dot-sourcing to load all `.ps1` files from Public folder and auto-exports them:
```powershell
$Public = @(Get-ChildItem -Recurse -Path $PSScriptRoot\Public\*.ps1)
foreach ($import in $Public) { . $import.fullname }
Export-ModuleMember -Function $Public.Basename
```

### Critical Workflow
1. **Setup**: `Add-SandboxShell` creates `C:\SandboxEnvironment` and adds Windows context menu items
2. **Packing**: Right-click folder → "Pack with IntunewinUtil" → [Invoke-IntunewinUtil.ps1](Intune-App-Sandbox/Configuration/Invoke-IntunewinUtil.ps1) packages as `.intunewin`
3. **Testing**: Right-click `.intunewin` → "Run test in Sandbox" → [Invoke-Test.ps1](Intune-App-Sandbox/Configuration/Invoke-Test.ps1) decodes and runs in Windows Sandbox

## PowerShell Conventions

### Naming Requirements
- **Package Folder Must Match Script Name**: Folder `Install-VSCode` must contain `Install-VSCode.ps1` (IntuneWinAppUtil enforces this)

### Special File Handling
- **PSADT Support**: Auto-detects PowerShell Application Deployment Toolkit packages:
  - PSADTv3: Uses `Deploy-Application.exe` as setup file
  - PSADTv4: Uses `Invoke-AppDeployToolkit.ps1`
  - See [Invoke-IntunewinUtil.ps1](Intune-App-Sandbox/Configuration/Invoke-IntunewinUtil.ps1#L7-L13)


## Windows Sandbox Integration

### WSB File Generation
[Invoke-Test.ps1](Intune-App-Sandbox/Configuration/Invoke-Test.ps1) dynamically creates `.wsb` XML config with:
- Mapped folders: Package location + `C:\SandboxEnvironment\bin`
- LogonCommand: PowerShell script to decode `.intunewin` and run installer as SYSTEM scheduled task

### Nested PowerShell Pattern
Critical technique in [Invoke-Test.ps1](Intune-App-Sandbox/Configuration/Invoke-Test.ps1#L94-L98):
```powershell
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-ex bypass "powershell {& C:\Temp\Install.ps1};New-Item C:\Temp\$Lastexitcode.code -force"'
```
Outer PowerShell captures `$LASTEXITCODE` from inner script execution and saves to file for result retrieval.

### Toast Notifications
Use [New-ToastNotification.ps1](Intune-App-Sandbox/Configuration/New-ToastNotification.ps1) to show progress inside Sandbox (defined in [toast.xml](Intune-App-Sandbox/Configuration/toast.xml)).

## Registry Context Menu Management

### Registry Drive Pattern
[Add-SandboxShell.ps1](Intune-App-Sandbox/Public/Add-SandboxShell.ps1#L55) creates temporary `HKCR_SD:` drive for HKEY_CLASSES_ROOT access:
```powershell
New-PSDrive -PSProvider registry -Root HKEY_CLASSES_ROOT -Name HKCR_SD
```

### Context Menu Paths
- **Pack**: `HKCR_SD:\Directory\Shell\Pack with IntunewinUtil\Command`
- **Test**: `HKCR_SD:\.intunewin\Shell\Run test in Sandbox\Command`

## Testing & Build

### Tests Location
[tests/Unit.Tests.ps1](tests/Unit.Tests.ps1) - Pester tests verify Configuration folder contains all 9 required files (icons, exes, scripts).

### Build Script
[build/build.ps1](build/build.ps1) - Prepares NuGet/PSGallery for module publishing.

## Development Workflow

### Making Changes
1. Edit scripts in `Intune-App-Sandbox/` folder structure
2. Test locally: `Import-Module .\Intune-App-Sandbox\Intune-App-Sandbox.psd1 -Force`
3. For Configuration/Helper changes: Re-run `Add-SandboxShell` to update `C:\SandboxEnvironment`
4. Run Pester tests: `Invoke-Pester .\tests\Unit.Tests.ps1`

### Module Installation Paths
- **Dev**: Import from repo folder
- **Production**: `Install-Module Intune-App-Sandbox` → installs to standard PowerShell module path
- **Sandbox Runtime**: Scripts copied to `C:\SandboxEnvironment` (used by context menu commands)

## Common Gotchas

1. **Admin Required**: Most operations require elevated PowerShell (enforced in Public functions)
2. **Sandbox Feature**: Windows Sandbox must be enabled (`Containers-DisposableClientVM` feature)
3. **Path Quoting**: Context menu commands use `%V` variable - always quote paths with spaces
4. **IntuneWinAppUtil Decoder**: Separate decoder exe ([IntuneWinAppUtilDecoder.exe](Intune-App-Sandbox/Configuration/)) required for unpacking inside Sandbox
