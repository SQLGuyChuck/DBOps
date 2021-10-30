USE master
GO
IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'sp_server_diag_event_parser' And ROUTINE_SCHEMA = 'dbo')
BEGIN
	EXEC('Create procedure dbo.sp_server_diag_event_parser  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.sp_server_diag_event_parser.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.sp_server_diag_event_parser.'
	END
END
GO

ALTER PROCEDURE dbo.sp_server_diag_event_parser
as
--SP_SERVER_DIAGNOSTICS Dynamic Parser for "events", v1.23
--You may use this at will, you may share it provided this header remains.  
-- Copyright 2012 Michael Bourgon
-- Commercial use or sale prohibited without permission. Personal, Internal Company, or Private use is fine.
-- If you're just running this as your job as a DBA, enjoy.
-- Please feel free to share, and feel free to send corrections or enhancements - thebakingdba.blogspot.com
-- Thanks to Marc_S on Stackoverflow for the help on parsing XML.
-- Thanks to Stack Overflow for forcing me to come up with a good question - so I found the flawed derived table slowdown.
-- mdb 2012/12/28 found the massive slowdown in the pre-parse name/datatype - changed from derived table (4 minutes) 
--  to a variable: 18 seconds. Wow.  Then split that out to a table variable (5 seconds).  Even on my trouble 
--  servers it now runs in under 2 minutes.
-- mdb 2013/01/08 even faster (18 sec!), by changing my end query to use the variable as well

--InANutShell: fast shred on the EVENTS portion of SP_SERVER_DIAGNOSTICS, getting the event type, sub-type and datatype.
--    Then query the XML, pulling out each event type with its specific attributes.  End result: human readable,
--    though with enough data to choke a horse.  

--takes 5 seconds to run, only valid on 2012 servers
if object_id('tempdb..#SpServerDiagnosticsResult') is null 
BEGIN
 CREATE TABLE #SpServerDiagnosticsResult 
 (
    rowId INT IDENTITY PRIMARY KEY,
    create_time DateTime,
    component_type varchar(128),
    component_name varchar(128),
    state int,
    state_desc varchar(20),
    data varchar(max)
 )
 INSERT INTO #SpServerDiagnosticsResult
 EXEC sys.sp_server_diagnostics
END 

SET NOCOUNT ON 
DECLARE @events TABLE (id INT IDENTITY PRIMARY KEY, EventName VARCHAR(100))
DECLARE @sql NVARCHAR(max)
DECLARE @min int, @max INT, @eventtype VARCHAR(100), @xml XML 
DECLARE @full_data_info TABLE (EventName NVARCHAR(100), SubEventName NVARCHAR(100), SubDataType NVARCHAR(50))
DECLARE @parmdefinition NVARCHAR(500)
--get a list of event types, then walk through each separately; columns won't match 
INSERT INTO @events (EventName)
select 
    DISTINCT EventName = Evt.value('(@name)[1]', 'varchar(100)')
FROM 
(
 SELECT CAST(data AS XML) AS xml_data 
 FROM #SpServerDiagnosticsResult 
 WHERE component_name = 'events'
)getlistofsubevents
CROSS APPLY xml_data.nodes('/events/session/RingBufferTarget/event') Tbl(Evt)
SELECT @xml = CAST(data AS XML)  FROM #SpServerDiagnosticsResult WHERE component_name = 'events'

 --break out each event type for the larger query; could just use nvarchar/varchar for everything, but returning the right data type is cleaner
 -- (and we need to know when it's a non-standard type for the name/text/value)
INSERT INTO @full_data_info
 select distinct
  EventName = Evt.value('(../@name)[1]', 'nvarchar(100)'), 
  SubEventName = Evt.value('(@name)[1]', 'nvarchar(100)'),
  SubDataType = CASE Evt.value('(type/@name)[1]', 'nvarchar(100)')
    WHEN 'int16' THEN N'int'
    WHEN 'int32' THEN N'int'
    WHEN 'uint16' THEN N'int'
    WHEN 'boolean' THEN N'bit'
    WHEN 'unicode_string' THEN N'nvarchar(1000)'
    WHEN 'uint32' THEN N'bigint'
    WHEN 'uint64' THEN N'nvarchar(1000)'
    WHEN 'guid' THEN N'uniqueidentifier'
    WHEN 'ansi_string' THEN N'nvarchar(1000)'
    ELSE N'nvarchar(150)' END --if unknown, then probably name/text/value. 
 FROM 
 (
 SELECT @xml AS xml_data 
 )event_xml_record
 CROSS APPLY xml_data.nodes('/events/session/RingBufferTarget/event/data') Tbl(Evt)
--Loop - for each event type, generate a SQL script for those columns
SELECT @min = MIN(id), @max = MAX(id) FROM @events
WHILE @min <= @max
BEGIN
 SET @sql = NULL 
 SELECT @eventtype = EventName FROM @events WHERE id = @min
  --header for the query
 SELECT @sql = N'select 
  EventName = Evt.value(''(@name)[1]'', ''varchar(100)'')
  ,OriginalTime = Evt.value(''(@timestamp)[1]'', ''varchar(100)'')' + CHAR(10) + CHAR(9)
  --meat of the query - get the data for each unique TYPE, if a normal value.
 -- if the subdatatype is not a "normal" type, we assume we want a name/text/value
 -- we use varchar(100) for that, rather than a separate CASE, for speed
 -- SO, don't just add varchar(100) to this CASE without understanding why.
 SELECT @sql = @sql + 
  N' ,' + SubEventName + 
  + CASE SubDataType
   when N'int' THEN N' = Evt.value(''(data[@name="' + SubEventName + '"]/value' + ')[1]'', ''' + SubDataType + ''')' + CHAR(10) + CHAR(9)
   WHEN N'bigint' THEN N' = Evt.value(''(data[@name="' + SubEventName + '"]/value'+ ')[1]'', ''' + SubDataType + ''')'  + CHAR(10) + CHAR(9)
   WHEN N'unicode_string' THEN N' = Evt.value(''(data[@name="' + SubEventName + '"]/value' + ')[1]'', ''' + SubDataType + ''')' + CHAR(10) + CHAR(9)
   WHEN N'uniqueidentifier' THEN N' = Evt.value(''(data[@name="' + SubEventName + '"]/value' + ')[1]'', ''' + SubDataType + ''')' + CHAR(10) + CHAR(9)
   WHEN N'nvarchar(1000)' THEN N' = Evt.value(''(data[@name="' + SubEventName + '"]/value' + ')[1]'', ''' + SubDataType + ''')' + CHAR(10) + CHAR(9)
   WHEN N'bit' THEN N' = Evt.value(''(data[@name="' + SubEventName + '"]/value' + ')[1]'', ''' + SubDataType + ''')' + CHAR(10) + CHAR(9)
   ELSE N' = isnull(Evt.value(''(data[@name="' + SubEventName + '"]/type/@name)[1]'', ''varchar(100)''),'''') + '' : ''
        + isnull(Evt.value(''(data[@name="' + SubEventName + '"]/text)[1]'', ''varchar(100)''),'''') + '' : ''
        + isnull(Evt.value(''(data[@name="' + SubEventName + '"]/value)[1]'', ''varchar(100)''),'''')' + CHAR(10) + CHAR(9)
   end
 FROM @full_data_info full_data_info 
 WHERE EventName = @eventtype
 --and the footer for our query; might be able to do a dual CROSS APPLY, but this is more readable
 SELECT @sql = @sql + N'
 from (
  SELECT @eventxml AS xml_data
 )spserverdiageventparser
 CROSS APPLY xml_data.nodes(''/events/session/RingBufferTarget/event'') Tbl(Evt)
 WHERE Evt.value(''(@name)[1]'', ''varchar(100)'') = ''' + @eventtype + ''''

SET @ParmDefinition = N'@eventxml xml'
  EXEC sp_executesql @sql, @parmdefinition, @eventxml = @xml
 PRINT @sql
  SET @min = @min + 1
END

DROP TABLE #SpServerDiagnosticsResult 
GO 


