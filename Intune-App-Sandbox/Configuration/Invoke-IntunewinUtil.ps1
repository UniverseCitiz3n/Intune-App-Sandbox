param(
    [String]$PackagePath
)

$SandboxCoreFolder = 'C:\SandboxEnvironment\core'
$Folder = Get-Item $PackagePath

if ($Folder.FullName -like '*PSADT'){
    $ArgumentList = "-c `"$($Folder.FullName)`" -s `"$($Folder.FullName)\Deploy-Application.exe`" -o `"$($Folder.FullName)`" -a `"$($Folder.FullName)`" -q"
} else{
    $ArgumentList = "-c `"$($Folder.FullName)`" -s `"$($Folder.FullName)\$($Folder.Name).ps1`" -o `"$($Folder.FullName)`" -a `"$($Folder.FullName)`" -q"
}
$Packing = Start-Process -FilePath $SandboxCoreFolder\IntuneWinAppUtil.exe -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow
$IntunewinFile = Get-ChildItem -Path $Folder.FullName -Filter '*.intunewin' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$TargetName = "$($Folder.Name).intunewin"
if ($IntunewinFile -and $IntunewinFile.Name -ne $TargetName) {
    Rename-Item -Path $IntunewinFile.FullName -NewName $TargetName -Force
}
