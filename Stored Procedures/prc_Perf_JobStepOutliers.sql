USE [DBOPS]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_Perf_JobStepOutliers]
    @HistoryStartDate DATETIME  = NULL --How far back in time of SQL Agent History do you want to use?
	,@HistoryEndDate DATETIME    = NULL
	,@MinHistExecutions INT      = 3
	,@MinAvgSecsDuration INT     = 30
	,@NotificationEmail VARCHAR(1000) = NULL
AS
BEGIN
/******************************************************************************
**    Name: prc_Perf_JobStepOutliers
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
**  9/6/2013	Chuck Lathrope  Found way to go back to jobstep outliers. Renamed for flexibility.
**  07/31/2019	Michael C		Changed sysjobhistory to sysjobhistoryall
******************************************************************************/
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @tableHTML  NVARCHAR(MAX)
		, @subjectMsg VARCHAR(75)

IF @NotificationEmail is null
BEGIN
	SELECT @NotificationEmail = COALESCE(ParameterValue,'alerts@YourDomainNameHere.com') --Select *
	FROM dbo.ProcessParameter 
	WHERE ParameterName = 'IT Ops Team Escalation'
END

SELECT @subjectMsg = cast(@@ServerName as varchar(100)) + ' has job(s) running longer than average.'

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

;WITH JobHistData AS
    (  
		SELECT jh.job_id
            ,step_id
            ,date_executed=msdb.dbo.agent_datetime(run_date, run_time)
            ,secs_duration=run_duration/10000.0*3600+run_duration%10000/100.0*60+run_duration%100
        FROM msdb.dbo.sysjobhistoryall jh
		JOIN msdb.dbo.sysjobs j ON j.job_id = jh.job_id  
		JOIN msdb.dbo.syscategories sc ON sc.category_id = j.category_id  
			AND sc.name NOT LIKE 'REPL-%' --Ignore replication as these are typically continuous
        WHERE step_id<>0
            AND run_status=1  --Succeeded
    )
     ,JobHistStats AS
    (
		SELECT job_id
            ,step_id
            ,AvgStepDuration=AVG(secs_duration*1.)
            ,AvgStepPlus2StDev=AVG(secs_duration*1.)+2*STDEVP(secs_duration)
        FROM JobHistData
		WHERE date_executed >= DATEADD(DAY, DATEDIFF(DAY,'19000101',@HistoryStartDate),'19000101')
			AND date_executed < DATEADD(DAY, 1 + DATEDIFF(DAY,'19000101',@HistoryEndDate),'19000101')   
		GROUP BY job_id,step_id
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
				td=CAST(act.start_execution_date AS VARCHAR(20)),'',
				td=CAST(DATEDIFF(SS, act.start_execution_date, GETDATE()) - ISNULL(SUM(secs_duration),0) AS INT),'',
				td=CAST(AvgStepDuration/60 AS INT),'',
				td=CAST(AvgStepPlus2StDev/60 AS INT)
	FROM msdb.dbo.sysjobs j
	JOIN msdb.dbo.syscategories sc ON sc.category_id = j.category_id  
		AND sc.name NOT LIKE 'REPL-%' --Ignore replication as these are typically continuous
	JOIN msdb.dbo.sysjobsteps s ON j.job_id=s.job_id
	JOIN @currently_running_jobs crj ON crj.job_id = j.job_id
	JOIN (SELECT job_id, MAX(start_execution_date) AS start_execution_date 
			FROM msdb.dbo.sysjobactivity 
			WHERE stop_execution_date IS NULL
				AND start_execution_date IS NOT NULL
				AND start_execution_date > GETDATE()-2 --Factor of safety for orphaned jobs. 
			GROUP BY Job_id 			) AS act ON act.job_id = j.job_id
	LEFT JOIN JobHistData job ON job.job_id = j.job_id AND job.date_executed >= act.start_execution_date 
		--Used to get logged total time of job. .job increments with start of a new step.
		--Left join b/c first step will not have preceeded data of course.
	LEFT JOIN JobHistStats jd ON jd.job_id = j.job_id AND jd.step_id=s.step_id AND jd.step_id = crj.current_step
		--Left join b/c we could have new job steps with not enough history on them. Null values eliminated with Having clause.
	WHERE crj.job_state = 1
	GROUP BY j.name,s.step_name,crj.current_step,act.start_execution_date
		,jd.step_id,jd.AvgStepDuration,jd.AvgStepPlus2StDev
	HAVING DATEDIFF(SS, act.start_execution_date, GETDATE()) - ISNULL(SUM(secs_duration),0) > AvgStepPlus2StDev
	ORDER BY j.name
	FOR XML PATH('tr'), TYPE       
	) AS NVARCHAR(MAX) )   
+ N'</table>' ;  

IF @tableHTML IS NOT NULL
EXEC prc_InternalSendMail         
        @Address = @NotificationEmail,
        @Subject = @subjectMsg,          
        @Body = @tableHTML,   
        @HTML  = 1  

END
;
GO


