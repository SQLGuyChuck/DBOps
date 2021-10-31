USE DBOPS
GO
IF (OBJECT_ID('dbo.PRC_DBA_SsisPackagesBackup') IS NULL)
BEGIN
	EXEC('create procedure dbo.PRC_DBA_SsisPackagesBackup as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.[PRC_DBA_SsisPackagesBackup].'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.[PRC_DBA_SsisPackagesBackup].'
	END
END

PRINT 'Altering Procedure: dbo.[PRC_DBA_SsisPackagesBackup]'
GO

/******************************************************************************  
**  File: $/ITDBOps/DBA/DBOps/StoredProcedures/PRC_DBA_SsisPackagesBackup.sql
**  Name: PRC_DBA_SsisPackagesBackup 
**  Desc: Backup SSIS packages folders except for files > 1GB to remote backup share.
**  Auth: Golla gurunadha  
**  Date: 12/28/2011
*******************************************************************************  
**  Change History  
*******************************************************************************  
**  Date:		Author:			Description:  
**  4/22/2013	Chuck Lathrope	Modified robocopy parameters.
**  5/14/2013	Chuck Lathrope	Added 2 to list of ok robocopy return statements for nothing to do.
**  6/3/2013	Chuck Lathrope	Improved cursor closing code.
**	09/06/2013	Matias Sincovich	Corrected ROBOCOPY ReturnCode handle.  link: http://support.microsoft.com/kb/954404
*******************************************************************************/  
ALTER PROCEDURE [dbo].[PRC_DBA_SsisPackagesBackup] 
	@SsisBackupPath varchar(400) = '\\sjl01magent02.prod.dm.local\backup02\SSISShareBackups'
AS
BEGIN

SET NOCOUNT ON

DECLARE @advanced_config INT -- to hold advance configuration running value from sp_configure 
	, @cmdshell_config INT -- to hold advance xp_cmdshell running value from sp_configure 
	, @sqlCommand VARCHAR(2000)
	, @RoboCopyCommand VARCHAR(2000) -- database name  
	, @ReturnCode INT --cmdshell return code
    , @ErrorMessage varchar(2000) --cmdshell return info

IF SUBSTRING(REVERSE(RTRIM(@SsisBackupPath)),1,1) <> '\'
	SET @SsisBackupPath = RTRIM(@SsisBackupPath) + '\'

SELECT @SsisBackupPath=@SsisBackupPath+REPLACE(@@SERVERNAME,'\','_')+'\'

SET @ErrorMessage = ''

IF OBJECT_ID('tempdb..#xp_fileexist_output') IS NOT NULL 
   DROP TABLE #xp_fileexist_output;

IF OBJECT_ID('tempdb..#SsisPackagesInfo') IS NOT NULL
	DROP TABLE #SsisPackagesInfo;

/*SP_CONFIGURE,XP_CMDSHELL ENABLE*/
--Get cmdshell & advanced configuration values from sys table 
SELECT @advanced_config = CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'show advanced options' ; 
SELECT @cmdshell_config = CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell' ; 
--If xp_cmdshell is disabled then enable it
IF @cmdshell_config = 0 
BEGIN 
	IF @advanced_config = 0 
	BEGIN 
		EXEC sp_configure 'show advanced options', 1; RECONFIGURE; 
	END 
	EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE; 
END 

--Create temp table to hold result of xp_cmdshell output
CREATE TABLE #temp (ResultsColumn VARCHAR(2000))

/* CHECKS BACKUP FOLDER EXIST, IF NOT CREATE IT */
--Create the temp table
CREATE TABLE #xp_fileexist_output ([FILE_EXISTS] int not null, [FILE_IS_DIRECTORY] Int not null, [PARENT_DIRECTORY_EXISTS] int not null)

--Insert into the temp table
INSERT INTO #xp_fileexist_output 
Exec xp_fileexist @SsisBackupPath 

--Find if at least the parent directory exists to validate the path.
IF (SELECT [PARENT_DIRECTORY_EXISTS] FROM #xp_fileexist_output) = 0
BEGIN
	RAISERROR ('Parent directory does not exist or we cannot access',16,1)
	RETURN 50000
END

/* PUSH SSIS PACKAGES INFORMATION TO A TEMP TABLE */
CREATE TABLE #ssispackagesinfo(SSISpackageName varchar(300) Default(''),SSISpackagesource varchar(3000) Default(''))

INSERT INTO #SsisPackagesInfo(SSISpackagesource) 
SELECT js.command 
FROM msdb.dbo.sysjobs j 
JOIN msdb.dbo.sysjobsteps js ON js.job_id = j.job_id  
WHERE Js.subsystem ='ssis' and js.command like '/File%'


/* CHECKS SSIS PACKAGES EXISTS */
IF (SELECT COUNT(*) FROM #SsisPackagesInfo)<>0 
BEGIN
	IF (SELECT FILE_IS_DIRECTORY FROM #xp_fileexist_output)=0 --Check to see if the directory Dir exist or not, IF NOT CREATE
	BEGIN        
		SELECT @SsisBackupPath = 'mkdir ' + @SsisBackupPath
		EXEC @ReturnCode = master.dbo.xp_cmdshell @SsisBackupPath

		IF @ReturnCode <> 0 
		BEGIN
			PRINT 'Error occurred: @ReturnCode = ' + CAST(@ReturnCode AS VARCHAR(5))
			GOTO ResetOptions
		END
		ELSE
			SELECT @SsisBackupPath = REPLACE(@SsisBackupPath,'mkdir ','')
	END

	--Now we should have created the missing server folder in destination, lets repopulate our existance temp table
	TRUNCATE Table #xp_fileexist_output

	INSERT INTO #xp_fileexist_output 
	Exec xp_fileexist @SsisBackupPath 
END
ELSE --IF NO SSIS PACKAGES THEN DISPLAY THE BELOW INFO
	PRINT @@servername+': NO SSIS packages on this server, nothing to do.'

/* IF SSIS PACKAGES EXISTS THEN COPY THEM TO BACKUP LOCATION*/
IF (SELECT FILE_IS_DIRECTORY FROM #xp_fileexist_output)=1
BEGIN
	/* TRANSFER SSIS PACKAGES TO BACKUP LOCATION*/
	--Get just the reverse of the dtsx and its path
	UPDATE #SsisPackagesInfo SET SSISpackagesource=SUBSTRING(REVERSE(SUBSTRING(SSISpackagesource, 1, CHARINDEX('.dtsx',SSISpackagesource) + 4)),1,CHARINDEX('"',REVERSE(SUBSTRING(SSISpackagesource, 1, CHARINDEX('.dtsx',SSISpackagesource) + 4)))-1)
	--Remove file name
	UPDATE #SsisPackagesInfo SET SSISpackagesource=REVERSE(SUBSTRING(SSISpackagesource,CHARINDEX('\',SSISpackagesource,1)+1,LEN(SSISpackagesource)-CHARINDEX('\',SSISpackagesource,1)+1))
	--Get last foldername for use in 
	UPDATE #SsisPackagesInfo SET SSISpackageName=REVERSE(SUBSTRING(REVERSE(SSISpackagesource),1,CHARINDEX('\',REVERSE(SSISpackagesource))-1))
	--Create backup path commands
	UPDATE #SsisPackagesInfo SET SSISpackagesource='Robocopy "'+SSISpackagesource+'" "'+@SsisBackupPath+SSISpackageName+'" *.* /XO /E /R:3 /W:3 /NP /MAX:102500000'
													

	DECLARE db_cursor CURSOR READ_ONLY FORWARD_ONLY FOR  
	SELECT DISTINCT SSISpackagesource FROM #Ssispackagesinfo

	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @RoboCopyCommand   

	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		PRINT 'Command to run: ' + @RoboCopyCommand

		INSERT #temp
		EXEC @ReturnCode = xp_cmdshell @RoboCopyCommand

		-- If we have an error populate variable
		--IF @ReturnCode NOT IN (0,1,2,3)
		IF @ReturnCode > 7
		BEGIN
			SELECT @ErrorMessage = @ErrorMessage + ResultsColumn   
			FROM #temp
			WHERE ResultsColumn IS NOT NULL
 
			--Display error message and return code
			--SELECT @ErrorMessage as ErrorMessage, @ReturnCode as ReturnCode
			RAISERROR (@ErrorMessage, 16, 1)
			GOTO ResetOptions
		END
		
		PRINT 'Successfully ran: ' + @RoboCopyCommand

		FETCH NEXT FROM db_cursor INTO @RoboCopyCommand   
	END   

	CLOSE db_cursor   
	DEALLOCATE db_cursor
	PRINT @@servername+': SSIS packages copied successfully' 
	PRINT 'BACKUP LOCATION'+@SsisBackupPath
END		

ELSE -- Unable to create the backup folder most likely.
	SET @ErrorMessage = 'Invalid backup location'+@SsisBackupPath

ResetOptions:
--Reset configuration values for xp_cmdshell AND advanced options 
IF @cmdshell_config = 0 
BEGIN 
	EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE; 
	IF @advanced_config = 0 
	BEGIN 
		EXEC sp_configure 'show advanced options', 0; RECONFIGURE; 
	END 
END

IF @ReturnCode IS NULL
BEGIN
	PRINT '@ReturnCode was null for some reason.'
	SET @ReturnCode = 0
END

IF EXISTS (select * from sys.dm_exec_cursors(@@spid)) 
BEGIN
	IF EXISTS (select * from sys.dm_exec_cursors(@@spid) where is_open = 1) 
		CLOSE db_cursor   
	DEALLOCATE db_cursor
END


RETURN @ReturnCode

END --proc;

GO