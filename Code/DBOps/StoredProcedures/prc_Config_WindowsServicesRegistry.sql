CREATE OR ALTER PROCEDURE dbo.prc_Config_WindowsServicesRegistry
AS
BEGIN
/*
7/23/2012 Matias Sincovich - Created
Description: This proc gather the attributes for the Windows Services specified on #temp_services table.
	The results are useful when you can't successfully access via PowerShell (Requires RPC)
	(PowerShell Get-WmiObject -Class Win32_Service -ComputerName $SourceServer).
		+Services: SQL Services, SQL Agent, IISS, Reporting Services, Analysis Services, MSDTC.
		+Values: ServiceName, DisplayName, StartName, Description, StartMode
	Note: This proc needs to run for each instance. More info about this values on: http://support.microsoft.com/kb/103000
** 05/10/2013	Matias Sincovich	Added DateChecked
*/
	DECLARE @KEY_VALUE varchar(100)
		,@ServerName varchar(50)
		,@NamedInstance bit
		,@ServiceName varchar(100)
		,@VersionNum varchar(100)
		,@KeyPathDef varchar(50)
		,@KeyPathNonDef varchar(50)
		,@Change_opt int
		,@KeyName varchar(50)
		,@DisplayName varchar(50)
		,@ObjectName varchar(50)
		,@Description varchar(100)
		,@Start varbinary(10)

	-- Services to Watch
	CREATE TABLE #temp_services(
		Name varchar(50) -- Service Name you want to Insert
		,default_name varchar(50) -- Default Key name on non-named instances
		,non_default varchar(50) -- Name to add before named instances
		,change_opt int -- If changes KeyValue. 0: no, 1: add ServerName,  2: add version number (80,90,100)
	)

	-- Add as many Services needed to watch
	INSERT INTO #temp_services VALUES ('SQL Server', 'MSSQLSERVER' ,'MSSQL$', 1)
	INSERT INTO #temp_services VALUES ('SQL Server Agent', 'SQLSERVERAGENT' ,'SQLAgent$', 1)
	INSERT INTO #temp_services VALUES ('SQL Server Integration Services', 'MsDtsServer' ,'MsDtsServer', 2)
	INSERT INTO #temp_services VALUES ('Analysis Services', 'MSOLAP' ,'MSOLAP$', 1)
	INSERT INTO #temp_services VALUES ('Distributed Transaction Coordinator', 'MSDTC' ,'MSDTC', 0)
	INSERT INTO #temp_services VALUES ('SQL Full-text Filter Daemon Launcher', 'MSSQLFDLauncher' ,'MSSQLFDLauncher', 0)
	INSERT INTO #temp_services VALUES ('SQL Server FullText Search', 'msftesql' ,'msftesql$', 1)
	INSERT INTO #temp_services VALUES ('SQL Server Reporting Services', 'ReportServer' ,'ReportServer$', 2)

	-- The KEYVALUE on Register depends if is a Named instance or not.
	IF CAST(SERVERPROPERTY('ServerName') AS varchar) LIKE '%\%' 
		BEGIN
			SET @NamedInstance = 1 
			SET @ServerName = RIGHT(CAST(SERVERPROPERTY('ServerName') AS varchar),LEN(CAST(SERVERPROPERTY('ServerName') AS varchar)) - CHARINDEX('\',CAST(SERVERPROPERTY('ServerName') AS varchar),1))
		END
		ELSE
		BEGIN 
			SET @NamedInstance = 0
			SET @ServerName = ''
		END
	-- SQL Server Major Version
	SELECT @VersionNum = SUBSTRING(CONVERT(VARCHAR,SERVERPROPERTY('productversion')), 0, CHARINDEX('.',CONVERT(VARCHAR,SERVERPROPERTY('productversion')),0)) + '0'

	CREATE TABLE #temp_Services_Values(
		ServerName varchar(50)
		,Name varchar(100)
		,DisplayName varchar(50)
		,StartName varchar(50)
		,[Description] varchar(100)
		,StartMode varbinary(10)
		)

	DECLARE cur_services CURSOR FORWARD_ONLY FOR 
		SELECT * FROM #temp_services

	OPEN cur_services
	FETCH NEXT FROM cur_services INTO @ServiceName, @KeyPathDef, @KeyPathNonDef, @Change_opt
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- First truncate values 
		SELECT @DisplayName = NULL, @ObjectName = NULL, @Description = NULL, @Start = NULL
		--Depending on Service
		IF @NamedInstance = 0 OR @Change_opt = 0
		BEGIN
			SET @KeyName = @KeyPathDef
			SET @KEY_VALUE = 'SYSTEM\CurrentControlSet\Services\' + @KeyPathDef
		END
		ELSE IF @NamedInstance = 1 AND @Change_opt = 1
			BEGIN
				SET @KeyName = @KeyPathNonDef + @ServerName
				SET @KEY_VALUE = 'SYSTEM\CurrentControlSet\Services\' + @KeyPathNonDef + @ServerName
				SET @ServiceName = @ServiceName + ' (' + @ServerName + ')'
			END
			ELSE IF @NamedInstance = 1 AND @Change_opt = 2
			BEGIN
				SET @KeyName = @KeyPathNonDef + @VersionNum
				SET @KEY_VALUE = 'SYSTEM\CurrentControlSet\Services\' + @KeyPathNonDef + @VersionNum
				SET @ServiceName = @ServiceName + ' (' + @VersionNum + ')'
			END
		
		EXECUTE master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @KEY_VALUE, 'DisplayName', @DisplayName OUTPUT;
		EXECUTE master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @KEY_VALUE, 'ObjectName', @ObjectName OUTPUT;
		EXECUTE master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @KEY_VALUE, 'Description', @Description OUTPUT;
		EXECUTE master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @KEY_VALUE, 'Start', @Start OUTPUT;
		
		INSERT INTO #temp_Services_Values
			SELECT @ServerName, @KeyName, @DisplayName, @ObjectName , @Description , @Start

		FETCH NEXT FROM cur_services INTO @ServiceName, @KeyPathDef, @KeyPathNonDef, @Change_opt
	END -- WHILE
	CLOSE cur_services
	DEALLOCATE cur_services

	--SELECT * FROM #temp_services
	SELECT GetDate() as DateChequed
	, Name
	, DisplayName
	, StartName
	--, Description
	, CASE StartMode 
		WHEN 0x01000000 THEN 'Automatically(Delay)'
		WHEN 0x02000000 THEN 'Automatically'
		WHEN 0x03000000 THEN 'Manual'
		WHEN 0x04000000 THEN 'Disabled'
		END as StartMode
	--,@ServerID
	 FROM #temp_services_Values
	WHERE DisplayName IS NOT NULL

	
END