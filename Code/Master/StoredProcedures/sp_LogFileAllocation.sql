Use master
go
IF (OBJECT_ID('dbo.sp_LogFileAllocation') IS NULL)
BEGIN
	EXEC('create procedure dbo.sp_LogFileAllocation  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.sp_LogFileAllocation.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.sp_LogFileAllocation.'
	END
END
GO

/*******************************************************************************    
** Procedure: sp_LogFileAllocation  
**    
**  Purpose: Return info about log file, great for watching growth over time.   
**    
**    
**  Created 1/7/2010 Chuck Lathrope    
*******************************************************************************    
**  Altered:
**	12/8/2014	Chuck Lathrope	Added non-readable AG database check
**  12/18/2015  Chuck Lathrope  Limited to primary and fully readable AG databases.
*******************************************************************************/    
  
ALTER PROCEDURE dbo.sp_LogFileAllocation
    @Dbname VARCHAR(100) ,  
	@LogToDBOPS bit = 0 ,
	@Notes VARCHAR(1000) = NULL
AS   
BEGIN     
  
SET NOCOUNT ON    
  
DECLARE @Pointer INT ,  
    @SQL VARCHAR(2000)  

DECLARE @DBList TABLE  
    (  
      ID INT IDENTITY(1, 1) ,  
      DBName VARCHAR(150) ,  
      SQLFileStats VARCHAR(1000)  
    )    
  
CREATE TABLE #Space  
    (  
      DBName VARCHAR(1000) ,  
      LogicalFileName VARCHAR(1000) ,  
      [SpaceUsed] DECIMAL(18, 4) ,  
      FileSizeMB DECIMAL(18, 4) ,  
      [AvailableSpaceMB] DECIMAL(18, 4)  
    )    
  
-----------------------    
--Populate temp tables for SQL 2005 and above.    
-----------------------    
IF CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR), 1, 2), '.', '') AS TINYINT) > 8   
BEGIN
	SELECT  @SQL = 
'USE [' + [name] + ']   
SELECT ''' + [name] + ''' AS DBName,   
f.name AS LogicalFileName,  
size/128 as FileSizeMB,  
size/128 - FILEPROPERTY(f.name, ''SpaceUsed'')/128.0 AS AvailableSpaceInMB    
FROM sys.database_files f (NOLOCK)  
Where type_desc = ''LOG'''  
	FROM sys.databases d 
	LEFT JOIN sys.availability_replicas AS AR
		ON d.replica_id = ar.replica_id
	LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
		ON ars.group_id = AR.group_id AND ars.replica_id = ar.replica_id
	LEFT JOIN sys.dm_hadr_database_replica_cluster_states AS dbcs
		ON ars.replica_id = dbcs.replica_id and d.replica_id = dbcs.replica_id AND d.group_database_id = dbcs.group_database_id
	WHERE DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
	AND (ars.role = 1 OR ISNULL(AR.secondary_role_allow_connections,2) = 2) --Primary or able to read secondary db, no read-intent only dbs.
	AND [Name] = ISNULL(@Dbname, [Name])   
END
ELSE   
    RETURN 0  


INSERT  INTO #Space  
        ( DBName ,  
          LogicalFileName ,  
		  FileSizeMB,  
          AvailableSpaceMB
        )  
        EXEC ( @SQL )    

IF @@ROWCOUNT = 0
	RAISERROR ('Database doesn''t exist or is not readable',16,1)

IF @LogToDBOPS = 1
BEGIN
	INSERT INTO DBOPS.dbo.DBLogFileAllocation (DBName, LogicalFileName, FileSizeMB, UsedSpaceMB, Notes)
	SELECT  @Dbname AS DBName ,  
			f.name AS LogicalFileName ,  
			CAST (ts.FileSizeMB as Int) as FileSizeMB,
			CAST(ts.FileSizeMB-ts.[AvailableSpaceMB] as int) AS UsedSpaceMB ,
			@Notes
	FROM    sys.master_files f WITH ( NOLOCK )  
			JOIN sys.sysdatabases sd WITH ( NOLOCK ) ON f.database_id = sd.dbid  
			JOIN sys.databases d WITH ( NOLOCK ) ON d.database_id = sd.dbid  
			JOIN #Space ts ON ts.DBName = d.name  
							  AND ts.LogicalFileName = f.name 
END
ELSE                
SELECT  @Dbname AS DBName ,  
        f.name AS LogicalFileName ,  
        CAST (ts.FileSizeMB as Int) as FileSizeMB,
        CAST(ts.FileSizeMB-ts.[AvailableSpaceMB] as int) AS UsedSpaceMB 
FROM    sys.master_files f WITH ( NOLOCK )  
        JOIN sys.sysdatabases sd WITH ( NOLOCK ) ON f.database_id = sd.dbid  
        JOIN sys.databases d WITH ( NOLOCK ) ON d.database_id = sd.dbid  
        JOIN #Space ts ON ts.DBName = d.name  
                          AND ts.LogicalFileName = f.name  

END--proc    
go

