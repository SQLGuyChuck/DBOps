SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Job_AllJobSteps
as
BEGIN
	SELECT --cast(getdate() as datetime) as CaptureDate,
	sj.job_id
	,sj.name as Job_name
	,sj.enabled as Job_Enabled
	,steps.step_uid
	,steps.step_id
	,steps.subsystem
	,steps.step_name
	,steps.database_name as step_database_name
	,steps.Output_file_name as Step_output_file_name
	,steps.command, 
	cast('1/1/1900 ' + CAST(ss.active_start_time / 10000 AS VARCHAR(10)) + ':' +
		RIGHT('00' + CAST(ss.active_start_time % 10000 / 100 AS VARCHAR(10)), 2) as datetime) AS active_start_time, 
	dbo.udf_schedule_description(ss.freq_type, ss.freq_interval, 
	ss.freq_subday_type, ss.freq_subday_interval, ss.freq_relative_interval, 
	ss.freq_recurrence_factor, ss.active_start_date, ss.active_end_date, 
	ss.active_start_time, ss.active_end_time) AS ScheduleDesc 
	FROM msdb.dbo.sysjobs sj (nolock) 
	left JOIN msdb.dbo.sysjobschedules sjs (nolock) ON sj.job_id = sjs.job_id 
	left JOIN msdb.dbo.sysschedules ss (nolock) ON sjs.schedule_id = ss.schedule_id 
	JOIN master.dbo.sysservers s (nolock) ON s.srvid = Sj.originating_server_id 
	JOIN msdb.dbo.sysjobsteps steps (nolock)ON sj.job_id=steps.job_id 
END
;
GO
