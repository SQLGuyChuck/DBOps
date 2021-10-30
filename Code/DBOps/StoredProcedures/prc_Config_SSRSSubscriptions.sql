CREATE OR ALTER PROCEDURE dbo.prc_Config_SSRSSubscriptions
AS
BEGIN
/*
** 09/04/2012 Matias Sincovich + Added DB validation and dynamic SQL USE, and Prettified
** 10/26/2012 Matias Sincovich + Fixed conversion and database name between []
** 12/27/2012 Matias Sincovich Space in column names deleted
*/
	IF EXISTS(SELECT * FROM master.sys.databases WHERE name like 'ReportServer%')
	BEGIN
		CREATE TABLE #temp_GetReportSubscriptions(
			[JobName] [sysname] NOT NULL,
			[Name] [nvarchar](425) NOT NULL,
			[path] [nvarchar](425) NOT NULL,
			[Description] [nvarchar](512) NULL,
			[Subject] [nvarchar](100) NULL,
			[To] [nvarchar](300) NULL,
			[LastStatus] [nvarchar](260) NULL,
			[InactiveFlags] [int] NOT NULL,
			[EventType] [nvarchar](260) NOT NULL,
			[LastRunTime] [datetime] NULL,
			[NextRunDate] [varchar](10) NULL,
			[NextRunTime] [char](8) NOT NULL,
			[DeliveryExtension] [nvarchar](260) NULL,
			[RenderFormat] [nvarchar](50) NULL,
			[JobCreatedDate] [datetime] NOT NULL,
			[JobModifiedDate] [datetime] NOT NULL
		)
		
		DECLARE @script NVARCHAR(MAX)
			, @db sysname
		
		DECLARE cur_db CURSOR FAST_FORWARD FOR
			SELECT name 
			FROM master.sys.databases
			WHERE name like 'ReportServer%'
		
		OPEN cur_db		
		FETCH NEXT FROM cur_db INTO @db
		WHILE @@FETCH_STATUS = 0
		BEGIN
		
			IF (OBJECT_ID( @db + '.dbo.Subscriptions') IS NOT NULL)
			BEGIN
				SET @script = ''
				SET @script = @script + ''
				SET @script = @script + 'SELECT j.name as JobName , e.Name , e.path , S.Description '
				SET @script = @script + '	, CONVERT(XML,[ExtensionSettings]).value(''(//ParameterValue/Value[../Name ="Subject"])[1]'',''nvarchar(100)'') as [Subject]  '
				SET @script = @script + '	, CONVERT(XML,[ExtensionSettings]).value(''(//ParameterValue/Value[../Name ="TO"])[1]'',''nvarchar(300)'') as [To]  '
				SET @script = @script + '	, [LastStatus] ,InactiveFlags ,[EventType] ,[LastRunTime]  '
				SET @script = @script + '	, CASE next_run_date  '
				SET @script = @script + '		WHEN 0 THEN null  '
				SET @script = @script + '		ELSE substring(CONVERT(varchar(15),next_run_date),1,4) + ''/''  '
				SET @script = @script + '			+ substring(CONVERT(varchar(15),next_run_date),5,2) + ''/''  '
				SET @script = @script + '			+ substring(convert(varchar(15),next_run_date),7,2)  '
				SET @script = @script + '		END as ''NextRunDate'' '
				SET @script = @script + '	, ISNULL(CASE len(next_run_time)  '
				SET @script = @script + '		WHEN 3 THEN cast(''00:0'' + Left(right(next_run_time,3),1) +'':'' + right(next_run_time,2) as char (8))  '
				SET @script = @script + '		WHEN 4 THEN cast(''00:'' + Left(right(next_run_time,4),2) +'':'' + right(next_run_time,2) as char (8))  '
				SET @script = @script + '		WHEN 5 THEN cast(''0'' + Left(right(next_run_time,5),1) +'':'' + Left(right(next_run_time,4),2) +'':''  '
				SET @script = @script + '			+ right(next_run_time,2) as char (8))  '
				SET @script = @script + '		WHEN 6 THEN cast(Left(right(next_run_time,6),2) +'':'' + Left(right(next_run_time,4),2) +'':''  '
				SET @script = @script + '			+ right(next_run_time,2) as char (8))  '
				SET @script = @script + '		END,''NA'') as ''NextRunTime'' '
				SET @script = @script + '	, [DeliveryExtension]  '
				SET @script = @script + '	, CONVERT(XML,[ExtensionSettings]).value(''(//ParameterValue/Value[../Name ="RenderFormat"])[1]'',''nvarchar(50)'') as [RenderFormat]  '
				SET @script = @script + '	, j.date_created as JobCreatedDate ,j.date_modified as JobModifiedDate  '
				SET @script = @script + ' FROM [' + LTRIM(RTRIM(@db)) + '].dbo.[Subscriptions] S  '
				SET @script = @script + '	INNER JOIN [' + LTRIM(RTRIM(@db)) + '].dbo.Catalog e ON s.report_oid = e.itemid  '
				SET @script = @script + '	INNER JOIN [' + LTRIM(RTRIM(@db)) + '].dbo.ReportSchedule R ON S.SubscriptionID = R.SubscriptionID  '
				SET @script = @script + '	INNER JOIN msdb.dbo.sysjobs J ON CONVERT(nvarchar(128),R.ScheduleID) = J.name  '
				SET @script = @script + '	INNER JOIN msdb.dbo.sysjobschedules JS ON J.job_id = JS.job_id '
				
				--Where Convert(XML,[ExtensionSettings]).value('(//ParameterValue/Value[../Name= "Subject"])[1]','nvarchar(100)') like '%video%' Order by InactiveFlags Desc, LastStatus 
				
				INSERT INTO #temp_GetReportSubscriptions
					EXEC (@script)
					
			END -- IF EXISTS (OBJECT_ID
			
			FETCH NEXT FROM cur_db INTO @db
		END -- WHILE @@FETCH_STATUS
		
		CLOSE cur_db
		DEALLOCATE cur_db
		
		SELECT * FROM #temp_GetReportSubscriptions
		
		DROP TABLE #temp_GetReportSubscriptions
	END -- IF (DB_ID('ReportServer') IS NOT NULL)
END