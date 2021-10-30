USE [msdb]
GO
Declare @jobexists bit
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'DBA: Purge DBOPS Tables')
BEGIN
	Set @jobexists = 1
	GOTO EndSave
END

DECLARE @ReturnCode INT, @ServerName varchar(100)
SELECT @ReturnCode = 0, @ServerName = @@Servername

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'DBA Stats' AND category_class=1)
BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @name=N'DBA Stats'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

BEGIN TRANSACTION

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Purge DBOPS Tables', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Purge out old DBOPS logging tables.', 
		@category_name=N'DBA Stats', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'IT Ops', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge whoisactive tables', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @DropStatement VARCHAR(1000);

DECLARE TableDrop CURSOR FORWARD_ONLY
FOR
SELECT	''drop table '' + name
FROM	sys.tables
WHERE	RIGHT(name, 8) < CONVERT(VARCHAR(8), GETDATE() - 60, 112)
		AND name LIKE ''whoisactive_%''; 

OPEN TableDrop;
FETCH NEXT FROM TableDrop INTO @DropStatement;
WHILE (@@fetch_status = 0)
BEGIN

	EXEC (@DropStatement);   
	FETCH NEXT FROM TableDrop INTO @DropStatement;

END; 

CLOSE  TableDrop;
DEALLOCATE TableDrop;

', 
		@database_name=N'DBOPS', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'DBA: Purge tables', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=64, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20150722, 
		@active_end_date=99991231, 
		@active_start_time=210000, 
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
	Print 'Job DBA: Purge DBOPS Tables exists, so skipping' 
GO

