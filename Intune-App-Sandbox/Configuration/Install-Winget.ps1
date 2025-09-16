[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if (Get-Command -Name 'winget.exe' -ErrorAction SilentlyContinue) {
    Write-Verbose 'winget.exe already available. Skipping installation.'
    return
}

if (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue) {
    if (Get-Command -Name 'winget.exe' -ErrorAction SilentlyContinue) {
        Write-Verbose 'App Installer present and winget.exe available. Skipping installation.'
        return
    }
}

Write-Host 'Installing Winget (App Installer) and dependencies in Windows Sandbox...' -ForegroundColor Yellow

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$releaseApiUri = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'
$githubHeaders = @{
    'User-Agent' = 'IntuneAppSandbox'
    'Accept'     = 'application/vnd.github+json'
}

try {
    $releaseInfo = Invoke-RestMethod -Uri $releaseApiUri -Headers $githubHeaders
}
catch {
    throw "Failed to query winget releases from GitHub: $($_.Exception.Message)"
}

if (-not $releaseInfo) {
    throw 'GitHub returned an empty response when requesting winget release metadata.'
}

$releaseTag = $releaseInfo.tag_name
if (-not $releaseTag) {
    throw 'Unable to determine the latest winget release tag from GitHub metadata.'
}

$assets = $releaseInfo.assets
if (-not $assets) {
    throw 'No release assets were returned for the latest winget release.'
}

Write-Host "Latest winget release detected: $releaseTag" -ForegroundColor Cyan

$dependenciesAsset = $assets | Where-Object { $_.name -match 'DesktopAppInstaller_Dependencies\.zip$' } | Select-Object -First 1
if (-not $dependenciesAsset) {
    throw 'Unable to locate DesktopAppInstaller_Dependencies.zip in the latest winget release.'
}

$appInstallerAsset = $assets |
    Where-Object { $_.name -match '^Microsoft\.DesktopAppInstaller_.*\.(msixbundle|appxbundle)$' } |
    Sort-Object { if ($_.name -like '*.msixbundle') { 0 } else { 1 } }, { $_.name } |
    Select-Object -First 1
if (-not $appInstallerAsset) {
    throw 'Unable to locate the Microsoft.DesktopAppInstaller msixbundle in the latest winget release.'
}

$downloadRoot = Join-Path -Path $env:TEMP -ChildPath 'WingetInstall'
$releaseDownloadRoot = Join-Path -Path $downloadRoot -ChildPath $releaseTag
$dependenciesArchive = Join-Path -Path $releaseDownloadRoot -ChildPath $dependenciesAsset.name
$dependenciesExtractPath = Join-Path -Path $releaseDownloadRoot -ChildPath 'Dependencies'
$appInstallerPath = Join-Path -Path $releaseDownloadRoot -ChildPath $appInstallerAsset.name

if (-not (Test-Path -Path $releaseDownloadRoot -PathType Container)) {
    New-Item -Path $releaseDownloadRoot -ItemType Directory -Force | Out-Null
}

function Get-FileFromGitHubRelease {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $DestinationPath -PathType Leaf)) {
        $message = if ($Description) {
            "Downloading $Description from $Uri"
        }
        else {
            "Downloading $Uri"
        }

        Write-Host $message -ForegroundColor Cyan
        Invoke-WebRequest -Uri $Uri -Headers $githubHeaders -OutFile $DestinationPath -UseBasicParsing
    }
    else {
        if ($Description) {
            Write-Verbose "$Description already downloaded at $DestinationPath"
        }
        else {
            Write-Verbose "File already downloaded at $DestinationPath"
        }
    }
}

Get-FileFromGitHubRelease -Uri $dependenciesAsset.browser_download_url -DestinationPath $dependenciesArchive -Description 'App Installer dependencies'
Get-FileFromGitHubRelease -Uri $appInstallerAsset.browser_download_url -DestinationPath $appInstallerPath -Description 'Microsoft App Installer bundle'

if (Test-Path -Path $dependenciesExtractPath -PathType Container) {
    Remove-Item -Path $dependenciesExtractPath -Recurse -Force
}

Write-Host 'Expanding dependencies archive...' -ForegroundColor Yellow
Expand-Archive -Path $dependenciesArchive -DestinationPath $dependenciesExtractPath -Force

$architectures = if ([Environment]::Is64BitOperatingSystem) { @('x64', 'x86') } else { @('x86') }
foreach ($architecture in $architectures) {
    $architecturePath = Join-Path -Path $dependenciesExtractPath -ChildPath $architecture
    if (-not (Test-Path -Path $architecturePath -PathType Container)) {
        continue
    }

    Get-ChildItem -Path $architecturePath -Filter '*.appx' | ForEach-Object {
        $packageName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        $packageMoniker = $packageName.Split('_')[0]
        $architectureMatch = $architecture.ToLowerInvariant()
        $existingPackage = Get-AppxPackage -Name $packageMoniker -ErrorAction SilentlyContinue | Where-Object {
            $_.Architecture.ToString().ToLowerInvariant() -eq $architectureMatch
        }

        if (-not $existingPackage) {
            Write-Host "Installing dependency package $($_.Name)" -ForegroundColor Green
            Add-AppxPackage -Path $_.FullName -ForceApplicationShutdown:$true
        }
        else {
            Write-Verbose "Dependency package $packageMoniker ($architecture) already installed."
        }
    }
}

Write-Host 'Installing Microsoft App Installer (winget)...' -ForegroundColor Yellow
Add-AppxPackage -Path $appInstallerPath -ForceApplicationShutdown:$true

if (Get-Command -Name 'winget.exe' -ErrorAction SilentlyContinue) {
    Write-Host 'Winget installation completed successfully.' -ForegroundColor Green
}
else {
    throw 'Winget installation failed. winget.exe not found after installation.'
}
