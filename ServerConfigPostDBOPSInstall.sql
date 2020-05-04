USE MASTER
GO
--These will need to be modified for your enviroment, but is what I used to setup/check new server.

--EXEC dbops.dbo.prc_Config_DBMail

--Delete maintenance plans that are not needed.

--If not created already:
USE [msdb]
GO
EXEC msdb.dbo.sp_add_operator @name=N'IT Ops', 
		@enabled=1, 
		@weekday_pager_start_time=0, 
		@weekday_pager_end_time=0, 
		@saturday_pager_start_time=0, 
		@saturday_pager_end_time=0, 
		@sunday_pager_start_time=0, 
		@sunday_pager_end_time=0, 
		@pager_days=0, 
		@email_address=N'alerts@limeade.com', 
		@category_name=N'[Uncategorized]'
GO


USE [master]
GO
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev', FILENAME = N'G:\SQLTemp\tempdev.mdf' ,SIZE = 8000MB , FILEGROWTH = 1000MB )
GO
ALTER DATABASE [tempdb] ADD FILE ( NAME = N'tempdev2', FILENAME = N'G:\SQLTemp\tempdev2.ndf' , SIZE = 8000MB , FILEGROWTH = 1000MB )
GO
ALTER DATABASE [tempdb] ADD FILE ( NAME = N'tempdev3', FILENAME = N'G:\SQLTemp\tempdev3.ndf' , SIZE = 8000MB , FILEGROWTH = 1000MB )
GO
ALTER DATABASE [tempdb] ADD FILE ( NAME = N'tempdev4', FILENAME = N'G:\SQLTemp\tempdev4.ndf' , SIZE = 8000MB , FILEGROWTH = 1000MB )
GO
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'templog', FILENAME = N'G:\SQLTemp\templog.ldf' , SIZE = 2000MB , FILEGROWTH = 1000MB )
GO

--Small use boxes:
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev', SIZE = 2000MB , FILEGROWTH = 1000MB )
GO
ALTER DATABASE [tempdb] ADD FILE ( NAME = N'tempdev2', FILENAME = N'D:\Data\MSSQL11.MSSQLSERVER\MSSQL\DATA\tempdev2.ndf' , SIZE = 2000MB , FILEGROWTH = 1000MB )
GO
ALTER DATABASE [tempdb] ADD FILE ( NAME = N'tempdev3', FILENAME = N'D:\Data\MSSQL11.MSSQLSERVER\MSSQL\DATA\tempdev3.ndf' , SIZE = 2000MB , FILEGROWTH = 1000MB )
GO
ALTER DATABASE [tempdb] ADD FILE ( NAME = N'tempdev4', FILENAME = N'D:\Data\MSSQL11.MSSQLSERVER\MSSQL\DATA\tempdev4.ndf' , SIZE = 2000MB , FILEGROWTH = 1000MB )
GO
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'templog', FILENAME = N'D:\Data\MSSQL11.MSSQLSERVER\MSSQL\DATA\templog.ldf' , SIZE = 1000MB , FILEGROWTH = 100MB )
GO

USE [master]
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', REG_SZ, N'E:\SQLData'
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', REG_SZ, N'F:\SQLLog'
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', REG_SZ, N'D:\Backup'
GO


USE [master]
GO
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modeldev', SIZE = 20480KB , FILEGROWTH = 51200KB )
GO
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modellog', SIZE = 10240KB , FILEGROWTH = 102400KB )
GO


IF NOT EXISTS (SELECT * FROM [msdb].[dbo].[sysmail_configuration]
			  where paramname = 'MaxFileSize'
			  and paramvalue < 10485760 ) --Allow 10MB attachments
EXECUTE msdb.dbo.sysmail_configure_sp 'MaxFileSize', '10485760' ;  

--SQL 2008:
--select @@ServerName as Server, replace(@@Version,Char(10),'') as SQLVersion, Physical_memory_in_bytes/1024000000 as MemGB,cpu_count/hyperthread_ratio AS REALCPUCount, cpu_count
--SQL 2012:
select @@ServerName as Server, replace(@@Version,Char(10),'') as SQLVersion, Physical_memory_kb/1024000 as MemGB,cpu_count/hyperthread_ratio AS REALCPUCount, cpu_count
FROM sys.dm_os_sys_info  

