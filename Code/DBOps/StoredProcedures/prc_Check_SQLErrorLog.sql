IF OBJECT_ID(N'dbo.SQLErrorLogReportLastRun', N'U') IS NULL 
    BEGIN  
        CREATE TABLE dbo.SQLErrorLogReportLastRun ( LastRunTime DATETIME )   
    END  
GO

IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'prc_Check_SQLErrorLog' And ROUTINE_SCHEMA = 'dbo')
    BEGIN
        EXEC('CREATE Procedure dbo.prc_Check_SQLErrorLog  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
        IF ( @@error = 0 ) 
            PRINT 'Successfully created empty stored procedure dbo.prc_Check_SQLErrorLog.'
        ELSE 
            BEGIN
                PRINT 'FAILED to create stored procedure dbo.prc_Check_SQLErrorLog.'
            END
    END
GO

ALTER PROCEDURE dbo.prc_Check_SQLErrorLog
    @SinceWhen DATETIME = NULL
AS
BEGIN
/**********************************************************************************      
**   Created on:    11/13/2008    
**   Usage:         Gather SQL Error Log data runs on client    
**   Code examples:    
**     1. To schedule a job reporting on error logs never overlaps data:    
**        exec dbops.dbo.prc_Check_SQLErrorLog    
**     2. To ad hoc display search result for all error logs since point in time:    
**        exec dbops.dbo.prc_Check_SQLErrorLog '2010-11-10'    
**    
** History:      
** 05/14/2009 - Modified to compatible for SQL 2008      
** 11/19/2010 - Refactored. Modified to be compatible for SQL 2008 R2. Removed SQL 2000    
** 12/27/2010 - Revised procedure to use coalesce on three possibilities for date based retrieval.  
** 08/09/2012 - Matias Sincovich 
**				+ Changed per xp_readerrorlog (with filters)
**				+ Now only works for SQL 2005 ahead
** 09/19/2012 - Matias Sincovich * Search SQL Agent error logs correctly. Added validation if proc is already running.
** 08/03/2015 - Chuck L Add more exclusions 
**********************************************************************************/
    SET NOCOUNT ON      
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED 
	
	DECLARE @cmd NVARCHAR(500)
		,@ArchiveNo INT
		,@version INT
		,@sinceParam VARCHAR(23)
		,@untilParam VARCHAR(23)
		,@LastRunTime datetime
	
	-- CHECK IF IT's ALREADY RUNNING
	IF EXISTS(SELECT es.session_id,  es.login_time, es.login_name
					, es.status, es.last_request_start_time
					, er.start_time, er.status, er.command
					, st.text
				FROM sys.dm_exec_sessions es
					JOIN Sys.dm_exec_requests er on es.session_id = er.session_id
					CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) st
				WHERE login_name = SYSTEM_USER
					and es.session_id <> @@SPID
					and (st.text like '%prc_Check_SQLErrorLog%' or st.text like '%readerrorlog%'))
	BEGIN
		DECLARE @subj VARCHAR(200)
		SET @subj = 'WARNING: prc_Check_SQLErrorLog already running on server' + RTRIM(@@SERVERNAME)
		
		PRINT 'prc_Check_SQLErrorLog It''s already running. Mail sent.'

		EXEC dbo.prc_InternalSendMail
			@Subject = @subj
			, @Body = 'Please check current running spids on server. prc_Check_SQLErrorLog It''s already running.'
		
		RETURN (1)
	END -- END IF PROC IT's ALREADY RUNNING

	IF @SinceWhen IS NULL
	BEGIN
        SELECT  @LastRunTime = COALESCE(LastRunTime,DATEADD(DAY, -2, GETDATE()))
        FROM    dbo.SQLErrorLogReportLastRun
        
		IF @LastRunTime < DATEADD(DAY, -3, GETDATE())
			SET @LastRunTime = DATEADD(DAY, -2, GETDATE())
    END
    ELSE
    BEGIN
    SET @LastRunTime = @SinceWhen
    END
   
	
	--SET @sinceParam = CONVERT(VARCHAR(23),@SinceWhen, 25)
	SET @untilParam = CONVERT(VARCHAR(23),GETDATE(), 25)
	SET @sinceParam = CONVERT(VARCHAR(23),@LastRunTime, 25)
	
	-- Get the product version 
    SELECT  @Version = CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR),
						1, 2), '.', '') AS TINYINT) ;      

    CREATE TABLE #SQLErrorLogList
           (
             ArchiveNo TINYINT ,
             [Date] DATETIME ,
             LogFileSize INT 
           )    
     CREATE TABLE #SQLErrorLogListAgent
           (
             ArchiveNo TINYINT ,
             [Date] DATETIME ,
             LogFileSize INT 
           )    

	/*  Temp store errorlog info */
	CREATE TABLE #SQLErrorLogContents
		(
		LogDate DATETIME ,
		ProcessInfo NVARCHAR(40) ,
		LogText NVARCHAR(3984)
		)
	
	--Populate temp tables with ErrorLog numbers   
    INSERT  INTO #SQLErrorLogList ( ArchiveNo ,[Date] , LogFileSize )
		EXEC ( N'master.dbo.sp_enumerrorlogs')  
	--Populate temp tables with ErrorLog numbers   
    INSERT  INTO #SQLErrorLogListAgent ( ArchiveNo ,[Date] , LogFileSize )
		EXEC ( N'master.dbo.sp_enumerrorlogs 2')       

	--  Note the error log output formats are different between SS2000 and SS2005     
    IF @Version >= 9
    BEGIN
        --  Loop through target logs and search interested keywords       
		SET @ArchiveNo = -1
		SET @cmd = N''
				
		WHILE 1 = 1 
        BEGIN      
            SELECT TOP 1
                    @ArchiveNo = ArchiveNo
            FROM    #SQLErrorLogList
            WHERE   ArchiveNo > @ArchiveNo
            ORDER BY ArchiveNo ASC 
                 
            IF @@ROWCOUNT = 0 
                BREAK
			
			SET @cmd = N'master.dbo.xp_readerrorlog '
			SET @cmd = @cmd + CAST(@ArchiveNo AS VARCHAR(3))-- Log file number
			SET @cmd = @cmd + ' , 1 , NULL , NULL' -- String filters
			SET @cmd = @cmd + ' , ''' + @sinceParam --start date
			SET @cmd = @cmd + ''' , ''' + @untilParam --end date
			SET @cmd = @cmd + ''' , ' + 'N''asc''' -- order
			
			/*
			--Valid example:
				EXEC master.dbo.xp_readerrorlog 0, 1, NULL, NULL
					, '2012-08-03 08:20:16.750', '2012-08-08 04:28:36.020', N'asc'
			*/
			INSERT  INTO #SQLErrorLogContents ( LogDate, ProcessInfo, LogText )
				EXEC ( @cmd )
		 
		END -- WHILE SQL Error Log
		
		SET @ArchiveNo = -1
		SET @cmd = N''
				
		WHILE 1 = 1 
        BEGIN      
            SELECT TOP 1
                    @ArchiveNo = ArchiveNo
            FROM    #SQLErrorLogListAgent
            WHERE   ArchiveNo > @ArchiveNo
            ORDER BY ArchiveNo ASC 
                 
            IF @@ROWCOUNT = 0 
                BREAK
			
			SET @cmd = N'master.dbo.xp_readerrorlog '
			SET @cmd = @cmd + CAST(@ArchiveNo AS VARCHAR(3))-- Log file number
			SET @cmd = @cmd + ' , 2 , NULL , NULL' -- String filters
			SET @cmd = @cmd + ' , ''' + @sinceParam --start date
			SET @cmd = @cmd + ''' , ''' + @untilParam --end date
			SET @cmd = @cmd + ''' , ' + 'N''asc''' -- order
			
			/*
			--Valid example:
				EXEC master.dbo.xp_readerrorlog 0, 1, NULL, NULL
					, '2012-08-03 08:20:16.750', '2012-08-08 04:28:36.020', N'asc'
			*/
			INSERT  INTO #SQLErrorLogContents ( LogDate, ProcessInfo, LogText )
				EXEC ( @cmd )
		 
		END -- WHILE SQL AGENT Error Log
	END -- IF SQL 2005 or 2008
	
    SELECT  @@ServerName AS ServerName ,
            LogDate ,
            ProcessInfo ,
            LogText
    FROM    #SQLErrorLogContents
    WHERE   /*ProcessInfo <> 'Backup'
            AND */LogText NOT LIKE N'The activated proc%'
            AND LogText NOT LIKE N'This instance of SQL Server%'
            AND LogText NOT LIKE N'DBCC CHECKDB% found 0 errors and repaired 0 errors%'
            AND LogText <> N'(c)%Microsoft Corporation.'
            AND LogText <> N'All rights reserved.'
            AND LogText NOT LIKE N'Server process ID%'
            AND LogText NOT LIKE N'System Manufacturer:%'
            AND LogText NOT LIKE N'Authentication mode%'
            AND LogText NOT LIKE N'Logging SQL Server messages in%'
            AND LogText NOT LIKE N'Microsoft SQL Server%'
            AND LogText NOT LIKE N'Starting up database%'
            AND LogText NOT LIKE N'The error log has been reinitialized%'
            AND LogText NOT LIKE N'A new instance of the full-text%'
            AND LogText NOT LIKE N'%This is an informational message only%'
            AND LogText NOT LIKE N'SQL Trace ID%'
            AND LogText NOT LIKE N'The resource database build version%'
            AND LogText <> N'Clearing tempdb database.'
            AND LogText <> N'A self-generated certificate was successfully loaded for encryption.'
            AND LogText NOT LIKE N'Server is listening%'
            AND LogText NOT LIKE N'Server local connection provider is ready%'
            AND LogText NOT LIKE N'Dedicated admin connection support was est%'
            AND LogText <> N'Service Broker manager has started.'
            AND LogText NOT LIKE N'%is disabled or not configured.'
            AND LogText NOT LIKE N'Registry startup parameters:%'
            AND LogText NOT LIKE N'Detected%CPUs%'
            AND LogText NOT LIKE N'FILESTREAM: effective level%'
            AND LogText NOT LIKE N'Setting database option%'
            --AND LogText NOT LIKE N'BackupVirtualDeviceFile%'
            AND LogText NOT LIKE N'Configuration option ''show advanced options%'
            AND LogText NOT LIKE N'SQL Trace stopped. Trace ID%'
            AND LogText NOT LIKE N'Configuration option ''xp_cmdshell'' changed %'
            AND LogText NOT LIKE N'%index restored for%'
            AND LogText <> N'Error: 14151, Severity: 18, State: 1.'
            AND LogText NOT LIKE N'Replication-Replication Distribution Subsystem: agent %'
			AND LogText NOT LIKE N'AppDomain%'
			AND LogText NOT LIKE N'Database was restored%'
			AND LogText <> N'All rights reserved.'
			AND LogText NOT LIKE N'A self-generated certificate%'
			AND LogText NOT LIKE N'Attempting to initialize Microsoft Distributed%'
			AND LogText NOT LIKE N'Attempting to recover in-doubt distributed transactions involving Microsoft Distributed%'
			AND LogText <> N'Authentication mode is MIXED.'
			AND LogText NOT LIKE N'Detected %'
			AND LogText NOT LIKE N'Lock partitioning is enabled.%'
			AND LogText NOT LIKE N'Logging SQL Server messages in file%'
			AND LogText NOT LIKE N'Microsoft SQL Server 200%'
			AND LogText NOT LIKE N'Multinode configuration:%'
			AND LogText NOT LIKE N'Server process ID is%'
			AND LogText NOT LIKE N'Server local connection provider is ready%'
			AND LogText NOT LIKE N'SQL Server is starting at normal priority base%'
			AND LogText NOT LIKE N'This instance of SQL Server last reported using a process ID%'
			AND LogText <>  N'Clearing tempdb database.'
			AND LogText <> N'Service Broker manager has started.'
			AND LogText NOT LIKE N'Setting database option%'
			AND LogText NOT LIKE N'SQL Trace ID%'
			AND LogText NOT LIKE N'FlushCache:%'--FlushCache: cleaned up 36565 bufs with 2714 writes in 70883 ms (avoided 123 new dirty bufs) for db 7:0
			AND LogText NOT LIKE N'%average throughput:%'--            average throughput:   4.03 MB/sec, I/O saturation: 3809, context switches 9323
			AND LogText NOT LIKE N'%last target outstanding:%'--            last target outstanding: 10, avgWriteLatency 11
			
	--Update the last run time      
    IF @SinceWhen IS NULL 
        BEGIN      
            IF EXISTS ( SELECT * FROM dbo.SQLErrorLogReportLastRun ) 
                UPDATE  dbo.SQLErrorLogReportLastRun SET LastRunTime = GETDATE()    
            ELSE 
                INSERT INTO dbo.SQLErrorLogReportLastRun VALUES ( GETDATE() )      
        END

    RETURN (0) 
END
GO
