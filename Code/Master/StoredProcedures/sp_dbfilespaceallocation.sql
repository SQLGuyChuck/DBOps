USE [Master]
GO

/*******************************************************************************            
** Procedure: sp_dbFileSpaceAllocation          
**            
**  Purpose: Return file space usage for all files on server or just a database.            
**  Also provide code necessary for common db moves.            
**            
**  Created 2/25/2007 Chuck Lathrope            
*******************************************************************************            
** Altered            
** 07/26/2007 Chuck Lathrope Added SQL 2005 method and more details per file.            
** 06/19/2008 Chuck Lathrope Added ONLINE status check.            
** 10/01/2008 Chuck Lathrope Bug fix for 2 dbs with same logical name.            
** 12/09/2008 Chuck Lathrope Added growthunit to result set and fixed proper growth size.            
** 12/19/2008 Chuck Lathrope dbo.sysaltfiles was replaced by sys.master_files in sql 2005 but           
  neither report file size correctly if db grows.            
** 03/29/2009 Chuck Lathrope Added SQL 2008 support and @TotalSizeOnly parameter.            
** 04/01/2009 Chuck Lathrope Bug fix for SQL 2000 results.            
** 06/01/2009 Chuck Lathrope Removed Cursors            
** 11/01/2009 Chuck Lathrope Covert to SQL 2005 only compatibility          
** 12/18/2009 Chuck Lathrope Added FileGroupName to output.          
** 12/21/2009 Chuck Lathrope Bug fixes with filesize and 12/18 bug introduction.          
** 01/30/2010 Chuck Lathrope Added parameters @StopGrowth and @LogPath. Updated file move code.          
** 08/12/2010 Chuck Lathrope Added new Full drive capability. DBName to QUOTENAME bug fix.          
** 08/14/2010 Chuck Lathrope Fixed DBMove output.          
** 09/10/2010 Chuck Lathrope Fixed max capping log file for @StopGrowth option.          
** 10/08/2010 Chuck Lathrope Added @ShowDetails and modified result sets.          
** 01/01/2011 Chuck Lathrope Refactored @FullDriveAnalysis and add more notes.          
** 02/03/2011 Chuck Lathrope Update dbmove process to be a copy and delete.    
** 07/27/2011 Chuck Lathrope Added @TotalFileGroupSizeOnly to show totals by filegroup.  
** 08/22/2012 Chuck Lathrope SQL 2012 compatibility  
** 10/04/2012 Chuck Lathrope Added % free space with @TotalFileGroupSizeOnly output
** 08/13/2013 Chuck Lathrope Added @StoreSizeHistory parameter option
** 09/03/2013 Chuck Lathrope Added recompile and sp_executesql. Check for dbops existance.
** 12/08/2014 Chuck Lathrope Added non-readable AG database check
** 10/22/2015 Chuck Lathrope Added Drive Space info
** 11/13/2015 Chuck Lathrope Added DriveLetter to TotalSpaceOnly Output.
** 12/18/2015 Chuck Lathrope Limited to primary and fully readable AG databases.
** 06/15/2021 Chuck Lathrope Filegroupname output fix
** 07/13/2021 Chuck Lathrope Added another  /1024 to drive space calculation.
** 10/29/2021 Chuck Lathrope Update column types and column names.
** 11/1/2021  Chuck Lathrope Add Filename and Filetype to store table.
*******************************************************************************/            

/****This proc is NON-destructive, it only prints out recommendations, you must review!******/          
CREATE OR ALTER PROCEDURE dbo.sp_dbFileSpaceAllocation
    @Dbname VARCHAR(100) = NULL ,  
    @DBMove BIT = 0 , --Move files to new location. @DataPath is required. Use other parameters to filter result.           
    @StopGrowth BIT = 0 , --Set all files to not grow on a given @DriveLetter          
    @DriveLetter CHAR(1) = NULL , -- Drive letter to focus result set on.          
    @DataPath VARCHAR(500) = NULL , --e.g. g:\sqldata            
    @LogPath VARCHAR(500) = NULL , --e.g. g:\sqllog. If null, will be same as @DataPath.          
    @TotalSizeOnly BIT = 0 , --Do a group by to get total database size info only.   
    @TotalFileGroupSizeOnly BIT = 0, --Do a group by with FileGroupName.  
    @ShowDetails BIT = 1 , --Maintain backwards compatibility with = 1. Otherwise don't show db settings and add datetimestamp for easy storing of results.
	@StoreSizeHistory BIT = 0, --Store filesize info locally in dbops.dbo.DBFileSpaceHistory
