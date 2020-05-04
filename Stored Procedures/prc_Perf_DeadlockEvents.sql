USE [DBOPS]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_Perf_DeadlockEvents]
	@MinutesInPast SMALLINT = 10, --Set to your job frequency interval.
	@NotificationEmail VARCHAR (1000)=NULL,
	@EmailEnabled BIT = 1
AS
BEGIN
/******************************************************************************
**		Name: prc_Perf_DeadlockEvents
**		Desc: Log deadlock events from dedicated Deadlock_Monitor Extended Events Session.
**    
**		NOTE: XEventData.XEvent.query('(data/value/deadlock/victim-list)[1]') [if <victim-list /> then can't save as XDL,
		-- you just need to set Maxdop=1 for application query causing it to fix.]
**
**		Auth: Chuck Lathrope
**		Date: 8/19/2013 
*******************************************************************************
**		Change History
*******************************************************************************
**		Date:		Author:				Description:
**		8/28/2013	Chuck Lathrope		Added @MinutesInPast parameter and MAXDOP hint.
**      9/5/2013	Chuck Lathrope		Store xe data in temp table.
**		9/12/2013	Chuck Lathrope		Refactor to use dedicated XE Session.
**		9/29/2016	Chuck Lathrope		Big perf improvement with xml shreading.
**		7/22/2019	Michael Capobianco	Added @EmailEnabled flag
*******************************************************************************/
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @SubjectMsg VARCHAR(200), @Body VARCHAR(2000)

IF @NotificationEmail IS NULL
BEGIN
	SELECT @NotificationEmail = COALESCE(ParameterValue,'alerts@YourDomainNameHere.com') --Select *
	FROM dbo.ProcessParameter 
	WHERE ParameterName = 'IT Ops Team Escalation'
END

Set @SubjectMsg = 'Deadlock occurred on server.'
Select @Body = 'You will need to look at the xml stored in this table. You can save it as deadlockgraph.xdl to view it graphically.

Select * from DBOPS.dbo.DeadLockEvents
Where TimeCaptured >= ''' + CAST(DateAdd(mi,-@MinutesInPast,Getdate()) as Varchar(20)) + ''''

--Check for existance
IF NOT EXISTS (SELECT event_session_address
			FROM sys.dm_xe_session_targets xet
			INNER JOIN sys.dm_xe_sessions xe ON ( xe.address = xet.event_session_address )
			WHERE xe.name = 'Deadlock_Monitor')
--It must not be started, or it doesn't exist
BEGIN TRY
	DECLARE @ErrorMessage NVARCHAR(4000),
			 @ErrorSeverity INT ,
			 @ErrorState INT ;
	--Attempt to start deadlock session
	ALTER EVENT SESSION Deadlock_Monitor ON SERVER STATE=START
END TRY
BEGIN CATCH 
	-- Error is the deadlock session doesn't exist, let's try to create it.
	IF ( ERROR_NUMBER() = 15151 )
	BEGIN
		BEGIN TRY
			--Try to create
			CREATE EVENT SESSION Deadlock_Monitor ON SERVER 
			ADD EVENT sqlserver.xml_deadlock_report(ACTION(package0.collect_system_time)) 
			ADD TARGET package0.ring_buffer
			WITH (STARTUP_STATE=ON)

			--Try to start again now
			ALTER EVENT SESSION Deadlock_Monitor ON SERVER STATE=START
		END TRY
		BEGIN CATCH
			SELECT  @ErrorMessage = ERROR_MESSAGE() ,
					@ErrorSeverity = ERROR_SEVERITY() ,
					@ErrorState = ERROR_STATE() ;
                   
			RAISERROR (@ErrorMessage, -- Message text.
				@ErrorSeverity, -- Severity.
				@ErrorState -- State.
				) ;
		END CATCH
	END
	ELSE IF ( ERROR_NUMBER() = 25705 )
		PRINT 'Already Started, so continuing on.'
	ELSE --Unknown error 
		BEGIN
			SELECT  @ErrorMessage = ERROR_MESSAGE() ,
					@ErrorSeverity = ERROR_SEVERITY() ,
					@ErrorState = ERROR_STATE() ;
                   
			RAISERROR (@ErrorMessage, -- Message text.
				@ErrorSeverity, -- Severity.
				@ErrorState -- State.
				) ;
		END
END CATCH ;

;WITH DeadlockData 
AS ( 
SELECT CAST(target_data AS XML) AS TargetData 
FROM sys.dm_xe_session_targets st 
JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address 
WHERE s.name = 'Deadlock_Monitor'
)
INSERT INTO DeadLockEvents (TimeCaptured,DeadLockGraph)
SELECT CONVERT(DATETIME2, SWITCHOFFSET(CONVERT(DATETIMEOFFSET, XEventData.XEvent.value('@timestamp','Datetime')), 
                            DATENAME(TzOffset, SYSDATETIMEOFFSET()))) AS TimeCaptured,
	XEventData.XEvent.query('(data/value/deadlock)[1]') AS DeadLockGraph 
FROM DeadlockData 
--CROSS APPLY TargetData.nodes('//RingBufferTarget/event') AS XEventData (XEvent) 
--WHERE XEventData.XEvent.value('@name','varchar(4000)') = 'xml_deadlock_report'
--massive improvements in cost using this version:
CROSS APPLY TargetData.nodes('//RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData (XEvent) 
WHERE CONVERT(DATETIME2, SWITCHOFFSET(CONVERT(DATETIMEOFFSET, XEventData.XEvent.value('@timestamp','Datetime')), 
                            DATENAME(TzOffset, SYSDATETIMEOFFSET()))) > DATEADD(mi,-@MinutesInPast,GETDATE())
OPTION (MAXDOP 1)

IF @@Rowcount > 0
	IF @EmailEnabled = 1
EXEC prc_InternalSendMail           
        @Address = @NotificationEmail, 
        @Subject = @SubjectMsg,            
        @Body = @Body,     
        @HTML = 0

END;
GO