--Check the patch level is appropriate based on description of fixes from Microsoft. Good summary here: http://sqlserverbuilds.blogspot.com/

select name, value, maximum, value_in_use, description, is_advanced
from sys.configurations
where name in ('max degree of parallelism','max server memory (MB)','show advanced options'
	,'cost threshold for parallelism','max degree of parallelism','remote admin connections'
	,'backup compression default','optimize for ad hoc workloads','Agent XPs','Database Mail XPs'
	,'xp_cmdshell','clr enabled','scan for startup procs','default trace enabled','cross db ownership chaining')

--EXEC sys.sp_configure N'optimize for ad hoc workloads', 1
--RECONFIGURE

--Have a server to compare too:
SELECT 'exec sp_configure '''+CAST(c1.name AS VARCHAR(1000))+''','+CAST(c1.value AS varchar(1000)),* 
FROM sys.configurations c
JOIN master.sys.configurations c1 ON c.configuration_id=c1.configuration_id
WHERE c.value_in_use<>c1.value_in_use

EXEC sp_configure 'show advanced options',1
RECONFIGURE
--Paste output from above into here.
EXEC sp_configure 'show advanced options',0
RECONFIGURE

--If you see look for auto startup procs, replication uses this, so don't freak, view them all per database:
SELECT name,create_date,modify_date
FROM sys.procedures
WHERE is_auto_executed = 1
--Replication: sp_MSrepl_startup


--Check to see what traces are enabled.
--RECONFIGURE deadlock graphs to email and log to a table instead of logging sql agent error log.
DBCC TRACESTATUS
--Get rid of these for old deadlock graphing:
--DBCC TRACESTATUS (1204, -1)
--DBCC TRACESTATUS (3605, -1)


--Are any of the database not owned by SA?
Declare @sql varchar(max)
select @sql = coalesce(@sql + 'ALTER AUTHORIZATION ON DATABASE::' + quotename(name) + ' TO SA;' +char(13)+char(10), 'ALTER AUTHORIZATION ON DATABASE::' + quotename(name) + ' TO SA;' +char(13)+char(10))
--select 'ALTER AUTHORIZATION ON DATABASE::' + quotename(name) + ' TO SA'
FROM sys.databases
where Database_id > 4 and owner_sid <> 1 and is_read_only = 0 and [state] = 0 and is_distributor = 0

Print @sql
-- OR to execute all
Exec (@SQL)



--To see all the sp_configure values:
exec sp_configure 'show advanced options' , 1
reconfigure

--To turn back off if not running below which also has this statement.
--exec sp_configure 'show advanced options' , 0
--reconfigure

--Strongly consider on OLTP boxes:
exec sp_configure 'max degree of parallelism', 12
RECONFIGURE

IF EXISTS (SELECT * from sys.configurations WHERE name = 'max server memory (MB)' and value_in_use=maximum)
BEGIN

	Declare @MemGB			smallint
		,@NewMemGB			nvarchar(6)
		,@MemoryCheckSQL	nvarchar(4000)

	Set @MemoryCheckSQL = CASE WHEN (@@microsoftversion / 0x1000000) & 0xff >= 11 THEN 
		'Select @TotalMemGB = Physical_memory_KB/1024000 From sys.dm_os_sys_info'
		ELSE 'Select @TotalMemGB = Physical_memory_in_bytes/1024000000 From sys.dm_os_sys_info'
		END
	execute master.dbo.sp_executesql @MemoryCheckSQL, N'@TotalMemGB int out', @MemGB out
	SELECT @MemGB
	If @MemGB >= 125
	Begin
		Set @NewMemGB = CAST(@MemGB-10 as NVarchar(3)) + '000'
		
		EXEC sys.sp_configure N'max server memory (MB)', @NewMemGB
	END
	ELSE
	If @MemGB <= 32
	Begin
		Set @NewMemGB = CAST(@MemGB-2 as NVarchar(3)) + '000'
		
		EXEC sys.sp_configure N'max server memory (MB)', @NewMemGB
	END
	ELSE 
	Begin
		Set @NewMemGB = CAST(@MemGB-4 as NVarchar(3)) + '000'
		
		EXEC sys.sp_configure N'max server memory (MB)', @NewMemGB
	END

END --Memory reconfig

-- Use 'backup compression default' when server is NOT CPU bound
IF EXISTS (SELECT * from sys.configurations WHERE name = 'backup compression default' and value_in_use = 0)
EXEC sys.sp_configure N'backup compression default', N'1'

--DAC:
IF EXISTS (SELECT * from sys.configurations WHERE name = 'remote admin connections' and value_in_use = 0)
EXEC sys.sp_configure N'remote admin connections', N'1'

--Database mail:
IF EXISTS (SELECT * from sys.configurations WHERE name = 'Agent XPs' and value_in_use = 0)
EXEC sys.sp_configure N'Agent XPs', N'1'

--cost threshold for parallelism (servers with > 1 cpu):
IF EXISTS (SELECT * from sys.configurations WHERE name = 'cost threshold for parallelism' and value_in_use = 5)
EXEC sys.sp_configure N'cost threshold for parallelism', N'30'

RECONFIGURE WITH OVERRIDE

exec sp_configure 'show advanced options',0;
RECONFIGURE;


-- Set database option defaults (ignore errors on read-only databases)
SELECT 'ALTER DATABASE ' + dtb.name + ' SET PAGE_VERIFY CHECKSUM',
dtb.page_verify_option AS [PageVerify],
dtb.name AS [Name],
dtb.database_id AS [ID],
suser_sname(dtb.owner_sid) AS [Owner]
FROM master.sys.databases AS dtb
where dtb.name not in ('master','model','msdb','tempdb')
and is_distributor = 0
and dtb.page_verify_option <> 2


SELECT 'ALTER DATABASE ' + dtb.name + ' SET AUTO_CLOSE OFF',
dtb.is_auto_close_on AS [AutoClose],
dtb.name AS [Name],
dtb.database_id AS [ID],
suser_sname(dtb.owner_sid) AS [Owner]
FROM master.sys.databases AS dtb
where dtb.name not in ('master','model','msdb','tempdb')
and is_distributor = 0
and is_auto_close_on <> 0


SELECT 'ALTER DATABASE ' + dtb.name + ' SET AUTO_SHRINK OFF',
dtb.is_auto_shrink_on AS [AUTO_SHRINK],
dtb.name AS [Name],
dtb.database_id AS [ID],
suser_sname(dtb.owner_sid) AS [Owner]
FROM master.sys.databases AS dtb
where dtb.name not in ('master','model','msdb','tempdb')
and is_distributor = 0
and is_auto_shrink_on <> 0


-- Limit error logs
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs', REG_DWORD, 10
GO

PRINT N'Altering SQL Server Agent Job System properties'
DECLARE @RETCODE int
EXEC @RETCODE = msdb.dbo.sp_set_sqlagent_properties
		@jobhistory_max_rows         = 100000,
		@jobhistory_max_rows_per_job = 500,
		@job_shutdown_timeout        = 15,
		@sysadmin_only               = NULL,
		@alert_replace_runtime_tokens= 1
IF @RETCODE != 0
BEGIN
	RAISERROR (N'Cannot change SQL Server Agent Job System properties.', 16, 1)
	RETURN
END
GO


--TEMPDB fix
/*
--Update the file locations before you run:
USE [master]
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', REG_SZ, N'E:\SQLData' <--update location
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', REG_SZ, N'E:\SQLLog' <--update location
*/

USE Master
GO
DECLARE @DataFile varchar(200)
	, @LogFile varchar(200)
	, @DSQL varchar(2000)
	, @rowcount tinyint

USE tempdb
Go
DECLARE @rowcount int,
	@DataFile varchar(300),
	@LogFile varchar(300),
	@DSQL varchar(MAX)

SELECT @rowcount=COUNT(*) FROM sys.database_files WHERE Type_desc = 'Rows'


IF @rowcount = 1 --We haven't optimized tempdb, so let's do that now.
BEGIN
	exec master.dbo.xp_instance_regread 
	 @rootkey = 'HKEY_LOCAL_MACHINE',
	 @key = 'Software\Microsoft\MSSQLServer\MSSQLServer',
	 @value_name= 'DefaultData',
	 @value = @DataFile OUTPUT

	exec master.dbo.xp_instance_regread 
	 @rootkey = 'HKEY_LOCAL_MACHINE',
	 @key = 'Software\Microsoft\MSSQLServer\MSSQLServer',
	 @value_name= 'DefaultLog',
	 @value = @LogFile OUTPUT

	--Override null value
	--IF @datafile is null
	--	Set @datafile = 'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA'
	 
	--Set empty logfile to be same location as populated datafile.
	IF @DataFile IS NOT NULL and @LogFile IS NULL
		SET @LogFile = @DataFile

	IF RIGHT(RTRIM(@DataFile),1) <> '\'
		SET @DataFile = @DataFile + '\'

	IF RIGHT(RTRIM(@LogFile),1) <> '\'
		SET @LogFile = @LogFile + '\'

	SET @DSQL = '
	ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N''tempdev'', SIZE = 5GB, FILEGROWTH = 2GB)
	ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdev2'', FILENAME = N'''+@DataFile+'tempdb2.ndf'', SIZE = 5GB , FILEGROWTH = 2GB)
	ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdev3'', FILENAME = N'''+@DataFile+'tempdb3.ndf'', SIZE = 5GB , FILEGROWTH = 2GB)
	ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdev4'', FILENAME = N'''+@DataFile+'tempdb4.ndf'', SIZE = 5GB , FILEGROWTH = 2GB)
	ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N''templog'', SIZE = 1GB, FILEGROWTH = 500MB )'
	
	--If you want to move all the files to new location, add these to the above files:
	--For tempdev: , FILENAME = N'''+@DataFile+'tempdev.mdf''
	--For templog: , FILENAME = N'''+@LogFile+'templog.ldf''

	IF @DataFile IS NOT NULL
		PRINT @DSQL
	ELSE 
	BEGIN
		SELECT 'Please provide a path for data and log file.'
		RAISERROR('Default database file paths are not provided, so tempdb fix cannot be run. Please alter "Software\Microsoft\MSSQLServer\MSSQLServer"::DefaultData and ::DefaultLog.', 18, 18)
	END

	PRINT 'Please massage tempdb reconfigure script to best suit server and existing size.'
