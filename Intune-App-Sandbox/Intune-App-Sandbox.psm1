$Private = @(Get-ChildItem -Recurse -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)
$Public = @(Get-ChildItem -Recurse -Path $PSScriptRoot\Public\*.ps1 | Where-Object { $_ -notmatch '\.Examples.ps1' })

foreach ($import in $Private) {
	try {
		. $import.fullname
	} catch {
		Write-Error -Message "Failed to import private function $($import.fullname): $_"
	}
}

foreach ($import in $Public) {
	try {
		. $import.fullname
	} catch {
		Write-Error -Message "Failed to import function $($import.fullname): $_"
	}
}

Export-ModuleMember -Function $Public.Basename