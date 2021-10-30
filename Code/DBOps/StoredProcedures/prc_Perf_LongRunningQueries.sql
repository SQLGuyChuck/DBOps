SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_Perf_LongRunningQueries]
	@MaxMinutes INT=15,
	@person_to_notify VARCHAR (1000)='alerts@YourDomainNameHere.com'
AS
BEGIN
/******************************************************************************
**  Name: prc_Perf_LongRunningQueries
**  Desc: This will get list of SPID(s) running for more than X minutes using sp_WhoIsActive
**
*******************************************************************************
**  Change History
*******************************************************************************
**  Date:		Author:			Description:
**  11/26/2012	Chuck Lathrope	Exclude jobs from alerts as there is dedicated process for this.
**  5/5/2013	Chuck Lathrope  Exclude SQL 2012 diagnostic query that comes up under NT AUTHORITY\SYSTEM
**  8/16/2013	Chuck Lathrope	Exclude SSIS program names as they will be included in job monitoring.
**  8/20/2013	Chuck Lathrope	Change to Duration column instead of secs and minutes.
**								Make sure logging of detailed processes has happened.
**								Add lookup note to email output for detailed process info.
**  8/22/2013	Chuck Lathrope	Blank emails coming in, moved Set @destination_table
**								Added sys.dm_exec_requests apply as last_batch could be the login time not current query.
**  9/3/2013	Chuck Lathrope	Added upper(cmd) NOT IN ('BRKR TASK'); Bug fix for checking existing logging.
** 11/25/2014	Chuck Lathrope  Added @ActivityTableExists checks to prevent missing table errors.
** 8/13/2015	Chuck Lathrope	Added join to sys.dm_exec_sessions to use is_user_process value.
** 06/03/2019	Michael C		Added logic to ignore AWS replication queries running under 4 hours.
** 06/04/2019	Michael C		Fixed blank email bug
** 06/11/2019	Michael C		Modified code to ignore AWS replication queries running under 4->5 hours
** 7/11/2019	Chuck Lathrope	Ignore TdService program for Azure
** 07/26/2019	Michael C		Ignore BACKUP DATABASE
** 07/30/2019	Michael C		Ignore Secure transfer queries under 1 hour
** 10/22/2018	Michael C       Updated to use Instance Description process prameter in subject line
*******************************************************************************/
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

Declare @Now Datetime
	, @tableHTML NVARCHAR(MAX)
	, @SubjectMsg varchar(255)
	, @destination_table VARCHAR(200)
	, @spwhoDestination_table VARCHAR(200)
	, @SecondsSinceLastCollection INT
	, @LogActivity BIT = 1
	, @dsql NVARCHAR(500)
	, @schema VARCHAR(4000)
	, @ActivityTableExists BIT = 0
	, @rowcount int
	, @InstanceDescription varchar(200)

CREATE TABLE #tempjobs (
	[SPID] [char](5),
	[Status] [varchar](250),
	[HostName] [nvarchar](150),
	[ProgramName] [varchar](250) NULL,
	[Command] [nvarchar](250),
	[CPUTime] [varchar](250),
	[DiskIO] [varchar](250),
	[memusage] bigint,
	[open_tran] smallint,
	[BlkBy] [varchar](150),
	[dbid] smallint,
	[Login] [nvarchar](250),
	[BatchStart] datetime,
	[ActiveSeconds] [int] NULL,
	[Duration] char(11) NULL,
	[DBName] [nvarchar](150) NULL,
	[Now] Datetime NULL
)

--Get default table name
SELECT @Now = Getdate(), @destination_table = 'WhoIsActive_' + CONVERT(VARCHAR, GETDATE(), 112), @spwhoDestination_table = 'dbops.dbo.' + @destination_table;

INSERT INTO #tempjobs ( SPID, Status, HostName, dbid, DBName, ProgramName, ActiveSeconds, Command, CPUTime,
	DiskIO, memusage, open_tran, BlkBy, Login, BatchStart, [Now] )
SELECT  spid, p.status, hostname, dbid, db_name(dbid), p.[program_name],
	datediff(second,req.start_time,getdate()), cmd, cpu, physical_io, memusage, open_tran, blocked,
	convert(sysname, rtrim(loginame)) as loginname, req.start_time, getdate()
