function New-ToastNotification {
	param(
		[string] $XmlPath,
		[string] $Title,
		[string] $Body
	)
	try {
		[xml] $Xml = (Get-Content -LiteralPath $XmlPath -Raw -ErrorAction Stop).Replace('%TITLE%', $Title).Replace('%BODY%', $Body)
		$Load = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
		$Load = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
		$AppID = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
		$ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument -ErrorAction Stop
		$ToastXml.LoadXml($Xml.OuterXml)
		$Toast = [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime]::new($ToastXml)
		[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppID).Show($Toast)
	}
	catch {
		Write-Warning "Could not show sandbox notification '$Body': $_"
	}
}