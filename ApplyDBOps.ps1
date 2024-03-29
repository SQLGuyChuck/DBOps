Param(
	[parameter(Mandatory=$true, Position=0)]
	[String]
	$TargetServer 
	,
	[parameter(Mandatory=$true, Position=1)]
	[Boolean]
	$PartialCodePush 
	,
	[parameter(Mandatory=$true, Position=2)]
	[Boolean]
	$ExcludeCodeExecution ) #If $PartialCodePush is True, $ExcludeCodeExecution code section will always be skipped.
	
#$TargetServer="Computer447"
#$PartialCodePush = $true
#$ExcludeCodeExecution = $true
if ( Get-PSSnapin -Registered | where {$_.name -eq 'SqlServerProviderSnapin100'} )
{ 
    if( !(Get-PSSnapin | where {$_.name -eq 'SqlServerProviderSnapin100'})) 
    {  
        Add-PSSnapin SqlServerProviderSnapin100 | Out-Null 
    } ;  
    if( !(Get-PSSnapin | where {$_.name -eq 'SqlServerCmdletSnapin100'})) 
    {  
        Add-PSSnapin SqlServerCmdletSnapin100 | Out-Null 
    } 
} 
else 
{ 
    if( !(Get-Module | where {$_.name -eq 'sqlps'})) 
    {  
        Import-Module 'sqlps' –DisableNameChecking 
    } 
} 

$error.clear()
$BasePath=""
$UserName = $null
$password = $null

IF(!($PartialCodePush)-or $PartialCodePush -like "$false")
{	$BasePath="C:\PowerShell\ITOps\DBOPS\code"}

IF($PartialCodePush -or $PartialCodePush -like "$true")
{	$BasePath="C:\PowerShell\ITOps\DBOPS\PartialCodePush"}


if ((Test-Path -path $BasePath) -ne $True)
{	Write-Output "$BaseInstallPath not exists. Cancelling..."
	exit}

$dbopsExists = 	(Invoke-Sqlcmd -ServerInstance $TargetServer -Database "Master" -Query "select name from master.dbo.sysdatabases where name like 'DBOPS'" -ErrorAction SilentlyContinue)
if($error)
{	Write-Output "***** Error establishing connection."
	#Write-host "***** Error establishing connection."
	Write-Output "Using hardcoded values in script for AlternateCredentials."
	#Write-host "Using hardcoded values in script for AlternateCredentials."

	$error.clear()
	$UserName = "jetcityjet2"

	Write-Output "Using username: " $UserName
	Write-Host "Using username: " $UserName
	
	$dbopsExists = 	(Invoke-Sqlcmd -ServerInstance $TargetServer -Database "Master" -Query "select name from master.dbo.sysdatabases where name like 'DBOPS'" -user $UserName )##-password $password)
	if($error -ne $null)
		{	 
		Write-Output "***** Could not connect to the server. Check security rights or network."
		Write-Host "***** Could not connect to the server. Check security rights or network."
		exit	
		}

}
if ($dbopsExists -eq $null)
{	 Write-Output "***** Failed to find DBOps database on server $TargetServer. Creating database"
	IF($userName -ne $null)
	{Invoke-Sqlcmd -ServerInstance $TargetServer -Database "master" -Inputfile "C:\PowerShell\ITOps\DBOPS\code\DBOps\CreateDBOPSDatabase.sql" -user $UserName }##-password $password}
	else {Invoke-Sqlcmd -ServerInstance $TargetServer -Database "master" -Inputfile "C:\PowerShell\ITOps\DBOPS\code\DBOps\CreateDBOPSDatabase.sql"}
}

	Write-Output "Running object scripts" 
	Write-Host "Running object scripts" 
	# then install all the scripts
	$PushOrderList = Get-Content C:\PowerShell\ITOps\DBOPS\ObjectPushOrderList.txt
	
	foreach ($PushObjectType in $PushOrderList) ## This loop is to maintain the push order
	{
		Write-Output $PushObjectType
		#foreach ($folder in $folders) 
		#{
			$InstallPath = $BasePath+"\DBOps" + "\" + $PushObjectType
			#$i = 0
			IF(Test-Path $InstallPath)
			{
				Write-Output $InstallPath
				$var = get-childitem $InstallPath | where {$_.FullName -like '*.sql'} # | Select FullName
				#Write-Output $PushObjectType
				#Write-Output $var.Fullname
				foreach($InputFile in $var)
				{
					#$i= $i +1
					#Write-Output $i	
					$InstallFile=$InstallPath+"\"+$inputfile
					Write-Output $InstallFile
					Write-Host $InstallFile
					
					IF($userName -ne $null)
					{Invoke-Sqlcmd -ServerInstance $TargetServer -Database "DBOPS" -Inputfile $InstallFile -user $UserName }##-password $password}
					else {Invoke-Sqlcmd -ServerInstance $TargetServer -Database "DBOPS" -Inputfile $InstallFile}
					if($error)
					{
						#Write-Output $error 
						$Error.Clear()
					}
				}
			}else{	Write-Output "Nothing to push"
			Write-Host "Nothing to push"}
		#}
	}
	# Now Master Database
	Write-Host "MASTER database objects."
	Write-Output "MASTER database objects."
	foreach ($PushObjectType in $PushOrderList) ## This loop is to maintain the push order
	{
		Write-Output $PushObjectType
		#foreach ($folder in $folders) 
		#{
			$InstallPath = $BasePath+"\Master" + "\" + $PushObjectType
			#$i = 0
			IF(Test-Path $InstallPath)
			{
				Write-Output $InstallPath
				$var = get-childitem $InstallPath | where {$_.FullName -like '*.sql'} # | Select FullName
				#Write-Output $PushObjectType
				#Write-Output $var.Fullname
				foreach($InputFile in $var)
				{
					#$i= $i +1
					#Write-Output $i	
					$InstallFile=$InstallPath+"\"+$inputfile
					Write-Output $InstallFile
					#Write-Host $InstallFile
					
					IF($userName -ne $null)
					{Invoke-Sqlcmd -ServerInstance $TargetServer -Database "Master" -Inputfile $InstallFile -user $UserName }##-password $password}
					else {Invoke-Sqlcmd -ServerInstance $TargetServer -Database "Master" -Inputfile $InstallFile}
					if($error)
					{
						#Write-Output $error 
						$Error.Clear()
					}
				}
			}else{	Write-Output "Nothing to push"}
		#}
	}
	
#Execute specific procs to configure a new server.
IF(($ExcludeCodeExecution -eq $true) -and ($PartialCodePush -eq $false))
{
	Write-Output "Running prc_dba_configuremail"
	Write-Host "Running prc_dba_configuremail"
	
	IF($userName -ne $null)
	{Invoke-Sqlcmd -ServerInstance $TargetServer -Database "DBOps" -Query "exec prc_dba_configuremail" -user $UserName } ##-password $password}
	else {Invoke-Sqlcmd -ServerInstance $TargetServer -Database "DBOps" -Query "exec prc_dba_configuremail"}
}

$error.clear()