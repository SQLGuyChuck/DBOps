USE [msdb]
GO

Declare @jobexists bit
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'DBA: Monitor Blocking')
BEGIN
	Set @jobexists = 1
	GOTO EndSave
END

DECLARE @ReturnCode INT, @ServerName varchar(100)
SELECT @ReturnCode = 0, @ServerName = @@Servername

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'DBA Monitoring' AND category_class=1)
BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @name=N'DBA Monitoring'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

BEGIN TRANSACTION
DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Monitor Blocking', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Monitor for blocking and log to dbops.dbo.BlockingMonitorHistory table.', 
		@category_name=N'Database Monitoring', 
		@owner_login_name=N'sa',
		@notify_email_operator_name=N'IT Ops', 
		@job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Monitor Blocking', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Declare @Blockingms varchar(7), @EscalationEmail varchar(200)
select @Blockingms=dbops.dbo.udf_GetProcessParameter (''Admin'',''Blocking Threshold (ms)''),
	 @EscalationEmail=dbops.dbo.udf_GetProcessParameter (''Admin'',''IT Ops Team Escalation'')

IF EXISTS (select spid from master.dbo.sysprocesses with (nolock) 
	where blocked > 0 and waittime >= @Blockingms and spid <> blocked)
Begin
	declare @maxident int, @subjectMsg varchar(50), @tableHTML varchar(500)

	select @maxident = max(ident) from dbo.BlockingMonitorHistory

	exec master.dbo.sp_lockinfo @preserve =1 

	select @subjectMsg = ''Blocking in '' + @@servername 
	select @tableHTML = ''Threshold is '' + @Blockingms + '' ms. To see all that was running during blocking capture, please run this query:</p>''  + 
					+ ''<p>SELECT * FROM DBOPS.dbo.BlockingMonitorHistory <br />'' + 
					+ ''WHERE ident >'' + convert(varchar(25),isnull(@maxident,0))
					+ ''</p><p>For more info on the data in the table, see this site: http://www.sommarskog.se/sqlutil/beta_lockinfo.html</p>''  

	EXEC dbops.dbo.prc_InternalSendMail       
			@Address = @EscalationEmail,      
			@Subject = @SubjectMsg,        
			@Body = @tableHTML, 
			@HTML  = 1

end
', 
		@database_name=N'DBOPS', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Monitor Blocking', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=30, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20081007, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @ServerName
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION

EndSave:
If @jobexists = 1
	Print 'Job DBA: Monitor Blocking exists, so skipping' 
GO
