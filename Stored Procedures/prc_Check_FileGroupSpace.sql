SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
  
CREATE OR ALTER PROCEDURE dbo.prc_Check_FileGroupSpace
	@Dbname VARCHAR(100) = NULL ,  
	@Operation VARCHAR(10) = 'SHOW' , -- If 'LOG', it will write results to table DBFileGroupSpaceResultsHistory.
	@EmailAlert BIT = 0 , -- Email alert
	@LargeDBSizeMB INT = 100000, --100GB is default large DB size.
	@MediumDBSizeMB INT = 20000, --20GB is default medium DB size.
	@PercentSml DECIMAL(5, 1) = 20.0 , --Used for Warning Percent Free Space < @MediumDBSizeMB
	@PercentMed DECIMAL(5, 1) = 10.0 , --Used for Warning Percent Free Space between @MediumDBSizeMB <= @LargeDBSizeMB
	@PercentLrg DECIMAL(5, 1) = 5.0 ,  --Used for Warning Percent Free Space > @LargeDBSizeMB
	@PercentCritical DECIMAL(5, 1) = 4.0 , --Used for any size DB.
	@NotificationEmail varchar(1000) = NULL, --It will lookup default IT Ops email in dbops.dbo.ProcessParameter
	@TLogThreshold TINYINT = 50
AS   
BEGIN                 
/*******************************************************************************                
** Procedure: prc_Check_FileGroupSpace              
**                
** Purpose: To proactively check for filegroup available space and make some recommendations on the changes that you may want to implement,
**		or add to exception table if you just want to ignore. It can either be run interactively and display results, email team and/or log to a table.
**		There are 3 classifications of databases sizes that are hardcoded in the proc. The percent free space based on these sizes are parameters.

-- Example with multiple files in filegroup: This proc will report number of files in filegroup that you will need to modify.
-- ALTER DATABASE [Analytics] MODIFY FILE (NAME = [testdb] [testdb_Data2], SIZE =  *Multiple Logical Files, Size is Avg.* 30MB)
** Notice that it includes all the logical file names, space delimited and quoted, for easy modification!
-- INSERT INTO DBOPS.DBO.DBFileGroupExceptions (DBName,FileGroupName,PercentFree, ExceptionReason)
-- VALUES ('Analytics','PRIMARY',5.0,'Give a reason here.')
-- To get detailed file info: exec sp_dbfilespaceallocation @dbname = 'Analytics' (This should be your Ctrl-4 key combination if you programmed in SSMS).

*******************************************************************************
**  Created  08/22/2013 Chuck Lathrope
*******************************************************************************
**  Altered		By				Description
**  9/9/2013	Chuck Lathrope	Convert to emailing results. Bug fixes for small db files.
**  12/8/2014	Chuck Lathrope  Added non-readable AG database check
**	2/8/2015	Chuck Lathrope	Add non-optimal settings check and recommendation
**  12/18/2015  Chuck Lathrope  Limited to primary and fully readable AG databases.
**  3/9/2016	Melanie Labuguen Add check for transaction log usage threshold. Added WarningLevel = 3.
**  7/13/2016	Melanie Labuguen Moved tempdb and model transaction log usage threshold into own threshold level. Added WarningLevel = 4.
*******************************************************************************************/     

