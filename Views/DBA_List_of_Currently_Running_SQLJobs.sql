USE [DBOPS]
GO
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
uSE:
select * from dbo.DBA_List_of_Currently_Running_SQLJobs where job_name = 'DBA: Trickle Delete' 

*/

CREATE OR ALTER VIEW [dbo].[DBA_List_of_Currently_Running_SQLJobs]
AS

SELECT TOP 100 PERCENT ja.job_id,
    j.name AS job_name,
    ja.start_execution_date,      
    ISNULL(last_executed_step_id,0)+1 AS current_executed_step_id,
    Js.step_name
FROM msdb.dbo.sysjobactivity ja 
LEFT JOIN msdb.dbo.sysjobhistoryall jh ON ja.job_history_id = jh.instance_id
JOIN msdb.dbo.sysjobs j ON ja.job_id = j.job_id
JOIN msdb.dbo.sysjobsteps js
    ON ja.job_id = js.job_id
    AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC  )
AND start_execution_date IS NOT NULL
AND stop_execution_date IS NULL


GO


