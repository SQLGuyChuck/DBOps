USE [msdb]
GO

Declare @jobexists bit
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'DBA: Log Proc Execution Stats')
BEGIN
	Set @jobexists = 1
	GOTO EndSave
END

DECLARE @ReturnCode INT, @ServerName varchar(100)
SELECT @ReturnCode = 0, @ServerName = @@Servername

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'DBA Monitoring' AND category_class=1)
BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'DBA Monitoring'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

BEGIN TRANSACTION

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA: Log Proc Execution Stats', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This proc logs the execution stats of all procedures', 
		@category_name=N'DBA Monitoring', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Log Proc Stats', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY(''PRODUCTVERSION'') AS VARCHAR), 1, 2), ''.'', '''') AS TINYINT) > 10
BEGIN
	IF EXISTS (SELECT d.database_id
			FROM sys.databases d 
			LEFT JOIN sys.availability_replicas AS AR
				ON d.replica_id = ar.replica_id
			LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
				ON ars.group_id = AR.group_id AND ars.replica_id = ar.replica_id
			LEFT JOIN sys.dm_hadr_database_replica_cluster_states AS dbcs
				ON ars.replica_id = dbcs.replica_id and d.replica_id = dbcs.replica_id AND d.group_database_id = dbcs.group_database_id
			WHERE DATABASEPROPERTYEX([name], ''status'') = ''ONLINE''  
			AND ars.role = 1)

		EXEC prc_Perf_ProcExecutionStats
END
ELSE
	EXEC prc_Perf_ProcExecutionStats', 
		@database_name=N'dbops', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Proc Stats', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20090820, 
		@active_end_date=99991231, 
		@active_start_time=100, 
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
	Print 'Job DBA: Log Proc Execution Stats exists, so skipping' 
GO

