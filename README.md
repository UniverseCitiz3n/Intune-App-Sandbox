# Intune-App-Sandbox

This tool is for testing Powershell Script which is packed using [Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) for installing software using Win32 Deployment profile in Intune.

# Installing

To configure tool on your device `Clone` this repo and run `Add-SandboxShell.ps1`.
It will create folder - `C:\SandboxEnvironment` where all neccessary items will be stored.
You will be also prompt to choose which context menu items you wish to apply.
1. Run test in Sandbox
1. Pack with IntunewinUtil
1. Both

# Using
Packing script and all neccessary executables is as simple as creating parent folder which is named exacly the same as `.ps` script inside.<br>
Then right-click on folder and pick `Pack with IntunewinUtil`.
<br><br>
![Pack](\packintuneutil.gif)
<br><br><br><br><br><br><br>
To test your package just right-click on `.intunewin` file and choose
`Run test in Sandbox`
![Test](\testsandbox.gif)

