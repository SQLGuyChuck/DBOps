# C:\PowerShell\ITOps\DBOPS\ScriptDBObjects.ps1 "C:\PowerShell\ITOps\DBOPS\ServerList.txt" "C:\temp\Staging" dbops > "C:\temp\StagingServerScript.log"
# See https://www.simple-talk.com/sql/database-administration/automated-script-generation-with-powershell-and-smo/ for better PS 
$getdate = get-date
write-host "Start Scripting: $getdate" 
write-host ""
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null
[System.Reflection.Assembly]::LoadWithPartialName("System.Data") | out-null

# location of server list text file
$servernamefile = $args[0]

# output file location
$filelocation = $args[1]

# output file location
$databasenametouse = $args[2]

# get the contents of the server file
$servernames = Get-Content $servernamefile

$getdate = get-date

#Output encoding
$sEnc = [System.Text.Encoding]::UTF8
			
# loop on servers
foreach ($servername in $servernames)
	{
	# get new server object
	$srv = new-object "Microsoft.SqlServer.Management.SMO.Server" $serverName
	$srv.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.View], "IsSystemObject")
	$srv.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.Table], "IsSystemObject")
	$srv.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.StoredProcedure], "IsSystemObject")
	$srv.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.UserDefinedFunction], "IsSystemObject")
	
	write-host ""
	write-host "#########################################################"
	write-host "Generating Scripts for $servername"
	write-host "#########################################################"

	# loop on databases in servers
	foreach ($Database in $srv.Databases)
		{
		$DatabaseName = $Database.Name
		if ($DatabaseName -eq $databasenametouse) {
		
			# Populate variables
			$serverdbfilepath = $filelocation + "\" + $servername + "\" + $DatabaseName
			$tablefilelocation = $serverdbfilepath + "\Tables"
			$tabletriggersfilelocation = $serverdbfilepath + "\Triggers"
			$viewfilelocation = $serverdbfilepath + "\Views"
			$storedprocedurefilelocation = $serverdbfilepath + "\Stored Procedures"
			$functionfilelocation = $serverdbfilepath + "\Functions"
			$securityfilelocation = $serverdbfilepath + "\Security"
			$typesfilelocation = $serverdbfilepath + "\Types"
			$dbtriggersfilelocation = $serverdbfilepath + "\DB Triggers"
			$synonymsfilelocation = $serverdbfilepath + "\Synonyms"
			$servicebrokerfilelocation = $serverdbfilepath + "\Service Broker"

			#Purge out folder of the server
			if ([System.IO.Directory]::Exists($serverdbfilepath) -eq $true) {del -force -recurse $serverdbfilepath | out-null}
	
			# Create folders
			mkdir $serverdbfilepath | out-null
			mkdir $tablefilelocation | out-null
			mkdir $tabletriggersfilelocation | out-null
			mkdir $viewfilelocation | out-null
			mkdir $storedprocedurefilelocation | out-null
			mkdir $securityfilelocation | out-null
			mkdir $functionfilelocation | out-null
			mkdir $typesfilelocation | out-null
			mkdir $dbtriggersfilelocation | out-null
			mkdir $synonymsfilelocation | Out-Null
			mkdir $servicebrokerfilelocation | out-null
			
			# Scripted Objects: ApplicationRoles, Assemblies, Defaults, FileGroups, LogFiles, PartitionFunctions, PartitionSchemes, PlanGuides, Roles, Rules, Schemas, ServiceBroker, StoredProcedures, Synonyms, 
			#	Tables, Triggers, UserDefinedDataTypes, UserDefinedFunctions, UserDefinedTypes, Users, Views
			
			# Other Available Objects: AsymmetricKeys, Certificates, DatabaseAuditSpecifications, ExtendedProperties, ExtendedStoredProcedures, 
			#	FullTextCatalogs, FullTextStopLists, SymmetricKeys, UserDefinedAggregates, UserDefinedTableTypes, XmlSchemaCollections

			# Create a timestamp string for use in the file names
			$currenttimestamp = get-date -uformat "%Y%m%d%H%M%S"

			# setup file name and location for DB creation
			#$filename = $filelocation + "\" + $servername  + "\" + $Database.Name + ".sql"

			# get new scripting object
			$scr = New-Object "Microsoft.SqlServer.Management.Smo.Scripter"
			$deptype = New-Object "Microsoft.SqlServer.Management.Smo.DependencyType"

			# set scripting options
			$scr.Server = $srv
			$options = New-Object "Microsoft.SqlServer.Management.SMO.ScriptingOptions"
			$options.DriAll = $true #constraints
			$options.AllowSystemObjects = $false
			#$options.IncludeDatabaseContext = $true
			$options.IncludeIfNotExists = $true
			$options.ClusteredIndexes = $true
			$options.Default = $true
			$options.DriAll = $true
			$options.Indexes = $true
			$options.IncludeHeaders = $false
			$options.AppendToFile = $true
			$options.ToFileOnly = $true
			$options.Permissions = $false
			$options.WithDependencies = $false
			$options.Encoding = $sEnc
			
			# set the options to the scripting object
			$scr.Options = $options

			# Database
			#$DatabaseName = $Database.Name
			#write-host "`t>> Generating Database Script: $DatabaseName  - $getdate <<"
			#$scr.Script($Database)


			# Start the prefetch, for performance reasons
			$Database.PrefetchObjects([Microsoft.SqlServer.Management.Smo.View], $options)
			$Database.PrefetchObjects([Microsoft.SqlServer.Management.Smo.Table], $options)
			$Database.PrefetchObjects([Microsoft.SqlServer.Management.Smo.StoredProcedure], $options)
			$Database.PrefetchObjects([Microsoft.SqlServer.Management.Smo.UserDefinedFunction], $options)

			# Everything else follows the same pattern; so only one set of comments will explain what's happening
			# Get the needed objects, (sometimes remove the ones that aren't system objects)
			# Before we script anything, check the count of objects, if it's an empty set, skip it - Then script them all
			# Set the current variable to null, so that it's not just sitting around in memory
			
			# There are dependencies from some objects to others, so perform these steps in a particular order...not just however the database object send them back in an iterator

			write-host "`t`t++ Generating Role Scripts ++ " -nonewline;
			$count = 0
			[array]$Users = $Database.Users | ? {$_.IsSystemObject -eq $false}
			if ($Users.Count -gt 0) {
			foreach ( $User in $Users ) 
				{ 
				$filename = $securityfilelocation + "\SecurityScripts.sql" ;
				$options.FileName = $filename; 
				$scr.Options = $options; 
				$count++
				if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
				$scr.Script($User)  
				}
			}
			[array]$Roles = $Database.Role | ? {$_.IsSystemObject -eq $false}
			if ($Roles.Count -gt 0) {
			foreach ( $Role in $Users ) 
				{ 
				$filename = $securityfilelocation + "\SecurityScripts.sql" ;
				$options.FileName = $filename; 
				$scr.Options = $options; 
				$count++
				if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
				$scr.Script($Role)  
				}
			}
			[array]$ApplicationRoles = $Database.ApplicationRoles ##| ? {$_.IsSystemObject -eq $false}
			if ($ApplicationRoles.Count -gt 0) {
				foreach ( $AppRole in $ApplicationRoles ) 
					{ 
					$filename = $securityfilelocation + "\SecurityScripts.sql" ;
					$options.FileName = $filename; 
					$scr.Options = $options; 
					$count++
					if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
					$scr.Script($AppRole)  
					}
			}
			write-host "";
			clear-variable -name Users
			clear-variable -name Roles
			clear-variable -name ApplicationRoles
			
			# Schemas
			#$Schemas = $Database.Schemas
			#if ($Schemas.Count -gt 0) {write-host "`t`t++ Generating Schema Scripts ++"; $scr.Script($Schemas)}
			#clear-variable -name Schemas

			# Partition Functions
			#$PartitionFunctions = $Database.PartitionFunctions
			#if ($PartitionFunctions.Count -gt 0) {write-host "`t`t++ Generating Partition Function Scripts ++"; $scr.Script($PartitionFunctions)}
			#clear-variable -name PartitionFunctions

			# Partition Schemes
			#$PartitionSchemes = $Database.PartitionSchemes
			#if ($PartitionSchemes.Count -gt 0) {write-host "`t`t++ Generating Partition Scheme Scripts ++"; $scr.Script($PartitionSchemes)}
			#clear-variable -name PartitionSchemes

			write-host "`t`t++ Generating Type Scripts ++ " -nonewline;
			$count = 0
			foreach ( $Type in $Database.UserDefinedTypes ) 
				{ 
				$filename = $typesfilelocation + "\" + $Type.Name  + ".sql" ;
				$options.FileName = $filename; 
				$scr.Options = $options; 
				$count++
				if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
				$scr.Script($Type)  
				}
			foreach ( $Type in $Database.UserDefinedDataTypes ) 
				{ 
				$filename = $typesfilelocation + "\" + $Type.Name  + ".sql" ;
				$options.FileName = $filename; 
				$scr.Options = $options; 
				$count++
				if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
				$scr.Script($Type)  
				}
			foreach ( $Type in $Database.UserDefinedTableTypes ) 
				{ 
				$filename = $typesfilelocation + "\" + $Type.Name  + ".sql" ;
				$options.FileName = $filename; 
				$scr.Options = $options; 
				$count++
				if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
				$scr.Script($Type)  
				}
			write-host "";
			
			# Rules
			#$Rules = $Database.Rules
			#if ($Rules.Count -gt 0) {write-host "`t`t++ Generating Rule Scripts ++"; $scr.Script($Rules)}
			#clear-variable -name Rules

			# Assemblies
			#$Assemblies = $Database.Assemblies
			#if ($Assemblies.Count -gt 0) {write-host "`t`t++ Generating Assembly Scripts ++"; $scr.Script($Assemblies)}
			#clear-variable -name Assemblies

			# Tables  
			write-host "`t`t++ Generating Table Scripts ++ " -nonewline;
			$count = 0
			$Tables = $Database.Tables | where {$_.IsSystemObject -eq $false}
			foreach ( $Table in $Tables ) {
				$filename = $tablefilelocation + "\" + $Table.Name + ".sql";
				$options.FileName = $filename; 
				$scr.Options = $options; 
				$count++
				if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
				$scr.Script($Table) 
				
				# Script table triggers
				[array]$DMLTrigger = $Table.Triggers | where {$_.IsSystemObject -eq $false}
				if ($DMLTrigger.Count -gt 0) {
					foreach ($trigger in $DMLTrigger )
					{
						$filename = $tabletriggersfilelocation + "\" + $trigger.Name + ".sql";
						$options.FileName = $filename; 
						$options.IncludeIfNotExists = $false
						$scr.Options = $options; 
						$scr.Script($trigger) 
						$options.IncludeIfNotExists = $true
						}
					}
				}
			write-host "";
			clear-variable -name Tables

			# Views 
			write-host "`t`t++ Generating View Scripts ++ " -nonewline;
			$count = 0
			foreach ( $View in $Database.Views ) 
				{ if ( $View.IsSystemObject -eq $false ) 
					{$filename = $viewfilelocation + "\" + $View.Name  + ".sql" ;
					$options.FileName = $filename; 
					$options.IncludeIfNotExists = $false
					$scr.Options = $options; 
					$count++
					if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
					$scr.Script($View) 
					$options.IncludeIfNotExists = $true
					} 
				}

			write-host "";
			clear-variable -name View

			write-host "`t`t++ Generating Synonym Scripts ++ " -nonewline;
			$count = 0
			$Synonyms = $Database.Synonyms
			foreach ( $Synonym in $Synonyms ) 
				{ 
				$filename = $synonymsfilelocation + "\" + $Synonym.Name  + ".sql" ;
				$options.FileName = $filename; 
				$scr.Options = $options; 
				$count++
				if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
				$scr.Script($Synonym)  
				}
			
			write-host "";
			clear-variable -name Synonyms

			write-host "`t`t++ Generating User Defined Functions Scripts ++ " -nonewline;
			$count = 0
			$UserDefinedFunctions = $Database.UserDefinedFunctions | ? {$_.IsSystemObject -eq $false}
			foreach ( $UserDefinedFunction in $UserDefinedFunctions ) 
				{ 
				$filename = $functionfilelocation + "\" + $UserDefinedFunction.Name  + ".sql" ;
				$options.FileName = $filename; 
				$options.IncludeIfNotExists = $false  ##Don't like the quoted use
				$scr.Options = $options; 
				$count++
				if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
				$scr.Script($UserDefinedFunction)  
				$options.IncludeIfNotExists = $true
				}
			
			write-host "";
			clear-variable -name UserDefinedFunctions
			
			# Stored Procedures		
			write-host "`t`t++ Generating Stored Procedure Scripts ++ " -nonewline;
			$count = 0
			foreach ( $StoredProcedure in $Database.StoredProcedures ) 
				{ if ( $StoredProcedure.IsSystemObject -eq $false ) 
					{$filename = $storedprocedurefilelocation + "\" + $StoredProcedure.Name + ".sql"; 
					$options.FileName = $filename; 
					$options.IncludeIfNotExists = $false  ##Don't like the quoted use
					$scr.Options = $options; 
					$count++
					if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
					$scr.Script($StoredProcedure) 
					$options.IncludeIfNotExists = $true
					} 
				}

			write-host "";
			clear-variable -name StoredProcedure

			# Plan Guides
			#$PlanGuides = $Database.PlanGuides
			#if ($PlanGuides.Count -gt 0) {write-host "`t`t++ Generating Plan Guide Scripts ++"; $scr.Script($PlanGuides)}
			#clear-variable -name PlanGuides

			# Service Broker Objects  $servicebrokerfilelocation
			$ServiceBroker = $Database.ServiceBroker

			write-host "`t`t++ Generating Service Broker Scripts ++ " -nonewline;
			$count = 0
			$Services = $ServiceBroker.Services | ? {$_.IsSystemObject -eq $false}
			foreach ( $Service in $Services ) 
				{ $filename = $servicebrokerfilelocation + "\" + $Service.Name + ".sql"; 
					$options.FileName = $filename; 
					$scr.Options = $options; 
					$count++
					if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
					$scr.Script($Service) 
				}
			$Queues = $ServiceBroker.Queues | ? {$_.IsSystemObject -eq $false}
			foreach ( $Queue in $Queues ) 
				{ $filename = $servicebrokerfilelocation + "\" + $Queue.Name + ".sql"; 
					$options.FileName = $filename; 
					$scr.Options = $options; 
					$count++
					if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
					$scr.Script($Queue) 
				}
			$ServiceContracts = $ServiceBroker.ServiceContracts | ? {$_.IsSystemObject -eq $false}
			foreach ( $ServiceContract in $ServiceContracts ) 
				{ $filename = $servicebrokerfilelocation + "\" + $ServiceContract.Name + ".sql"; 
					$options.FileName = $filename; 
					$scr.Options = $options; 
					$count++
					if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
					$scr.Script($ServiceContract) 
				}
			$MessageTypes = $ServiceBroker.MessageTypes | ? {$_.IsSystemObject -eq $false}
			foreach ( $MessageType in $MessageTypes ) 
				{ $filename = $servicebrokerfilelocation + "\" + $MessageType.Name + ".sql"; 
					$options.FileName = $filename; 
					$scr.Options = $options; 
					$count++
					if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
					$scr.Script($MessageType) 
				}
				
			write-host "";
			clear-variable -name MessageTypes
			clear-variable -name ServiceContracts
			clear-variable -name Queues
			clear-variable -name Services
			clear-variable -name ServiceBroker

			# Database Level Triggers. Force array for count to work on 1 object
			[array]$Triggers = $Database.Triggers | where {$_.IsSystemObject -eq $false}
			if ($Triggers.Count -gt 0) {write-host "`t`t++ Generating Database Level Trigger Scripts ++" -nonewline;}
			$count = 0
			foreach ( $Trigger in $Triggers ) 
				{ $filename = $dbtriggersfilelocation + "\" + $Trigger.Name + ".sql"; 
					$options.FileName = $filename; 
					$scr.Options = $options; 
					$count++
					if ($count % 10 -eq 0) {write-host $count -nonewline} else {write-host "." -nonewline;}
					$scr.Script($Trigger) 
				}
			clear-variable -name Triggers
			
			}
			clear-variable -name Database
		}
	}
	clear-variable -name servername

$getdate = get-date
write-host ""
write-host "End Scripting: $getdate"