/*
--Debug: 
Declare @Operation VARCHAR(10) = 'ALERT' ,
	@Dbname VARCHAR(100) ,
	@LargeDBSizeMB INT = 200000, --200GB is default large DB size.
	@MediumDBSizeMB INT = 20000,
    @PercentSml DECIMAL(5, 1)  ,  
	@PercentMed DECIMAL(5, 1)  ,  
	@PercentLrg DECIMAL(5, 1)  ,
	@PercentCritical DECIMAL(5, 1) ,
	@MinimumDBSizeMB int ,
	@NotificationEmail varchar(1000),
	@EmailAlert BIT = 0
		    
	SET @PercentSml = 20
	SET @PercentMed = 10
	SET @PercentLrg = 5
	SET @PercentCritical = 4.0
	SET @EmailAlert = 0
*/
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  
              
    DECLARE @Pointer INT ,  
        @SQL NVARCHAR(2000) ,
		@LogicalNameList VARCHAR(2000) ,

		@tableHTML  NVARCHAR(MAX),
		@SubjectMsg VARCHAR(75)

	IF @NotificationEmail is null
	BEGIN
		SELECT @NotificationEmail = ParameterValue --Select *
		FROM dbo.ProcessParameter 
		WHERE ParameterName = 'IT Ops Team Escalation'

		--If no matching rows, default email to:
		SELECT COALESCE(@NotificationEmail,'alerts@YourDomainNameHere.com')
	END

	SET @Pointer = 1                
              
    DECLARE @DBList TABLE (  
            ID INT IDENTITY(1, 1) ,  
            DBName VARCHAR(150) ,  
            FileGroupName VARCHAR(100) ,  
            SQLFileStats NVARCHAR(1000)  
        )                
        
    IF object_id('tempdb..#FileSpace') IS NOT NULL 
		DROP TABLE #FileSpace 
        
    CREATE TABLE #FileSpace  
        (  
            DBName VARCHAR(1000) ,  
            FileGroupName VARCHAR(150) ,  
            LogicalFileName VARCHAR(1000) ,  
            FileSizeMB DECIMAL(18, 4) ,  
            FileAvailableSpaceMB DECIMAL(18, 4)  
        )

    IF object_id('tempdb..#DBFileListResults') IS NOT NULL 
		DROP TABLE #DBFileListResults
        
    CREATE TABLE #DBFileListResults  
        (  
            DBName SYSNAME ,  
            FileGroupName VARCHAR(150) , 
			FileType VARCHAR(15) , 
			FGSizeDesc CHAR(3) NULL , --SML, MED, LRG
            FGSizeMB INT ,  
            FGFreeSpaceMB NUMERIC ,  
            FGGrowthMB INT ,  
			IsPercentGrowth tinyint,
            FGFileCount SMALLINT ,
			FGReadOnly BIT , --Is the filegroup read-only?
            PercentFree DECIMAL(5, 1),
            WarningLevel TINYINT NULL,
			LogicalFileNames VARCHAR(2000)         
        ) 

-----------------------                
--Populate temp tables.                
-----------------------                
              
    IF CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR), 1, 2), '.', '') AS TINYINT) > 10   
        INSERT  INTO @DBList ( DBName, SQLFileStats )  
            SELECT  [name] ,  
N'USE [' + [name] + ']               
SELECT ''' + [name] + ''' AS DBName,       
ds.name as FileGroupName,       
f.name AS LogicalFileName,       
size/128.0 as FileSizeMB,       
size/128.0 - FILEPROPERTY(f.name, ''SpaceUsed'')/128.0 AS FileAvailableSpaceMB       
FROM sys.database_files f WITH (NOLOCK)       
Left JOIN sys.data_spaces ds WITH ( NOLOCK ) ON ds.data_space_id = f.data_space_id
WHERE f.type in (0,1) and size/128 > 0'  --Data or Log files only and significant size. --select *
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
    ELSE IF CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR), 1, 2), '.', '') AS TINYINT) > 8   
        INSERT  INTO @DBList ( DBName, SQLFileStats )  
            SELECT  [name] ,  