END 
go

--Local policy rights
--Act as part of the operating system
--Perform volume maintenance tasks
--Lock pages in memory
--Audit Policy changes: Add 2 options for Audit failed login attempts.

--Production Server Trace Flags:
--;-T1118;-T834;-T835;-T3226;-T2371;


--Dev server fixes:
--ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev', SIZE = 1GB, FILEGROWTH = 500MB)
--ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'templog', SIZE = 500MB, FILEGROWTH = 100MB )

--What does current db file space look like?
exec xp_fixeddrives
--or for drives only with db files on them:
SELECT DISTINCT volume_mount_point, total_bytes/1024/1024 AS TotalMB, available_bytes/1024/1024 AS AvailableMB
, CAST((total_bytes - available_bytes) / (total_bytes*1.0) * 100 AS MONEY) AS PercentUsed
--select *
FROM sys.master_files AS f
CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.FILE_ID);


EXEC sp_dbfilesizegrowth --best run in text mode. Take with grain of salt what it recommends.

--Find space issues and fix with either growing file, or adding to exclusion table (do one or the other):
exec dbops.dbo.prc_Check_FileGroupSpace
	@Operation = 'show' , -- If 'LOG', it will write results to table DBFileGroupSpaceResultsHistory.
	@EmailAlert = 0 , -- Email alert
	@LargeDBSizeMB = 100000, --100GB is default large DB size.
	@MediumDBSizeMB = 20000 --20GB is default medium DB size.


--Example output:
--Run either of the statments depending on if you are out of space on drive and want to cap file or grow it.
--ims_AllSystems_Archive	PRIMARY	ALTER DATABASE [ims_AllSystems_Archive] MODIFY FILE (NAME = [ims_AllSystems_Archive_Data01] [ims_AllSystems_Archive_Data02] [ims_AllSystems_Archive_Data03] [ims_AllSystems_Archive_Data04], SIZE = *Multiple Logical Files, Size is Avg.* 40000MB )   
--INSERT INTO dbops.DBO.DBFileGroupExceptions (DBName,FileGroupName,PercentFree, ExceptionReason)  --VALUES ('ims_AllSystems_Archive','PRIMARY',0.1,'Give a reason here.')

--Notice that if multiple files in a file group, I provide sample, just duplicate and alter as shown below, but be VERY conscious of the file growth amount, it may not be even growth and therefore fail on you!
ALTER DATABASE [ims_AllSystems_Archive] MODIFY FILE (NAME = [ims_AllSystems_Archive_Data01]   , SIZE =  40000MB ) 
ALTER DATABASE [ims_AllSystems_Archive] MODIFY FILE (NAME =  [ims_AllSystems_Archive_Data02]  , SIZE =  40000MB ) 
ALTER DATABASE [ims_AllSystems_Archive] MODIFY FILE (NAME =   [ims_AllSystems_Archive_Data03] , SIZE =  40000MB ) 
ALTER DATABASE [ims_AllSystems_Archive] MODIFY FILE (NAME =    [ims_AllSystems_Archive_Data04], SIZE =  40000MB ) 



