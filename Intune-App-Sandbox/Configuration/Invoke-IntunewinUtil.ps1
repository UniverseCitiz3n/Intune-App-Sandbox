param(
    [String]$PackagePath
)

$SandboxOperatingFolder = 'C:\SandboxEnvironment\bin'
$Folder = Get-Item $PackagePath

$ArgumentList = "-c `"$($Folder.FullName)`" -s `"$($Folder.FullName)\$($Folder.Name).ps1`" -o `"$($Folder.FullName)`" -a `"$($Folder.FullName)`" -q"
$Packing = Start-Process -FilePath $SandboxOperatingFolder\IntuneWinAppUtil.exe -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow