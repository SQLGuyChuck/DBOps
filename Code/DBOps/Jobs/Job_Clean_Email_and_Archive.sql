USE [msdb]
GO
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'DBA: Archive - DB Mail')
EXEC msdb.dbo.sp_delete_job @job_name=N'DBA: Archive - DB Mail', @delete_unused_schedule=1
GO
/****** Object:  Job [DBA: Archive - DB Mail]    Script Date: 10/07/2009 10:12:09 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 10/07/2009 10:12:09 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Archive - DB Mail', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Archive mail log]    Script Date: 10/07/2009 10:12:10 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Archive mail log', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'use dbops
--Mail archiving and purging.
--Archiving old email:
DECLARE @LastMonth nvarchar(12);
DECLARE @CopyDate nvarchar(20) ;
DECLARE @CreateTable nvarchar(250) ;
SET @LastMonth = (SELECT CAST(DATEPART(yyyy,GETDATE()) AS CHAR(4)) + ''_'' + CAST(DATEPART(mm,GETDATE())-1 AS varchar(2))) ;
SET @CopyDate = (SELECT CAST(CONVERT(char(8), CURRENT_TIMESTAMP- DATEPART(dd,GETDATE()-1), 112) AS datetime))
SET @CreateTable = ''SELECT * INTO DBOPS.dbo.[DBMailArchive_'' + @LastMonth + ''] FROM msdb.dbo.sysmail_allitems WHERE send_request_date < '''''' + @CopyDate +'''''''';
EXEC sp_executesql @CreateTable ;


--DECLARE @LastMonth nvarchar(12);
--DECLARE @CopyDate nvarchar(20) ;
--DECLARE @CreateTable nvarchar(250) ;
SET @LastMonth = (SELECT CAST(DATEPART(yyyy,GETDATE()) AS CHAR(4)) + ''_'' + CAST(DATEPART(mm,GETDATE())-1 AS varchar(2))) ;
SET @CopyDate = (SELECT CAST(CONVERT(char(8), CURRENT_TIMESTAMP- DATEPART(dd,GETDATE()-1), 112) AS datetime))
SET @CreateTable = ''SELECT * INTO DBOPS.dbo.[DBMailArchive_Attachments_'' + @LastMonth + ''] FROM msdb.dbo.sysmail_attachments 
 WHERE mailitem_id in (SELECT DISTINCT mailitem_id FROM [DBMailArchive_'' + @LastMonth + ''] )'';
EXEC sp_executesql @CreateTable ;

--DECLARE @LastMonth nvarchar(12);
--DECLARE @CopyDate nvarchar(20) ;
--DECLARE @CreateTable nvarchar(250) ;
SET @LastMonth = (SELECT CAST(DATEPART(yyyy,GETDATE()) AS CHAR(4)) + ''_'' + CAST(DATEPART(mm,GETDATE())-1 AS varchar(2))) ;
SET @CopyDate = (SELECT CAST(CONVERT(char(8), CURRENT_TIMESTAMP- DATEPART(dd,GETDATE()-1), 112) AS datetime))
SET @CreateTable = ''SELECT * INTO DBOPS.dbo.[DBMailArchive_Log_'' + @LastMonth + ''] FROM msdb.dbo.sysmail_Event_Log 
 WHERE mailitem_id in (SELECT DISTINCT mailitem_id FROM [DBMailArchive_'' + @LastMonth + ''] )'';
EXEC sp_executesql @CreateTable ;


--Delete all mail previous to yesterday.
--DECLARE @CopyDate nvarchar(20) ;
SET @CopyDate = (SELECT CAST(CONVERT(char(8), CURRENT_TIMESTAMP- DATEPART(dd,GETDATE()-1), 112) AS datetime)) ;
EXECUTE msdb.dbo.sysmail_delete_mailitems_sp @sent_before = @CopyDate ;
--
--DECLARE @CopyDate nvarchar(20) ;
SET @CopyDate = (SELECT CAST(CONVERT(char(8), CURRENT_TIMESTAMP- DATEPART(dd,GETDATE()-1), 112) AS datetime)) ;
EXECUTE msdb.dbo.sysmail_delete_log_sp @logged_before = @CopyDate ;


', 
		@database_name=N'msdb', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Monthly Once', 
		@enabled=1, 
		@freq_type=16, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20081103, 
		@active_end_date=99991231, 
		@active_start_time=10500, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO
