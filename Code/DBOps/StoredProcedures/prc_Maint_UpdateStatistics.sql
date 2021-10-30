CREATE OR ALTER PROCEDURE dbo.prc_Maint_UpdateStatistics
	@RowModificationCount INT = 20000,
	@StalenessInDays TINYINT = 6
AS 
BEGIN   
/******************************************************************************    
**  Name: prc_Maint_UpdateStatistics    
**  Desc: Update old statistics based on age and row modifications.
**	Limitations: It will only work on SQL 2008 R2 SP2 or SQL 2012 SP1 or greater
**      
*******************************************************************************    
**  Change History    
*******************************************************************************    
**  Date:		Author:			Description:    
**  09/09/2013	Chuck Lathrope  Created
**  02/06/2015  Chuck Lathrope	Made alwayson compatible
**  12/18/2015  Chuck Lathrope  Limit to only primary AlwaysOn databases.
*******************************************************************************/  
SET NOCOUNT ON  

DECLARE @VersionMajor int,
	@VersionMinor int,
	@BuildNumber int,
	@Pointer INT ,
    @SQL NVARCHAR(max)

SELECT @VersionMajor=(@@microsoftversion / 0x1000000) & 0xff,
	@VersionMinor=(@@microsoftversion / 0x10000) & 0xff,
	@BuildNumber=(@@microsoftversion & 0xffff),
	@Pointer = 1  

IF (@VersionMajor <= 10 AND @VersionMinor = 0)
	OR (@VersionMajor = 10 AND @VersionMinor = 50 AND @BuildNumber < 4000) 
	OR (@VersionMajor = 11 AND @VersionMinor = 0 AND @BuildNumber < 3000)
	RAISERROR ('This proc requires SQL to be at 10.50.4000 or 11.0.3000 or higher', 16,1)

CREATE TABLE #Commands (Command VARCHAR(max))  

DECLARE @DBList TABLE (
      ID INT IDENTITY(1, 1) ,
      CommandToRun VARCHAR(max)
    )
	  
DECLARE @StatstoUpdate TABLE (
      ID INT IDENTITY(1, 1) ,
      CommandToRun VARCHAR(max)
    )  

IF CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR), 1, 2), '.', '') AS TINYINT) > 10   
	INSERT  INTO @DBList ( CommandToRun )
	SELECT  'USE [' + [name] + ']; SET NOCOUNT ON
	INSERT INTO dbops.dbo.StatisticsHistory (DBID, ObjectID, ObjectName, StatsName, last_updated, rows, rows_sampled, unfiltered_rows, modification_counter)
	SELECT db_id(), s.object_id, OBJECT_SCHEMA_NAME(s.object_id, db_id()) + ''.'' + quotename(object_name(s.object_id) ) as object_name, name, 
		last_updated, rows, rows_sampled, unfiltered_rows, modification_counter 
	FROM sys.stats AS s 
	CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp 
	WHERE sp.object_id > 100
	AND modification_counter > ' + CAST(@RowModificationCount as varchar(10)) + '
	AND last_updated < getdate() -' + CAST(@StalenessInDays as varchar(2)) 
    FROM sys.databases d 
	LEFT JOIN sys.availability_replicas AS AR
		ON d.replica_id = ar.replica_id
	LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
		ON ars.group_id = AR.group_id AND ars.replica_id = ar.replica_id
	LEFT JOIN sys.dm_hadr_database_replica_cluster_states AS dbcs
		ON ars.replica_id = dbcs.replica_id and d.replica_id = dbcs.replica_id AND d.group_database_id = dbcs.group_database_id
	WHERE DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
	AND ars.role = 1 --Primary only 
	AND d.database_id > 4
	AND name <> 'ReportServerTempDB'
ELSE 
	INSERT  INTO @DBList ( CommandToRun )
	SELECT  'USE [' + [name] + ']; SET NOCOUNT ON
	INSERT INTO dbops.dbo.StatisticsHistory (DBID, ObjectID, ObjectName, StatsName, last_updated, rows, rows_sampled, unfiltered_rows, modification_counter)
	SELECT db_id(), s.object_id, OBJECT_SCHEMA_NAME(s.object_id, db_id()) + ''.'' + quotename(object_name(s.object_id) ) as object_name, name, 
		last_updated, rows, rows_sampled, unfiltered_rows, modification_counter 
	FROM sys.stats AS s 
	CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp 
	WHERE sp.object_id > 100
	AND modification_counter > ' + CAST(@RowModificationCount as varchar(10)) + '
	AND last_updated < getdate() -' + CAST(@StalenessInDays as varchar(2)) 
	FROM    sys.databases
	WHERE   DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
	AND database_id > 4
	AND name <> 'ReportServerTempDB'


WHILE @Pointer <= ( SELECT MAX(ID) FROM @DBList ) 
BEGIN  

    SELECT  @SQL = CommandToRun
    FROM    @DBList
    WHERE   ID = @Pointer  

	EXEC sp_executesql @SQL

    SET @Pointer = @Pointer + 1  
END  

IF EXISTS (SELECT * FROM dbo.StatisticsHistory Where DateUpdated IS NULL)
BEGIN
	--Now to run the update stats commands:
	SELECT @Pointer = 1, @SQL = NULL

	INSERT  INTO @StatstoUpdate ( CommandToRun )
	SELECT DISTINCT 'USE [' + DB_Name(DBID) + ']; Update Statistics ' + ObjectName + ';Update dbops.dbo.StatisticsHistory Set DateUpdated = SYSDATETIME() WHERE DBID = ' 
	+ CAST(DBID as varchar(3)) + ' AND ObjectID = ' + CAST(ObjectID as varchar(30)) + ' AND DateUpdated IS NULL'
	FROM dbo.StatisticsHistory
	WHERE DateUpdated IS NULL

	WHILE @Pointer <= ( SELECT MAX(ID) FROM @StatstoUpdate ) 
	BEGIN  

		SELECT  @SQL = CommandToRun
		FROM    @StatstoUpdate
		WHERE   ID = @Pointer  

		--Just so you can see what was run:
		Print @SQL

		EXEC sp_executesql @SQL

		SET @Pointer = @Pointer + 1  
	END  
END
END--proc  
go

