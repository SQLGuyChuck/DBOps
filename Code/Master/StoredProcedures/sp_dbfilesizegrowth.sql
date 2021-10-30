USE master
GO

/*****************************************************************************************  
**  Name: sp_DBFileSizeGrowth
**  Desc: This will generate the alter db statement according to optimal settings
**
**    
**  Return values: Displays alter db scripts.  Recommend to print to text output in SSMS.
**	Also, set SSMS text output display length to 9999 per column to prevent truncation.
**  
******************************************************************************************  
**  Change History  
******************************************************************************************  
**  Date:		Author:			Description:  
**	04/01/2009	Chuck Lathrope	SQL 2000 bug fixes. Removed cursor.
**								Ignore the files which were already stopped autogrowth
**  12/21/2009  Chuck Lathrope	Made SQL 2005+ compatible only. Small tweaks.
**  7/31/2013	Chuck Lathrope	Made small adjustments for small databases.
**  8/6/2013	Chuck Lathrope	Made adjustment for >100GB files. filetype = 'ROWS' bug fix
**  8/9/2013	Chuck Lathrope	Made more adjustments for log file growths.
**  8/27/2013	Chuck Lathrope  Bug fix for log < 50 MB
**  10/14/2014  Chuck Lathrope	Add minimum data/log file size change.
**	12/8/2014	Chuck Lathrope	Added non-readable AG database check
**  2/8/2015	Chuck Lathrope	Improvements to AG check and output modifications.
**  12/18/2015  Chuck Lathrope  Limited to primary and fully readable AG databases.
**  7/14/2021   Chuck Lathrope	Separated growth statements for small db's. 
**								Exclude filestream files. Improve big log file shrink statements.
******************************************************************************************/
CREATE OR ALTER PROCEDURE [dbo].[sp_DBFileSizeGrowth]
    @Dbname VARCHAR(100) = NULL,
	@Debug BIT = 0
AS 
BEGIN

SET NOCOUNT ON;

/*Testing*/
--DECLARE @Dbname VARCHAR(100), @debug bit = 1
--SET @dbname = 'tempdb'
/*Testing*/

DECLARE @StrSql VARCHAR(500) ,
    @db VARCHAR(128) ,
    @logicalname SYSNAME ,
    @crlf CHAR(2) ,
    @Pointer INT ,
    @SQL VARCHAR(2000)

SELECT  @crlf = CHAR(13) + CHAR(10) ,
        @Pointer = 1  


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

CREATE TABLE #DBFileListResults
(
  DBName SYSNAME ,
  LogicalName SYSNAME ,
  FileSizeMB INT ,
  FreeSpaceMB NUMERIC ,
  FileType VARCHAR(10) ,
  maxsize INT ,
  growth INT ,
  growthunit VARCHAR(2)
)  

-----------------------  
--Populate temp tables.  
-----------------------  

    --IF CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR),1, 2), '.', '') AS TINYINT) > 8 
        INSERT  INTO @DBList ( DBName , SQLFileStats )
        SELECT  [name] ,