N'USE [' + [name] + ']               
SELECT ''' + [name] + ''' AS DBName,       
ds.name as FileGroupName,       
f.name AS LogicalFileName,       
size/128.0 as FileSizeMB,       
size/128.0 - FILEPROPERTY(f.name, ''SpaceUsed'')/128.0 AS FileAvailableSpaceMB       
FROM sys.database_files f WITH (NOLOCK)       
Left JOIN sys.data_spaces ds WITH ( NOLOCK ) ON ds.data_space_id = f.data_space_id
WHERE f.type in (0,1) and size/128 > 0'  --Data or Log files only and significant size. --select *
            FROM sys.databases d 
			WHERE DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
			AND [Name] = ISNULL(@Dbname, [Name])    

	ELSE
        RAISERROR('Too old a version of SQL',16,1) 
              
    WHILE @Pointer <= ( SELECT MAX(ID) FROM @DBList )   
    BEGIN                
        SELECT  @SQL = SQLFileStats  
        FROM    @DBList  
        WHERE   ID = @Pointer                
              
        INSERT  INTO #FileSpace  
                ( DBName ,  
                    FileGroupName ,  
                    LogicalFileName ,  
                    FileSizeMB ,  
                    FileAvailableSpaceMB   
                )  
        EXEC sp_executesql @SQL              


        SET @Pointer = @Pointer + 1                
    END                

    INSERT  INTO #DBFileListResults  
        (   DBName ,  
			FileGroupName ,  
			FileType ,
			FGReadOnly ,
            FGSizeMB ,  
            FGFreeSpaceMB ,  
            FGGrowthMB ,
            FGFileCount ,
            PercentFree 
        )  
        SELECT  DB_NAME(d.database_id) AS DBName ,  
                CASE WHEN ts.FileGroupName is NULL THEN '-LOG-' ELSE ts.FileGroupName END, 
				type_desc AS FileType ,  
				f.is_read_only ,
                SUM(ts.FileSizeMB) AS FileSizeMB ,  
                SUM(ISNULL(ts.FileAvailableSpaceMB, 0)) AS FGFreeSpaceMB ,  
                SUM(CASE WHEN is_percent_growth = 0 THEN growth / 128  
                    ELSE ts.FileSizeMB*growth/100
					END) AS FGGrowthMB ,
                COUNT(*) AS FGFileCount ,
				CONVERT (DECIMAL(5, 1), ( SUM(ts.FileAvailableSpaceMB) * 100.0 / SUM(ts.FileSizeMB))) 'PercentFree'
        FROM    sys.master_files f WITH ( NOLOCK )  
                JOIN sys.databases d WITH ( NOLOCK ) ON d.database_id = f.database_id 
                JOIN #FileSpace ts ON ts.DBName = d.name  
                                    AND ts.LogicalFileName = f.name  
        WHERE   d.name = ISNULL(@dbname, d.name)  
                AND d.is_read_only = 0  --Database is not read only
        GROUP BY DB_NAME(d.database_id), ts.FileGroupName, type_desc, f.is_read_only
        HAVING SUM(ts.FileSizeMB) > 0 --Excludes weird small files.

