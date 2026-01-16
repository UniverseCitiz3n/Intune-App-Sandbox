param(
    [String]$PackagePath
)
$Global:ErrorActionPreference = 'Stop'
$SandboxOperatingFolder = 'C:\SandboxEnvironment\bin'
$Folder = Get-Item $PackagePath

if ($Folder.FullName -like '*PSADT') {
    $ArgumentList = "-c `"$($Folder.FullName)`" -s `"$($Folder.FullName)\Deploy-Application.exe`" -o `"$($Folder.FullName)`" -a `"$($Folder.FullName)`" -q"
} elseif ($folder.FullName -like '*PSADTv4') {
    $ArgumentList = "-c `"$($Folder.FullName)`" -s `"$($Folder.FullName)\Invoke-AppDeployToolkit.exe`" -o `"$($Folder.FullName)`" -a `"$($Folder.FullName)`" -q"
} else {
    $ArgumentList = "-c `"$($Folder.FullName)`" -s `"$($Folder.FullName)\$($Folder.Name).ps1`" -o `"$($Folder.FullName)`" -a `"$($Folder.FullName)`" -q"
}
try {
    $Packing = Start-Process -FilePath $SandboxOperatingFolder\IntuneWinAppUtil.exe -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow
} catch {
    Write-Error "An error occurred: $_"
    Pause
}