'USE [' + [name] + '] 
SELECT ''' + [name] + ''' AS DBName, 
f.name AS LogicalFileName,
size/128.0 as FileSizeMB,
size/128.0 - FILEPROPERTY(f.name, ''SpaceUsed'')/128.0 AS AvailableSpaceInMB  
FROM sys.database_files f (NOLOCK)'
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


    WHILE @Pointer <= ( SELECT  MAX(ID) FROM  @DBList ) 
    BEGIN  

        SELECT  @SQL = SQLFileStats
        FROM    @DBList
        WHERE   ID = @Pointer  

        INSERT  INTO #Space
                ( DBName ,
                  LogicalFileName ,
                  FileSizeMB ,
                  [AvailableSpaceMB]
                )
                EXEC ( @SQL )  

        SET @Pointer = @Pointer + 1  
    END  

    INSERT  INTO #DBFileListResults
            ( DBName ,
              LogicalName ,
              FileSizeMB ,
              FreeSpaceMB ,
              FileType ,
              [maxsize] ,
              growth ,
              growthunit
            )
    SELECT  DB_NAME(d.database_id) AS DBName ,
            f.name AS LogicalFileName ,
            CAST(ts.FileSizeMB AS INT) AS FileSizeMB ,
            CAST(ts.[AvailableSpaceMB] AS INT) AS FreeSpaceMB ,
            type_desc AS FileType ,
            CASE WHEN max_size > 1 THEN max_size / 128 ELSE max_size END AS max_size ,
            CASE WHEN is_percent_growth = 0 THEN growth / 128 ELSE growth END AS Growth ,
            CASE WHEN is_percent_growth = 1 THEN '%' ELSE 'MB' END AS GrowthUnit
    FROM    sys.master_files f WITH ( NOLOCK )
            JOIN sys.sysdatabases sd WITH ( NOLOCK ) ON f.database_id = sd.dbid
            JOIN sys.databases d WITH ( NOLOCK ) ON d.database_id = sd.dbid
            JOIN #Space ts ON ts.DBName = d.name
                              AND ts.LogicalFileName = f.name
    WHERE   d.name = ISNULL(@dbname, d.name)
            AND f.is_read_only = 0
			AND f.type < 2
    ORDER BY d.name ,
            f.physical_name  

	--Testing use.
	IF @Debug = 1
		SELECT  * FROM #DBFileListResults
		
	--Small sized DB's:
    SELECT  CONCAT('--sp_DBFileSizeGrowth output from Server ', @@SERVERNAME, ' on ', getdate(), @crlf, 'use [master]' , @crlf , 'GO') AS RunNotes
	UNION ALL
	SELECT '--Set minimum Data file size to at least 50MB.'  + @crlf 
	+ 'ALTER DATABASE [' + DBNAME + '] MODIFY FILE (NAME = N'''
            + LogicalName + ''', SIZE = 50MB)'
    FROM    #DBFileListResults
    WHERE   (filesizemb < 50)
			AND FileType = 'ROWS'
	UNION ALL
	SELECT '--Set minimum Data file growth to at least 50MB.'  + @crlf 
	+ 'ALTER DATABASE [' + DBNAME + '] MODIFY FILE (NAME = N'''
            + LogicalName + ''', FILEGROWTH = 50MB )'
    FROM    #DBFileListResults
    WHERE   (growth < 25)
			AND FileSizeMB < 50
			AND FileType = 'ROWS'
	UNION ALL
	SELECT '--Set minimum Log file size to at least 25MB.'  + @crlf 
	+ 'ALTER DATABASE [' + DBNAME + '] MODIFY FILE (NAME = N'''
            + LogicalName + ''', SIZE = 25MB)'
    FROM    #DBFileListResults
    WHERE   (filesizemb < 25)
			AND FileType = 'LOG'
	UNION ALL
	SELECT '--Set minimum Log file growth to at least 25MB.'  + @crlf 
	+ 'ALTER DATABASE [' + DBNAME + '] MODIFY FILE (NAME = N'''
            + LogicalName + ''', FILEGROWTH = 25MB )'
    FROM    #DBFileListResults
    WHERE   (growth < 25)
			AND FileSizeMB < 50
			AND FileType = 'LOG'
	UNION ALL
	SELECT '--Data FileSize > .05 < .5 GB'  + @crlf 
	+ 'ALTER DATABASE [' + DBNAME + '] MODIFY FILE (NAME = N'''
            + LogicalName + ''', FILEGROWTH = 100MB )'
    FROM    #DBFileListResults
    WHERE   1=1--filetype = 'ROWS'
			AND filesizemb > 50
            AND filesizemb < 500
            AND ( ( growthunit = 'MB' AND growth < 100 )
                  OR ( growthunit = '%' )
                )
	UNION ALL
	SELECT '--Log FileSize > .5 < 5'  + @crlf 
	+ 'ALTER DATABASE [' + DBNAME + '] MODIFY FILE (NAME = N'''
            + LogicalName + ''', FILEGROWTH = 100MB )'
    FROM    #DBFileListResults
    WHERE   filetype = 'LOG'
			AND filesizemb > 500
			AND filesizemb < 5000
            AND Growth <> 0
            AND ( ( growthunit = 'MB' AND growth < 100 )
                  OR ( growthunit = '%')
                ) 
	UNION ALL
	SELECT '--Data FileSize > .5 < 20 GB'  + @crlf 
	+ 'ALTER DATABASE [' + DBNAME + '] MODIFY FILE (NAME = N'''
            + LogicalName + ''', FILEGROWTH = 500MB )'
    FROM    #DBFileListResults
    WHERE   filetype = 'ROWS'
			AND filesizemb >= 500
            AND filesizemb < 20480
            AND ( ( growthunit = 'MB' AND growth < 500 )
                  OR ( growthunit = '%' )
                )
	UNION ALL
	SELECT '--Log FileSize > 5'  + @crlf 
	+ 'ALTER DATABASE [' + DBNAME + '] MODIFY FILE (NAME = N'''
            + LogicalName + ''', FILEGROWTH = 500MB )'
    FROM    #DBFileListResults
    WHERE   filetype = 'LOG'
			AND filesizemb >= 5000
            AND Growth <> 0
            AND ( ( growthunit = 'MB' AND growth < 500 )
                  OR ( growthunit = '%')
                ) -- growth is less than 10 GB
	UNION ALL
    SELECT '--Data FileSize > 20 < 100 GB'  + @crlf 
	+ 'ALTER DATABASE [' + DBNAME + '] MODIFY FILE (NAME = N'''
            + LogicalName + ''', FILEGROWTH = 5000MB )'
    FROM    #DBFileListResults
    WHERE   filetype = 'ROWS'
			AND filesizemb >= 20480
            AND filesizemb < 102400
            AND Growth <> 0
            AND ( ( growthunit = 'MB' AND growth < 5000 )
                  OR ( growthunit = '%')
                ) -- growth is less than 5 GB
	UNION ALL
    SELECT '--Data FileSize > 100 GB'  + @crlf 
	+ 'ALTER DATABASE [' + DBNAME + '] MODIFY FILE (NAME = N'''
            + LogicalName + ''', FILEGROWTH = 10000MB )'
    FROM    #dbfilelistresults o
    WHERE   filetype = 'ROWS'
            AND filesizemb >= 102400
            AND Growth <> 0
            AND ( ( growthunit = 'MB' AND growth < 10000 )
                  OR ( growthunit = '%' )
                ) -- growth is less than 10 GB


	--Check if log file size is > 50% of the total data space and shrink it to 1/4 of size as first guess.
    SELECT CONCAT('--Log Size > 50% of Data Size. Check VLF count first, if > 100 shrink to 0 or as close as you can get a re-grow it.'  , @crlf 
	, 'EXEC master.dbo.prc_Maint_VLFTracking @DBName = ''' , dbname , '''' , @crlf
	, 'EXEC master.dbo.sp_dbFileSpaceAllocation @DBName = ''' , dbname , '''' , @crlf
	, 'USE ' , dbname , @crlf + 'GO' ,@crlf , 'CHECKPOINT', @crlf, 'DBCC SHRINKFILE (N''' , LogicalName , ''' , '
    , CAST(
		CASE WHEN CAST((CASE WHEN sumData < 100 THEN 50 ELSE sumData END) / 4 AS INT) < 100
		THEN CAST((CASE WHEN sumData < 100 THEN 50 ELSE sumData END) / 4 AS INT)
		WHEN CAST((CASE WHEN sumData < 100 THEN 50 ELSE sumData END) / 4 AS INT) < 1000
		THEN ROUND(CAST((CASE WHEN sumData < 100 THEN 50 ELSE sumData END) / 4 AS INT),-2)
		ELSE ROUND(CAST((CASE WHEN sumData < 100 THEN 50 ELSE sumData END) / 4 AS INT),-3)
		END
	AS VARCHAR(6))--End CAST 
	, ')' , @crlf
    , 'GO --If you choose to shrink some of the log files, please run this proc again.' , @crlf
	, 'EXEC master.dbo.prc_Maint_VLFTracking @DBName = ''' , dbname , '''' , @crlf
	, 'EXEC master.dbo.sp_dbFileSpaceAllocation @DBName = ''' , dbname , '''' , @crlf, @crlf)
    FROM    #DBFileListResults t
    JOIN	(
            SELECT  Data.Datadbname, Logs.sumLog, Data.sumData, 100.0*(Data.sumData-Logs.sumLog)/Data.sumData as PercentData
            FROM    ( SELECT    SUM(filesizemb) AS sumData ,
                                dbname Datadbname
                      FROM      #DBFileListResults
                      WHERE     filetype = 'ROWS'
                      GROUP BY  dbname
                    ) Data
                    JOIN ( SELECT   SUM(filesizemb) AS sumLog ,
                                    dbname Logsdbname
                           FROM     #DBFileListResults
                           WHERE    filetype = 'LOG'
                           GROUP BY dbname
                         ) Logs ON Logs.Logsdbname = Data.Datadbname
					WHERE   Logs.sumLog > 50 
			) s ON s.Datadbname = t.dbname
	WHERE filetype = 'log'
	AND PercentData < 50

--select dbname, FileType,sum(case when FileType = 'log' then filesizemb else 0 end) - sum(case when FileType = 'data' then filesizemb else 0 end) 
--from #DBFileListResults
--group by dbname, FileType

END
GO