FROM master.sys.sysprocesses p with (nolock)
JOIN sys.dm_exec_sessions s ON s.session_id = p.spid
OUTER APPLY
(
	SELECT TOP(1)
		CASE
			WHEN ( p.hostprocess > '' OR r.total_elapsed_time < 0 )
			THEN
				r.start_time
			ELSE
				DATEADD
				( ms, 1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())), 
					DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())
				)
		END AS start_time
	FROM sys.dm_exec_requests AS r
	WHERE
		r.session_id = p.spid
		AND r.request_id = p.request_id
) AS req
WHERE  s.is_user_process = 1
AND p.[program_name] NOT like 'SQLAgent%'
AND p.[program_name] NOT like 'SSIS-%'
AND p.[program_name] NOT like 'DatabaseMail%'
AND p.[program_name] <> 'TdService' --Azure health
AND req.start_time IS NOT NULL --Active spid
AND spid <> @@Spid
AND upper(cmd) NOT IN ('BRKR TASK', 'BACKUP DATABASE')
--AND lower(status) NOT IN ( 'sleeping', 'background','dormant')
--AND upper(cmd) NOT IN ('AWAITING COMMAND', 'MIRROR HANDLER', 'LAZY WRITER' ,'CHECKPOINT SLEEP', 'RA MANAGER', 'TASK MANAGER')

update t
set Duration = REPLACE(STR(ActiveSeconds/86400,2),' ','0')
	+ ':' + REPLACE(STR((ActiveSeconds%86400)/3600,2),' ','0')
	+ ':' + REPLACE(STR((ActiveSeconds%3600)/60,2),' ','0')
	+ ':' + REPLACE(STR((ActiveSeconds%60),2),' ','0')
	,DBName = CASE WHEN s.is_distributor = 1 Then 'Distribution' Else DBName END --In case DB name change.
from #tempjobs t
join master.sys.databases s on t.dbid = s.database_id

--Ignore replication related items and tasks under threshold @MaxMinutes
Delete #tempjobs
Where DBName = 'Distribution'
OR ((ISNULL(ActiveSeconds,600000) / 60.0) < @MaxMinutes)
--SQL 2012 diagnostic query looks like this
OR (ProgramName LIKE 'Microsoft_ Windows_ Operating System'
	and [login] = 'NT AUTHORITY\SYSTEM')
OR rtrim(ltrim([login])) = ''

--Select in case you are running interactively and getting a rowcount. < Not sure what this means so I'm keeping it in
If @@rowcount = 0
	Goto NoRows

--Ignore AWS running <x hours
Delete #tempjobs
Where [login] = 'prod_aws_replication'
and duration < '00:05:00:00'

Delete #tempjobs
Where [login] = 'Job.Scheduler'
and duration < '00:01:00:00'

select @rowcount = count(1) from #tempjobs

if @rowcount = 0
	Goto NoRows

------------------------------------------------------------------------
--Check for duplication of work on collecting current activity with job.
------------------------------------------------------------------------

