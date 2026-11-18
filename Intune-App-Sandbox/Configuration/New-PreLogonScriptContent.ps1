function New-PreLogonScriptContent {
    <#
    .SYNOPSIS
        Generates the pre-logon script content for sandbox initialization.
    .DESCRIPTION
        Creates the PowerShell script that loads the toast helper, runs the main
        logon script, and records startup errors on the sandbox desktop.
    .PARAMETER SandboxDesktopPath
        The sandbox desktop path (e.g., C:\Users\WDAGUtilityAccount\Desktop).
    .PARAMETER PackageFolderName
        The name of the package folder for the logon script filename.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SandboxDesktopPath,

        [Parameter(Mandatory)]
        [string]$PackageFolderName
    )

    $DesktopLiteral = $SandboxDesktopPath.Replace("'", "''")
    $LogonScriptLiteral = "${PackageFolderName}_LogonCommand.ps1".Replace("'", "''")

    @"
`$ErrorActionPreference = 'Stop'
Start-Transcript -LiteralPath (Join-Path '$DesktopLiteral' 'Intune-App-Sandbox-startup.log') | Out-Null
try {
    . (Join-Path `$PSScriptRoot 'New-ToastNotification.ps1')
    & (Join-Path `$PSScriptRoot '$LogonScriptLiteral')
}
catch {
    Write-Error -ErrorRecord `$_ -ErrorAction Continue
    throw
}
finally {
    Stop-Transcript | Out-Null
}
"@
}
