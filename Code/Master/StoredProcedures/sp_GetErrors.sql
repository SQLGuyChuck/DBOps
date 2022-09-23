IF EXISTS (select * from sys.server_event_sessions where [name] = 'ErrorSession')
	ALTER EVENT SESSION ErrorSession ON SERVER STATE = STOP

IF EXISTS (select * from sys.server_event_sessions where [name] = 'ErrorSession')
	DROP EVENT SESSION ErrorSession ON SERVER 

CREATE EVENT SESSION ErrorSession ON SERVER 
    ADD EVENT sqlserver.error_reported            
    -- collect failed SQL statement, the SQL stack that led to the error, 
    -- the database id in which the error happened and the username that ran the statement 
    
    (
        ACTION (sqlserver.sql_text, sqlserver.tsql_stack, sqlserver.database_id, 
			sqlserver.username, sqlserver.client_app_name, sqlserver.client_hostname, package0.collect_system_time)
        WHERE severity >= 14 and error_number <> 2557 and error_number <> 17830
    )  
    ADD TARGET package0.ring_buffer    
        (SET max_memory = 1024)
WITH (max_dispatch_latency = 1 seconds, EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, STARTUP_STATE = ON)

--Uncomment this part out to start the session as it will take memory and cpu (light amount)
--IF EXISTS (select * from sys.server_event_sessions where [name] = 'ErrorSession')
--	ALTER EVENT SESSION ErrorSession ON SERVER STATE = START


USE MASTER
go
	
CREATE OR ALTER PROCEDURE dbo.sp_GetErrors
AS
--Created by Chuck Lathrope: https://github.com/SQLGuyChuck/DBOps to see other good DBA stuff.
--Use at your own risk.

;WITH ee AS (
SELECT XEvent.query('.') AS event_data 
FROM 
(    -- Cast the target_data to XML 
	SELECT CAST(target_data AS XML) AS TargetData 
	FROM sys.dm_xe_session_targets st 
	JOIN sys.dm_xe_sessions s 
		ON s.address = st.event_session_address 
	WHERE name = 'ErrorSession' 
	  AND target_name = 'ring_buffer'
) AS Data 
-- Split out the Event Nodes 
CROSS APPLY TargetData.nodes ('RingBufferTarget/event') AS XEventData (XEvent) 
)
,CTE AS (
SELECT  
        event_data.value('(event/@name)[1]', 'varchar(50)') AS event_name,
        DATEADD(hh, 
            DATEDIFF(hh, GETUTCDATE(), CURRENT_TIMESTAMP), 
            event_data.value('(event/@timestamp)[1]', 'datetime2')) AS [timestamp],
        COALESCE(event_data.value('(event/data[@name="database_id"]/value)[1]', 'int'), 
            event_data.value('(event/action[@name="database_id"]/value)[1]', 'int')) AS database_id,
            
        event_data.value('(event/data[@name="error_number"]/value)[1]', 'int') as [error],
        event_data.value('(event/data[@name="severity"]/value)[1]', 'int') as [severity],
        event_data.value('(event/data[@name="message"]/value)[1]', 'nvarchar(1000)') as [error_message],
        
        event_data.value('(event/action[@name="session_id"]/value)[1]', 'int') AS [session_id],
        
        event_data.value('(event/action[@name="client_app_name"]/value)[1]', 'nvarchar(4000)') AS [client_app_name],
        event_data.value('(event/action[@name="client_hostname"]/value)[1]', 'nvarchar(4000)') AS [client_hostname]
        ,event_data.value('(event/action[@name="collect_system_time"]/text)[1]', 'datetime') AS [collect_system_time]
        ,event_data.value('(event/action[@name="username"]/value)[1]', 'nvarchar(4000)') AS [username]
        --event_data.value('(event/data[@name="cpu"]/value)[1]', 'int') AS [cpu],
        --event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint') AS [duration],
        --event_data.value('(event/data[@name="reads"]/value)[1]', 'bigint') AS [reads],
        --event_data.value('(event/data[@name="writes"]/value)[1]', 'bigint') AS [writes],
        --event_data.value('(event/data[@name="state"]/text)[1]', 'nvarchar(4000)') AS [state],
        --event_data.value('(event/data[@name="offset"]/value)[1]', 'int') AS [offset],
        --event_data.value('(event/data[@name="offset_end"]/value)[1]', 'int') AS [offset_end],
        --event_data.value('(event/data[@name="nest_level"]/value)[1]', 'int') AS [nest_level],
        ,CAST(event_data.value('(event/action[@name="tsql_stack"]/value)[1]', 'nvarchar(4000)') AS XML) AS [tsql_stack]
        ,REPLACE(event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)'), CHAR(10), CHAR(13)+CHAR(10)) AS [sql_text]
        ,event_data.value('(event/data[@name="source_database_id"]/value)[1]', 'int') AS [source_database_id]
        --event_data.value('(event/data[@name="object_id"]/value)[1]', 'int') AS [object_id],
        --event_data.value('(event/data[@name="object_type"]/text)[1]', 'int') AS [object_type],
        --CAST(SUBSTRING(event_data.value('(event/action[@name="attach_activity_id"]/value)[1]', 'varchar(50)'), 1, 36) AS uniqueidentifier) as activity_id,
        --CAST(SUBSTRING(event_data.value('(event/action[@name="attach_activity_id"]/value)[1]', 'varchar(50)'), 38, 10) AS int) as event_sequence
FROM ee )
select    event_name 
    ,[timestamp] 
	,d.name AS DatabaseName
     --,[collect_system_time]
     --, dateadd(minute, datepart(TZoffset, sysdatetimeoffset()), [collect_system_time]) AS [system_time]
    ,[error_message]
    ,error
    ,severity
	,CAST('<?query -- 
' + sql_text + '
----?>' AS XML) AS sql_text
    ,client_app_name
    ,client_hostname
    ,username 
    ,tsql_stack
from CTE
JOIN sys.databases d ON d.database_id = CTE.database_id
where error NOT IN (
	2557 -- show statistics
	, 17830 -- network error occurred
	, 8429 -- 
	, 8462 -- conversation is closed
	)
order by [timestamp] DESC
GO

