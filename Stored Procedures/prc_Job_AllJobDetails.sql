SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE dbo.prc_Job_AllJobDetails        
AS
BEGIN     
	SELECT --getdate() as CaptureDate, 
		sj.job_id, sj.name, CAST(ss.active_start_time / 10000 AS VARCHAR(10))           
		 + ':' + RIGHT('00' + CAST(ss.active_start_time % 10000 / 100 AS VARCHAR(10)), 2) AS active_start_time,           
		 dbops.dbo.udf_schedule_description(ss.freq_type, ss.freq_interval,          
		  ss.freq_subday_type, ss.freq_subday_interval, ss.freq_relative_interval,          
		  ss.freq_recurrence_factor, ss.active_start_date, ss.active_end_date,          
		  ss.active_start_time, ss.active_end_time) AS ScheduleDesc        
		 , sj.enabled     
		 , o.email_address as OperatorEmail
		 , o.enabled AS OperatorEnabled
		 , o.name as OperatorName
		 , CASE notify_level_eventlog 
			WHEN 0 THEN 'Never' WHEN 1 THEN 'Succeeds' 
			WHEN 2 THEN 'Fails' WHEN 3 THEN 'Completes' END AS Notify_Eventlog
		 , CASE notify_level_email  
			WHEN 0 THEN 'Never' WHEN 1 THEN 'Succeeds' 
			WHEN 2 THEN 'Fails' WHEN 3 THEN 'Completes' END Notify_Email
		 , CASE notify_level_netsend  
			WHEN 0 THEN 'Never' WHEN 1 THEN 'Succeeds' 
			WHEN 2 THEN 'Fails' WHEN 3 THEN 'Completes' END AS Notify_Netsend
		 , CASE notify_level_page  
			WHEN 0 THEN 'Never' WHEN 1 THEN 'Succeeds' 
			WHEN 2 THEN 'Fails' WHEN 3 THEN 'Completes' END AS Notify_Pager 
	FROM msdb.dbo.sysjobs sj (nolock)        
	LEFT JOIN  msdb.dbo.sysjobschedules sjs (nolock) ON sj.job_id = sjs.job_id         
	LEFT JOIN  msdb.dbo.sysschedules ss (nolock) ON sjs.schedule_id = ss.schedule_id   
	LEFT JOIN  msdb.dbo.sysoperators o (nolock) on sj.notify_email_operator_id = o.id        
	ORDER BY sj.NAME    
END;
;
GO
