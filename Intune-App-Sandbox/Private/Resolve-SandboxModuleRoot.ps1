function Resolve-SandboxModuleRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.InvocationInfo]
        $InvocationInfo,

        [string]
        $ScriptRoot
    )

    $candidateRoots = @()

    if ($InvocationInfo.MyCommand.Module -and $InvocationInfo.MyCommand.Module.ModuleBase) {
        $candidateRoots += $InvocationInfo.MyCommand.Module.ModuleBase
    }

    if ($InvocationInfo.MyCommand.Path) {
        $candidateRoots += (Split-Path -Path $InvocationInfo.MyCommand.Path -Parent)
    }

    if ($ScriptRoot) {
        $candidateRoots += $ScriptRoot
    }

    $candidateRoots = $candidateRoots | Where-Object { $_ } | Select-Object -Unique

    foreach ($candidate in $candidateRoots) {
        $resolved = Resolve-Path -Path $candidate -ErrorAction SilentlyContinue
        if (-not $resolved) {
            continue
        }

        foreach ($resolvedPath in $resolved) {
            $current = $resolvedPath.ProviderPath
            while ($current) {
                if (Test-Path -Path (Join-Path -Path $current -ChildPath 'Configuration')) {
                    return (Get-Item -Path $current).FullName
                }

                $parent = Split-Path -Path $current -Parent
                if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
                    break
                }

                $current = $parent
            }
        }
    }

    throw "Unable to locate the Intune-App-Sandbox module root. Ensure the 'Configuration' folder exists alongside this script."
}