--Does the activity table exist yet?
SET @dsql = N'IF EXISTS ( SELECT * FROM sys.tables  WHERE name = ''' + @destination_table + ''') Set @ActivityTableExists=1'
EXEC sp_executesql @dsql, N'@ActivityTableExists bit output', @ActivityTableExists = @ActivityTableExists OUTPUT

IF EXISTS (SELECT * FROM msdb.dbo.sysjobs_view WHERE name = N'DBA: Monitor Server Activity' AND enabled = 1)
	AND @ActivityTableExists = 1
BEGIN
	--Activity job exists, so let's see if it is running or ran recently. 
	DECLARE @currently_running_jobs TABLE (
		job_id UNIQUEIDENTIFIER NOT NULL
		,last_run_date INT NOT NULL
		,last_run_time INT NOT NULL
		,next_run_date INT NOT NULL
		,next_run_time INT NOT NULL
		,next_run_schedule_id INT NOT NULL
		,requested_to_run INT NOT NULL
		,request_source INT NOT NULL
		,request_source_id SYSNAME NULL
		,running INT NOT NULL
		,current_step INT NOT NULL
		,current_retry_attempt INT NOT NULL
		,job_state INT NOT NULL
		)

	--Find currently job activity:
	INSERT INTO @currently_running_jobs
	EXECUTE master.dbo.xp_sqlagent_enum_jobs 1,''

	--Is monitoring server activity job running? If so, don't kick off another instance of logging.
	IF NOT EXISTS (Select * from @currently_running_jobs t Join msdb.dbo.sysjobs j on t.job_id = j.job_id
					Where name = 'DBA: Monitor Server Activity' and job_state = 1)
	BEGIN
		--What was last time of activity capture?
		SET @dsql = N'SELECT @SecsDiff=DATEDIFF(ss,MAX(collection_time),getdate()) FROM ' + @destination_table
		EXEC sp_executesql @dsql, N'@SecsDiff int output', @SecsDiff = @SecondsSinceLastCollection OUTPUT
	END
	ELSE
		SET @SecondsSinceLastCollection = 100000

	--Is time since last activity collection less than duration of current issues (we captured it in logging)?
	IF EXISTS (SELECT * FROM #tempjobs WHERE @SecondsSinceLastCollection < --1500 secs example
			(SELECT MIN(ActiveSeconds) FROM #tempjobs) ) --1000 secs, then something is newer and we need to collect data.
		SET @LogActivity = 0
END

IF @LogActivity = 1
BEGIN
	EXEC master.dbo.sp_WhoIsActive @get_transaction_info = 1, @get_plans = 1, @RETURN_SCHEMA = 1, @SCHEMA = @schema OUTPUT ;

	SET @schema = 'IF OBJECT_ID('''+ @destination_table + ''', ''U'') IS NULL
	' + REPLACE(@schema, '<table_name>', @destination_table) ;

	EXEC(@schema) ;

	EXEC master.dbo.sp_WhoIsActive @get_transaction_info = 1, @get_plans = 1, @DESTINATION_TABLE = @spwhoDestination_table
END

select @InstanceDescription = dbops.dbo.udf_GetProcessParameter ('Admin','Instance Description')

SELECT @SubjectMsg = @InstanceDescription + ' has Long Running Queries Threshold(' + CONVERT(VARCHAR(6), @MaxMinutes) + ') Minutes'

SET @tableHTML =
    N'<table border="1" cellpadding="0" cellspacing="0">' +
    '<tr><th>SPID</th>' + '<th>HostName</th>' + '<th>DBName</th>' + '<th>Login</th>' + '<th>BlkBy</th>' + '<th>Duration (dd:hh:mm:ss)</th>' +
	'<th>Command</th>' + '<th>Status</th>' + '<th>BatchStart</th>' + '<th>ProgramName</th>' +
     CAST ( ( SELECT td = td.SPID, '',
					td = ISNULL(td.HostName,''), '',
					td = ISNULL(td.DBName,''), '',
					td = ISNULL(td.[Login],''), '',
					td = ISNULL(td.BlkBy,''), '',
					td = ISNULL(td.Duration,''), '',
					td = ISNULL(td.Command,''), '',
					td = ISNULL(td.[Status],''), '',
					td = ISNULL(CAST(td.BatchStart AS VARCHAR(20)),''), '', --Making it more readable (so the T isn't in middle).
					td = ISNULL(td.ProgramName,'')
  FROM #tempjobs td
  GROUP BY td.SPID,td.HostName,td.DBName,td.BlkBy,td.Duration,td.DBName,td.Command,td.[Status],td.BatchStart,td.ProgramName,td.[Login]
  FOR XML PATH('tr'), TYPE
) AS NVARCHAR(MAX) ) +
    N'</table><br /><p>Run this query to see more details:<p />'
		+ 'Select * from dbops.dbo.' + @destination_table
		+ ' Where Collection_Time >= ''' + CAST(@Now AS VARCHAR(20)) + ''''

EXEC prc_InternalSendMail
        @Address = @person_to_notify,
        @Subject = @SubjectMsg,
        @Body = @tableHTML,
        @HTML  = 1
GOTO Cleanup

NoRows:
PRINT 'There are no queries running for more than ' + CONVERT(VARCHAR(25),@MaxMinutes) + ' minutes.'

Cleanup:
DROP TABLE #tempjobs

END;
GO