--Advanced features:          
    @FullDriveAnalysis BIT = 0 , -- A drive is full (@DriveLetter is not required) and you want to add more files to another location and you typically don't want to move files.          
    @FullDriveNewFileSpaceSizeMB INT = NULL , -- Using @FullDriveAnalysis, how big to make new file. Growth is 10% of that number.          
    @FullDriveNewFileSuffix VARCHAR(10) = NULL , -- Using @FullDriveAnalysis, what should we append to new file to make name unique? e.g. 100, 101          
    @FullDriveFreeSpaceMBThreshold INT = NULL -- Using @FullDriveAnalysis, find files that have no growth and < this amount of free space in MB. e.g. 2000          
WITH RECOMPILE
AS   
BEGIN             

    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
          
    DECLARE @Pointer INT ,  
        @SQL NVARCHAR(2000) ,  
        @DATETIME DATETIME ,  
        @advanced_config INT , -- to hold advance configuration running value from sp_configure      
        @cmdshell_config INT -- to hold advance xp_cmdshell running value from sp_configure      
          
    SET @DATETIME = GETDATE()          
          
    CREATE TABLE #CheckPathExistance  
        (  
          FileExists INT ,  
          FileIsDir INT ,  
          ParentDirExists INT  
        )          
          
    IF @DataPath IS NOT NULL   
        BEGIN          
			--Fix up path to conform for later use:          
            IF RIGHT(@DataPath, 1) <> '\'   
                SET @DataPath = @DataPath + '\'          
          
			--Assume log files are going to same place as data if NULL.          
            IF @DataPath IS NOT NULL  
                AND @Logpath IS NULL   
                SET @LogPath = @DataPath          
			--Fix up path to conform for later use:          
            ELSE   
                IF @LogPath IS NOT NULL  
                    AND RIGHT(@LogPath, 1) <> '\'   
                    SET @LogPath = @LogPath + '\'           
          
			--Check data backup path existance          
            SELECT  @SQL = 'master.dbo.xp_fileexist "' + @DataPath + '"'          
            INSERT  #CheckPathExistance  
                    EXEC ( @SQL )          
          
            IF NOT EXISTS ( SELECT  *  
                            FROM    #CheckPathExistance  
                            WHERE   FileIsDir = 1 )   
                BEGIN          
                    PRINT 'Error - Could not find or connect to data backup folder: '  
                        + @DataPath          
                    DROP TABLE #CheckPathExistance          
                    RETURN 1          
                END          
          
            TRUNCATE TABLE #CheckPathExistance          
          
			--Check log backup path existance          
            SELECT  @SQL = 'master.dbo.xp_fileexist "' + @LogPath + '"'          
            INSERT  #CheckPathExistance  
                    EXEC ( @SQL )          
          
            IF NOT EXISTS ( SELECT  *  
                            FROM    #CheckPathExistance  
                            WHERE   FileIsDir = 1 )   
                BEGIN          
                    PRINT 'Error - Could not find or connect to log backup folder: '  
                        + @LogPath          
                    DROP TABLE #CheckPathExistance          
                    RETURN 1          
                END          
        END--@DataPath IS NOT NULL          
          
           
    IF @DBMove = 1   
        BEGIN          
			-- Unacceptable conditions          
            IF ( @DBMove = 1 AND @DataPath IS NULL )   
                BEGIN            
                    RAISERROR ('@DataPath can''t be null with @DBMove enabled.', 16, 1) WITH NOWAIT          
                    RETURN 1          
                END          
        END --@DBMove = 1          
          
    IF @FullDriveAnalysis = 1   
        BEGIN          
            IF @FullDriveNewFileSpaceSizeMB IS NULL  
                OR @FullDriveNewFileSuffix IS NULL  
                OR @FullDriveFreeSpaceMBThreshold IS NULL   
                BEGIN          
                    RAISERROR ('With @FullDriveAnalysis, you must provide these parameters: @FullDriveNewFileSpaceSizeMB, @FullDriveNewFileSuffix, @FullDriveFreeSpaceMBThreshold.', 16, 1) WITH NOWAIT          
                    RETURN 1          
				END          
            IF @DBName IS NULL  
                AND @DriveLetter IS NULL   
                BEGIN          
                    RAISERROR ('With @FullDriveAnalysis, you must provide @DBName or @DriveLetter to limit results.', 16, 1) WITH NOWAIT          
                    RETURN 1          
                END          
        END          
          
    SET @Pointer = 1            
          
    DECLARE @DBList TABLE  
        (  
          ID INT IDENTITY(1, 1) ,  
          DBName VARCHAR(150) ,  
          FileGroupName VARCHAR(100) ,  
          SQLFileStats VARCHAR(1000)  
        )            
          
    CREATE TABLE #Space  
        (  
          DBName VARCHAR(1000) ,  
          FileGroupName VARCHAR(150) ,  
          LogicalFileName VARCHAR(1000) ,  
          [SpaceUsed] DECIMAL(18, 4) ,  
          FileSizeMB DECIMAL(18, 4) ,  
          [AvailableSpaceMB] DECIMAL(18, 4)  
        )            
          
    CREATE TABLE #DBFileListResults  
        (  
          DBName SYSNAME ,  
          FileGroupName VARCHAR(150) ,  
          LogicalFileName SYSNAME ,  
          FileName NVARCHAR(520) ,  
          FileSizeMB INT ,  
          FreeSpaceMB INT ,  
          FileType VARCHAR(15) ,  
          MaxSize INT,  
          Growth INT,  
          GrowthUnit VARCHAR(2) , 
		  DriveTotalGB SMALLINT,
		  DriveAvailableGB SMALLINT,
		  DrivePercentUsed DECIMAL(5,2) NULL, 
          Compatibility VARCHAR(10) ,  
          RecoveryMode VARCHAR(11) ,  
          Trustworthy BIT ,  
          DBChaining BIT ,  
          FullText BIT ,  
          RO BIT ,  
          Sparse BIT ,  
          DriveLetter CHAR(1)  
        )          
          
