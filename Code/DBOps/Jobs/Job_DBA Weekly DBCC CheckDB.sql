USE [msdb]
GO

Declare @jobexists bit
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'DBA: Weekly DBCC CheckDB')
BEGIN
	Set @jobexists = 1
	GOTO EndSave
END

DECLARE @ReturnCode INT, @ServerName varchar(100)
SELECT @ReturnCode = 0, @ServerName = @@Servername

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @name=N'Database Maintenance'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

BEGIN TRANSACTION
DECLARE @jobId BINARY(16)
EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name=N'DBA: Weekly DBCC CheckDB', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Runs DBCC CHECKDB against all databases except model.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'IT Ops', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Run DBCC checkdb on all databases', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON

DECLARE  @UpdateUsageCount int
        , @RepairItemsFound int 
        , @Body varchar(max)
        , @Success bit
        , @Address varchar(50)
        , @MailSubject nvarchar(255)

Set @RepairItemsFound = ''''
Set @Address = ''databasealerts@YourDomainHere.com''
 
DECLARE database_cursor CURSOR FORWARD_ONLY FOR 
	SELECT name 
	FROM master.sys.databases s
	Left JOIN (Select DBID, max(InsertDate) as InsertDate
				From DBCCHistory
				Group by DBID
				) h on h.dbid = s.database_id
	WHERE name NOT in (''model'')
	AND name not like ''%backup%''
	AND DATABASEPROPERTYEX(name, ''Status'') = ''Online''
	AND DATABASEPROPERTYEx(name, ''IsInStandBy'') = 0
	AND s.source_database_id IS NULL
	order by h.insertdate, name
				
DECLARE @database_name sysname
	OPEN database_cursor 
	FETCH NEXT FROM database_cursor INTO @database_name
	WHILE @@FETCH_STATUS=0

	BEGIN
 		Print ''Next DB: '' + @database_name
 		
		Truncate table DBCCResults  

		IF (SERVERPROPERTY(''productversion'') < ''11.0%'')
		BEGIN
			INSERT INTO DBCCResults (	
				Error, 
				Level, 
				State, 
				MessageText, 
				RepairLevel,
				Status,
				DbId, 
				ObjectId, 
				IndexId, 
				PartitionID,
				AllocUnitID, 
				[File], 
				Page, 
				Slot, 
				RefFile,
				RefPage,
				RefSlot,
				Allocation)
      
			EXEC (''DBCC CHECKDB('' + '''''''' + @database_name + '''''''' + '') WITH TABLERESULTS, DATA_PURITY'')
		END
		ELSE
		BEGIN
			INSERT INTO DBCCResults (	
				Error,
				Level,
				State,
				MessageText,
				RepairLevel,
				Status,
				DbId,
				DbFragId,
				ObjectId,
				IndexId,
				PartitionID,
				AllocUnitID,
				RidDbId,
				RidPruId,
				[File],
				Page,
				Slot,
				RefDbId,
				RefPruId,
				RefFile,
				RefPage,
				RefSlot,
				Allocation)
      
			EXEC (''DBCC CHECKDB('' + '''''''' + @database_name + '''''''' + '') WITH TABLERESULTS, DATA_PURITY'')
		END

		SELECT @RepairItemsFound = count(*)
		FROM DBCCResults 
		WHERE RepairLevel is not null

		SELECT @UpdateUsageCount = count(*) 
		FROM DBCCResults
		WHERE MessageText like ''%Run DBCC UPDATEUSAGE%''

		IF @UpdateUsageCount > 0
		BEGIN
			PRINT ''Updating usage on database: '' + @database_name
			EXEC (''DBCC UPDATEUSAGE('' + '''''''' + @database_name + '''''''' + '')'')
		END

		If @RepairItemsFound > 0
		BEGIN
			IF (SERVERPROPERTY(''productversion'') >= ''11.0%'')
			BEGIN
				INSERT INTO DBCCHistory (
					DBName,
					Error,
					Level,
					State,
					MessageText,
					RepairLevel,
					Status,
					DbId,
					DbFragId,
					ObjectId,
					IndexId,
					PartitionID,
					AllocUnitID,
					RidDbId,
					RidPruId,
					[File],
					Page,
					Slot,
					RefDbId,
					RefPruId,
					RefFile,
					RefPage,
					RefSlot,
					Allocation)
				SELECT @database_name,
					Error, Level, State, MessageText, RepairLevel, Status, DbId, DbFragId, ObjectId, IndexId,
					PartitionID, AllocUnitID, RidDbId, RidPruId, [File], Page, Slot, RefDbId,
					RefPruId, RefFile, RefPage, RefSlot, Allocation 
				FROM DBCCResults 
				WHERE RepairLevel is not null
			END
			ELSE
			BEGIN
				INSERT INTO DBCCHistory (
					DBName,
					Error,
					Level,
					State, 
					MessageText,
					RepairLevel,
					Status, 
					DbId, 
					ObjectId, 
					IndexId, 
					PartitionID,
					AllocUnitID,
					[File], 
					Page, 
					Slot, 
					RefFile, 
					RefPage, 
					RefSlot, 
					Allocation)
				SELECT @database_name,
					Error, Level, State, MessageText, RepairLevel, Status, DbId, ObjectId, IndexId,
					PartitionID, AllocUnitID, [File], Page, Slot, RefFile, RefPage, RefSlot, Allocation 
				FROM DBCCResults 
				WHERE RepairLevel is not null
			END
		End
		ELSE
		BEGIN
			INSERT INTO DBCCHistory (
				DbId, 
				DBName,
				MessageText)
			SELECT top 1 DBID, @database_name, ''All Good''
			FROM DBCCResults 
		END
      
		Set @Body = Coalesce(''Found '' + cast(@RepairItemsFound as varchar(4)) + '' item(s) needing repair. See table DBCCHistory for details.'' + Char(13) + Char(10),Char(13) + Char(10) + ''No repair issues found.'') 
		Set @MailSubject = ''DBCC CHECKDB found errors on Database: '' + @database_name

		IF (@RepairItemsFound > 0)
		BEGIN
			exec prc_internalsendmail @Address = @Address,    
			@Subject = @MailSubject,
			@Body = @Body,
			@HighPriority = 1,
			@Success = @Success Output
		END 

		Set @RepairItemsFound = NULL
		Set @UpdateUsageCount = NULL
		fetch next from database_cursor into @database_name
end

close database_cursor
deallocate database_cursor
', 
		@database_name=N'DBOPS', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'DBA: DBCC checkdb', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=64, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20100913, 
		@active_end_date=99991231, 
		@active_start_time=93000, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @servername
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
If @jobexists = 1
	Print 'Job DBA: Weekly DBCC CheckDB exists, so skipping' 
GO


