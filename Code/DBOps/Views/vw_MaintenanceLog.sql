USE [msdb]
GO

IF NOT EXISTS(SELECT [object_id] FROM sys.views WHERE [name] = 'vw_MaintenanceLog')
Exec ('Create view vw_MaintenanceLog as Select ''Empty view'' as temp')
go
ALTER VIEW vw_MaintenanceLog AS
SELECT [name]
	,[step_name]
    ,(SELECT [log] AS [text()] FROM [msdb].[dbo].[sysjobstepslogs] sjsl2 WHERE sjsl2.log_id = sjsl.log_id FOR XML PATH(''), TYPE) AS 'Log'
	,sjsl.[date_created]
    ,sjsl.[date_modified]
    ,[log_size]
FROM [msdb].[dbo].[sysjobstepslogs] sjsl
INNER JOIN [msdb].[dbo].[sysjobsteps] sjs ON sjs.[step_uid] = sjsl.[step_uid]
INNER JOIN [msdb].[dbo].[sysjobs] sj ON sj.[job_id] = sjs.[job_id]
WHERE [name] = 'DBA: Weekly Maintenance';
GO