Run C:\PowerShell\DBOPS\Code\MSPerfDashboards2012\MSDashboardSQL2012SetupOnly.sql


--Shrink a file after using the database:
--DBCC SHRINKFILE(logicalname, 3000)

--exec sp_dbfilespaceallocation  -- are there any db's in FULL recovery that shouldn't be? If so change, and do full backup to set in stone.
--ALTER DATABASE limeade SET RECOVERY SIMPLE

--What does backup history look like?
exec dbops.dbo.prc_Maint_BackupMetrics

--How many vlf's do we have? Then fix with: \DBAScripts\DBConfigChecksandFixes\VLF fix.sql (above 200 fix, else ignore)
exec dbops.dbo.prc_Maint_vlftracking

--Should we use ad hoc workloads?
\DBAScripts\ServerConfigChecksandFixes\Should we use optimize for ad hoc workloads.sql
--To see all the sp_configure values:
exec sp_configure 'show advanced options' , 1
reconfigure

EXEC sys.sp_configure N'optimize for ad hoc workloads', N'1'

--To turn back off if not running below which also has this statement.
exec sp_configure 'show advanced options' , 0
RECONFIGURE WITH OVERRIDE


USE [msdb]
GO

--To check service broker status for MSDB.
--Enable service broker in MSDB, we need to enable this because database mail works with this.
IF NOT EXISTS (Select 1 FROM sys.databases WHERE name='msdb' and is_broker_enabled = 1)
BEGIN
	EXEC sp_executesql N'ALTER DATABASE msdb SET enable_broker'
	--Once its done, run the below query in MSDB to enable the queue ExternalMailQueue
	EXEC msdb.dbo.sysmail_start_sp
	ALTER QUEUE ExternalMailQueue WITH status = on
END

-------------------------------------------
--Setup Alerts and Notifications of Alerts.
-------------------------------------------

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Agent Alerts Sev 10' AND category_class=2)
BEGIN
EXEC msdb.dbo.sp_add_category @class=N'ALERT', @type=N'NONE', @name=N'Agent Alerts Sev 10'
END


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Pending IO Issue-825') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Pending IO Issue-825'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'This is a warning that IO corruption could happen in future.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Pending IO Issue-825',
			@message_id                   = 825,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 10'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Pending IO Issue-825''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Pending IO Issue-825' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Pending IO Issue-825', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Disk IO delay-833') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Disk IO delay-833'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'This means you had an IO stall, slow IO or too many table scans.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Disk IO delay-833',
			@message_id                   = 833,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 10'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Disk IO delay-833''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Disk IO delay-833' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Disk IO delay-833', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Checkpoint failed log out of space-3619') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Checkpoint failed log out of space-3619'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Run a log backup if FULL recovery, else remove space somehow on disk to allow it to complete.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Checkpoint failed log out of space-3619',
			@message_id                   = 3619,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 10'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Checkpoint failed log out of space-3619''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Checkpoint failed log out of space-3619' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Checkpoint failed log out of space-3619', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Scheduler yield issue-17883') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Scheduler yield issue-17883'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Very busy CPU, query DMVs and look at perf mon to see if other than SQL consuming CPU.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Scheduler yield issue-17883',
			@message_id                   = 17883,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 10'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Scheduler yield issue-17883''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Scheduler yield issue-17883' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Scheduler yield issue-17883', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Scheduler yield issue-17884') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Scheduler yield issue-17884'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Very busy CPU, query DMVs and look at perf mon to see if other than SQL consuming CPU.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Scheduler yield issue-17884',
			@message_id                   = 17884,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 10'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Scheduler yield issue-17884''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Scheduler yield issue-17884' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Scheduler yield issue-17884', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Scheduler yield issue-17888') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Scheduler yield issue-17888'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Very busy CPU, query DMVs and look at perf mon to see if other than SQL consuming CPU.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Scheduler yield issue-17888',
			@message_id                   = 17888,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 10'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Scheduler yield issue-17888''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Scheduler yield issue-17888' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Scheduler yield issue-17888', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO

DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'IO completion error-17887') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''IO completion error-17887'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'See http://technet.microsoft.com/en-us/library/cc280543.aspx'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'IO completion error-17887',
			@message_id                   = 17887,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 10'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''IO completion error-17887''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'IO completion error-17887' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'IO completion error-17887', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Significant memory paged out-17890') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Significant memory paged out-17890'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'You may not have locked pages in memory right and OS requested RAM from SQL. Possibly lower max memory setting in SQL.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Significant memory paged out-17890',
			@message_id                   = 17890,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 10'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Significant memory paged out-17890''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Significant memory paged out-17890' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Significant memory paged out-17890', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Agent Alerts Sev 16' AND category_class=2)
BEGIN
EXEC msdb.dbo.sp_add_category @class=N'ALERT', @type=N'NONE', @name=N'Agent Alerts Sev 16'
END


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Possible corrupt index-2511') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Possible corrupt index-2511'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Run DBCC CheckDB on databases.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Possible corrupt index-2511',
			@message_id                   = 2511,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 16'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Possible corrupt index-2511''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Possible corrupt index-2511' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Possible corrupt index-2511', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'DB Page issue-5242') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''DB Page issue-5242'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Call MS CSS for help with this one.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'DB Page issue-5242',
			@message_id                   = 5242,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 16'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''DB Page issue-5242''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'DB Page issue-5242' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'DB Page issue-5242', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'DB Page issue-5243') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''DB Page issue-5243'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Call MS CSS for help with this one.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'DB Page issue-5243',
			@message_id                   = 5243,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 16'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''DB Page issue-5243''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'DB Page issue-5243' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'DB Page issue-5243', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'DB page corruption-5250') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''DB page corruption-5250'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Dead database, possibly from hardware issue. Restore from backup. A file header page or boot page in the specified database is corrupted.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'DB page corruption-5250',
			@message_id                   = 5250,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 16'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''DB page corruption-5250''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'DB page corruption-5250' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'DB page corruption-5250', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO



DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Not enough memory-17130') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Not enough memory-17130'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Not enough memory for the configured number of locks. SQL will retry, if many alerts like this, add memory to server.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Not enough memory-17130',
			@message_id                   = 17130,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 16'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Not enough memory-17130''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Not enough memory-17130' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Not enough memory-17130', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Not enough memory-17300') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Not enough memory-17300'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'SQL Server was unable to run a new system task, either because there is insufficient memory or the number of configured sessions exceeds the maximum allowed in the server. Use sp_configure with option ''user connections'' to check the maximum number of user connections allowed. Use sys.dm_exec_sessions to check the current number of sessions, including user processes.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Not enough memory-17300',
			@message_id                   = 17300,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 16'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Not enough memory-17300''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Not enough memory-17300' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Not enough memory-17300', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO

IF NOT EXISTS (SELECT * FROM msdb.dbo.syscategories WHERE name=N'Agent Alerts Sev 17' AND category_class=2)
BEGIN
EXEC msdb.dbo.sp_add_category @class=N'ALERT', @type=N'NONE', @name=N'Agent Alerts Sev 17'
END


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Buffer pool is full-802') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Buffer pool is full-802'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'See http://technet.microsoft.com/en-us/library/aa337354.aspx for guidance.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Buffer pool is full-802',
			@message_id                   = 802,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 17'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Buffer pool is full-802''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Buffer pool is full-802' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Buffer pool is full-802', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Latch wait timeout-845') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Latch wait timeout-845'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Busy server. A process was waiting to acquire a latch, but the process waited until the time limit expired and failed to acquire one.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Latch wait timeout-845',
			@message_id                   = 845,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 17'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Latch wait timeout-845''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Latch wait timeout-845' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Latch wait timeout-845', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Disk out of space-1101') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Disk out of space-1101'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = NULL
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Disk out of space-1101',
			@message_id                   = 1101,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 17'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Disk out of space-1101''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Disk out of space-1101' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Disk out of space-1101', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Filegroup out of space-1105') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Filegroup out of space-1105'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Run exec dbops.dbo.prc_DBA_CheckFileGroupSpace'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Filegroup out of space-1105',
			@message_id                   = 1105,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 17'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Filegroup out of space-1105''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Filegroup out of space-1105' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Filegroup out of space-1105', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Transaction log full-9002') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Transaction log full-9002'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Run exec sp_dbfilespaceallocation to see if still full. If so, add some space and backup the log. Then check log backup intervals.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Transaction log full-9002',
			@message_id                   = 9002,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 17'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Transaction log full-9002''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Transaction log full-9002' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Transaction log full-9002', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Agent Alerts Sev 19' AND category_class=2)
BEGIN
EXEC msdb.dbo.sp_add_category @class=N'ALERT', @type=N'NONE', @name=N'Agent Alerts Sev 19'
END


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Not enough memory for query-701') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Not enough memory for query-701'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'See http://technet.microsoft.com/en-us/library/aa337311.aspx for guidance.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Not enough memory for query-701',
			@message_id                   = 701,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 19'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Not enough memory for query-701''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Not enough memory for query-701' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Not enough memory for query-701', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Agent Alerts Sev 20' AND category_class=2)
BEGIN
EXEC msdb.dbo.sp_add_category @class=N'ALERT', @type=N'NONE', @name=N'Agent Alerts Sev 20'
END


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Transaction log corruption-3624') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Transaction log corruption-3624'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Transaction log corruption trigger, please call on-call DBA.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Transaction log corruption-3624',
			@message_id                   = 3624,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 20'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Transaction log corruption-3624''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Transaction log corruption-3624' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Transaction log corruption-3624', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Agent Alerts Sev 21' AND category_class=2)
BEGIN
EXEC msdb.dbo.sp_add_category @class=N'ALERT', @type=N'NONE', @name=N'Agent Alerts Sev 21'
END


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'DB Page corruption-605') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''DB Page corruption-605'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'See http://technet.microsoft.com/en-us/library/aa337419.aspx for guidance.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'DB Page corruption-605',
			@message_id                   = 605,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 21'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''DB Page corruption-605''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'DB Page corruption-605' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'DB Page corruption-605', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Agent Alerts Sev 22' AND category_class=2)
BEGIN
EXEC msdb.dbo.sp_add_category @class=N'ALERT', @type=N'NONE', @name=N'Agent Alerts Sev 22'
END


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'DB file missing-5180') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''DB file missing-5180'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = NULL
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'DB file missing-5180',
			@message_id                   = 5180,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 22'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''DB file missing-5180''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'DB file missing-5180' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'DB file missing-5180', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'DB page read or latch error-8966') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''DB page read or latch error-8966'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'Check SQL Error log for accompanying information, could just be a time out.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'DB page read or latch error-8966',
			@message_id                   = 8966,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 22'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''DB page read or latch error-8966''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'DB page read or latch error-8966' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'DB page read or latch error-8966', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Agent Alerts Sev 23' AND category_class=2)
BEGIN
EXEC msdb.dbo.sp_add_category @class=N'ALERT', @type=N'NONE', @name=N'Agent Alerts Sev 23'
END


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Internal Filestream error-5572') 
AND (@@microsoftversion / 0x1000000) & 0xff >= 10
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Internal Filestream error-5572'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = NULL
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Internal Filestream error-5572',
			@message_id                   = 5572,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 23'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Internal Filestream error-5572''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Internal Filestream error-5572' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Internal Filestream error-5572', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Possible index corruption-9100') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Possible index corruption-9100'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = NULL
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Possible index corruption-9100',
			@message_id                   = 9100,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 23'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Possible index corruption-9100''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Possible index corruption-9100' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Possible index corruption-9100', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Agent Alerts Sev 24' AND category_class=2)
BEGIN
EXEC msdb.dbo.sp_add_category @class=N'ALERT', @type=N'NONE', @name=N'Agent Alerts Sev 24'
END

DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Severe IO Failure-823') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Severe IO Failure-823'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'A Windows read or write request has failed. The error code that is returned by Windows and the corresponding text are inserted into the message. In the read case, SQL Server will have already retried the read request four times. Run DBCC CheckDB.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Severe IO Failure-823',
			@message_id                   = 823,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@database_name                = NULL,
			@event_description_keyword    = NULL,
			@job_name                     = NULL,
			@performance_condition        = NULL,
			@category_name                = N'Agent Alerts Sev 24'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Severe IO Failure-823''.', 16, 1)
		RETURN
	END
	--Create notification of operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Severe IO Failure-823' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Severe IO Failure-823', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO

