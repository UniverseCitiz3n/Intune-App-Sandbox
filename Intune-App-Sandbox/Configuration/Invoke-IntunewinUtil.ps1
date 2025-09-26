param(
    [String]$PackagePath
)

$Global:ErrorActionPreference = 'Stop'

$SandboxCoreFolder = 'C:\SandboxEnvironment\core'
if (-not (Test-Path -LiteralPath $SandboxCoreFolder -PathType Container)) {
    throw "Sandbox core folder '$SandboxCoreFolder' was not found. Run Add-SandboxShell first."
}

$intuneWinAppUtilPath = Join-Path -Path $SandboxCoreFolder -ChildPath 'IntuneWinAppUtil.exe'
if (-not (Test-Path -LiteralPath $intuneWinAppUtilPath -PathType Leaf)) {
    throw "Unable to locate IntuneWinAppUtil.exe at '$intuneWinAppUtilPath'."
}

$Folder = Get-Item -LiteralPath $PackagePath
if (-not $Folder.PSIsContainer) {
    throw "PackagePath '$PackagePath' must point to a directory."
}

if ($Folder.FullName -like '*PSADT') {
    $ArgumentList = "-c `"$($Folder.FullName)`" -s `"$($Folder.FullName)\Deploy-Application.exe`" -o `"$($Folder.FullName)`" -a `"$($Folder.FullName)`" -q"
} elseif ($Folder.FullName -like '*PSADTv4') {
    $ArgumentList = "-c `"$($Folder.FullName)`" -s `"$($Folder.FullName)\Invoke-AppDeployToolkit.exe`" -o `"$($Folder.FullName)`" -a `"$($Folder.FullName)`" -q"
} else {
    $ArgumentList = "-c `"$($Folder.FullName)`" -s `"$($Folder.FullName)\$($Folder.Name).ps1`" -o `"$($Folder.FullName)`" -a `"$($Folder.FullName)`" -q"
}

try {
    $null = Start-Process -FilePath $intuneWinAppUtilPath -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow
} catch {
    throw "Failed while executing IntuneWinAppUtil.exe: $($_.Exception.Message)"
}

$IntunewinFile = Get-ChildItem -Path $Folder.FullName -Filter '*.intunewin' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$TargetName = "$($Folder.Name).intunewin"
if ($IntunewinFile -and $IntunewinFile.Name -ne $TargetName) {
    Rename-Item -Path $IntunewinFile.FullName -NewName $TargetName -Force
}
