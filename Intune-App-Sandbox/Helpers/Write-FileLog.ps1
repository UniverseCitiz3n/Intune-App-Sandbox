Function Write-FileLog {
	[CmdletBinding()]
	Param (
		# Type can be: 'i' for Info, 'w' for Warn, 'e' for Error)]
		[Alias('t')]
		[Parameter()]
		[ValidateSet('Info', 'Warn', 'Error')]
		[System.String]$Type = 'Info',
		# Message
		[Alias('m')]
		[Parameter()]
		[System.String]$Message,
		# Message
		[Alias('s')]
		[Parameter()]
		[Switch]$FunctionStart,
		# ProcessName will mark in log which function is running now
		[Alias('lf')]
		[Parameter()]
		[System.String]$LogFile,
		# ProcessName will mark in log which function is running now
		[Alias('lfe')]
		[Parameter()]
		[System.String]$LogFileError,
		# Message
		[Alias('o')]
		[Parameter()]
		[Switch]$LogOverWrite
	)
	if ($LogOverWrite) {
		$Append = $false
	} else {
		$Append = $true
	}

	if ($Type -eq 'Error') {
		$FilePath = $LogFileError
	} else {
		$FilePath = $LogFile
	}

	if ($FunctionStart -and -not $Message) {
		$Message = 'START function'
	}

	$callerFunction = (Get-PSCallStack)[1]
	if ($callerFunction.InvocationInfo -and $callerFunction.InvocationInfo.MyCommand -and $callerFunction.InvocationInfo.MyCommand.Name) {
		$callerNameCommand = $callerFunction.InvocationInfo.MyCommand.Name
	} else {
		$callerNameCommand = '';
	}
	if ($callerFunction.ScriptName) {
		$callerNameScript = Split-Path -Leaf $callerFunction.ScriptName
	} else {
		$callerNameScript = '';
	}
	if ($callerFunction.ScriptLineNumber) {
		$callerLineNumber = $callerFunction.ScriptLineNumber
	} else {
		$callerLineNumber = ''
	}

	if ($callerNameCommand -eq '' -and $callerNameScript -ne '') {
		$callerNameCommand = $callerNameScript
	}

	$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

	$msg = "[$timestamp] [$callerNameCommand] [$callerLineNumber] [$Type] $Message"

	$msg | Out-File -FilePath $FilePath -Append:$Append -Encoding ASCII

	Write-Verbose -Message $msg

	if ($Type -eq 'Error') {
		Throw $msg
	}
}