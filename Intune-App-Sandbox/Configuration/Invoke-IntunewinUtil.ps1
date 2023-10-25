param(
    [String]$PackagePath
)

$SandboxOperatingFolder = 'C:\SandboxEnvironment\bin'
$Folder = Get-Item $PackagePath

if ($Folder.FullName -like '*PSADT'){
    $ArgumentList = "-c `"$($Folder.FullName)`" -s `"$($Folder.FullName)\Deploy-Application.exe`" -o `"$($Folder.FullName)`" -a `"$($Folder.FullName)`" -q"
} else{
    $ArgumentList = "-c `"$($Folder.FullName)`" -s `"$($Folder.FullName)\$($Folder.Name).ps1`" -o `"$($Folder.FullName)`" -a `"$($Folder.FullName)`" -q"
}
$Packing = Start-Process -FilePath $SandboxOperatingFolder\IntuneWinAppUtil.exe -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow