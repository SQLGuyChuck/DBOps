
$Path=$args[1]
$Path
IF ($Path -eq $null)
{
	$Path = "C:\PowerShell\ITOps\DBOPS\PartialCodePush"
}

forfiles /p $Path /s /c "cmd /c if @isdir==FALSE del @file"