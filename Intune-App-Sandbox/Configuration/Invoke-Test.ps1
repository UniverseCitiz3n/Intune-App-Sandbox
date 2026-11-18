<#
.SYNOPSIS
    Invoke-Test v2.0 - Tests Intune Win32 app packages in Windows Sandbox.
.DESCRIPTION
    Decodes and runs .intunewin packages in an isolated Windows Sandbox environment.
    Supports standard PowerShell installers and PSADT v3/v4 packages.
.PARAMETER PackagePath
    Full path to the .intunewin file to test.
.NOTES
    Version: 1.4.0
    Refactored with helper functions for improved maintainability.
#>
param(
    [Parameter(Mandatory)]
    [String]$PackagePath,

    [Parameter()]
    [Switch]$RunAsUser
)

$ErrorActionPreference = 'Stop'

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
$PackageItem = Get-Item -LiteralPath $PackagePath
$PackageFolderName = $PackageItem.Directory.Name
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

New-Item -Path $BinFolder -ItemType Directory -Force | Out-Null
#endregion

#region Computed Paths
$SandboxSharedPath = "$SandboxDesktopPath\$PackageFolderName"
$FullStartupPath = "$SandboxSharedPath\$FileName"
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
    RunAsUser             = $RunAsUser.IsPresent
}

$LogonScriptContent = New-LogonScriptContent -Params $LogonScriptParams
$PreLogonScriptContent = New-PreLogonScriptContent -SandboxDesktopPath $SandboxDesktopPath -PackageFolderName $PackageFolderName

# Write logon scripts to bin folder (mapped to sandbox desktop\bin)
$LogonScriptPath = Join-Path $BinFolder "${PackageFolderName}_LogonCommand.ps1"
$PreLogonScriptPath = Join-Path $BinFolder "${PackageFolderName}_PreLogonCommand.ps1"

Set-Content -LiteralPath $LogonScriptPath -Value $LogonScriptContent -Encoding UTF8 -Force
Set-Content -LiteralPath $PreLogonScriptPath -Value $PreLogonScriptContent -Encoding UTF8 -Force
#endregion

#region Create and Launch Sandbox
$GuestPreLogonPath = "$SandboxDesktopPath\bin\${PackageFolderName}_PreLogonCommand.ps1"
$WSBPath = Join-Path $SandboxOperatingFolder "$PackageFolderName.wsb"

New-WSBConfig -OutputPath $WSBPath `
              -HostFolder $PackageDirectory `
              -BinFolder $BinFolder `
              -PreLogonScriptPath $GuestPreLogonPath

Start-Process -FilePath $WSBPath
#endregion