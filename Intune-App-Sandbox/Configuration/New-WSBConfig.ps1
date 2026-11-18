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
    .PARAMETER PreLogonScriptPath
        The guest path to the script to execute on sandbox logon.
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
        [string]$PreLogonScriptPath
    )

    # XML-encode values to handle special characters in paths/commands
    $XmlHostFolder = [System.Security.SecurityElement]::Escape($HostFolder)
    $XmlBinFolder = [System.Security.SecurityElement]::Escape($BinFolder)
    $LogonCommand = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $PreLogonScriptPath
    $XmlLogonCommand = [System.Security.SecurityElement]::Escape($LogonCommand)

    $Config = @"
<Configuration>
<VGpu>Enable</VGpu>
<Networking>Enable</Networking>
<MappedFolders>
<MappedFolder>
<HostFolder>$XmlHostFolder</HostFolder>
<ReadOnly>false</ReadOnly>
</MappedFolder>
<MappedFolder>
<HostFolder>$XmlBinFolder</HostFolder>
<ReadOnly>true</ReadOnly>
</MappedFolder>
</MappedFolders>
<LogonCommand>
<Command>$XmlLogonCommand</Command>
</LogonCommand>
</Configuration>
"@

    $ParentDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path -LiteralPath $ParentDir)) {
        New-Item -Path $ParentDir -ItemType Directory -Force | Out-Null
    }

    Set-Content -LiteralPath $OutputPath -Value $Config -Encoding UTF8 -Force
    $OutputPath
}