-----------------------            
--Populate temp tables.            
-----------------------            

    IF CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR),1, 2), '.', '') AS TINYINT) <= 8   
		RETURN 0
	ELSE IF CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR),1, 2), '.', '') AS TINYINT) >= 11
        INSERT  INTO @DBList ( DBName, SQLFileStats )  
        SELECT  [name],  
                'USE [' + [name] + ']           
SELECT ''' + [name] + ''' AS DBName,   
ds.name as FileGroupName,   
f.name AS LogicalFileName,   
size/128.0 as FileSizeMB,   
size/128.0 - FILEPROPERTY(f.name, ''SpaceUsed'')/128.0 AS AvailableSpaceInMB   
FROM sys.database_files f (NOLOCK)   
Left JOIN sys.data_spaces ds WITH ( NOLOCK ) ON ds.data_space_id = f.data_space_id'  
        FROM sys.databases d 
		LEFT JOIN sys.availability_replicas AS AR
			ON d.replica_id = ar.replica_id
		LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
			ON ars.group_id = AR.group_id AND ars.replica_id = ar.replica_id
		LEFT JOIN sys.dm_hadr_database_replica_cluster_states AS dbcs
			ON ars.replica_id = dbcs.replica_id and d.replica_id = dbcs.replica_id AND d.group_database_id = dbcs.group_database_id
		WHERE state_desc = 'ONLINE'  
		AND (ars.role = 1 OR ISNULL(AR.secondary_role_allow_connections,2) = 2) --Primary or able to read secondary db, no read-intent only dbs.
		AND [Name] = ISNULL(@Dbname, [Name])         
    ELSE 
	    INSERT  INTO @DBList ( DBName, SQLFileStats )  
        SELECT  [name],  
                'USE [' + [name] + ']           
