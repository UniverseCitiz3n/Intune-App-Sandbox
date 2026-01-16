function New-WSBConfig {
    <#
    .SYNOPSIS
        Generates Windows Sandbox configuration XML.
    .DESCRIPTION
        Creates a .wsb file with mapped folders and logon command.
    .PARAMETER OutputPath
        Full path to the .wsb file to create.
    .PARAMETER HostFolder
        The host folder containing the package to map into sandbox.
    .PARAMETER BinFolder
        The bin folder path on host to map (read-only).
    .PARAMETER TestFolder
        The test folder path on host for this app's test artifacts.
    .PARAMETER LogonCommand
        The command to execute on sandbox logon.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$HostFolder,

        [Parameter(Mandatory)]
        [string]$BinFolder,

        [Parameter(Mandatory)]
        [string]$TestFolder,

        [Parameter(Mandatory)]
        [string]$LogonCommand
    )

    $Config = @"
<Configuration>
<VGpu>Enable</VGpu>
<Networking>Enable</Networking>
<MappedFolders>
<MappedFolder>
<HostFolder>$HostFolder</HostFolder>
<ReadOnly>false</ReadOnly>
</MappedFolder>
<MappedFolder>
<HostFolder>$BinFolder</HostFolder>
<ReadOnly>true</ReadOnly>
</MappedFolder>
<MappedFolder>
<HostFolder>$TestFolder</HostFolder>
<ReadOnly>false</ReadOnly>
</MappedFolder>
</MappedFolders>
<LogonCommand>
<Command>$LogonCommand</Command>
</LogonCommand>
</Configuration>
"@

    $ParentDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $ParentDir)) {
        New-Item -Path $ParentDir -ItemType Directory -Force | Out-Null
    }

    Set-Content -Path $OutputPath -Value $Config -Force
    $OutputPath
}