------------------------------------------
-- Update table
------------------------------------------

	--Update IsPercentGrowth
	UPDATE t1
	SET IsPercentGrowth = t.IsPercentGrowth
	FROM 
		(SELECT d.name, MAX(CAST(f.is_percent_growth AS TINYINT)) AS IsPercentGrowth 
		FROM sys.master_files f WITH ( NOLOCK )  
		JOIN sys.databases d WITH ( NOLOCK ) ON d.database_id = f.database_id 
		GROUP BY d.name) t
    JOIN #DBFileListResults t1 ON t1.DBName = t.name  

	--Update exceptions
	UPDATE t1
	SET WarningLevel = CASE WHEN t1.PercentFree >= ex.PercentFree THEN 0 ELSE NULL END
		,FGSizeDesc = CASE WHEN FGSizeMB >= @LargeDBSizeMB THEN 'LRG'
				WHEN FGSizeMB >= @MediumDBSizeMB AND FGSizeMB < @LargeDBSizeMB THEN 'MED'
				WHEN FGSizeMB < @MediumDBSizeMB THEN 'SML'
				END
	FROM #DBFileListResults t1
	JOIN DBOPS.dbo.DBFileGroupExceptions ex ON t1.DbName = ex.DbName 
		AND t1.FileGroupName = ISNULL(ex.FileGroupName,'-LOG-')
		
	--Update remaining rows and update FGSizeDesc.
    UPDATE t1 
		SET FGSizeDesc = CASE WHEN FGSizeMB >= @LargeDBSizeMB THEN 'LRG'
				WHEN FGSizeMB >= @MediumDBSizeMB AND FGSizeMB < @LargeDBSizeMB THEN 'MED'
				WHEN FGSizeMB < @MediumDBSizeMB THEN 'SML'
				END,
			WarningLevel = CASE WHEN t1.PercentFree <= @PercentCritical
				THEN 2 --Less than @PercentCritical free is critical state if not in exception above.
				WHEN ((t1.PercentFree < @PercentLrg AND FGSizeMB >= @LargeDBSizeMB )
						OR (t1.PercentFree < @PercentMed AND FGSizeMB BETWEEN @MediumDBSizeMB AND @LargeDBSizeMB )
						OR (t1.PercentFree < @PercentSml AND FGSizeMB < @MediumDBSizeMB )) 
				THEN 1 --Warning level
				END 
    FROM  #DBFileListResults t1
    WHERE t1.WarningLevel IS NULL

	--Update logical file names, make a list if multiple files in FG
	Update r		--Select DBName, FileGroupName, STUFF(p.n, 1, 1, '') AS LogicalList
	Set LogicalFileNames = STUFF(p.n, 1, 1, '') 
	FROM (SELECT Distinct DBName, FileGroupName from #FileSpace) F1
	Join #DBFileListResults r on r.DBName = F1.DBName AND r.FileGroupName = ISNULL(F1.FileGroupName,'-LOG-') 
	CROSS APPLY	(
		SELECT ',' + LogicalFileName  
		FROM #FileSpace F2
		WHERE F1.DBName = F2.DBName AND ISNULL(F1.FileGroupName,'') = ISNULL(F2.FileGroupName,'')
		FOR XML PATH('')) AS p(n)

	--Added 3/9/16: Update for log file percent free.
    UPDATE	#DBFileListResults
	SET		WarningLevel = 3
    FROM	#DBFileListResults
    WHERE	FileType = 'LOG'
			AND
			PercentFree <= @TLogThreshold
			AND
			DBName not in ('tempdb','model')	--Added 7/13/16: Remove from default threshold

	--Added 7/13/16: Update for tempdb and model
    UPDATE	#DBFileListResults
	SET		WarningLevel = 4
    FROM	#DBFileListResults
    WHERE	FileType = 'LOG'
			AND
			PercentFree <= 20
			AND
			DBName in ('tempdb','model')

--Debug
--select --@PercentLrg,@PercentMed,@PercentSml,@LargeDBSizeMB,@MediumDBSizeMB,
--*
--from #DBFileListResults
--where WarningLevel >= 1
--Select * from #FileSpace
--SELECT * FROM #DBFileListResults

------------------------------------------      
-- Save results if not a DBA investigation.
------------------------------------------      
 
    IF @Operation = 'LOG'
    BEGIN
		INSERT INTO dbo.DBFileGroupSpaceResultsHistory
					(DBName
					,FileGroupName
					,FGSizeDesc
					,FGSizeMB
					,FGFreeSpaceMB
					,FileType
					,FGGrowthMB
					,FGFileCount
					,FGReadOnly
					,PercentFree
					,WarningLevel)
		SELECT DBName, FileGroupName, FGSizeDesc, FGSizeMB, FGFreeSpaceMB, FileType, FGGrowthMB, FGFileCount, FGReadOnly, PercentFree, WarningLevel
		FROM #DBFileListResults
	END
 
-------------------------------------------------      
-- Show Results or email alert.
-------------------------------------------------      
		
	IF @EmailAlert = 0
	BEGIN
		SELECT DBName, FileGroupName, FGFileCount, FileType, FGSizeDesc, FGSizeMB, FGFreeSpaceMB, FGGrowthMB, PercentFree, WarningLevel,
		CASE WarningLevel
			WHEN 3 THEN 'Percent free for Log file is above the threshold (' + CAST(@TLogThreshold AS varchar(2)) + '%). Please investigate.'
			WHEN 4 THEN 'Percent free for Log file is above the threshold (80%). Please investigate.'
		ELSE
			'ALTER DATABASE ' + QUOTENAME(DBName) + ' MODIFY FILE (NAME = '
			+ '[' + REPLACE(LogicalFileNames,',','] [') + ']'
			+ ', SIZE = '
			+ CASE WHEN FGFileCount > 1 THEN '*Multiple Logical Files, Size is Avg.* ' ELSE '' END 
			+ CASE WHEN FGSizeMB < 25 THEN '25'  
					--Add 5% to existing size and divide by number of files in FG.
					WHEN FGSizeDesc = 'LRG' THEN CAST(CAST(ROUND((FGSizeMB + ( 5+@PercentLrg)/100.0 * FGSizeMB)/FGFileCount,-4) AS INT) AS VARCHAR(20))
					WHEN FGSizeDesc = 'MED' THEN CAST(CAST(ROUND((FGSizeMB + ( 5+@PercentMed)/100.0 * FGSizeMB)/FGFileCount,-3) AS INT) AS VARCHAR(20))
					WHEN FGSizeDesc = 'SML' THEN CAST(CAST(ROUND((FGSizeMB + (10+@PercentSML)/100.0 * FGSizeMB)/FGFileCount,-1) AS INT) AS VARCHAR(20))
				END + 'MB ' 
			+ CASE WHEN FGGrowthMB < 25 AND FGSizeDesc = 'SML' THEN ', FileGrowth = 25MB' 
				   WHEN FGGrowthMB < 400 AND FGSizeDesc = 'MED' THEN ', FileGrowth = 400MB' 
				   WHEN FGGrowthMB < 1000 AND FGSizeDesc = 'LRG' THEN ', FileGrowth = 1000MB' 
				ELSE '' END
			+ ') ' + CHAR(13) + CHAR(10) 
			+ '--INSERT INTO DBOPS.DBO.DBFileGroupExceptions (DBName,FileGroupName,PercentFree, ExceptionReason)' + CHAR(13) + CHAR(10)
			+ '--VALUES (''' + DBName + ''',''' + FileGroupName + ''',' + CAST(PercentFree AS VARCHAR(10)) + ',''Give a reason here.'')'
		END
			AS [Recommended Example DB File Changes]
		FROM #DBFileListResults fg
		WHERE WarningLevel >= 1
		AND FGReadOnly = 0  --Filegroup is not read only
		ORDER BY WarningLevel DESC, PercentFree
		
		IF EXISTS (SELECT * FROM #DBFileListResults WHERE IsPercentGrowth > 0 OR FGSizeMB < 25)
			SELECT '--Non optimal settings detected on a db, please run: exec master.dbo.sp_dbfilesizegrowth' AS DBSettingsIssueDetected
	END
	ELSE --Generate email to send
	BEGIN
		--Set Email Subject Message
		IF EXISTS (SELECT * FROM #DBFileListResults WHERE WarningLevel IN (3,4))
			SELECT @SubjectMsg = 'Server ' + @@SERVERNAME + ' has CRITICAL level database transaction log space issue.'-- on ' + @DBNameList  
		ELSE IF EXISTS (SELECT * FROM #DBFileListResults WHERE WarningLevel = 2)
			SELECT @SubjectMsg = 'Server ' + @@SERVERNAME + ' has CRITICAL level database filegroup space issue.'-- on ' + @DBNameList
		ELSE IF EXISTS (SELECT * FROM #DBFileListResults WHERE WarningLevel = 1)
			SELECT @SubjectMsg = 'Server ' + @@SERVERNAME + ' has Warning level database filegroup space issue.'-- on ' + @DBNameList
		ELSE Return

		SELECT @tableHTML = 
		N'<table border="1" cellpadding="0" cellspacing="0">' + '<tr>' + 
		'<th>DB Name</th>' +      
		'<th>Filegroup Name</th>' + 
		'<th>FG File Count</th>' + 
		'<th>File Type</th>' + 
		'<th>FG Size Desc</th>' + 
		'<th>FG Size MB</th>' + 
		'<th>FG FreeSpace MB</th>' + 
		'<th>FG Growth MB</th>' + 
		'<th>Percent Free</th>' + 
		'<th>Warning Level</th>' + 
		'<th>Recommendations - Increase file size, or add exception. Estimate sizes used.</th></tr>' +      
		CAST ( ( SELECT td=DBName, '',
		td=FileGroupName, '', 
		td=FGFileCount, '', td=FileType, '', td=FGSizeDesc, '',
		td=FGSizeMB, '', td=FGFreeSpaceMB, '', td=FGGrowthMB, '', td=PercentFree, '',
		td=CASE WHEN WarningLevel = 1 THEN 'Warning' ELSE 'CRITICAL' END, '',
		td=CASE WarningLevel
			WHEN 3 THEN 'Percent free for Log file is above the threshold (' + CAST(@TLogThreshold AS varchar(2)) + '%). Please investigate.'
			WHEN 4 THEN 'Percent free for Log file is above the threshold (80%). Please investigate.'
			ELSE
				'ALTER DATABASE ' + QUOTENAME(DBName) + ' MODIFY FILE (NAME = '
				+ '[' + REPLACE(LogicalFileNames,',','] [') + ']'
				+ ', SIZE = ' 
				+ CASE WHEN FGFileCount > 1 THEN '*Multiple Logical Files, Size is Avg.* ' ELSE '' END 
				+ CASE WHEN FGSizeMB < 25 THEN '25'
						--Add 5% to existing size and divide by number of files in FG.
						WHEN FGSizeDesc ='LRG' THEN CAST(CAST(ROUND((FGSizeMB + (5+@PercentLrg)/100.0 * FGSizeMB)/FGFileCount,-4) AS INT) AS VARCHAR(20))
						WHEN FGSizeDesc = 'MED' THEN CAST(CAST(ROUND((FGSizeMB + (5+@PercentMed)/100.0 * FGSizeMB)/FGFileCount,-3) AS INT) AS VARCHAR(20))
						WHEN FGSizeDesc = 'SML' THEN CAST(CAST(ROUND((FGSizeMB + (10+@PercentSML)/100.0 * FGSizeMB)/FGFileCount,-1) AS INT) AS VARCHAR(20))
					END + 'MB ' 
				+ CASE WHEN FGGrowthMB < 25 AND FGSizeDesc = 'SML' THEN ', FileGrowth = 25MB' 
					   WHEN FGGrowthMB < 400 AND FGSizeDesc = 'MED' THEN ', FileGrowth = 400MB' 
					   WHEN FGGrowthMB < 1000 AND FGSizeDesc = 'LRG' THEN ', FileGrowth = 1000MB' 
					ELSE '' END
				+ ') '
				+ '--INSERT INTO DBOPS.DBO.DBFileGroupExceptions (DBName,FileGroupName,PercentFree, ExceptionReason) '
				+ '--VALUES (''' + DBName + ''',''' + FileGroupName + ''',' + CAST(PercentFree AS VARCHAR(10)) + ',''Give a reason here.'')' + CHAR(13) + CHAR(10)
				+ CASE WHEN IsPercentGrowth = 1 OR FGSizeMB < 25 THEN  CHAR(13) + CHAR(10) + '--Non optimal settings detected on db, please run:'
				+ CHAR(13) + CHAR(10) + 'exec master.dbo.sp_dbfilesizegrowth ''' + DBName + '''' ELSE '' END
			END
		FROM #DBFileListResults
		WHERE WarningLevel >= 1
		AND FGReadOnly = 0  --Filegroup is not read only
		ORDER BY WarningLevel DESC, PercentFree
		FOR XML PATH('tr'), TYPE       
		) AS NVARCHAR(MAX) )   
		+ N'</table> <p>This alert came from prc_Check_FileGroupSpace. You can also see detailed file size information with sp_dbfilespaceallocation. '
		+'If a file group has multiple files, use sp_dbfilespaceallocation to figure out which file(s) to grow as the size this proc gives is an average of all files.</p>' ;
		
		--Add note if bad settings are detected.
		IF EXISTS (SELECT * FROM #DBFileListResults WHERE IsPercentGrowth > 0 OR FGSizeMB < 25)
				SELECT @tableHTML = @tableHTML + CHAR(13) + CHAR(10) + '--Non optimal settings detected on a db, please run:'
			+ CHAR(13) + CHAR(10) + 'exec master.dbo.sp_dbfilesizegrowth'
		;  
		
		EXEC prc_InternalSendMail         
			@Address = @NotificationEmail,
			@Subject = @subjectMsg,          
			@Body = @tableHTML,   
			@HTML  = 1  

	END--IF @EmailAlert = 0

END--proc
;
GO
