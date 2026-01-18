<#
.SYNOPSIS
    Invoke-Test v2.0 - Tests Intune Win32 app packages in Windows Sandbox.
.DESCRIPTION
    Decodes and runs .intunewin packages in an isolated Windows Sandbox environment.
    Supports standard PowerShell installers and PSADT v3/v4 packages.
.PARAMETER PackagePath
    Full path to the .intunewin file to test.
.NOTES
    Version: 2.0
    Refactored with helper functions for improved maintainability.
#>
param(
    [Parameter(Mandatory)]
    [String]$PackagePath
)

#region Import Helpers
. (Join-Path $PSScriptRoot 'New-WSBConfig.ps1')
. (Join-Path $PSScriptRoot 'New-LogonScriptContent.ps1')
. (Join-Path $PSScriptRoot 'New-PreLogonScriptContent.ps1')
#endregion

#region Configuration
$SandboxOperatingFolder = 'C:\SandboxEnvironment'
$SandboxDesktopPath = 'C:\Users\WDAGUtilityAccount\Desktop'
$SandboxTempFolder = 'C:\Temp'
$ToastTitle = 'Intune App Sandbox'
#endregion

#region Package Metadata
$PackageItem = Get-Item $PackagePath
$PackageFolderName = Split-Path (Split-Path $PackagePath -Parent) -Leaf
$FileName = $PackageItem.Name
$FileNameZIP = $FileName -replace '\.intunewin$', '.zip'
$PackageDirectory = $PackageItem.Directory.FullName

# Detect PSADT v3/v4 or standard installer
$FileNameRun = switch -Wildcard ($FileName) {
    'Deploy-Application*'      { 'Deploy-Application.exe' }
    'Invoke-AppDeployToolkit*' { 'Invoke-AppDeployToolkit.ps1' }
    default                    { $FileName -replace '\.intunewin$', '.ps1' }
}
#endregion

#region Folder Setup
$BinFolder = Join-Path $SandboxOperatingFolder 'bin'

if (-not (Test-Path -Path $SandboxOperatingFolder -PathType Container)) {
    New-Item -Path $SandboxOperatingFolder -ItemType Directory -Force | Out-Null
}
#endregion

#region Computed Paths
$SandboxSharedPath = "$SandboxDesktopPath\$PackageFolderName"
$FullStartupPath = """$SandboxSharedPath\$FileName"""
$ToastNotificationPath = "$SandboxDesktopPath\bin"
#endregion

#region Generate Logon Scripts
$LogonScriptParams = @{
    ToastNotificationPath = $ToastNotificationPath
    ToastTitle            = $ToastTitle
    SandboxTempFolder     = $SandboxTempFolder
    FullStartupPath       = $FullStartupPath
    SandboxDesktopPath    = $SandboxDesktopPath
    FileName              = $FileName
    FileNameZIP           = $FileNameZIP
    FileNameRun           = $FileNameRun
    PackageFolderName     = $PackageFolderName
}

$LogonScriptContent = New-LogonScriptContent -Params $LogonScriptParams
$PreLogonScriptContent = New-PreLogonScriptContent -SandboxDesktopPath $SandboxDesktopPath -PackageFolderName $PackageFolderName

# Write logon scripts to bin folder (mapped to sandbox desktop\bin)
$LogonScriptPath = Join-Path $BinFolder "${PackageFolderName}_LogonCommand.ps1"
$PreLogonScriptPath = Join-Path $BinFolder "${PackageFolderName}_PreLogonCommand.ps1"

New-Item -Path $LogonScriptPath -ItemType File -Value $LogonScriptContent -Force | Out-Null
New-Item -Path $PreLogonScriptPath -ItemType File -Value $PreLogonScriptContent -Force | Out-Null
#endregion

#region Create and Launch Sandbox
$StartupCommand = "powershell.exe -WindowStyle Hidden -executionpolicy bypass -command $SandboxDesktopPath\bin\${PackageFolderName}_PreLogonCommand.ps1"
$WSBPath = Join-Path $SandboxOperatingFolder "$PackageFolderName.wsb"

New-WSBConfig -OutputPath $WSBPath `
              -HostFolder $PackageDirectory `
              -BinFolder $BinFolder `
              -LogonCommand $StartupCommand

Start-Process $WSBPath
#endregion