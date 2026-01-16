function New-PreLogonScriptContent {
    <#
    .SYNOPSIS
        Generates the pre-logon script content for sandbox initialization.
    .DESCRIPTION
        Creates the PowerShell script that sets execution policy, loads toast notification
        function into profile, and launches the main logon script.
    .PARAMETER SandboxDesktopPath
        The sandbox desktop path (e.g., C:\Users\WDAGUtilityAccount\Desktop).
    .PARAMETER PackageFolderName
        The name of the package folder for the logon script filename.
    .PARAMETER SandboxTestFolder
        The sandbox-side test folder path for this app.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SandboxDesktopPath,

        [Parameter(Mandatory)]
        [string]$PackageFolderName,

        [Parameter(Mandatory)]
        [string]$SandboxTestFolder
    )

    @"
Set-ExecutionPolicy Bypass -Force;
new-item `$PSHOME\Profile.ps1;
Set-Content -Path `$PSHOME\Profile.ps1 -Value '. $SandboxDesktopPath\bin\New-ToastNotification.ps1';
powershell -file '$SandboxTestFolder\LogonCommand.ps1'
"@
}
