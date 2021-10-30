USE [DBOPS]
GO
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
USE:
select * from dbo.DBA_List_of_Currently_Running_SQLJobs where job_name = 'DBA: Trickle Delete' 

*/

CREATE OR ALTER VIEW [dbo].[DBA_List_of_Currently_Running_SQLJobs]
AS

SELECT TOP (100) PERCENT ja.job_id,
    job.name AS job_name,
    ja.start_execution_date,      
    ISNULL(last_executed_step_id,0)+1 AS current_executed_step_id,
    Js.step_name
FROM msdb.dbo.sysjobs_view job
JOIN msdb.dbo.sysjobactivity ja ON job.job_id = ja.job_id
JOIN msdb.dbo.sysjobsteps js ON ja.job_id = js.job_id
    AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
JOIN msdb.dbo.syssessions sess ON sess.session_id = ja.session_id
JOIN (
    SELECT MAX( agent_start_date ) AS max_agent_start_date
    FROM msdb.dbo.syssessions
	) sess_max ON sess.agent_start_date = sess_max.max_agent_start_date
WHERE 
    run_requested_date IS NOT NULL 
	AND stop_execution_date IS NULL


GO


