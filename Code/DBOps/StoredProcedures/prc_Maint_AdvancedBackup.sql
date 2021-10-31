IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'prc_Maint_AdvancedBackup' And ROUTINE_SCHEMA = 'dbo')
BEGIN
	EXEC('CREATE Procedure dbo.prc_Maint_AdvancedBackup as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.prc_Maint_AdvancedBackup.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.prc_Maint_AdvancedBackup.'
	END
END
GO

/*
-- Name: prc_Maint_AdvancedBackup
-- Revision History:  
-- 01/18/08 - 2.0 Chuck Lathrope  
--   If litespeed xp proc missing, gracefully change to native backup.  
--   Reliant on function GetDelimListasTable to parse @ExcludedDBs value.  
--   Truncate Log if database in simple mode and log backup requested. Continue without error.  
--   Hardcoded @Threads option to 2.  2 or 3 threads work best for multiprocessor computers.  
--   Changed @PerformDBCC default to not perform DBCC. Typically done by other process.  
--   Check for backup path existance or connectivity.  
--   Added @CompressionLevel setting  
--   Changed definition of @InitBackupDevice to be like INIT setting on backup command.  
--    0-Append to file with just db name.  
--    1-Set Init, use timestamp in filename.  
--   Add @StatusMsg as an Output parameter.  
--   Lowered security restrictions if @MSDBHistoryPurge is set to 0.  
--   Prevent deletion of files that are appends without date in file name.  
-- 02/22/08 Removed @InitBackupDevice check from @RetainDays file deletion section.   
-- 04/04/08 Revamped @debug = 1 usage to print out more.  
-- 06/08/08 - 2.1 Added delimited list capability to @DBName parameter.  
-- 07/14/08 - 2.5 Fixed bug with 6/8 update. Removed backup table log choice with @LOGResults bit variable.  
--      Moved logging into proc prc_Maint_InsDatabaseBackupLog. Improved @debug = 1 output.  
-- 08/10/08 - 2.6 Added multiple file backup option.  
--      Changed default backup compression ratio to 1.  
--      Added Begin Try around xp_cmdshell statements. Now SQL 2005 compatible only (Remove to make SQL 2000 compatible)  
--      Add preserve backup option @PreserveBackupSet to allow the RetainDays option to skip over file. (New extension).  
--      Override @LOGResults value if prc_Maint_InsDatabaseBackupLog doesn't exist  
--      Added @RetryAttempts for times when backup fails because of a networking hiccup.  
-- 10/03/08 - 2.7 @NumberOfBackupFiles=@NumberOfBackupFiles-1 now, need to test on native backup if true number is created you specified.  
-- 12/01/08 - 3.0 Refactored 2.7 update to not do subtraction. A few minor bug fixes.  
--      Refactored @cmd statement to run at end after all the precursor work instead of after each backup type.  
--      Added initialize backup file override if past first backup attempt.  
--      Improved backup logging with prc_Maint_InsDatabaseBackupLog modifications and added more logging and debug steps.  
--      @PreserveBackupSet alters backup extension now.  
--      @InitBackupDevice bug fix for native backups adds With FORMAT option, otherwise file would have to exist.  
--      Added @BackupCmd added to help find offline files for failed backup attempts.  
--      Added @BackupSingleDB <> 1 AND @BackupType IN ('G') check which stops execution of proc.  
--      Refactored path variable creation. Added variable reset for multiple db backups.  
--      Added @DBName database name range capability to limit databases to backup.  
--      Increased amount of debug print and logging statements.  
-- 12/29/08 - 3.1 Added Desktop Heap Issue check as xp_cmdshell results will always be null.  
-- 03/19/09 - 3.2 Added @SLSLogging and @SLSOptionalCommands for improved Litespeed support  
--      Added @MaxTransferSizeKB for backup transfer size.  
--      Added @MirrorBackupDir for mirrored backup location.  
--      Changed file name date format to be YYYYMMDD-24hh.mm  
--      Removed multiple file write for log backups. Overkill. Create them more often if file size to big.  
-- 04/14/09 - 3.3 Bugfix @BackupTypeShortDesc missing in dir output capture. Removed old file type find.  
--      Replace space in database name with _ for file saving.  
-- 05/07/09 - 3.4 Added Litespeed ErrorCode and ErrorMessage to DBOPS database.  
-- 05/14/09 - 3.5 Added FileGroup backup functionality  
-- 07/26/09 - 3.6 Cleaned up MSDB purge history process. Optimized for possible blocking with large deletes.  
--      Changed @Success default to 1. Added edition check and wipe out parameters passed that only work with Enterprise edition.  
-- 11/30/09 - 3.7 Added SQL 2008 compressed db option and invalid singleton database logic failure change for non-existant db.  
-- 06/21/10 - 3.8 Added support for remote or local drive mapping with username and password.  
--      Added @OLRMap and @EncryptedValue parameters.  
-- 08/26/10 - 3.9 Added raiserror when backup directory cannot be created.  
-- 09/07/10 - 3.91 Added Diff before Full backup error handling to reset to Full backup.  
-- 09/07/10 - 3.92 Added @CompleteSuccess variable to track entire process and raiserror at end if 0.  
-- 10/24/10 - 3.93 Removed drive check in mapping drive.  
-- 01/01/11 - 4.0 Added @Copy_Only parameter.  
-- 01/25/11 - 4.1 Change to >= @RetainDays instead of > as with large backups you would have 2 copies of weekly full backups, but really just want one.   
     Change @RetainDays = 8 if you want to keep 2 Full weekly backups.  
-- 04/16/12 - 4.2 File cleanup process doesn't work for db's with spaces in the name.      
-- 05/29/12 - 4.2 Added @PurgeFilesOnly parameter to just cleanup backup location.  
-- 08/13/12 - 5.0 Removed as many xp_cmdshell operations as possible. Moved many of the code sections around to improve readability.  
     Added more error handling and parameter validation. Added @Description, @BufferCount, @BufferCount, and @BlockSize parameters.   
     Added support FOR SQLSafe, SQLBackup, and Hyperbac.  
     Changed @SLSThreads to @Threads since it can be used by other products. Added default backup location lookup in registry.  
-- 10/23/14 - 5.1 Code cleanup. Change net use command to not be a drive letter.
	 Added attempt to create folder if not exists to help with creating new base folder on passed in @BackupDir example below       
--  
--  Return codes:    
--  -1 -> User executing needs SYSADMIN rights.    
--   0 -> Success.    
--   1 -> Hard failure. View @StatusMsg value for error messages.    
--   2 -> Invalid option provided. View @StatusMsg value for reason.    
--  5 -> BackupDir issues with drive letter mapping.  
--  10 -> Could not find or connect to backup folder.    
--  11 -> Unable to create backup directory.  
--  
--  Example Usage:  
--  
--Declare @RC int, @StatusMsg varchar(1024)  
--Exec @RC = prc_Maint_AdvancedBackup @RetryAttempts=2, @BackupType='C', @DBName='*', @Debug = 0, @NumberOfBackupFiles = 2, @BackupDir='e:\backups', @VerifyBackup = 0, @ExcludedDBs = 'Model,litespeedlocal,questworkdatabase,reportservertempdb', @CreateSrvDir
 = 1, @StatusMsg=@StatusMsg OUTPUT  
--or  
--Exec @RC = prc_Maint_AdvancedBackup @RetryAttempts=2, @BackupType='C', @DBName='DBOPS', @MSDBPurgeHistory = 1, @MSDBRetainDays=60,@Debug = 0, @NumberOfBackupFiles = 2, @InitBackupDevice=0, @BackupDir='\\blv91wdbbac01.prod.dm.local\DBBackup', @LOGResults=1
, @VerifyBackup = 0, @RetainDays = 7, @CreateSrvDir = 1, @StatusMsg=@StatusMsg OUTPUT  
--or  
--Exec @RC = prc_Maint_AdvancedBackup @RetryAttempts=2, @BackupType='C', @DBName='A-M', @ExcludedDBs = 'Model', @Debug = 1, @InitBackupDevice=1, @BackupDir='\\blv91dd01\backup\dbbackups\', @LOGResults=1, @VerifyBackup = 0, @RetainDays = 7, @CreateSrvDir = 1
, @StatusMsg=@StatusMsg OUTPUT  
--Select @RC, @StatusMsg  

--Full example with mapping drive
--Declare @RC int, @StatusMsg varchar(1024) , @BackupDir varchar(500), @date date = getdate()
--	,@backuptype char(1), @backuptypedesc varchar(4) = 'Full'
--SELECT @backuptype = case when @backuptypedesc = 'Full' THEN 'c'
--						  when @backuptypedesc = 'Diff' THEN 'd'
--						else 'l' End
--,@BackupDir =  '\\192.168.111.205\backups\DB3\DB3_' + @backuptypedesc +'_' + replace(convert(varchar(10), @date, 2),'.','_')
--Exec @RC = prc_Maint_AdvancedBackup @RetryAttempts=2, @BackupType=@BackupType, @DBName='*', @MSDBPurgeHistory = 1
--, @MSDBRetainDays=60, @Debug = 0, @NumberOfBackupFiles = 1, @InitBackupDevice=1, @BackupDir=@BackupDir, @LOGResults=1
--, @CreateSrvDir = 0, @BackupProduct= 2, @ExcludedDBs = 'Model', @VerifyBackup = 0, @RetainDays = 30
--, @DriveLetterMapping = 1, @BackupDriveUser = 'backups', @BackupDrivePassword = '...'
--, @StatusMsg=@StatusMsg OUTPUT  
--Select @RC, @StatusMsg  

--Todo:  
--Change FILE option to just backup online data, like full text indexes because of this error:
--Msg 62309, Sev 19, State 1: SQL Server has returned a failure message to LiteSpeed which has prevented the operation from succeeding.   
--The following message is not a LiteSpeed message. Please refer to SQL Server books online or Microsoft technical support for a solution:     
--BACKUP DATABASE is terminating abnormally.  The backup of full-text catalog 'GoogleAnalytics' is not permitted because it is not online.   
--Check errorlog file for the reason that full-text catalog became offline and bring it online. Or use FILE option to only backup online data.  
--Add alert of some kind if doing a diff backup and no sign of recent full backup has occurred in log table.  
Can send plain text encryption value or litespeed provided encrypted value with xp_encrypt_backup_key  
--Fix up filegroup backup to be more comprehensive.  
--Improve @Operation population.  
--Logging uses LitespeedLocal.dbo. database info, but needs to be in sp_executesql as it may not exist.
*****************************************************************************************/  
ALTER PROCEDURE dbo.prc_Maint_AdvancedBackup  
 @BackupType char(1) = 'C'      
 --'C' for Complete/Full Database Backup (Default)  
 --'D' for Differential Backups  
 --'G' for Individual Filegroup Backups  
 --'L' for Transaction Log Backups  
 ,@DBName varchar(4000) = '*'  
 --'*' = Backup All Databases (Default)  
 --Range A-Z which will translate into database name start letter. First letter only. A-C will be >=A and <= C, so you can have multiple jobs A-C;D-G etc.  
 --Delimited list of databases to be included in backup operation.  
 ,@ExcludedDBs varchar(1024) = NULL  
 --Delimited list of files to be excluded in backup operation  
 ,@BackupDir varchar(300) = NULL  
 --Directory/Path to store backups DON'T include servername at end of path if you set @CreateSrvDir=1 or @CreateSubDir=1 (can use UNC paths as well).  
 ,@DriveLetterMapping bit = NULL, @BackupDriveUser varchar(100) = NULL, @BackupDrivePassword varchar(100) = NULL  
 --If remote backup point needs user/pass, set bit to 1 and provide user and password to be mapped. @BackupDir is full path to map.  
 ,@MirrorBackupDir varchar(300) = NULL  
 --Backup location to duplicate the backup (no relation to database mirroring) - Enterprise feature only of course, what did you expect? Only have option for 1 mirror. Technically 3 more could be created.  
 ,@NumberOfBackupFiles tinyint = 1  
 --Number of files to backup to, @FileName backup option  
 ,@BufferCount int = NULL  
 --Is SQL server buffers to use. Microsoft recommends this formula: NumberofBackupDevices*3 + NumberofBackupDevices + NumberofDatabaseFiles = BufferCount. 20 default and minimum 150 maximum.  
 --http://sqlcat.com/technicalnotes/archive/2008/04/21/tuning-the-performance-of-backup-compression-in-sql-server-2008.aspx  
 --BufferCount and MaxTransferSize can be used together for optimum compression.   
 ,@MaxTransferSizeKB int = 1024  
 --Specifies the data size in bytes for each transfer when communicating with SQL Server. The size can be any multiple of 64KB in the range from 64KB to 4MB.  
 ,@BlockSize smallint = NULL  
 --BlockSize used by backup software, typically only altered when using tape destinations. Check BOL for more info.  
 --NOTE: Litespeed has a wizard that you can use to find optimum values for optional parameters.  
 ,@RetryAttempts tinyint = 1  
 --Number of attempts to run backup command. Good for use on flakey LANs.  
 ,@VerifyBackup tinyint = 1  
 --0 = Skip Verification  
 --1 = Perform verification of backups (Default)  
 ,@Backup_Readonly bit = 0  
 -- 0 = Don't backup readonly databases (Default)  
 ,@BackupProduct tinyint = 0  
 --0 = Use SQL LiteSpeed Extended Stored Procedure Interface (Default)  
 --1 = Use Redgate SQLBackup  
 --2 = Use SQL Native Backup  
 --3 = Use Idera SQLSafe  
 --4 = Use Hyperbac  
 ,@Description nvarchar(255) = NULL  
 --Backup description override to include in backup set. Currently it will be populated with: 'Backup of database ' + @DBName + ' on ' + CAST(GETDATE() AS VARCHAR(30))  
 ,@Debug bit = 0  
 --0 = Minimal logging (Default)  
 --1 = Print verbose logging  
 ,@Copy_Only bit = 0  
 --1 = Do a FULL backup, but don't reset log chain (if you are doing log shipping use this).  
 ,@EncryptionKey varchar(1024) = NULL  
 --Encryption Key used to secure Backup Devices (Optional).  
 ,@EncryptedValue varchar(1024) = NULL  
 --Use litespeed encrypted value instead of plain text @EncryptionKey. xp_encrypt_backup_key  
 ,@CompressionLevel tinyint = 3 --3 or 4 is vendor recommended value.  
 --Litespeed compression level to use.  
 --0 no compression  
 --1 compression using algorithm (a)  
 --2-10 compression using algorithm (b), on a progressive scale from least compression to most compression, with a corresponding CPU trade-off.  
 ,@OLRMap bit = 1  
 --Create object level restore map (Litespeed Enterprise only feature) for fast object recovery.  
 ,@DoubleClickRestore int = 0  
 --Create Litespeed doubleclick restore.  
 ,@Threads tinyint = 2  
 --Number of worker threads to use to backup when backing up to one file. Only valid with products LITESPEED, SQLBACKUP, SQLSAFE.  
 ,@SLSThrottle tinyint = 100  
 --Set LiteSpeed's CPU % throttle usage. Value should be between 1 and 100.  
 ,@SLSAffinity tinyint = 0  
 --Set LiteSpeed's processor affinity. Default is 0.  
 --On a 4-processor box, processors are numbered 0, 1, 2, and 3.   
 --0 = All processors  
 --1 = Processor 0  
 --2 = Processor 1  
 --3 = Processor 0 and 1  
 --4 = Processor 2  
 --5 = Processor 2 and 0  
 --6 = Processor 2 and 1  
 --7 = Processor 2, 1 and 0  
 --8 = Processor 3  
 --See SQL SiteSpeed documentation for more information on the @affinity variable.  
 ,@SLSPriority tinyint = 0  
 --Base priority of SQL LiteSpeed Backup process.  
 --0 = Normal (Default)  
 --1 = Above Normal  
 --2 = High  
 ,@SLSLogging tinyint = 0 --C:\Documents and Settings\All Users\Application Data\Quest\LiteSpeed  
 --0 - No logging.  
 --1 - Automatically generates a "crash dump" file in the LiteSpeed Program Files\Logs directory in the event of a process failure or abnormal termination.   
  --This can be used by Product Technical Support for problem determination and analysis.  
 --2 - Generates a verbose log file for the operation regardless of the process outcome (success or failure). These logs must be manually deleted.  
 --3 - LiteSpeed creates verbose logs and only saves them if the back up fails. If it succeeds, LiteSpeed does not save the log.  
 ,@SLSOptionalCommands varchar(400) = NULL  
 --Send in other commands not listed. Format not checked but should be like @ioflag='OVERLAPPED',@ioflag='SEQUENTIAL_SCAN'  
 ,@RetainDays smallint = 7  
 --Number of days to retain backup device files, if supplied backup files older than the number of days specified  
 --will be purged. Use proc prc_Maint_DBBackupHistory to get dynamic day value based on last full or diff backup.  
 ,@MSDBPurgeHistory bit = 1  
 --Purge MSDB history if set to 1. Days kept is = @MSDBRetainDays  
 ,@MSDBRetainDays smallint = 90  
 --Days of MSDB history to keep.  
 ,@InitBackupDevice tinyint = 1  
 --0 = Append to existing file if it exists.  
 --1 = Reinitialize backup device (timestamped name and no append to file)   
 ,@PerformDBCC bit = 0  
 --0 = Do not Perform DBCC CHECKDB prior to backing up database (default)   
 --1 = Perform DBCC CHECKDB prior to backing up database  
 ,@CreateSubDir bit = 0  
 --Creates a subdirectory under the backup directory for each db being backed up named same as database name.  
 ,@CreateSrvDir bit = 1  
 --Creates a directory under the backup directory for the current server, used for scenarios where multiple servers   
 --are backing up to the same location, ensures no namespace conflicts  
 ,@LOGResults bit = 1  
 --Log each DB backup results using a call to prc_Maint_InsDatabaseBackupLog.  
 ,@PreserveBackupSet bit = 0  
 --0 = Normal operation (Default)  
 --1 = Change filename by appending .save to file name to prevent @RetainDays from deleting.  
 ,@PurgeFilesOnly bit = 0  
 --0 = Normal operation backups will happen (Default)  
 --1 = Backup and verify steps will be skipped and file deletion steps will run.  
 ,@StatusMsg varchar(1024) = NULL OUTPUT  
  
AS   
BEGIN  
  
    SET NOCOUNT ON  
  
    DECLARE  
		@Backup_Readonly_Init BIT ,  
        @BackupCmd VARCHAR(1000) ,  
        @BackupDate VARCHAR(20) ,  
        @BackupDesc VARCHAR(300) ,  
        @BackupDirWorking VARCHAR(300) ,  
        @Backupname VARCHAR(300) ,  
        @BackupSingleDB BIT ,  
        @BackupType_Init CHAR(1) ,  
        @BackupTypeShortDesc VARCHAR(4) ,  
        @BackupTypeShortDesc_Init VARCHAR(4) ,  
        @BaseBUFileDatalength INT ,  
        @BUFile VARCHAR(300) ,  
        @BUFileDate VARCHAR(12) ,  
        @Cmd NVARCHAR(4000) ,  
        @CmdStr VARCHAR(500) ,  
        @CompleteSuccess BIT, --What is status of entire operation? Any backup failure = failure = Return 1.  
        @DBID INT ,  
        @DBMode VARCHAR(50) ,  
        @DBStatus INT ,  
        @DesktopHeapIssue BIT ,  
        @DSQL VARCHAR(100) ,  
        @dsqlFileGroupIncludeList VARCHAR(4000) ,  
        @FileExt VARCHAR(9) ,  
        @Filenames VARCHAR(1024) ,  
        @FileNumber TINYINT ,  
        @Incr INT ,  
        @LiteSpeedErrorMessage VARCHAR(2000) ,  
        @MaxIncr INT ,  
        @MaxTransferSizeBytes INT ,  
        @MirrorBackupDirWorking VARCHAR(300) ,  
        @MSDBPurgeDate DATETIME ,  
        @Operation VARCHAR(35) ,  
        @Options VARCHAR(100) ,  
        @ParmDefinition NVARCHAR(20) ,  
        @ParmDefinitionVerify NVARCHAR(20) ,  
        @PhyName VARCHAR(1024) ,  
        @RC INT ,  
        @RetryAttemptNumber TINYINT ,  
        @ServerName VARCHAR(100) ,  
        @SQLVersion CHAR(2) ,  
        @Success BIT ,  
        @VerifyRC INT   
  
    DECLARE @DateList TABLE (  
          Incr INT IDENTITY ,  
          DateValue VARCHAR(10)  
        )  
    DECLARE @FGList TABLE (  
          FilegroupName VARCHAR(25) ,  
          DbFileName SYSNAME ,  
          state_desc VARCHAR(25) ,  
          is_read_only BIT  
        )  
  
	CREATE TABLE #CheckPathExistance (  
	  FileExists INT ,  
	  FileIsDir INT ,  
	  ParentDirExists INT  
	)  

	--=====================================  
	--Check dependencies.  
	--=====================================  
  
	--Mandatory function  
	IF NOT EXISTS ( SELECT	*
				 FROM	sys.objects objects
				 INNER JOIN sys.schemas schemas ON objects.[schema_id] = schemas.[schema_id]
				 WHERE	objects.[type] = 'TF'
						AND schemas.[name] = 'dbo'
						AND objects.[name] = 'GetDelimListasTable' )
	BEGIN  
		SET @StatusMsg = 'The function GetDelimListasTable is missing. Download from here http://www.sqlwebpedia.com/'  
		RAISERROR(@StatusMsg,16,1) WITH LOG  
		RETURN 1  
	END  
  
	--Override @LOGResults if prc_Maint_InsDatabaseBackupLog doesn't exist  
    IF @LOGResults = 1 AND ( OBJECT_ID('dbo.prc_Maint_InsDatabaseBackupLog') IS NULL )   
    BEGIN  
        PRINT 'Could not find prc_Maint_InsDatabaseBackupLog, so changing logging to 0.'  
        SET @LOGResults = 0  
    END  
   
	--Litespeed check  
	IF @BackupProduct = 0
	AND NOT EXISTS ( SELECT	*
					 FROM	[master].sys.objects
					 WHERE	[type] = 'X'
							AND [name] = 'xp_backup_database' )
	BEGIN  
		PRINT 'Could not detect LiteSpeed is installed, so continuing with native SQL backup.'  
		SET @BackupProduct = 2  
	END  
  
	--Redgate SQLBackup check  
	IF @BackupProduct = 1
	AND NOT EXISTS ( SELECT	*
					 FROM	[master].sys.objects
					 WHERE	[type] = 'X'
							AND [name] = 'sqlbackup' )
	BEGIN  
		PRINT 'Could not detect SQLBackup is installed, so continuing with native SQL backup.'  
		SET @BackupProduct = 2  
	END  
  
	--Idera SQLSafe check  
	IF @BackupProduct = 3
	AND NOT EXISTS ( SELECT	*
					 FROM	[master].sys.objects
					 WHERE	[type] = 'X'
							AND [name] = 'xp_ss_backup' )
	BEGIN  
		PRINT 'Could not detect SQLSafe is installed, so continuing with native SQL backup.'  
		SET @BackupProduct = 2  
	END  
  
  
 --=====================================  
 --Initialize variables.  
 --=====================================  
   
	--Assume we have litespeed installed, and @BackupProduct is not a valid value.  
	IF @BackupProduct NOT IN (0, 1, 2, 3, 4)
		SET @BackupProduct = 0  
	      
	--If BackupDir is empty, get default from registry settings.  
	IF @BackupDir IS NULL
		OR @BackupDir = ''
		EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
			N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory',
			@BackupDir OUTPUT  

	IF @BackupDir IS NULL
		OR @BackupDir = ''
	BEGIN  
		SELECT	@StatusMsg = 'Error - backup folder not defined: '
				+ ISNULL(@BackupDir, '')  
		RAISERROR(@StatusMsg,16,1) WITH LOG  
		RETURN 10  
	END  

	SET @SQLVersion = SUBSTRING(CONVERT(NCHAR(20), SERVERPROPERTY(N'ProductVersion')), 1,
								CHARINDEX(N'.',  CONVERT(NCHAR(20), SERVERPROPERTY(N'ProductVersion'))) - 1)  

	IF SERVERPROPERTY('EngineEdition') < 3 --3 is Enterprise edition which is only edition to support these commands.  
	BEGIN  
		SET @MirrorBackupDir = NULL  
		SET @Backup_Readonly = 0  
	END  

	--Fix up backup path to conform for later use:  
	IF RIGHT(RTRIM(@BackupDir), 1) = '\'
		SET @BackupDir = LEFT(RTRIM(@BackupDir), LEN(RTRIM(@BackupDir)) - 1)  
	      
	IF RIGHT(RTRIM(@MirrorBackupDir), 1) = '\'
		SET @MirrorBackupDir = LEFT(RTRIM(@MirrorBackupDir),
									LEN(RTRIM(@MirrorBackupDir)) - 1)  

	SELECT	@BackupSingleDB = 0
		  , @BackupDirWorking = @BackupDir
		  , @MirrorBackupDirWorking = @MirrorBackupDir
		  , @ServerName = REPLACE(@@ServerName, '\', '_')
		  , @Filenames = ''
		  , @RetryAttemptNumber = 1
		  , @ParmDefinition = N'@RC INT OUTPUT'
		  , @ParmDefinitionVerify = N'@VerifyRC INT OUTPUT'
		  , @MaxTransferSizeBytes = @MaxTransferSizeKB * 1024
		  , @MSDBPurgeDate = CAST(CONVERT(VARCHAR(10), GETDATE() - @MSDBRetainDays, 101) AS DATETIME)  

	--Assume everything was a success.  
	SELECT	@Success = 1
		  , @CompleteSuccess = 1  

	--We don't want to delete any .save files even if old for failsafe reasons.  
	IF @RetainDays IS NOT NULL
		AND @PreserveBackupSet = 1
		SET @RetainDays = NULL  

	--If @RetainDays is 0 and a log backup, force preserve one days worth of files.  
	IF @RetainDays = 0
		AND @BackupType = 'L'
		SET @RetainDays = 1  

	SELECT	@FileExt = CASE	WHEN @BackupProduct = 0 THEN '.SLS'
							WHEN @BackupProduct = 1 THEN '.SQB'
							WHEN @BackupProduct = 2 THEN '.BAK'
							WHEN @BackupProduct = 3 THEN '.SAFE'
							WHEN @BackupProduct = 4 THEN '.HBC'
					   END  
   
 --=====================================  
 --Validate passed in variables.  
 --=====================================  
   
	--Check Access Level Rights for purging history  
	IF IS_SRVROLEMEMBER('sysadmin') = 0
		AND @MSDBPurgeHistory = 1
	BEGIN  
		SELECT	@StatusMsg = 'Error - Insufficient system access for '
				+ SUSER_SNAME()
				+ ' to perform backup as @MSDBPurgeHistory = 1. Set to 0.'  
		RAISERROR(@StatusMsg,17,1) WITH LOG  
		RETURN -1  
	END  

	--Litespeed has a CPU throttle option - not used typically though.  
	IF @SLSThrottle NOT BETWEEN 1 AND 99
		SET @SLSThrottle = NULL  

	--Set thread count to null if less than 2 or writing to multiple files as that is default for all backup software.  
	IF @Threads < 2
		OR @NumberOfBackupFiles > 1
		SET @Threads = NULL  

	--Used by Litespeed and Native backups.  
	IF @MaxTransferSizeKB < 64
		OR @MaxTransferSizeKB > 4096
		OR @MaxTransferSizeKB % 64 <> 0
	BEGIN  
		SET @MaxTransferSizeBytes = 1048576  
		PRINT '@MaxTransferSizeKB parameter passed was invalid. Valid range is 64-4096KB in 64KB multiples. Resetting to 1024KB.'  
	END  

	--Per BOL, ignored for products that don't support it.  
	IF @BlockSize NOT IN (512, 1024, 2048, 4096, 8192, 16384, 32768, 65536)
	BEGIN  
		SELECT	@StatusMsg = 'The value for @BlockSize must be one of these values: ( 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536 ).'  
		RAISERROR(@StatusMsg,16,1) WITH LOG  
		RETURN 2  
	END  

	--Per BOL. Ignored for products that don't support it.  
	IF @BufferCount <= 0
		OR @BufferCount > 2147483647
	BEGIN  
		SELECT	@StatusMsg = 'The value for parameter @BufferCount = '
				+ CAST(ISNULL(@BufferCount, 'NULL') AS VARCHAR(10))
				+ ' is not supported.'  
		RAISERROR(@StatusMsg,16,1) WITH LOG  
		RETURN 2  
	END  

	--Only valid with products LITESPEED, SQLBACKUP, SQLSAFE. If other product used, it will be ignored.  
	IF @Threads IS NOT NULL
		AND @Threads > 32
	BEGIN  
		SELECT	@StatusMsg = 'The value for @Threads is not supported - must be 1-32.'  
		RAISERROR(@StatusMsg,16,1) WITH LOG  
		RETURN 2  
	END  

	--We don't want too many files created.  
	IF @NumberOfBackupFiles > 20
		SET @NumberOfBackupFiles = 20  

	--Can only have one file for .exe restores.  
	IF @NumberOfBackupFiles > 0
		AND @DoubleClickRestore = 1
		SET @NumberOfBackupFiles = 1  

	IF LEN(@Description) > 255
		OR (@BackupProduct = 1
			AND LEN(@Description) > 128
		   )
	BEGIN  
		SELECT	@StatusMsg = 'The length for parameter @Description is not supported. Max length is: '
				+ CASE WHEN @BackupProduct = 'LITESPEED' THEN '128'
					   ELSE '255'
				  END + '. Your length was '
				+ CAST(LEN(@Description) AS VARCHAR(5)) + '.'  
		RAISERROR(@StatusMsg,16,1) WITH LOG  
		RETURN 2  
	END  

	--Validate @BackupType Argument  
	SET @BackupType = UPPER(@BackupType)  
	  
	IF @BackupType IN ('C', 'D', 'G', 'L')
	BEGIN  
		IF @BackupType = 'C'
			SELECT	@BackupTypeShortDesc = 'Full'  
		IF @BackupType = 'D'
			SELECT	@BackupTypeShortDesc = 'Diff'  
		IF @BackupType = 'G'
			SELECT	@BackupTypeShortDesc = 'FGrp'  
		IF @BackupType = 'L'
			SELECT	@BackupTypeShortDesc = 'TLog'  
	END  
	ELSE
	BEGIN  
		SELECT	@StatusMsg = ' Error - Valid values for the @BackupType parameter are C, D, F, G, or L'   
		RAISERROR(@StatusMsg,16,1) WITH LOG  
		RETURN 2    
	END  
	      
	SELECT	@Backup_Readonly_Init = @Backup_Readonly
		  , @BackupType_Init = @BackupType
		  , @BackupTypeShortDesc_Init = @BackupTypeShortDesc  
  
 --Validate CPU affinity for Litespeed  
	IF (@SLSAffinity > 0)
	BEGIN  
		DECLARE	@ProcessorCount INT  
		CREATE TABLE #MSVer (
			  [Index] INT
			, [Name] VARCHAR(255)
			, Internal_Value INT NULL
			, Charater_Value VARCHAR(255)
			)  
		INSERT	#MSVer
				EXEC master.dbo.xp_msver  
		SELECT	@ProcessorCount = Internal_Value
		FROM	#MSVer
		WHERE	[Name] = 'ProcessorCount'  

		DECLARE	@i INT  
		DECLARE	@binstr VARCHAR(2048)  
		SELECT	@binstr = ''  
		SELECT	@i = @ProcessorCount  

		WHILE @i > 0
			BEGIN  
				SELECT	@binstr = @binstr + '1'  
				SELECT	@i = @i - 1  
			END  

		IF CAST(@SLSAffinity AS BINARY) > CAST(@binstr AS BINARY)
			BEGIN  
				SET @Operation = 'SLSAffinity Check'  
				SELECT	@StatusMsg = 'Error - Invalid processor affinity specified.  Please set @SLSAffinity to NULL or consult SQL LiteSpeed''s documentation.'  

				DROP TABLE #MSVer  
                  
				RAISERROR(@StatusMsg,16,1) WITH LOG  
				RETURN 2    
			END  
	END--IF (@SLSAffinity > 0)  
  
  
	--Create mapped drive  
	IF @DriveLetterMapping = 1
	BEGIN  
		SELECT	@Cmd = 'net use "' + @BackupDir
				 + '" /USER:' + @BackupDriveUser + ' "' + @BackupDrivePassword + '"'
				 
		IF @Debug > 0
			PRINT @Cmd  
  
		BEGIN TRY  
			EXEC @RC = master.dbo.xp_cmdshell @Cmd, NO_OUTPUT   
		END TRY  
		BEGIN CATCH  
			IF @@Error = 15281 --xp_cmdshell is disabled, so lets temporarily enable it.  
				BEGIN  
					EXEC sp_configure 'show advanced option', '1';  
					RECONFIGURE;  
					EXEC sp_configure 'xp_cmdshell', '1';  
					RECONFIGURE;  
  
					EXEC @RC = master.dbo.xp_cmdshell @Cmd, NO_OUTPUT  
  
					EXEC sp_configure 'xp_cmdshell', '0';  
					EXEC sp_configure 'show advanced option', '0';  
					RECONFIGURE;  
				END  
		END CATCH  
  
		----Set @BackupDir to mapped drive letter.  
		--SET @BackupDirWorking = @DriveLetterMapping + ':\'  
   
		--128 is a desktop heap space issue. Logoff all extra users and try again or see http://support.microsoft.com/kb/824422  
		IF @RC = 128
			BEGIN  
				SELECT	@DesktopHeapIssue = 1
					  , @RC = 0
					  , @CompleteSuccess = 0  
  
				IF @LOGResults = 1
					EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,
						@DatabaseID = @DBID, @DBName = @DBName,
						@Operation = @Operation,
						@MessageText = 'Error 128 returned from xp_cmdshell. Logoff all extra users and try again if full failure or see http://support.microsoft.com/kb/824422',
						@Success = 0  
			END  
	END --IF @DriveLetterMapping IS NOT NULL   
  

  
	--Check for backup path existance  
    SELECT  @Cmd = 'master.dbo.xp_fileexist "' + @BackupDirWorking + '"'  
    INSERT  #CheckPathExistance  
            EXEC ( @Cmd )  
            
    IF NOT EXISTS ( SELECT * FROM #CheckPathExistance WHERE FileIsDir = 1 )   
    BEGIN 
		-- Attempt to create directory if it doesn't exist  
		BEGIN  
			SET @Cmd = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = master.dbo.xp_create_subdir N'''
				+ @BackupDirWorking
				+ ''' IF @ReturnCode <> 0 RAISERROR(''Error creating directory.'', 16, 1)'  
			
			IF @Debug > 0
				PRINT @Cmd  
			
			EXEC ( @Cmd )  
			--SET @Error = @@ERROR  
		END  
  
		--Test again
        TRUNCATE TABLE #CheckPathExistance  
        SELECT  @Cmd = 'master.dbo.xp_fileexist "' + @BackupDirWorking + '"'  
        INSERT  #CheckPathExistance  
                EXEC ( @Cmd ) 
        
		IF NOT EXISTS ( SELECT * FROM #CheckPathExistance WHERE FileIsDir = 1 )   
		BEGIN 
			SELECT  @StatusMsg = 'Error - Could not find or connect to backup folder: ' + @BackupDirWorking  
			--DROP TABLE #CheckPathExistance  
			RAISERROR(@StatusMsg,16,1) WITH LOG  
			RETURN 10  
		END
    END  
  
    IF @Debug > 0   
        PRINT @Cmd  
  
	--Check for backup mirror path existance  
    IF @MirrorBackupDirWorking IS NOT NULL   
    BEGIN  
        TRUNCATE TABLE #CheckPathExistance  
        SELECT  @Cmd = 'master.dbo.xp_fileexist "' + @MirrorBackupDirWorking + '"'  
        INSERT  #CheckPathExistance  
                EXEC ( @Cmd )  

        IF NOT EXISTS ( SELECT * FROM #CheckPathExistance WHERE FileIsDir = 1 )   
        BEGIN
    		-- Attempt to create directory if it doesn't exist  
			BEGIN  
				SET @Cmd = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = master.dbo.xp_create_subdir N'''
					+ @MirrorBackupDirWorking
					+ ''' IF @ReturnCode <> 0 RAISERROR(''Error creating directory.'', 16, 1)'  
				
				IF @Debug > 0
					PRINT @Cmd  
				
				EXEC ( @Cmd )  
				--SET @Error = @@ERROR  
			END  
			
			--Test again
			TRUNCATE TABLE #CheckPathExistance  
			SELECT  @Cmd = 'master.dbo.xp_fileexist "' + @MirrorBackupDirWorking + '"'  
			INSERT  #CheckPathExistance  
					EXEC ( @Cmd )  
					
			IF NOT EXISTS ( SELECT * FROM #CheckPathExistance WHERE FileIsDir = 1 )   
			BEGIN
				SELECT  @StatusMsg = 'Error - Could not find or connect to mirror backup folder: ' + @MirrorBackupDirWorking  
				--DROP TABLE #CheckPathExistance  
				RAISERROR(@StatusMsg,16,1) WITH LOG  
				RETURN 10  
			END
        END  
    END  
  
    IF @Debug > 0   
        PRINT @Cmd  
  
 ----Set @BackupDir to include server name  
 --IF @DriveLetterMapping IS NOT NULL  
 -- SET @BackupDir = REPLACE(@BackupDir,'\','')  
  
    SELECT  @BackupDirWorking = @BackupDirWorking + CASE WHEN @CreateSrvDir = 1  
                                               THEN '\' + @ServerName + '\'  
                                               ELSE '\' END   
    SELECT  @MirrorBackupDirWorking = @MirrorBackupDirWorking + CASE WHEN @CreateSrvDir = 1  
                                               THEN '\' + @ServerName + '\'  
                                               ELSE '\' END   
    TRUNCATE TABLE #CheckPathExistance  
  
	--Check for backup path existance when servername is included in backup path  
	IF @CreateSrvDir = 1
	BEGIN  
		--Check for backup path existance  
		SELECT	@Cmd = 'master.dbo.xp_fileexist "' + @BackupDirWorking + '"'  
		INSERT	#CheckPathExistance
				EXEC (@Cmd)  
  
		-- Create directory if it doesn't exist  
		IF NOT EXISTS ( SELECT	* FROM	#CheckPathExistance
						WHERE	FileIsDir = 1 )
		BEGIN  
			SET @Cmd = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = master.dbo.xp_create_subdir N'''
				+ @BackupDirWorking
				+ ''' IF @ReturnCode <> 0 RAISERROR(''Error creating directory.'', 16, 1)'  
			EXEC ( @Cmd )  
			--SET @Error = @@ERROR  
		END  
  
		IF @Debug > 0
			PRINT @Cmd  
  
		--Check for backup mirror path existance  
		IF @MirrorBackupDirWorking IS NOT NULL
		BEGIN  
			TRUNCATE TABLE #CheckPathExistance  
			SELECT	@Cmd = 'master.dbo.xp_fileexist "'
					+ @MirrorBackupDirWorking + '"'  
			INSERT	#CheckPathExistance
					EXEC (@Cmd
						)  

			IF NOT EXISTS ( SELECT	*
							FROM	#CheckPathExistance
							WHERE	FileIsDir = 1 )
			BEGIN  
				SET @Cmd = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = master.dbo.xp_create_subdir N'''
					+ @MirrorBackupDirWorking
					+ ''' IF @ReturnCode <> 0 RAISERROR(''Error creating directory.'', 16, 1)'  
				EXEC ( @Cmd )  
			--SET @Error = @@ERROR  
			END  
		END  
  
		IF @Debug > 0
			PRINT @Cmd  
  
----Reset @BackupDirOrig to include servername.  
--SET @BackupDirOrig = @BackupDir  
	END -- @CreateSrvDir = 1  
  
 --=====================================  
 --Validate DB names passed in.  
 --=====================================  
  
    SET @Operation = 'Validate DBName'  
  
 --Validate delimited list or singleton db backup.  
    IF @DBName <> '*' AND PATINDEX('[A-Z]-[A-Z]', @DBName) <> 1   
    BEGIN  
        IF PATINDEX('%[;,:.|]%', @DBName) = 0 --Multiple DB's NOT passed in.  
            BEGIN  
                IF NOT EXISTS ( SELECT  [name]  
                                FROM    master.dbo.sysdatabases  
                                WHERE   [name] = @DBName )   
                BEGIN  
                    SELECT  @StatusMsg = 'Error - Invalid database selected for @DBName (' + @DBName + ') parameter'   
                    SELECT  @Success = 0, @CompleteSuccess = 0  
                    GOTO NoCursorReturn  
                END  
                ELSE   
                    IF @Debug > 0   
                    BEGIN  
                        SELECT  @StatusMsg = @DBName + ' Selected for ' + @BackupTypeShortDesc + ' Backup'   
                        PRINT @StatusMsg  
                        IF @LOGResults = 1   
                            EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,  
                                @DatabaseID = @DBID, @DBName = @DBName,  
                                @Operation = 'Validate DBName w/debug',  
                                @MessageText = @StatusMsg,  
                                @Success = 1  
                    END  

                SET @BackupSingleDB = 1 --Used to avoid cursor below.  

                GOTO BackupOneDatabase  
            END  
        ELSE --Delimitor present, find all matching databases.  
            BEGIN   
                IF NOT EXISTS ( SELECT  [name]  
                                FROM    master.dbo.sysdatabases  
                                WHERE   [name] IN (SELECT  * FROM dbo.GetDelimListasTable(@DBName,DEFAULT) ) )   
                BEGIN  
                    SELECT  @StatusMsg = 'Error - Invalid databases selected for @DBName (' + @DBName + ') parameter'   
                    GOTO FailedBackup  
                END  

 --We have at least one good db name.  
                DECLARE DBCursor CURSOR FAST_FORWARD FOR  
                SELECT  name, dbid, status  
                FROM    master.dbo.sysdatabases  
                WHERE   [name] IN (SELECT  * FROM dbo.GetDelimListasTable(@DBName, DEFAULT) )  

                IF @Debug > 0   
                BEGIN  
                    SELECT  @StatusMsg = 'Multiple databases selected for ' + @BackupTypeShortDesc + ' Backup'   
                    PRINT @StatusMsg  

                    IF @LOGResults = 1   
                        EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,  
                            @DatabaseID = @DBID, @DBName = @DBName,  
                            @Operation = @Operation,  
                            @MessageText = @StatusMsg, @Success = 1  
                END  
            END  
    END  
    ELSE   
        IF PATINDEX('[A-Z]-[A-Z]', @DBName) = 1 --Range of Databases Requested.  
        BEGIN  
            DECLARE DBCursor CURSOR FAST_FORWARD FOR  
            SELECT  name, dbid, status  
            FROM    master.dbo.sysdatabases  
            WHERE   [name] <> 'tempdb'   
            AND [name] NOT IN (SELECT * FROM dbo.GetDelimListasTable(ISNULL(@ExcludedDBs, ''), DEFAULT) )   
			AND LEFT([name], 1) >= LEFT(@DBName,1)   
            AND LEFT([name], 1) <= RIGHT(@DBName,1)  

            IF @@ROWCOUNT = 0   
                PRINT 'No matching rows found in range: ' + @DBName  

            IF @Debug > 0   
            BEGIN  
                SELECT  @StatusMsg = 'Specified range of databases were selected for ' + @BackupTypeShortDesc + ' Backup'   
                PRINT @StatusMsg  

                IF @LOGResults = 1   
                    EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,  
                        @DatabaseID = @DBID, @DBName = @DBName,  
                        @Operation = @Operation,  
                        @MessageText = @StatusMsg, @Success = 1  
            END  
        END  
        ELSE --'*' was provided for all db's. Check @ExcludedDBs for excluded domains.  
        BEGIN  
            DECLARE DBCursor CURSOR FAST_FORWARD FOR  
            SELECT  name, dbid, status  
            FROM    master.dbo.sysdatabases  
            WHERE   [name] <> 'tempdb'   
            AND [name] NOT IN (SELECT * FROM  dbo.GetDelimListasTable(ISNULL(@ExcludedDBs, ''), DEFAULT) )  

            IF @Debug > 0   
            BEGIN  
                SELECT  @StatusMsg = 'Many databases were selected for ' + @BackupTypeShortDesc + ' Backup'   
                PRINT @StatusMsg  

                IF @LOGResults = 1   
                    EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,  
                        @DatabaseID = @DBID, @DBName = @DBName,  
                        @Operation = @Operation,  
                        @MessageText = @StatusMsg, @Success = 1  
            END  
        END  
  
    OPEN DBCursor --Yes it is a cursor, and no you shouldn't worry that one exists.  
    FETCH NEXT FROM DBCursor INTO @DBName, @DBID, @DBStatus  
    WHILE ( @@FETCH_STATUS = 0 )   
        BEGIN  
  
            BackupOneDatabase: --Skip cursor if only one database.  
  
			--Reset variables  
            SELECT  @Options = NULL,   
					@RC = NULL,  
                    @dsqlFileGroupIncludeList = NULL,   
                    @Success = 1,  
                    @StatusMsg = NULL,   
                    @BackupDirWorking = NULL,   
                    @RetryAttemptNumber = 0,  
                    @Backup_Readonly = @Backup_Readonly_Init,  
                    @BackupType = @BackupType_Init,  
                    @BackupTypeShortDesc = @BackupTypeShortDesc_Init   
  
			--FileGroup backup check  
            IF @BackupType = 'G' AND @Backup_Readonly = 0   
            BEGIN  
                DELETE  FROM @FGList  

                SET @BackupCmd = 'select ds.name,df.name,state_desc,ds.is_read_only  
from [' + @DBName + '].sys.database_files df  
join [' + @DBName + '].sys.filegroups ds on ds.data_space_id = df.data_space_id'  
                INSERT  INTO @FGList  
                        EXEC ( @BackupCmd )  
   
                IF EXISTS ( SELECT * FROM @FGList WHERE is_read_only = 1 )   
                BEGIN     
					SELECT  @dsqlFileGroupIncludeList = COALESCE(@dsqlFileGroupIncludeList + ',' + 'FILEGROUP=''' + FilegroupName + '''',  
                                                      'FILEGROUP=''' + FilegroupName + '''')  
                    FROM    @FGList  
                    WHERE   is_read_only = 0  
                END  
                ELSE --No read-only filegroups, so must be user error.  
                BEGIN  
                    SELECT  @Backup_Readonly_Init = @Backup_Readonly,  
                            @BackupType_Init = @BackupType,  
                            @BackupTypeShortDesc_Init = @BackupTypeShortDesc  
                    SELECT  @Backup_Readonly = 1, @BackupType = 'C',  
                            @BackupTypeShortDesc = 'Full'  
                END  
            END  
  
   --=====================================  
   --Validate DB Status.  
   --=====================================  
   
            SET @Operation = 'DB Status Check'  
     
            SET @BackupDate = '.' + REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(16), GETDATE(), 120), '-', ''), ' ', '-'), ':', '.')  
            SET @Backupname = @ServerName + '.' + @DBName  
            SET @RetryAttemptNumber = 1  
  
            IF @DBID IS NULL   
                SET @DBID = DB_ID(@DBName)  
  
   --Check Database Accessibility  
            SET  @DBMode = 'OK'  
  
            IF DATABASEPROPERTY(@DBName, 'IsDetached') > 0   
                SELECT  @DBMode = 'Detached'  
            ELSE IF DATABASEPROPERTY(@DBName, 'IsInLoad') > 0   
                    SELECT  @DBMode = 'Loading'  
                ELSE IF DATABASEPROPERTY(@DBName, 'IsNotRecovered') > 0   
                        SELECT  @DBMode = 'Not Recovered'  
                    ELSE IF DATABASEPROPERTY(@DBName, 'IsInRecovery') > 0   
                            SELECT  @DBMode = 'Recovering'  
                        ELSE IF DATABASEPROPERTY(@DBName, 'IsSuspect') > 0   
                                SELECT  @DBMode = 'Suspect'  
                            ELSE IF DATABASEPROPERTY(@DBName, 'IsOffline') > 0   
                                    SELECT  @DBMode = 'Offline'  
                                ELSE IF DATABASEPROPERTY(@DBName, 'IsEmergencyMode') > 0   
                                        SELECT  @DBMode = 'Emergency Mode'  
                                    ELSE IF DATABASEPROPERTY(@DBName, 'IsShutDown') > 0   
                                            SELECT  @DBMode = 'Shut Down (problems during startup)'  
  
            IF @DBMode <> 'OK'   
            BEGIN  
                SET @StatusMsg = 'Error - Unable to backup ' + @DBName + ' - Database is in ' + @DBMode + ' state'  
                IF @Debug > 0   
                    PRINT @StatusMsg  

                GOTO FailedBackup  
            END  
  
			--If @DBName = '*', then we have to not check until we populate DBNames in the cursor.  
            SELECT  @BackupDirWorking = @BackupDir + CASE WHEN @CreateSrvDir = 1  
                THEN '\' + @ServerName + '\'  
                ELSE '\' END   
            + CASE WHEN @CreateSubDir = 1  
               THEN REPLACE(@DBName,' ', '_') + '\'  
               ELSE '' END  
            SELECT  @MirrorBackupDirWorking = @MirrorBackupDir + CASE WHEN @CreateSrvDir = 1  
                THEN '\' + @ServerName + '\'  
                ELSE '\' END   
            + CASE WHEN @CreateSubDir = 1  
               THEN REPLACE(@DBName,' ', '_') + '\'  
               ELSE '' END  
                                                         
			--Initialize DB backup file name with full path.  
			SELECT	@PhyName = @BackupDirWorking + @ServerName + '.'
					+ REPLACE(@DBName, ' ', '_') + '.' + @BackupTypeShortDesc
					+ @BackupDate + @FileExt  
			IF @DEBUG > 0
				BEGIN  
					PRINT '@BackupDir=' + @BackupDir  
					PRINT '@BackupDirWorking=' + @BackupDirWorking  
					PRINT '@PhyName=' + @PhyName  
				END  
  
			--Check for backup path existance when DB name is included in backup path  
			IF @CreateSubDir = 1
			BEGIN  
			--Check for backup path existance  
				TRUNCATE TABLE #CheckPathExistance  
				SELECT	@Cmd = 'master.dbo.xp_fileexist "' + @BackupDirWorking + '"'  
				INSERT	#CheckPathExistance
						EXEC (@Cmd
							)  

				-- Create directory if it doesn't exist  
				IF NOT EXISTS ( SELECT	*
								FROM	#CheckPathExistance
								WHERE	FileIsDir = 1 )
				BEGIN  
					SET @Cmd = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = master.dbo.xp_create_subdir N'''
						+ @BackupDirWorking
						+ ''' IF @ReturnCode <> 0 RAISERROR(''Error creating directory.'', 16, 1)'  
						--  SET @Cmd = 'EXECUTE master.dbo.xp_create_subdir N''' + @BackupDir + ''' '  

					IF @Debug > 0
						PRINT @Cmd  
					ELSE
						EXEC ( @Cmd )  
					IF @@ERROR <> 0
					BEGIN  
						SET @Operation = 'DB Storage Check'  
						SELECT	@StatusMsg = 'Error - Unable to create backup directory ('
								+ @BackupDirWorking + ')'
							  , @Success = 0
							  , @CompleteSuccess = 0  
						--RAISERROR(@StatusMsg,16,1)  
						RETURN 10  
					END  
				END --IF NOT EXISTS ( SELECT * FROM #CheckPathExistance WHERE FileIsDir = 1 )   

				--Check for backup mirror path existance  
				IF @MirrorBackupDirWorking IS NOT NULL
				BEGIN  
					TRUNCATE TABLE #CheckPathExistance  
					SELECT	@Cmd = 'master.dbo.xp_fileexist "'
							+ @MirrorBackupDirWorking + '"'  
					INSERT	#CheckPathExistance
							EXEC (@Cmd
								)  

					IF NOT EXISTS ( SELECT	* FROM	#CheckPathExistance
									WHERE	FileIsDir = 1 )
					BEGIN  
						SET @Cmd = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = master.dbo.xp_create_subdir N'''
							+ @MirrorBackupDirWorking
							+ ''' IF @ReturnCode <> 0 RAISERROR(''Error creating Mirror directory.'', 16, 1)'  
						IF @Debug > 0
							PRINT @Cmd  
						ELSE
							EXEC ( @Cmd )  
						IF @@ERROR <> 0
						BEGIN  
							SET @Operation = 'DB Storage Check'  
							SELECT	@StatusMsg = 'Error - Unable to create mirror backup directory ('
									+ @MirrorBackupDirWorking + ')'
								  , @Success = 0
								  , @CompleteSuccess = 0  
							RETURN 10  
						END  
					END  
				END --IF @MirrorBackupDirWorking IS NOT NULL   

			--DROP TABLE #CheckPathExistance  
			  
			END -- @CreateSrvDir = 1  
  
  
			--Build the Backup File Name  
            IF @PreserveBackupSet = 1   
                SET @FileExt = @FileExt + '.save'  
  
  
			--Run DBCC CHECKDB if requested  
            IF @PerformDBCC = 1   
            BEGIN  
                SET @Operation = 'DBCC CHECKDB Start'  

                IF @LOGResults = 1   
                    EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,  
                        @DatabaseID = @DBID, @DBName = @DBName,  
                        @Operation = @Operation, @MessageText = @StatusMsg,  
                        @Success = 1  

                IF @Debug > 0   
                BEGIN  
                    SELECT  @StatusMsg = 'Executing DBCC CHECKDB on Database ' + @DBName + CHAR(10)  
                    PRINT @StatusMsg  
                    DBCC CHECKDB (@DBName)  
                    SET @RC = @@ERROR  
                END  
                ELSE   
                BEGIN  
                    DBCC CHECKDB (@DBName) WITH NO_INFOMSGS  
                    SET @RC = @@ERROR  
                END  

                SET @Operation = 'DBCC CHECKDB Finish'  

                IF @LOGResults = 1   
                    EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,  
                        @DatabaseID = @DBID, @DBName = @DBName,  
                        @Operation = @Operation, @MessageText = @StatusMsg,  
                        @Success = 1  
            END  
  
			--Handle errors.  
            IF @RC <> 0   
				GOTO FailedBackup  
            ELSE   
                IF @LOGResults = 1   
                    EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,  
                            @DatabaseID = @DBID, @DBName = @DBName,  
                            @Operation = @Operation, @MessageText = @StatusMsg,  
                            @Success = 1  
                              
			--=============================  
			--Backup database(s)  
			--=============================  
     
			--Can't do Differential or log backup on Master DB.  
            IF @BackupType IN ('L', 'D') AND @DBName = 'Master'   
                GOTO NextDB  
  
            ResetBackupType:  
  
			--Take care of log backups on simple recovery DBs.  
            IF DATABASEPROPERTYEX(@DBName, 'Recovery') = 'SIMPLE' AND @BackupType = 'L'  
            BEGIN  
                IF @Debug > 0   
                BEGIN  
                    SELECT  @StatusMsg = 'System Database ' + @DBName + ' skipped for transaction log backup'   
                    PRINT @StatusMsg  
                END  

                IF @BackupSingleDB = 0   
                    GOTO NextDB  
                ELSE --Just one system database log requested.  
                BEGIN  
                    SELECT  @StatusMsg = 'Error - Unable to backup the log for ' + @DBName + ' - System Database'  
                    RAISERROR(@StatusMsg,17,1) WITH LOG  
                    RETURN 1  
                END  
            END --IF @DBID <= 4 (System DB's)  
  
    
            IF @BackupType = 'D'   
            BEGIN  
                SET @Operation = 'DIFF Backup'  
                SET @Options = 'DIFFERENTIAL'  
            END  
            ELSE IF @BackupType = 'C'   
                SET @Operation = 'FULL Backup'  
            ELSE IF @BackupType = 'G'    
                SET @Operation = 'Filegroup Backup'  
            ELSE IF @BackupType = 'L'    
                SET @Operation = 'Log Backup'  


            IF @Copy_Only = 1 --SQL server will ignore if differential backup.  
                SET @Options = 'Copy_Only'  
  
			--========================  
			--Native SQL Backup  
			--========================  
			IF @BackupProduct = 2
			BEGIN  
				SELECT	@BackupCmd = CASE WHEN @BackupType IN ('C', 'D', 'G')
										  THEN 'BACKUP DATABASE ['
											   + @DBName + '] '
											   + ISNULL(@dsqlFileGroupIncludeList,
														'') + ' TO '
										  WHEN @BackupType = 'L'
											   AND NOT @DBStatus & 8 <> 0
										  THEN 'BACKUP LOG [' + @DBName
											   + '] ' + ' TO '
										  WHEN @BackupType = 'L'
											   AND @DBStatus & 8 <> 0
											   AND SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR),
														  1, 2) < 10 --Deprecated in SQL 2008. (Not necessary.)  
											   THEN 'BACKUP TRAN ['
											   + @DBName
											   + '] WITH TRUNCATE_ONLY'
									 END
					  , @FileNumber = 1
					  , @Filenames = 'DISK = ''' + @PhyName + ''''  

				IF @NumberOfBackupFiles > 1
				BEGIN  
					WHILE @FileNumber < @NumberOfBackupFiles
					BEGIN  
						SET @Filenames = @Filenames + ',DISK = '''
							+ REPLACE(@PhyName, @FileExt,
									  '_'
									  + CAST(@FileNumber AS VARCHAR(2))
									  + @FileExt + '''')     
						SET @FileNumber = @FileNumber + 1  
					END  
				END  

				SELECT	@BackupCmd = @BackupCmd + @Filenames  

				IF @MirrorBackupDirWorking IS NOT NULL
				BEGIN  
					SET @BackupCmd = @BackupCmd + ' Mirror to '
						+ REPLACE(@Filenames, @BackupDirWorking,
								  @MirrorBackupDirWorking)  
				END  

				-- SET Options for backup. Append values to @Options which starts out as NULL value.  
				IF SERVERPROPERTY('EngineEdition') >= 3
					AND @CompressionLevel > 0
					AND @SQLVersion >= 10
					SELECT	@Options = COALESCE(@Options + ', COMPRESSION', ' COMPRESSION')  
				IF @EncryptionKey IS NOT NULL
					SELECT	@Options = COALESCE(@Options
												+ ', PASSWORD = '''
												+ @EncryptionKey + '''',
												' PASSWORD = '''
												+ @EncryptionKey + '''')  
				IF @InitBackupDevice = 1
					SELECT	@Options = COALESCE(@Options
												+ ', INIT, FORMAT',
												' INIT, FORMAT')  
				IF @MaxTransferSizeBytes <> 1048576
					SELECT	@Options = COALESCE(@Options
												+ ', MAXTRANSFERSIZE = '
												+ CAST(@MaxTransferSizeBytes AS VARCHAR(9)),
												' MAXTRANSFERSIZE = '
												+ CAST(@MaxTransferSizeBytes AS VARCHAR(9)))  
				IF @Options IS NOT NULL
					SET @BackupCmd = @BackupCmd + ' WITH ' + @Options  

			END --IF @BackupProduct = 2  

			--========================  
			--Litespeed SQL Backup  
			--========================  
			
			ELSE IF @BackupProduct = 0   
			BEGIN  
				SELECT	@Backupname = CASE WHEN @BackupType = 'L'
										   THEN @Backupname + 'Log Backup' --This is a litespeed only option.  
										   ELSE 'Backup'
									  END
					  , @BackupDesc = CASE WHEN @BackupType = 'L'
										   THEN 'Backup of database log for DB ' + @DBName
												+ ' on ' + CAST(GETDATE() AS VARCHAR(30))
										   ELSE 'Backup of database ' + @DBName + ' on '
												+ CAST(GETDATE() AS VARCHAR(30))
									  END
					  , @FileNumber = 1
					  , @Filenames = ', @filename = ' + CHAR(39) + @PhyName + CHAR(39)
					  , @BackupCmd = CASE WHEN @BackupType = 'L'
										  THEN N'EXEC master.dbo.xp_backup_log @database = '
											   + CHAR(39) + @DBName + CHAR(39) + CHAR(10)
											   + @Filenames
										  ELSE N'EXEC @RC = master.dbo.xp_backup_database @database = '
											   + CHAR(39) + @DBName + CHAR(39)
									 END  

				IF @NumberOfBackupFiles > 0
				BEGIN  
					WHILE @FileNumber < @NumberOfBackupFiles
					BEGIN  
						SET @Filenames = @Filenames + ', @filename = '''
							+ REPLACE(@PhyName, @FileExt,
									  '_' + CAST(@FileNumber AS VARCHAR(2))
									  + @FileExt + '''')    
						SET @FileNumber = @FileNumber + 1  
					END  
				END  

				SELECT	@BackupCmd = @BackupCmd + CHAR(10) + @Filenames  

				IF @MirrorBackupDirWorking IS NOT NULL
				BEGIN  
					SET @BackupCmd = @BackupCmd + ' @Mirror = ' + REPLACE(@Filenames,
																	  @BackupDirWorking,
																	  @MirrorBackupDirWorking)  
				END  

				--Note: @Threads are ignored by multiple files in Litespeed.  
				SET @BackupCmd = @BackupCmd + CHAR(10) + ', @backupname = ' + CHAR(39)
					+ @Backupname + CHAR(39) + CHAR(10) + ', @desc = ' + CHAR(39)
					+ COALESCE(@Description, @BackupDesc) + CHAR(39) + CHAR(10)
					+ COALESCE(',' + REPLACE(@dsqlFileGroupIncludeList, 'filegroup',
											 '@filegroup') + CHAR(39) + CHAR(10), '')
					+ ', @threads = ' + CONVERT(VARCHAR(2), @Threads) + CHAR(10)
					+ ', @CompressionLevel = ' + CONVERT(VARCHAR(2), @CompressionLevel)
					+ CHAR(10) + COALESCE(', @throttle = '
										  + CONVERT(VARCHAR(3), @SLSThrottle) + CHAR(10),
										  '') + ', @affinity = '
					+ CONVERT(VARCHAR(4), ISNULL(@SLSAffinity, 'NULL')) + CHAR(10)
					+ ', @priority = ' + CONVERT(VARCHAR(2), @SLSPriority) + CHAR(10)
					+ ', @init = ' + CONVERT(VARCHAR(1), @InitBackupDevice) + CHAR(10)
					+ ', @doubleclick = ' + CONVERT(CHAR(1), @DoubleClickRestore)
					+ CHAR(10) + ', @logging = ' + CONVERT(CHAR(1), @SLSLogging) + CHAR(10)
					+ ', @olrmap = ' + CONVERT(CHAR(1), @OLRMap) + CHAR(10)
					+ ', @MaxTransferSize = ' + CONVERT(VARCHAR(7), @MaxTransferSizeBytes)
					+ CHAR(10) + COALESCE(', ' + @SLSOptionalCommands + CHAR(10), '') --+ COALESCE(', ''' + REPLACE(@SLSOptionalCommands,'''','''''') + '' + char(10), '')  
					+ COALESCE(', @with = ' + CHAR(39) + @Options + CHAR(39) + CHAR(10),
							   '')--Blank if no Options.  
				IF @EncryptionKey IS NOT NULL
					SELECT	@BackupCmd = @BackupCmd + ', @encryptionkey = ' + CHAR(39)
							+ @EncryptionKey + CHAR(39) + CHAR(10)  
				IF @EncryptedValue IS NOT NULL
					SELECT	@BackupCmd = @BackupCmd + ', @jobp = ' + CHAR(39)
							+ @EncryptedValue + CHAR(39) + CHAR(10)  

				--Backup cannot append to an exe.  
				IF @DoubleClickRestore = 1
					AND @InitBackupDevice <> 1
				BEGIN  
					SET @DoubleClickRestore = 0  
					IF @Debug > 0
					BEGIN  
						SELECT	@StatusMsg = 'Cannot create DoubleClick Restore with @InitBackupDevice = 0'  
						PRINT @StatusMsg  
					END  
				END  
				ELSE
					IF @DoubleClickRestore = 1
						SET @PhyName = @PhyName + '.exe'  

			END--IF @BackupProduct ='D'

            ELSE   
				
			IF @BackupType = 'L' --Transaction Log Backup  
            BEGIN  

				--==========================  
				--Quest Litespeed Log Backup  
				--==========================  
                IF @BackupProduct = 0   
                    BEGIN  
                        SELECT  @Backupname = @Backupname + ' Log Backup',  
                                @BackupDesc = 'Backup of database Log for DB ' + @DBName + ' on ' + CAST(GETDATE() AS VARCHAR(30)),  
                                @FileNumber = 1,  
                                @Filenames = ', @filename = ' + CHAR(39) + @PhyName + CHAR(39)  

                        SELECT  @BackupCmd = 'EXEC master.dbo.xp_backup_log' + CHAR(10) + '@database = ' + CHAR(39) + @DBName + CHAR(39) + CHAR(10) + @Filenames  

                        IF @MirrorBackupDirWorking IS NOT NULL   
                        BEGIN  
                            SET @BackupCmd = @BackupCmd + ' @Mirror = ' + REPLACE(@Filenames, @BackupDirWorking, @MirrorBackupDirWorking)  
                        END  

                        SET @BackupCmd = @BackupCmd + CHAR(10) + ', @backupname = ' + CHAR(39) + @Backupname + CHAR(39) + CHAR(10) + ', @desc = ' + CHAR(39) + COALESCE(@Description,@BackupDesc) + CHAR(39) + CHAR(10) + ', @threads = ' 
                        + CONVERT(VARCHAR(2), @Threads) + CHAR(10) + ', @CompressionLevel = ' + CONVERT(VARCHAR(2), @CompressionLevel) + CHAR(10) + COALESCE(', @throttle = ' + CONVERT(VARCHAR(3), @SLSThrottle) + CHAR(10), '') 
                        + ', @affinity = ' + CONVERT(VARCHAR(2), ISNULL(@SLSAffinity, 'NULL')) + CHAR(10) + ', @priority = ' + CONVERT(VARCHAR(2), @SLSPriority) + CHAR(10) + ', @init = ' + CONVERT(CHAR(1), @InitBackupDevice) + CHAR(10) 
                        + ', @doubleclick = ' + CONVERT(CHAR(1), @DoubleClickRestore) + CHAR(10) + ', @logging = ' + CONVERT(CHAR(1), @SLSLogging) + CHAR(10) + ', @MaxTransferSize = ' + CONVERT(VARCHAR(7), @MaxTransferSizeBytes)   
                        + CHAR(10) + COALESCE(', ' + @SLSOptionalCommands + CHAR(10), '')  

                        IF @EncryptionKey IS NOT NULL   
                            SELECT  @BackupCmd = @BackupCmd + ', @encryptionkey = ' + CHAR(39) + @EncryptionKey + CHAR(39) + CHAR(10)  

						--Backup cannot append to an exe.  
                        IF @DoubleClickRestore = 1 AND @InitBackupDevice <> 1   
                        BEGIN  
                            SET @DoubleClickRestore = 0  
                            IF @Debug > 0   
                                BEGIN  
                                    SELECT @StatusMsg = 'Cannot create DoubleClick Restore with @InitBackupDevice = 0'  
                                    PRINT @StatusMsg  
                                END  
                        END  
                        ELSE   
                            IF @DoubleClickRestore = 1   
                                SET @PhyName = @PhyName + '.exe'  
                    END --Transaction Log Backup Litespeed  
                      
				ELSE IF @BackupProduct = 2
				--==========================
				--NATIVE LOG BACKUP START      
				--==========================
				BEGIN  
					SET @Filenames = 'DISK = ''' + @PhyName + ''''      
					SET @BackupCmd = 'BACKUP LOG [' + @DBName + '] TO ' + @Filenames      

					IF @MirrorBackupDir IS NOT NULL
					BEGIN      
						SET @BackupCmd = @BackupCmd + ' Mirror to ' + REPLACE(@Filenames,
																		  @BackupDirWorking,
																		  @MirrorBackupDirWorking)      
					END      
					     
					IF @EncryptionKey IS NOT NULL
						SELECT	@Options = ' PASSWORD = ''' + @EncryptionKey + ''''      
					IF @InitBackupDevice IS NOT NULL
						SELECT	@Options = COALESCE(@Options + ', INIT, FORMAT',
													'INIT, FORMAT')      
					IF @MaxTransferSizeBytes <> 1048576
						SELECT	@Options = COALESCE(@Options + ', MAXTRANSFERSIZE = '
													+ CAST(@MaxTransferSizeBytes AS VARCHAR(9)),
													' MAXTRANSFERSIZE = '
													+ CAST(@MaxTransferSizeBytes AS VARCHAR(9)))      
					IF @OPTIONS IS NOT NULL
						SET @BackupCmd = @BackupCmd + ' WITH ' + @OPTIONS      

				END --IF @BackupProduct = 2   
			END --IF @BackupType = 'L' Transaction Log Backup  

		--================================================  
		--Begin execution of generated backup command:  
		--================================================  
		IF @PurgeFilesOnly = 0  
		BEGIN  
		SELECT  @StatusMsg = 'Command executed: ' + CHAR(10) + @BackupCmd + CHAR(10)  
		  
		IF @Debug > 0   
		BEGIN  
			PRINT 'Executing ' + @Operation + ' of Database ' + @DBName + CHAR(10)  
			PRINT @StatusMsg  
		END  

		SET @Operation = CASE WHEN @BackupProduct = 0 THEN 'Quest Litespeed '  
			   WHEN @BackupProduct = 1 THEN 'Redgate SQLBackup '  
			   WHEN @BackupProduct = 2 THEN 'Native SQL '  
			   WHEN @BackupProduct = 3 THEN 'Idera SQLSafe '  
			   WHEN @BackupProduct = 4 THEN 'Hyperbac '  
			   ELSE ''  
			 END  
		                            
		SET @Operation = @Operation + CASE WHEN @BackupType = 'L' THEN 'Log Backup'  
				   WHEN @BackupType = 'C' THEN 'Data Backup'  
				   WHEN @BackupType = 'G' THEN 'Filegroup Backup'  
				   WHEN @BackupType = 'D' THEN 'Diff Backup'  
				   ELSE ''  
				 END  

		--Log start of backup.  
		IF @LOGResults = 1  
			EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,  
			@DatabaseID = @DBID, @DBName = @DBName,  
			@Operation = @Operation,  
			@NumberofFiles = @NumberOfBackupFiles,  
			@PhysicalLocation = @PhyName,  
			@MirrorBackupLocation = @MirrorBackupDirWorking,  
			@Success = @Success, @MessageText = @StatusMsg,  
			@BackupInitialized = @InitBackupDevice,  
			@CompressionLevel = @CompressionLevel,  
			@SLSThrottle = @SLSThrottle, @SLSAffinity = @SLSAffinity,  
			@SLSPriority = @SLSPriority,  
			@EncryptionKey = @EncryptionKey,  
			@MaxTransferSizeKB = @MaxTransferSizeKB,  
			@SLSOptionalCommands = @SLSOptionalCommands  

		--Start the backup, retry if # of Attempts was passed in.  
		WHILE @RetryAttemptNumber <= @RetryAttempts  
		BEGIN  

			--EXECUTE DB Backup Operation:  
			IF @BackupProduct = 0 --Note: Can't capture extended stored proc error values with try/catch.  
			BEGIN  
				EXEC sp_executesql @BackupCmd, @ParmDefinition, @RC OUTPUT  
				SET @Success = CASE	WHEN @RC = 0 THEN 1
									ELSE 0
							   END  
			END  
			ELSE
			BEGIN  
				BEGIN TRY  
					EXEC (@BackupCmd)  
					SET @Success = 1  
				END TRY  
				BEGIN CATCH  
					IF ERROR_NUMBER() = 3013
						BEGIN  
							IF @Debug > 0
								PRINT 'Diff backup attempted before Full backup has occurred.'  
							SELECT	@BackupType = 'C'
								  , @Options = NULL
								  , @RC = NULL
								  , @dsqlFileGroupIncludeList = NULL
								  , @Success = 1
								  , @StatusMsg = NULL
								  , @BackupDirWorking = NULL
								  , @RetryAttemptNumber = 0  

							GOTO ResetBackupType  
						END  

					SELECT	@Success = 0
						  , @CompleteSuccess = 0  
					SET @StatusMsg = 'Errorcode=' + CAST(ERROR_NUMBER() AS VARCHAR(6))
						+ ': ' + 'ErrorMessage=' + ISNULL(ERROR_MESSAGE(), '')  
				END CATCH  
			END  

			IF @Debug > 0   
				PRINT 'Return Code=' + CAST (@rc AS VARCHAR(6))  

			--Log success  
			IF @Success = 1
				BEGIN  
					IF @RetryAttemptNumber = 1
						SET @Operation = @Operation + ' Finished'  
					IF @LOGResults = 1
						EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,
							@DatabaseID = @DBID, @DBName = @DBName,
							@Operation = @Operation, @NumberofFiles = @NumberOfBackupFiles,
							@PhysicalLocation = @PhyName,
							@MirrorBackupLocation = @MirrorBackupDirWorking,
							@Success = @Success, @MessageText = @StatusMsg,
							@BackupInitialized = @InitBackupDevice,
							@CompressionLevel = @CompressionLevel,
							@SLSThrottle = @SLSThrottle, @SLSAffinity = @SLSAffinity,
							@SLSPriority = @SLSPriority, @EncryptionKey = @EncryptionKey,
							@MaxTransferSizeKB = @MaxTransferSizeKB,
							@SLSOptionalCommands = @SLSOptionalCommands  

					BREAK  
				END  
				ELSE
				BEGIN  
				--Log failure  
					SELECT	@Success = 0
						  , @CompleteSuccess = 0
						  , @Operation = @Operation + ' Failed'
						  , @StatusMsg = 'Attempt#' + CAST(@RetryAttemptNumber AS CHAR(1))
							+ ': Error = ' + ISNULL(@StatusMsg, '')  
					IF @LOGResults = 1
					BEGIN  
						IF @BackupProduct = 0
							AND EXISTS ( SELECT	*
										 FROM	master.dbo.sysdatabases
										 WHERE	NAME = 'LiteSpeedLocal' )
							--SELECT TOP 1
							--		@StatusMsg = @StatusMsg
							--		+ CONVERT(VARCHAR(1500), ERRORMESSAGE)
							--FROM	LitespeedLocal.dbo.LitespeedActivity a
							--JOIN	LitespeedLocal.dbo.LitespeedDatabase d ON d.databaseid = a.databaseid
							--WHERE	databasename = @DBName
							--ORDER BY activityid DESC   
							
							SET @StatusMsg = 'Check SELECT TOP 1
@StatusMsg = @StatusMsg
+ CONVERT(VARCHAR(1500), ERRORMESSAGE)
FROM	LitespeedLocal.dbo.LitespeedActivity a
JOIN	LitespeedLocal.dbo.LitespeedDatabase d ON d.databaseid = a.databaseid
WHERE	databasename = ''' + @DBName + '''
ORDER BY activityid DESC'

						EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,
							@DatabaseID = @DBID, @DBName = @DBName,
							@Operation = @Operation,
							@NumberofFiles = @NumberOfBackupFiles,
							@PhysicalLocation = @PhyName,
							@MirrorBackupLocation = @MirrorBackupDirWorking,
							@Success = @Success, 
							@MessageText = @StatusMsg,
							@BackupInitialized = @InitBackupDevice,
							@CompressionLevel = @CompressionLevel,
							@SLSThrottle = @SLSThrottle, 
							@SLSAffinity = @SLSAffinity,
							@SLSPriority = @SLSPriority,
							@EncryptionKey = @EncryptionKey,
							@MaxTransferSizeKB = @MaxTransferSizeKB,
							@SLSOptionalCommands = @SLSOptionalCommands  
					END  

					IF @RC = 9987 --Possible FTS index in offline state.  
					BEGIN  
						SET @BackupCmd = 'select db_name() as CurrentDB, df.name as logicalname, df.type_desc, physical_name, state_desc  
from [' + @DBName + '].sys.database_files df  
left join [' + @DBName + '].sys.data_spaces ds on ds.data_space_id = df.data_space_id  
Where (ds.type = ''FG'' or ds.type is null) order by df.type'  

						EXEC @BackupCmd  
					END  

					SET @RetryAttemptNumber = @RetryAttemptNumber + 1  
					SET @Operation = REPLACE(@Operation, ' Failed', '')  
				END  
			END--WHILE @RetryAttemptNumber <= @RetryAttempts  
		END-- @PurgeFilesOnly = 0  
		
		--If we are in failed backup condition, go on to next db, skip verify step.  
            IF @RC <> 0 AND @BackupSingleDB = 1   
                GOTO NoCursorReturn  
            ELSE   
                IF @RC <> 0   
                    GOTO NextDB  
   
			--===========================  
			--Verify Backup Device  
			--===========================  
   
			IF @VerifyBackup = 1
				AND @PurgeFilesOnly = 0
				BEGIN  
					SELECT	@Operation = 'Verify Backup'  
					IF @BackupProduct = 2
					BEGIN  
						SELECT	@BackupCmd = 'RESTORE VERIFYONLY FROM '
								+ @Filenames  

						IF @EncryptionKey IS NOT NULL
							SELECT	@BackupCmd = @BackupCmd
									+ ' WITH PASSWORD = '''
									+ @EncryptionKey + ''''  

					END --IF @BackupProduct = 2  
					ELSE
					BEGIN  
						SELECT	@BackupCmd = 'EXEC @VerifyRC = master.dbo.xp_restore_verifyonly'
								+ CHAR(10) + RIGHT(@Filenames,
												   (LEN(@Filenames) - 1))
								+ CHAR(10)  

						IF @EncryptionKey IS NOT NULL
							SELECT	@BackupCmd = @BackupCmd
									+ ', @encryptionkey = ' + CHAR(39)
									+ @EncryptionKey + CHAR(39) + CHAR(10)  

					END --IF @BackupProduct <> 2  
  
					--Begin execution of generated verify command.  
					SELECT	@StatusMsg = 'Command executed: ' + CHAR(10)
							+ @BackupCmd + CHAR(10)  
                      
					IF @Debug > 0
					BEGIN  
						PRINT 'Executing Verify of Backup Device '
							+ @PhyName + CHAR(10)  
						PRINT @StatusMsg  
					END  
  
					WAITFOR DELAY '00:00:02' --Give time to close file.  
					IF @LOGResults = 1
						EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,
							@DatabaseID = @DBID, @DBName = @DBName,
							@Operation = @Operation,
							@NumberofFiles = @NumberOfBackupFiles,
							@PhysicalLocation = @PhyName,
							@MirrorBackupLocation = @MirrorBackupDirWorking,
							@Success = 1, @MessageText = @StatusMsg,
							@BackupInitialized = @InitBackupDevice,
							@CompressionLevel = @CompressionLevel,
							@SLSThrottle = @SLSThrottle,
							@SLSAffinity = @SLSAffinity,
							@SLSPriority = @SLSPriority,
							@EncryptionKey = @EncryptionKey,
							@MaxTransferSizeKB = @MaxTransferSizeKB,
							@SLSOptionalCommands = @SLSOptionalCommands  
  
					--EXECUTE DB Verify Operation:  
					IF @BackupProduct = 0 --Can't capture extended stored proc error values with try/catch.  
					BEGIN  
						EXEC sp_executesql @BackupCmd,
							@ParmDefinitionVerify, @VerifyRC OUTPUT  
						SET @Success = CASE	WHEN @VerifyRC = 0 THEN 1
											ELSE 0
									   END  
					END  
					ELSE
					BEGIN  
						BEGIN TRY  
							EXEC (@BackupCmd)  
							SET @Success = 1  
						END TRY  
						BEGIN CATCH  
							SELECT	@Success = 0
								  , @StatusMsg = 'Errorcode='
									+ CAST(ERROR_NUMBER() AS VARCHAR(6))
									+ ': ' + 'ErrorMessage='
									+ ISNULL(ERROR_MESSAGE(), '')
								  , @CompleteSuccess = 0  
						END CATCH  
					END  
  
					IF @Debug > 0
						PRINT 'Return Code=' + CAST (@VerifyRC AS VARCHAR(6))  
  
					IF @Success = 0
						SET @Operation = @Operation + ' Failed'  
					ELSE
						SET @Operation = 'Verify Backup Finished'  
  
					IF @LOGResults = 1
					BEGIN  
						IF @BackupProduct = 0
							AND EXISTS ( SELECT	*
										 FROM	master.dbo.sysdatabases
										 WHERE	NAME = 'LiteSpeedLocal' )
							--SELECT TOP 1
							--		@StatusMsg = @StatusMsg
							--		+ CONVERT(VARCHAR(1500), ERRORMESSAGE)
							--FROM	LitespeedLocal.dbo.LitespeedActivity a
							--JOIN	LitespeedLocal.dbo.LitespeedDatabase d ON d.databaseid = a.databaseid
							--WHERE	databasename = @DBName
							--ORDER BY activityid DESC   

							SET @StatusMsg = 'Check SELECT TOP 1
@StatusMsg = @StatusMsg
+ CONVERT(VARCHAR(1500), ERRORMESSAGE)
FROM	LitespeedLocal.dbo.LitespeedActivity a
JOIN	LitespeedLocal.dbo.LitespeedDatabase d ON d.databaseid = a.databaseid
WHERE	databasename = ''' + @DBName + '''
ORDER BY activityid DESC'

						EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,
							@DatabaseID = @DBID, @DBName = @DBName,
							@Operation = @Operation,
							@NumberofFiles = @NumberOfBackupFiles,
							@PhysicalLocation = @PhyName,
							@MirrorBackupLocation = @MirrorBackupDirWorking,
							@Success = @Success, @MessageText = @StatusMsg,
							@BackupInitialized = @InitBackupDevice,
							@CompressionLevel = @CompressionLevel,
							@SLSThrottle = @SLSThrottle,
							@SLSAffinity = @SLSAffinity,
							@SLSPriority = @SLSPriority,
							@EncryptionKey = @EncryptionKey,
							@MaxTransferSizeKB = @MaxTransferSizeKB,
							@SLSOptionalCommands = @SLSOptionalCommands  
					END  
  
				END--IF @VerifyBackup = 1  
  
				--===========================  
				--Clean up tasks--  
				--===========================  
				--Delete Old Backup Files and Remove Backup History  
				IF @RetainDays IS NOT NULL
					AND @Success = 1
					AND @DesktopHeapIssue IS NULL--If heap issue, xp_cmdshell results will be null.  
					BEGIN  
						SELECT	@StatusMsg = 'File Cleanup Process: '
							  , @Operation = 'File Cleanup'  
  
						IF @LOGResults = 1
						BEGIN      
							EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,
								@DatabaseID = @DBID, @DBName = @DBName,
								@Operation = @Operation,
								@NumberofFiles = @NumberOfBackupFiles,
								@PhysicalLocation = @BackupDirWorking,
								@Success = @Success,
								@MessageText = @StatusMsg      
						END  
       
						--Building up Table of Files to Delete  
						IF OBJECT_ID('tempdb.dbo.#DirOut') > 0
							DROP TABLE #DirOut  
						CREATE TABLE #DirOut ([Output] VARCHAR(255))  
  
						SELECT	@CmdStr = 'dir "' + @BackupDirWorking
								+ @ServerName + '.' + REPLACE(@DBName, ' ',
															  '_') + '.'
								+ @BackupTypeShortDesc + '.*' + @FileExt
								+ '" /B'  
  
						BEGIN TRY  
							INSERT	#DirOut
									EXEC master.dbo.xp_cmdshell @CmdStr  
						END TRY  
						BEGIN CATCH  
							IF ERROR_NUMBER() = 15281  --xp_cmdshell is disabled, so lets temporarily enable it.  
							BEGIN  
								PRINT 'xp_cmdshell access is turned off, trying again by temporarily turning it on and back off'  

								EXEC sp_configure 'show advanced option', '1';  
								RECONFIGURE;  
								EXEC sp_configure 'xp_cmdshell', '1';  
								RECONFIGURE;  

								INSERT	#DirOut
										EXEC master.dbo.xp_cmdshell @CmdStr  

								EXEC sp_configure 'xp_cmdshell', '0';  
								EXEC sp_configure 'show advanced option', '0';  
								RECONFIGURE;  
							END  
						END CATCH  
  
						DELETE	FROM #DirOut
						WHERE	[OUTPUT] IS NULL  
  
						--Doing a dir on anything will get you a successful xp_cmdshell output;  
						--assume we captured error message if row still exists and not like ServerName%  
						IF NOT EXISTS ( SELECT	*
										FROM	#DirOut
										WHERE	[OUTPUT] LIKE @ServerName + '%'
												OR [Output] = 'File Not Found' )
							BEGIN  
								SELECT	@StatusMsg = 'Error trying to run - '
										+ @StatusMsg + @CmdStr
										+ '. CMD Message: ' + [OUTPUT]
								FROM	#DirOut
								WHERE	[OUTPUT] NOT LIKE @ServerName + '%'  
  
								SELECT	@Operation = 'Getting Directory Listing'
									  , @CompleteSuccess = 0  
  
								IF @LOGResults = 1
									EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,
										@DatabaseID = @DBID, @DBName = @DBName,
										@Operation = @Operation,
										@PhysicalLocation = @PhyName,
										@MirrorBackupLocation = @MirrorBackupDirWorking,
										@Success = 0,
										@MessageText = @StatusMsg  
  
								--Skip deletion as folder has issue, or some other error occurred.  
								GOTO PurgeHistory  
							END  
  
						IF @Debug > 0
						BEGIN  
							PRINT ISNULL(@StatusMsg, '') + @CmdStr  
						END  
  
						--===========================  
						--Purging Files--  
						--===========================  
						DECLARE BUFiles CURSOR FAST_FORWARD READ_ONLY
						FOR
						--Limit cursor to just bare minimum. Only backup type currently selected will be in table.  
						SELECT	[Output]
						FROM	#DirOut
						WHERE	[OUTPUT] LIKE @ServerName + '.'
								+ REPLACE(@DBName, ' ', '_') + '%' + @FileExt  
  
						OPEN BUFiles  
						FETCH NEXT FROM BUFiles INTO @BUFile  
						WHILE @@FETCH_STATUS = 0
						BEGIN  
							--Initialize variable:  
							SELECT	@BaseBUFileDatalength = LEN(@ServerName
															  + '.'
															  + REPLACE(@DBName,
															  ' ', '_') + '.')
									+ 4 --4 is for backup type (Full, etc.)      
    
							--Reconstruct DateTime From Filename  
							IF @BUFile LIKE @ServerName + '.'
								+ REPLACE(@DBName, ' ', '_')
								+ '.[A-Z][A-Z][A-Z][A-Z].[2][0-1][0-9][0-9][0-9][0-9][0-9][0-9]%'
								+ @FileExt
								BEGIN  
									SELECT	@BUFileDate = LEFT(SUBSTRING(@BUFile,
															  @BaseBUFileDatalength
															  + 2,
															  LEN(@BUFile)), 8)  
								END  
                      
							--Compare Date 1/25/2011 - Change to >= @RetainDays instead of > as with large backups you would have 2 copies of weekly full backups, but really just want one.  
							IF DATEDIFF(d,
										CONVERT(SMALLDATETIME, @BUFileDate, 12),
										GETDATE()) >= @RetainDays
								BEGIN  
									SELECT	@CmdStr = 'del "'
											+ @BackupDirWorking + @BUFile
											+ '"'  
									IF @Debug > 0
										PRINT 'Debug Print: ' + @CmdStr  
									ELSE
										BEGIN  
											BEGIN TRY  
												EXEC @RC = master.dbo.xp_cmdshell @CmdStr,
													NO_OUTPUT  
											END TRY  
											BEGIN CATCH  
												IF ERROR_NUMBER() = 15281  --xp_cmdshell is disabled, so lets temporarily enable it.  
													BEGIN  
														PRINT 'xp_cmdshell access is turned off, trying again by temporarily turning it on and back off'  

														EXEC sp_configure 'show advanced option',
															'1';  
														RECONFIGURE;  
														EXEC sp_configure 'xp_cmdshell',
															'1';  
														RECONFIGURE;  

														EXEC @RC = master.dbo.xp_cmdshell @CmdStr,
															NO_OUTPUT  

														EXEC sp_configure 'xp_cmdshell',
															'0';  
														EXEC sp_configure 'show advanced option',
															'0';  
														RECONFIGURE;  
													END  
												ELSE
													BEGIN  
														SELECT
															  @StatusMsg = 'Error trying to run - '
															  + @StatusMsg
															  + @CmdStr
															  + ' Errorcode='
															  + CAST(ERROR_NUMBER() AS VARCHAR(6)) + ': '
															  + 'ErrorMessage=' + ': '
															  + ISNULL(ERROR_MESSAGE(),
															  '')  

														SELECT
															  @Operation = 'Deleting Old Files'
															, @CompleteSuccess = 0  

														IF @LOGResults = 1
															EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,
															  @DatabaseID = @DBID,
															  @DBName = @DBName,
															  @Operation = @Operation,
															  @PhysicalLocation = @PhyName,
															  @MirrorBackupLocation = @MirrorBackupDirWorking,
															  @Success = 0,
															  @MessageText = @StatusMsg  

														IF @Debug > 0
														BEGIN  
															PRINT @StatusMsg  
														END  
													END  
											END CATCH  
										END  
								END --IF DATEDIFF(d, CONVERT(SMALLDATETIME, @BUFileDate, 12), GETDATE()) >= @RetainDays   
							ELSE
								IF @Debug > 0
								BEGIN  
									SELECT	@StatusMsg = 'Debug Print: File '
											+ @BUFile
											+ ' does not match date criteria: '
											+ CAST(CONVERT(SMALLDATETIME, @BUFileDate, 12) AS VARCHAR(12))
											+ ' < '
											+ CAST(GETDATE() - @RetainDays AS VARCHAR(12))  
									PRINT @StatusMsg  
								END  
							FETCH NEXT FROM BUFiles INTO @BUFile  
						END  
  
						CLOSE BUFiles  
						DEALLOCATE BUFiles  
						DROP TABLE #DirOut  
  
						SET @StatusMsg = 'Finished file cleanup process.'  
  
						--Purge MSDB backup history.  
						PurgeHistory:  
						IF @MSDBPurgeHistory = 1
							AND @Debug = 0
							AND @MSDBPurgeDate IS NOT NULL
							BEGIN  
								INSERT	INTO @DateList
										(DateValue
										)
										SELECT DISTINCT
												CONVERT(VARCHAR(10), backup_start_date, 101) AS DateValue
										FROM	MSDB.dbo.backupset (NOLOCK)
										WHERE	backup_start_date < @MSDBPurgeDate  
  
								SELECT	@MaxIncr = @@RowCount
									  , @Incr = 1  
  
								WHILE @Incr <= @MaxIncr
								BEGIN  
									SELECT	@DSQL = 'EXEC MSDB.DBO.SP_DELETE_BACKUPHISTORY '''
											+ DateValue + ''''
									FROM	@DateList
									WHERE	Incr = @Incr  

									EXEC (@DSQL)  
									SET @Incr = @Incr + 1  
								END  
							END --IF @MSDBPurgeHistory = 1 and @Debug = 0    
					END--IF @RetainDays IS NOT NULL  
  
            IF @BackupSingleDB = 1   
                GOTO NoCursorReturn  
            ELSE   
                GOTO NextDB  
  
            FailedBackup:  
  
            IF EXISTS ( SELECT * FROM master.dbo.sysdatabases  
                        WHERE   NAME = 'LiteSpeedLocal' ) AND @BackupProduct = 0   
                --SELECT TOP 1 @LiteSpeedErrorMessage = CONVERT(VARCHAR(1500), ERRORMESSAGE)  
                --FROM    LitespeedLocal.dbo.LitespeedActivity a  
                --JOIN LitespeedLocal.dbo.LitespeedDatabase d ON d.databaseid = a.databaseid  
                --WHERE   databasename = @DBName  
                --ORDER BY activityid DESC 
                
 				SET @LiteSpeedErrorMessage = 'Check SELECT TOP 1
@StatusMsg = @StatusMsg
+ CONVERT(VARCHAR(1500), ERRORMESSAGE)
FROM	LitespeedLocal.dbo.LitespeedActivity a
JOIN	LitespeedLocal.dbo.LitespeedDatabase d ON d.databaseid = a.databaseid
WHERE	databasename = ''' + @DBName + '''
ORDER BY activityid DESC'

            SELECT  @StatusMsg = COALESCE(@StatusMsg, @LiteSpeedErrorMessage + ' Error - ' + @Operation),  
                    @CompleteSuccess = 0  
   
            IF @Debug > 0   
                SELECT  @StatusMsg AS StatusMsg, @RC AS RCReturned, @BackupCmd AS CommandRun  
  
            IF @LOGResults = 1   
                EXEC dbo.prc_Maint_InsDatabaseBackupLog @BackupType = @BackupTypeShortDesc,  
                    @DatabaseID = @DBID, @DBName = @DBName,  
                    @Operation = @Operation,  
                    @NumberofFiles = @NumberOfBackupFiles,  
                    @PhysicalLocation = @PhyName,  
                    @MirrorBackupLocation = @MirrorBackupDirWorking, @Success = 0,  
                    @MessageText = @StatusMsg,  
                    @BackupInitialized = @InitBackupDevice,  
                    @CompressionLevel = @CompressionLevel,  
                    @SLSThrottle = @SLSThrottle, @SLSAffinity = @SLSAffinity,  
                    @SLSPriority = @SLSPriority,  
                    @EncryptionKey = @EncryptionKey,  
                    @MaxTransferSizeKB = @MaxTransferSizeKB,  
                    @SLSOptionalCommands = @SLSOptionalCommands  
  
            IF @RC = 11704 AND @BackupSingleDB = 0   
                GOTO NextDB  
            ELSE   
                IF @BackupSingleDB = 1   
                    GOTO NoCursorReturn  
  
            NextDB:  
            FETCH NEXT FROM DBCursor INTO @DBName, @DBID, @DBStatus  
  
        END --DBs Cursor  
  
    CLOSE DBCursor  
    DEALLOCATE DBCursor  
  
    NoCursorReturn:  
  
    IF @Success = 0   
        SET @CompleteSuccess = 0  
  
    IF @CompleteSuccess = 1   
    BEGIN  
		SET @StatusMsg = 'All Successful.'  
		RETURN 0  
    END  
    ELSE   
        RAISERROR (@StatusMsg,16,1)  
  
END --Proc  
