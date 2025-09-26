param(
    [Parameter(Mandatory = $true)]
    [string] $PackagePath,
    [switch] $EnableWinget
)

$Global:ErrorActionPreference = 'Stop'

$packageItem = Get-Item -LiteralPath $PackagePath
if ($packageItem.PSIsContainer) {
    throw "PackagePath '$PackagePath' must point to an .intunewin file."
}

$PackageFolderName = Split-Path (Split-Path $packageItem.FullName -Parent) -Leaf
$FileName = $packageItem.Name
$SandboxRootFolder = 'C:\SandboxEnvironment'
$SandboxCoreFolder = Join-Path $SandboxRootFolder 'core'
$SandboxAppRoot = Join-Path $SandboxRootFolder 'apps'
$AppFolder = Join-Path $SandboxAppRoot $PackageFolderName
$SandboxFile = "$PackageFolderName.wsb"
$SandboxFilePath = Join-Path $AppFolder $SandboxFile
$FileNameZIP = $FileName -replace '.intunewin', '.zip'

switch -Wildcard ($FileName) {
    'Deploy-Application*' { $FileNameRun = 'Deploy-Application.exe'; break }
    'Invoke-AppDeployToolkit*' { $FileNameRun = 'Invoke-AppDeployToolkit.exe'; break }
    default { $FileNameRun = $FileName -replace '.intunewin', '.ps1' }
}

$SandboxDesktopPath = 'C:\Users\WDAGUtilityAccount\Desktop'
$SandboxTempFolder = 'C:\Temp'
$SandboxSharedPath = Join-Path $SandboxDesktopPath $PackageFolderName
$FullStartupPath = '"' + (Join-Path $SandboxSharedPath $FileName) + '"'
$ToastNotificationPath = Join-Path $SandboxDesktopPath 'core'
$ToastTitle = 'Intune App Sandbox'

if (-not (Test-Path -LiteralPath $SandboxCoreFolder -PathType Container)) {
    throw "Sandbox core folder '$SandboxCoreFolder' was not found. Run Add-SandboxShell first."
}

if (-not (Test-Path -LiteralPath $AppFolder -PathType Container)) {
    New-Item -Path $AppFolder -ItemType Directory -Force | Out-Null
}

function New-WSB {
    param(
        [Parameter(Mandatory = $true)]
        [string] $CommandToRun
    )

    New-Item -Path $SandboxFilePath -ItemType File -Force | Out-Null
    $config = @"
<Configuration>
<VGpu>Enable</VGpu>
<Networking>Enable</Networking>
<MappedFolders>
<MappedFolder>
<HostFolder>$((Get-Item -LiteralPath $PackagePath).Directory)</HostFolder>
<ReadOnly>false</ReadOnly>
</MappedFolder>
<MappedFolder>
<HostFolder>$SandboxCoreFolder</HostFolder>
<ReadOnly>true</ReadOnly>
</MappedFolder>
<MappedFolder>
<HostFolder>$AppFolder</HostFolder>
<ReadOnly>true</ReadOnly>
</MappedFolder>
</MappedFolders>
<LogonCommand>
<Command>$CommandToRun</Command>
</LogonCommand>
</Configuration>
"@
    Set-Content -Path $SandboxFilePath -Value $config
}

$ScriptBlock = @"
New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title '$ToastTitle' -Body 'Pre-configurations and file decoding initiated'
if (!(Test-Path -Path $SandboxTempFolder -PathType Container)) {
    New-Item -Path $SandboxTempFolder -ItemType Directory | Out-Null
}
Copy-Item -Path $FullStartupPath -Destination $SandboxTempFolder -Force
`$decoder = Start-Process -FilePath $SandboxDesktopPath\core\IntuneWinAppUtilDecoder.exe -ArgumentList "$SandboxTempFolder\$FileName /s" -NoNewWindow -PassThru -Wait

Rename-Item -Path "$SandboxTempFolder\$FileName.decoded" -NewName `'$FileNameZIP`' -Force
Expand-Archive -Path "$SandboxTempFolder\$FileNameZIP" -Destination $SandboxTempFolder -Force
Remove-Item -Path "$SandboxTempFolder\$FileNameZIP" -Force
New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title '$ToastTitle' -Body 'Decoding finished!'

`$taskName = 'Install App'
`$exitCodeFile = Join-Path $SandboxTempFolder '$Lastexitcode.code'
if (Test-Path `$exitCodeFile) { Remove-Item `$exitCodeFile -Force }

`$TaskActionArgument = '-ex bypass "powershell {New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title {$ToastTitle} -Body {Installing software};`
    & $SandboxTempFolder\$FileNameRun;`
    `$code = `$LASTEXITCODE;`
    Set-Content -Path $SandboxTempFolder\`$Lastexitcode.code -Value `$code -Force;`
    New-ToastNotification -XmlPath $ToastNotificationPath\toast.xml -Title {$ToastTitle} -Body """Installation completed with code: `$code""";}`"'

`$trigger = New-ScheduledTaskTrigger -Once -At `$(Get-Date).AddSeconds(5)
`$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument `$TaskActionArgument
`$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1) -AllowStartIfOnBatteries -StartWhenAvailable:`$false

Register-ScheduledTask -TaskName `$taskName -Trigger `$trigger -User 'SYSTEM' -Action `$action -Settings `$settings -Force | Out-Null
Start-ScheduledTask -TaskName `$taskName

try {
    for (`$i = 0; `$i -lt 720; `$i++) {
        if (Test-Path `$exitCodeFile) { break }
        Start-Sleep -Seconds 5
    }
} finally {
    Unregister-ScheduledTask -TaskName `$taskName -Confirm:$false -ErrorAction SilentlyContinue
}
"@

New-Item -Path $AppFolder -Name "$PackageFolderName`_LogonCommand.ps1" -ItemType File -Value $ScriptBlock -Force | Out-Null

$installWingetLine = if ($EnableWinget.IsPresent) { "& 'C:\Users\WDAGUtilityAccount\Desktop\core\Install-Winget.ps1';" } else { '' }

$PreLogonContent = @"
Set-ExecutionPolicy Bypass -Force;
New-Item -Path $PSHOME\Profile.ps1 -ItemType File -Force | Out-Null;
Set-Content -Path $PSHOME\Profile.ps1 -Value '. C:\Users\WDAGUtilityAccount\Desktop\core\New-ToastNotification.ps1';
$installWingetLine
powershell -file '$SandboxDesktopPath\$PackageFolderName\$PackageFolderName`_LogonCommand.ps1'
"@

New-Item -Path $AppFolder -Name "$PackageFolderName`_PreLogonCommand.ps1" -ItemType File -Value $PreLogonContent -Force | Out-Null

$Startup_Command = "powershell.exe -WindowStyle Hidden -executionpolicy bypass -command $SandboxDesktopPath\$PackageFolderName\$PackageFolderName`_PreLogonCommand.ps1"

New-WSB -CommandToRun $Startup_Command

Start-Process $SandboxFilePath
