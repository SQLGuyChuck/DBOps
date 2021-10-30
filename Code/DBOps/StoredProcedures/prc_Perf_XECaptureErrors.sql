IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'prc_Perf_XECaptureErrors' And ROUTINE_SCHEMA = 'dbo')
BEGIN
	EXEC('CREATE Procedure dbo.prc_Perf_XECaptureErrors  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.prc_Perf_XECaptureErrors.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.prc_Perf_XECaptureErrors.'
	END
END
GO

ALTER procedure dbo.prc_Perf_XECaptureErrors 
(
	@Action					VARCHAR(254)		--START, STOP, ANALYZE
	,@Severityge			INT	= 16			--captures errors with severities greater than or equal to the param
)
AS  
BEGIN
	/*
		See documentation at: http://www.davewentzel.com/content/why-isnt-my-java-catching-sql-errorsorhow-i-learned-stop-worrying-and-love-ringbuffer-target

		EXEC dbo.prc_Perf_XECaptureErrors 'START', 11
		EXEC dbo.prc_Perf_XECaptureErrors 'STOP'
		EXEC dbo.prc_Perf_XECaptureErrors 'ANALYZE'

	*/

	IF @Action NOT IN ('START','STOP','ANALYZE')
	BEGIN
		RAISERROR ('Not a valid @Action param.',16,1);
		RETURN 1;
	END;

	IF @Action IN ('START','STOP')
	BEGIN
		--first, drop the session if it exists.  No need to stop it first
		IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='XECaptureErrors')
		BEGIN
			DROP EVENT SESSION [XECaptureErrors] ON SERVER;
		END
	END;

	IF @Action IN ('START')
	BEGIN
		--create the session.  You can't use variables in CREATE EVENT SESSION statements so we 
		--need to create dynamic sql due to @Severityge
		DECLARE @exec_str VARCHAR(4000);
		SELECT @exec_str = '
		CREATE EVENT SESSION [XECaptureErrors] ON SERVER 
		ADD EVENT sqlserver.error_reported 
			( 
				ACTION    (
								package0.collect_system_time,
								package0.last_error,
								sqlserver.client_app_name,
								sqlserver.client_hostname,
								sqlserver.database_name,
								sqlserver.nt_username,
								sqlserver.username,
								sqlserver.plan_handle,
								sqlserver.query_hash,
								sqlserver.session_id,
								sqlserver.sql_text,
								sqlserver.tsql_frame,
								sqlserver.tsql_stack
							)
				WHERE    ([severity] >= ' + convert(varchar(4000),@Severityge) + ')   
			) 
		ADD TARGET package0.ring_buffer (SET max_memory = 4096) 
		WITH 
			(        
				STARTUP_STATE=OFF ,
				max_dispatch_latency = 1 seconds
			) 
		;';
		--PRINT @exec_str
		EXEC (@exec_str)	

		--Start it
		ALTER EVENT SESSION XECaptureErrors ON SERVER STATE = start

		PRINT 'Running.  Please remember to run EXEC dbo.prc_Perf_XECaptureErrors ''STOP'''
		RETURN 0;
	END;

	IF @Action IN ('ANALYZE')
	BEGIN
		CREATE TABLE #RawXML (TargetData xml);
		CREATE TABLE #EventList (EventObjId BIGINT, EventName varchar(100),TimeStamp datetimeoffset, TargetData xml);

		BEGIN TRY
			insert into #RawXML
			select convert(xml, target_data) as TargetData
			from sys.dm_xe_session_targets st
			join sys.dm_xe_sessions s on s.address = st.event_session_address
			where name = 'XECaptureErrors' 

			INSERT INTO #EventList
			SELECT 
				ROW_NUMBER() OVER (ORDER BY T.x) 
			,   T.x.value('@name', 'varchar(100)') 
			,   T.x.value('@timestamp', 'datetimeoffset') 
			,   TargetData 
			FROM 
				#RawXML RawXML   
			CROSS APPLY 
				TargetData.nodes('/RingBufferTarget/event') T(x) 

			select * from #EventList e
		
			SELECT 
				e.EventObjId, 
				e.TimeStamp, 
				data_name = T2.x.value('@name', 'varchar(100)'), 
				data_value = T2.x.value('value[1]', 'varchar(max)'), 
				data_text = T2.x.value('text[1]', 'varchar(max)') 
			FROM 
				#EventList e
			CROSS APPLY 
				e.TargetData.nodes('/RingBufferTarget/event/*') T2(x) 

		END TRY
		BEGIN CATCH
			SELECT ERROR_MESSAGE()
			RAISERROR ('We threw an error, most likely invalid xml.  Make sure you run STOP',16,1)
			RETURN 1
		END CATCH

	END;

END;
GO
--GRANT EXEC ON dbo.prc_Perf_XECaptureErrors TO Public;
GO


----Test Harness
--BEGIN TRY
--	IF OBJECT_ID('tempdb..#test') IS NOT NULL DROP TABLE #test
--	CREATE TABLE #test (ID int NOT NULL);
--	INSERT INTO #test VALUES (1);
--	INSERT INTO #test VALUES (1);
--	ALTER TABLE #test ADD CONSTRAINT blah PRIMARY KEY CLUSTERED (ID);
--END TRY
--BEGIN CATCH
--	IF ERROR_NUMBER() = 1505
--	--The CREATE UNIQUE INDEX statement terminated because a duplicate key was found for the object name
--	BEGIN
--		SELECT 'Hey, I caught an error!'
--	END
--END CATCH