--Create alert 'Severe IO Failure-824'
DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Severe IO Failure-824') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Severe IO Failure-824'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = 'This error indicates that Windows reports that the page is successfully read from disk, but SQL Server has discovered something wrong with the page. This usually indicates a problem in the I/O subsystem.'
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Severe IO Failure-824',
			@message_id                   = 824,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@database_name                = NULL,
			@event_description_keyword    = NULL,
			@job_name                     = NULL,
			@performance_condition        = NULL,
			@category_name                = N'Agent Alerts Sev 24'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Severe IO Failure-824''.', 16, 1)
		RETURN
	END
	--Create notification of operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Severe IO Failure-824' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Severe IO Failure-824', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
go


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'Unexpected cache page change-832') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''Unexpected cache page change-832'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = NULL
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'Unexpected cache page change-832',
			@message_id                   = 832,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts Sev 24'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Unexpected cache page change-832''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'Unexpected cache page change-832' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'Unexpected cache page change-832', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Agent Alerts AlwaysOn' AND category_class=2)
BEGIN
EXEC msdb.dbo.sp_add_category @class=N'ALERT', @type=N'NONE', @name=N'Agent Alerts AlwaysOn'
END

DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'AlwaysOn Role Change(failover)-1480') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''AlwaysOn Role Change(failover)-1480'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = NULL
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'AlwaysOn Role Change(failover)-1480',
			@message_id                   = 1480,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 0,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts AlwaysOn'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''Unexpected cache page change-832''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'AlwaysOn Role Change(failover)-1480' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'AlwaysOn Role Change(failover)-1480', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO



DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'AlwaysOn Data Movement - Suspended-35264') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''AlwaysOn Data Movement - Suspended-35264'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = NULL
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'AlwaysOn Data Movement - Suspended-35264',
			@message_id                   = 35264,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts AlwaysOn'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''AlwaysOn Data Movement - Suspended-35264''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'AlwaysOn Data Movement - Suspended-35264' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'AlwaysOn Data Movement - Suspended-35264', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO


DECLARE @RETCODE int
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysalerts WHERE name = N'AlwaysOn Data Movement - Resumed-35265') 
BEGIN 
	PRINT N' '
	PRINT N'Create alert ''AlwaysOn Data Movement - Resumed-35265'''
	DECLARE @notification_message nvarchar(512)
	SET @notification_message = NULL
	EXEC @RETCODE = msdb.dbo.sp_add_alert 
			@name                         = N'AlwaysOn Data Movement - Resumed-35265',
			@message_id                   = 35265,
			@severity                     = 0,
			@enabled                      = 1,
			@delay_between_responses      = 900,
			@notification_message         = @notification_message,
			@include_event_description_in = 1,
			@category_name                = N'Agent Alerts AlwaysOn'
	IF @RETCODE != 0
	BEGIN
		RAISERROR (N'Cannot create alert ''AlwaysOn Data Movement - Resumed-35265''.', 16, 1)
		RETURN
	END
	--Create notification for operator 'IT Ops'
	IF NOT EXISTS (
		SELECT * 
		FROM msdb.dbo.sysnotifications n 
			INNER JOIN msdb.dbo.sysoperators o ON (n.operator_id = o.id)
			INNER JOIN msdb.dbo.sysalerts a ON (n.alert_id = a.id)
		WHERE
			a.name = N'AlwaysOn Data Movement - Resumed-35265' AND
			o.name = N'IT Ops'
		) 
	BEGIN
		IF EXISTS (SELECT * FROM msdb.dbo.sysoperators WHERE name = N'IT Ops') 
		BEGIN
			EXEC @RETCODE = msdb.dbo.sp_add_notification N'AlwaysOn Data Movement - Resumed-35265', N'IT Ops', 1
			IF @RETCODE != 0
			BEGIN
				RAISERROR (N'Cannot create notification of operator ''IT Ops''', 16, 1)
				RETURN
			END
		END
		ELSE
			PRINT N'warning: Operator ''IT Ops'' was not found.'
	END
	ELSE
	BEGIN
		RAISERROR (N'Notification of operator ''IT Ops'' already exists.', 16, 1)
		RETURN
	END

END  
GO
