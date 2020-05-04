USE [DBOPS]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_Perf_JobOutliers]
    @HistoryStartDate DATETIME  = NULL --How far back in time of SQL Agent History do you want to use?
	,@HistoryEndDate DATETIME    = NULL
	,@MinHistExecutions INT      = 3
	,@MinAvgSecsDuration INT     = 30
	,@person_to_notify VARCHAR(1000) = NULL
AS
BEGIN

/******************************************************************************
**    Name: prc_Perf_JobOutliers
**
**    Returns: One result set containing a list of jobs that are currently running
**		and are running longer than two standard deviations away from their historical average. 
**		http://thomaslarock.com/2012/10/how-to-find-currently-running-long-sql-agent-jobs/
**
*******************************************************************************
**          Change History
*******************************************************************************
**  Date:       Author:         Description:
**	8/15/2013	Chuck Lathrope	Created
**  8/16/2013	Chuck Lathrope	Bug fix on duration value and removed AND secs_duration > AvgPlus2StDev
**  8/19/2013	Chuck Lathrope	Removed jobstep history as SQL doesn't provide current time to current step.
**								Added dbops.dbo.LongRunningJobIgnoreList
**  9/5/2013	Chuck Lathrope	Added StepName to LongRunningJobIgnoreList lookup.
**  9/6/2013	Chuck Lathrope  Bug fix for 8/19 fix. Need to limit to full job timing.
**  1/20/2016   Chuck Lathrope  Limit to most recent MSDB job history session as hanging jobs from last
**								restart will report as never completing.
**  07/31/2019	Michael C		Changed sysjobhistory to sysjobhistoryall
**  10/22/2018  Michael C		Changed Updated to use Instance Description process parameter in subject line
******************************************************************************/
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @tableHTML  NVARCHAR(MAX)
		, @subjectMsg varchar(75)
		,@InstanceDescription varchar(200)

IF @person_to_notify is null
BEGIN
	SELECT @person_to_notify = ParameterValue --Select *
	FROM dbops.dbo.ProcessParameter 
	where ParameterName = 'IT Ops Team Escalation'
END

select @InstanceDescription = dbops.dbo.udf_GetProcessParameter ('Admin','Instance Description')

SELECT @subjectMsg = @InstanceDescription + ' has job(s) running longer than average.'

IF @HistoryStartDate IS NULL SET @HistoryStartDate='19000101' ;
IF @HistoryEndDate IS NULL SET @HistoryEndDate=GETDATE() ;

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

--capture details on current job status
INSERT INTO @currently_running_jobs
EXECUTE master.dbo.xp_sqlagent_enum_jobs 1,''


;WITH sysja AS (
	SELECT sja.session_id,
		   sja.job_id,
		   sja.start_execution_date,
		   sja.last_executed_step_id,
		   sja.last_executed_step_date,
		   sja.stop_execution_date
	FROM msdb.dbo.sysjobactivity sja
	JOIN (SELECT MAX(session_id) AS session_id FROM msdb.dbo.syssessions) s ON s.session_id = sja.session_id
	)
, JobHistData AS
    (  
		SELECT jh.job_id
            ,date_executed=msdb.dbo.agent_datetime(run_date, run_time)
            ,secs_duration=run_duration/10000.0*3600+run_duration%10000/100.0*60+run_duration%100
        FROM msdb.dbo.sysjobhistoryall jh
		JOIN msdb.dbo.sysjobs j ON j.job_id = jh.job_id  
		JOIN msdb.dbo.syscategories sc ON sc.category_id = j.category_id  
			AND sc.name NOT LIKE 'REPL-%' --Ignore replication as these are typically continuous
        WHERE step_id=0 --Full job timing.
            AND run_status=1  --Succeeded
    )
     ,JobHistStats AS
    (
		SELECT job_id
            ,AvgDuration=AVG(secs_duration)
            ,AvgPlus2StDev=AVG(secs_duration)+2*STDEVP(secs_duration)
        FROM JobHistData
		WHERE date_executed >= DATEADD(DAY, DATEDIFF(DAY,'19000101',@HistoryStartDate),'19000101')
			AND date_executed < DATEADD(DAY, 1 + DATEDIFF(DAY,'19000101',@HistoryEndDate),'19000101')   
		GROUP BY job_id
		HAVING COUNT(*) >= @MinHistExecutions
			AND AVG(secs_duration*1.) >= @MinAvgSecsDuration
	)
    SELECT @tableHTML =      
		N'<table border="1" cellpadding="0" cellspacing="0">' + '<tr>' + 
		'<th>Job Name</th>' +      
		'<th>Current Step</th>' + 
		'<th>Start Time</th>' + 
		'<th>Duration (min)</th>' + 
		'<th>Avg Duration (min)</th>' + 
		'<th>Threshhold (min)</th></tr>' +      
		CAST ( ( SELECT td = j.name, '',
				td = 'Step ' + CAST(crj.current_step AS VARCHAR(2)) + ': ' + s.step_name, '',
				td=CAST(MAX(act.start_execution_date) AS VARCHAR(20)),'',
				td=CAST(DATEDIFF(mi, act.start_execution_date, GETDATE()) AS INT),'',
				td=CAST(AvgDuration/60 AS INT),'',
				td=CAST(AvgPlus2StDev/60 AS INT)
	FROM JobHistData jd
	JOIN JobHistStats jhs ON jd.job_id = jhs.job_id
	JOIN msdb.dbo.sysjobs j ON jd.job_id = j.job_id
	JOIN msdb.dbo.sysjobsteps s ON jd.job_id=s.job_id
	JOIN @currently_running_jobs crj ON crj.job_id = jd.job_id AND crj.current_step = s.step_id
	JOIN sysja AS act ON act.job_id = jd.job_id
		AND act.stop_execution_date IS NULL
		AND act.start_execution_date IS NOT NULL
		--Should be not needed with latest fix: AND start_execution_date > GETDATE()-2 --Factor of safety for orphaned jobs.
	WHERE DATEDIFF(SS, act.start_execution_date, GETDATE()) > AvgPlus2StDev
	AND crj.job_state = 1
	AND NOT EXISTS (SELECT * FROM dbo.LongRunningJobIgnoreList list WHERE j.Name = list.JobName AND ISNULL(list.StepName,s.step_name) = s.step_name
					AND (MinutesToIgnore = -1 OR DATEDIFF(mi, act.start_execution_date, GETDATE()) < MinutesToIgnore))
	GROUP BY j.name, 'Step ' + CAST(crj.current_step AS VARCHAR(2)) + ': ' + s.step_name
		, DATEDIFF(mi, act.start_execution_date, GETDATE()), AvgDuration, AvgPlus2StDev
	ORDER BY j.name    
	FOR XML PATH('tr'), TYPE       
	) AS NVARCHAR(MAX) )   
+ N'</table>' ;  

IF @tableHTML IS NOT NULL
EXEC prc_InternalSendMail         
        @Address = @person_to_notify,
        @Subject = @subjectMsg,          
        @Body = @tableHTML,   
        @HTML  = 1  
END

GO


