$InputFile = $args[0]
$PartialCodePush = $args[1]
$ExcludeCodeList = $args[2]

$e=0
IF ($InputFile -eq $null)
{	Write-host "You must specified a valid InputFile"
	$e=1
}
IF (($PartialCodePush -ne $true)-and ($PartialCodePush -ne $false))
{	Write-host "You must specified a valid state ($true | $false) for PartialCodePush"
	$e=1
}
IF (($ExcludeCodeList -ne $true)-and ($ExcludeCodeList -ne $false))
{	Write-host "You must specified a valid state ($true | $false) for ExcludeCodeList"
	$e=1
}

IF ($e -eq 1)
{	Write-host "Cancelling the PUSH."
	exit
}

$LogFile=".\logfile.txt"

Write-host "Beginning installation" |out-file $LogFile

"" |out-file $LogFile -append
foreach($ServerName in Get-Content $InputFile)
{	$error.clear()
	Write-host $ServerName
	"Servername: " + $ServerName |out-file $LogFile -append
	.\ApplyDBOps.ps1 $ServerName $PartialCodePush $ExcludeCodeList|out-file $LogFile -append

	$error |out-file $LogFile -append
	"" |out-file $LogFile -append
}

Write-host "Completed installation" |out-file $LogFile -append

Write-host "Press any key to exit."
$key = [Console]::ReadKey($true) 