SELECT ''' + [name] + ''' AS DBName,   
ds.name as FileGroupName,   
f.name AS LogicalFileName,   
size/128.0 as FileSizeMB,   
size/128.0 - FILEPROPERTY(f.name, ''SpaceUsed'')/128.0 AS AvailableSpaceInMB   
FROM sys.database_files f (NOLOCK)   
Left JOIN sys.data_spaces ds WITH ( NOLOCK ) ON ds.data_space_id = f.data_space_id'  
        FROM sys.databases d 
		WHERE state_desc = 'ONLINE'  
		AND [Name] = ISNULL(@Dbname, [Name]) 
       
          
    WHILE @Pointer <= ( SELECT MAX(ID) FROM @DBList )   
    BEGIN            
        SELECT  @SQL = SQLFileStats  
        FROM    @DBList  
        WHERE   ID = @Pointer            
          
        INSERT  INTO #Space ( DBName, FileGroupName, LogicalFileName, FileSizeMB, AvailableSpaceMB )  
                EXEC sp_executesql @SQL         
          
        SET @Pointer = @Pointer + 1            
    END            

    INSERT  INTO #DBFileListResults ( DBName, LogicalfileName, FileGroupName,  
                                      [filename], FileSizeMB, FreeSpaceMB,  
                                      FileType, [maxsize], growth, growthunit,  
									  DriveTotalGB, DriveAvailableGB, DrivePercentUsed,
                                      Compatibility, RecoveryMode, Trustworthy,  
                                      DBChaining, Fulltext, RO, Sparse, DriveLetter )  
    SELECT  DB_NAME(d.database_id) AS DBName,  
            f.name AS LogicalFileName, 
			ts.FileGroupName,  
            physical_name AS FileName, 
			CAST(ts.FileSizeMB as INT) as FileSizeMB,
            CAST(ISNULL(ts.[AvailableSpaceMB], 0) as INT) AS FreeSpaceMB,  
            f.type_desc AS FileType,  
            CASE WHEN max_size > 1 THEN max_size / 128  
                    ELSE max_size  
            END AS max_size,  
            CASE WHEN is_percent_growth = 0 THEN growth / 128  
                    ELSE growth  
            END AS Growth,
			CASE WHEN is_percent_growth = 1 THEN '%'  
                                ELSE 'MB'  
                            END AS GrowthUnit,  
		    CAST(total_bytes/1024/1024/1024 as SMALLINT) AS DriveTotalGB,
		    CAST(available_bytes/1024/1024/1024 as SMALLINT) AS DriveAvailableGB,
			CAST((total_bytes - available_bytes) / (total_bytes*1.0) * 100 AS DECIMAL(5,2)) AS DrivePercentUsed,
            CASE WHEN d.compatibility_level < 80 THEN 'SQL7.0'  
                    WHEN d.compatibility_level = 80 THEN 'SQL2000'  
                    WHEN d.compatibility_level = 90 THEN 'SQL2005'  
                    WHEN d.compatibility_level = 100 THEN 'SQL2008'  
                    WHEN d.compatibility_level = 110 THEN 'SQL2012'  
					WHEN d.compatibility_level = 120 THEN 'SQL2014'  
					WHEN d.compatibility_level = 130 THEN 'SQL2016'
					WHEN d.compatibility_level = 140 THEN 'SQL2017'
					WHEN d.compatibility_level > 140 THEN 'SQL2019+'
            END AS Compatibility,  
            d.recovery_model_desc AS RecoveryMode,  
            is_trustworthy_on AS Trustworty,  
            is_db_chaining_on AS DBChaining,  
            is_fulltext_enabled AS [FullText], f.is_read_only AS RO,  
            is_sparse AS Sparse, LEFT(physical_name, 1) AS DriveLetter
    FROM    sys.master_files f WITH ( NOLOCK )  
			LEFT JOIN sys.data_spaces ds WITH ( NOLOCK ) ON ds.data_space_id = f.data_space_id
            JOIN sys.databases d WITH ( NOLOCK ) ON d.database_id = f.database_id
            JOIN #Space ts ON ts.DBName = d.name  
                                AND ts.LogicalFileName = f.name  
			CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.FILE_ID)
    WHERE   d.name = ISNULL(@dbname, d.name)  
    

    IF @StoreSizeHistory = 1 --AND EXISTS (Select name From sys.sysdatabases Where name = 'DBOPS')
		Insert into dbo.DBFileSpaceHistory (DBName, FileGroupName, LogicalFileName, [Filename], FileSizeMB, FreeSpaceMB,FileType, DriveTotalGB, DriveAvailableGB, DrivePercentUsed)
		Select DBName, FileGroupName, LogicalFileName, [Filename], FileSizeMB,  FreeSpaceMB, FileType, DriveTotalGB, DriveAvailableGB, DrivePercentUsed
		From #DBFileListResults
	
    IF @ShowDetails = 0  
        AND @TotalSizeOnly = 0  
        AND @FullDriveAnalysis = 0   
        AND @TotalFileGroupSizeOnly = 0  
        SELECT  @@ServerName, DBName, FileGroupName, LogicalFileName,  
                [Filename], FileSizeMB, FreeSpaceMB, FileType, MaxSize, DriveTotalGB, DriveAvailableGB, DrivePercentUsed,
				Growth, GrowthUnit, @DATETIME AS DateCaptured  
        FROM    #DBFileListResults  
        WHERE   DriveLetter = ISNULL(@DriveLetter, DriveLetter)              
    ELSE   
        IF @ShowDetails = 1  
            AND @TotalSizeOnly = 0  
            AND @FullDriveAnalysis = 0   
            AND @TotalFileGroupSizeOnly = 0  
            SELECT  DBName, FileGroupName, LogicalFileName, [Filename],  
                    FileSizeMB, FreeSpaceMB, FileType, MaxSize, DriveTotalGB, DriveAvailableGB, DrivePercentUsed,
					Growth, GrowthUnit,  Compatibility, RecoveryMode, [Trustworthy],  
                    DBChaining, [FullText], RO, Sparse  
            FROM    #DBFileListResults  
            WHERE   DriveLetter = ISNULL(@DriveLetter, DriveLetter)
			ORDER BY DBName, FileType DESC, FileName
        ELSE   
            IF @TotalSizeOnly = 1  
                AND @FullDriveAnalysis = 0   
                SELECT  DBName, LEFT([Filename], 1) AS DriveLetter, SUM(FileSizeMB) AS FileSizeMB,  
                        SUM(FreeSpaceMB) AS FreeSpaceMB, 
						DriveTotalGB, DriveAvailableGB, DrivePercentUsed,
						@DATETIME AS DateCaptured  
                FROM    #DBFileListResults  
                GROUP BY DBName,LEFT([Filename], 1), DriveTotalGB, DriveAvailableGB, DrivePercentUsed          
            ELSE IF @TotalFileGroupSizeOnly = 1  
                AND @FullDriveAnalysis = 0   
                SELECT  DBName, ISNULL(FileGroupName,'{Log File(s)}'), SUM(FileSizeMB) AS FileSizeMB,  
                        SUM(FreeSpaceMB) AS FreeSpaceMB, CONVERT (DECIMAL(5, 1), ( SUM(FreeSpaceMB) * 100 / CASE WHEN SUM(FileSizeMB) = 0 THEN .0000001 ELSE SUM(FileSizeMB) END )) AS PercentFree,
                        @DATETIME AS DateCaptured  
                FROM    #DBFileListResults  
                GROUP BY DBName, FileGroupName, Compatibility, RecoveryMode, Trustworthy,  
                        DBChaining, FullText, RO, Sparse     
            ELSE IF @FullDriveAnalysis = 1          
                BEGIN          
                    PRINT 'There are no checks for the possibility of the same filegroup and filetype exist at destination, so compare manually to first resultset.           
It maybe better to grow those files instead.'          
                    SELECT  DBName, FileGroupName, FileType, LogicalFileName,  
                            FileName, RecoveryMode,  
                            SUM(FileSizeMB) TotalUsedSpace,  
                            SUM(FreeSpaceMB) TotalFreeSpace,
							DriveTotalGB, DriveAvailableGB, DrivePercentUsed
                    FROM    #DBFileListResults o  
					WHERE   DriveLetter = LEFT(@DataPath, 1)          
						  --AND FileType <> 'LOG'          
						  --AND RecoveryMode <> 'Simple'          
                            AND EXISTS ( SELECT DBName, FileGroupName,  
                                                FileType  
                                         FROM   #DBFileListResults t  
                                         WHERE  DBName IN (  
                                                SELECT DISTINCT  
                                                        DBName  
                                                FROM    #DBFileListResults  
                                                WHERE   DriveLetter = ISNULL(@DriveLetter,  
                                                              DriveLetter) )  
                                                AND t.DBName = o.DBName  
                                                AND t.FileGroupName = o.FileGroupName  
                                                AND t.FileType = o.FileType  
                                         GROUP BY DBName, FileGroupName,  
                                                FileType  
                                         HAVING SUM(FreeSpaceMB) < @FullDriveFreeSpaceMBThreshold )  
                    GROUP BY DBName, FileGroupName, FileType, LogicalFileName,  
                            FileName, RecoveryMode, DriveTotalGB, DriveAvailableGB, DrivePercentUsed       
          
                    SELECT  DBName, FileGroupName, FileType,  
                            SUM(FileSizeMB) TotalUsedSpace,  
                            SUM(FreeSpaceMB) TotalFreeSpace,  
                            CASE WHEN FileType = 'Rows'  
                                 THEN 'ALTER DATABASE [' + DBName  
                                      + '] ADD FILE ( NAME = N''' + DBName  
                                      + @FullDriveNewFileSuffix  
                                      + ''', FILENAME = N''' + @DataPath  
                                      + DBName + @FullDriveNewFileSuffix  
                                      + '.ndf'', SIZE = '  
                                      + CAST(@FullDriveNewFileSpaceSizeMB AS VARCHAR(7))  
                                      + 'MB, FILEGROWTH = '  
                                      + CAST(@FullDriveNewFileSpaceSizeMB / 10 AS VARCHAR(7))  
                                      + 'MB) TO FILEGROUP [' + FileGroupName  
                                      + ']'  
                                 WHEN RecoveryMode <> 'SIMPLE'  
                                 THEN 'ALTER DATABASE [' + DBName  
                                      + '] ADD LOG FILE ( NAME = N''' + DBName  
                                      + @FullDriveNewFileSuffix  
                                      + ''', FILENAME = N''' + @LogPath  
                                      + DBName + @FullDriveNewFileSuffix  
                                      + '.ndf'' , SIZE = 300MB , FILEGROWTH = 300MB)'  
                                 ELSE '--Skipping extra log file as DB is in Simple recovery mode'  
                            END AS CodeToRun  
                    FROM    #DBFileListResults  
                    WHERE   DBName IN (  
                            SELECT DISTINCT  
                                    DBName  
                            FROM    #DBFileListResults  
                            WHERE   DriveLetter = ISNULL(@DriveLetter,  
                                                         DriveLetter) )  
                    GROUP BY DBName, FileGroupName, FileType, RecoveryMode  
                    HAVING  SUM(FreeSpaceMB) < @FullDriveFreeSpaceMBThreshold          
          
                    RETURN 0--all good and remaining options don't apply.          
                END  
   
	-- Print out code to move database files to new location.          
    IF @DBMove = 1   
        BEGIN          
			--Get the actual configuration values from sys table      
            SELECT  @advanced_config = CAST(value_in_use AS INT)  
            FROM    sys.configurations  
            WHERE   name = 'show advanced options' ;      
      
            SELECT  @cmdshell_config = CAST(value_in_use AS INT)  
            FROM    sys.configurations  
            WHERE   name = 'xp_cmdshell' ;      
      
			--if xp_cmdshell is not enabled then display the command to reconfigure      
            IF @cmdshell_config = 0   
                BEGIN      
                    IF @advanced_config = 0   
                        BEGIN      
                            SELECT  'EXEC sp_configure '  
                                    + '''show advanced options'', 1; RECONFIGURE;'      
                        END      
                    SELECT  'EXEC sp_configure '  
                            + '''xp_cmdshell'', 1; RECONFIGURE;'      
                END      
       
            SELECT  'ALTER DATABASE ' + QUOTENAME(DBName)  
                    + ' MODIFY FILE ( NAME =N''' + LogicalFileName  
                    + ''', filename='''  
                    + CASE WHEN FileType = 'Rows' THEN @DataPath  
                           ELSE @LogPath  
                      END + REVERSE(SUBSTRING(REVERSE(filename), 0,  
                                              CHARINDEX('\', REVERSE(filename),  
                                                        1))) + ''');'  
                    + CHAR(13) + CHAR(10)  
            FROM    #DBFileListResults  
            WHERE   dbname = ISNULL(@dbname, dbname)  
                    AND DriveLetter = ISNULL(@DriveLetter, DriveLetter)           
          
            SELECT  DISTINCT  
                    'ALTER DATABASE ' + QUOTENAME(DBName) + ' SET OFFLINE;'  
                    + CHAR(13) + CHAR(10)  
            FROM    #DBFileListResults  
            WHERE   dbname = ISNULL(@dbname, dbname)  
                    AND DriveLetter = ISNULL(@DriveLetter, DriveLetter)          
          
            SELECT  'exec xp_cmdshell ''copy "' + FileName + '" "'  
                    + CASE WHEN FileType = 'Rows' THEN @DataPath  
                           ELSE @LogPath  
                      END + REVERSE(SUBSTRING(REVERSE(filename), 0,  
                                              CHARINDEX('\', REVERSE(filename),  
                                                        1))) + '"' + ''';'  
                    + CHAR(13) + CHAR(10)  
            FROM    #DBFileListResults  
            WHERE   dbname = ISNULL(@dbname, dbname)  
                    AND DriveLetter = ISNULL(@DriveLetter, DriveLetter)           
          
            SELECT  DISTINCT  
                    'ALTER DATABASE ' + QUOTENAME(DBName) + ' SET ONLINE;'  
            FROM    #DBFileListResults  
            WHERE   dbname = ISNULL(@dbname, dbname)  
                    AND DriveLetter = ISNULL(@DriveLetter, DriveLetter)           
           
            SELECT  'exec xp_cmdshell ''del "' + FileName + '"'';' + CHAR(13)  
                    + CHAR(10)  
            FROM    #DBFileListResults  
            WHERE   dbname = ISNULL(@dbname, dbname)  
                    AND DriveLetter = ISNULL(@DriveLetter, DriveLetter)  
                      
   --Reset configuration values for xp_cmdshell AND advanced options      
       
            IF @cmdshell_config = 0   
                BEGIN      
                    SELECT  'EXEC sp_configure '  
                            + '''xp_cmdshell'', 0; RECONFIGURE;'      
                    IF @advanced_config = 0   
                        BEGIN      
                            SELECT  'EXEC sp_configure '  
                                    + '''show advanced options'', 0; RECONFIGURE;'      
                        END      
                END      
        END--if @DataMove = 1            
    ELSE   
        IF @StopGrowth = 1  
            AND @DriveLetter IS NOT NULL   
            BEGIN          
                SELECT  'ALTER DATABASE ' + QUOTENAME(DBName)  
                        + ' MODIFY FILE ( NAME =N''' + LogicalFileName  
                        + ''', FILEGROWTH = 0)'  
                FROM    #DBFileListResults  
                WHERE   dbname = ISNULL(@dbname, dbname)  
                        AND DriveLetter = @DriveLetter  
                        AND Growth <> 0          
            END          
          
END--proc            
;
