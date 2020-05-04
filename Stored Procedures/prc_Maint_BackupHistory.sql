SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
  
CREATE OR ALTER PROCEDURE dbo.prc_Maint_BackupHistory (  
  @DBName VARCHAR(100),  
  @TableDataOnly BIT = 0, --You just want to see output table only.  
  @MaxDaysSinceLastFullBackup TINYINT = NULL,  
  @MaxPercentageofLastFullBackup TINYINT = NULL,  
 --(1-100) If 75 and 1 TB backup, max differential backup would be 750GB.  
  @DaysSinceLastFullBackup SMALLINT = NULL OUTPUT,  
  @DaysSincePrevLastFullBackup SMALLINT = NULL OUTPUT,  
  @DaysSinceLastDiffBackup SMALLINT = NULL OUTPUT,  
  @DaysSincePrevLastDiffBackup SMALLINT = NULL OUTPUT  
)  
AS   
BEGIN
/******************************************************************************  
**  Name: prc_Maint_BackupHistory  
**  Desc: Get backup information since last 2 full backups on a database.  
**      
**  Parameter info:  
**  @MaxPercentageofLastFullBackup - Data may change quickly, so may want full  
**   backup to happen faster than scheduled full or @MaxDaysSinceLastFullBackup.  
**  
** Example useage:  
--DECLARE @RC int  
--DECLARE @DBName varchar(100)  
--DECLARE @MaxDaysSinceLastFullBackup tinyint,  
--@MaxPercentageofLastFullBackup tinyint,  
--@DaysSinceLastFullBackup smallint,  
--@DaysSincePrevLastFullBackup smallint,  
--@DaysSinceLastDiffBackup smallint,  
--@DaysSincePrevLastDiffBackup smallint  
  
--Set @DBName = 'namehost'  
--Set @MaxPercentageofLastFullBackup = 75  
  
--EXECUTE @RC = prc_Maint_BackupHistory  
--   @DBName=@DBName  
--   --,@TableDataOnly=1  
--  ,@MaxDaysSinceLastFullBackup=@MaxDaysSinceLastFullBackup  
--  ,@MaxPercentageofLastFullBackup=@MaxPercentageofLastFullBackup  
--  ,@DaysSinceLastFullBackup =@DaysSinceLastFullBackup output  
--  ,@DaysSincePrevLastFullBackup =@DaysSincePrevLastFullBackup  output  
--  ,@DaysSinceLastDiffBackup=@DaysSinceLastDiffBackup  output  
--  ,@DaysSincePrevLastDiffBackup =@DaysSincePrevLastDiffBackup output  
  
--Select @RC Result, @DaysSinceLastFullBackup DaysSinceLastFullBackup, @DaysSincePrevLastFullBackup DaysSincePrevLastFullBackup  
--, @DaysSinceLastDiffBackup DaysSinceLastDiffBackup, @DaysSincePrevLastDiffBackup DaysSincePrevLastDiffBackup  
  
**  
**  Auth: Chuck Lathrope  
**  Date: 6/24/2010  
*******************************************************************************  
**  Change History  
*******************************************************************************  
**  Date:  Author:    Description:  
** 7/29/2010  Chuck Lathrope  Add db existance check.
**  9/7/2010  Chuck Lathrope  Added Return 0 if no Full backup.
** 11/2/2010  Chuck Lathrope  Bug fix for when backups haven't occurred recently.
** 12/28/2010 Chuck Lathrope  Accounted for DB's with space at end of name.
*******************************************************************************/  
SET NOCOUNT ON ;  
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;  
  
DECLARE @dbbackupsize BIGINT ,  
    @MaxFULLBackupID INT,  
    @PrevFULLBackupID INT,  
    @MaxDIFFBackupID INT,  
    @PrevDIFFBackupID INT  
      
IF NOT EXISTS (Select * from sys.databases where QUOTENAME(name) = QUOTENAME(@dbname))  
BEGIN  
 PRINT 'Database does not exist'  
 Return 1  
END  
  
--Get most recent FULL backup ID.  
Select @MaxFULLBackupID = backup_set_id, @DaysSinceLastFullBackup = Datediff(dd,backup_start_date,GETDATE())  
from msdb.dbo.backupset where backup_set_id =  
 (SELECT  MaxFULLBackupID = MAX(backup_set_id)  
 FROM    msdb.dbo.backupset  
 WHERE   ( QUOTENAME(database_name) = QUOTENAME(@dbname) OR  QUOTENAME(database_name) = QUOTENAME(rtrim(@dbname)))  
   AND type = 'D' --full backup.  
 GROUP BY database_name)  
  
--Get previous FULL backup ID.  
Select @PrevFULLBackupID = backup_set_id, @DaysSincePrevLastFullBackup = Datediff(dd,backup_start_date,GETDATE())  
from msdb.dbo.backupset where backup_set_id =  
 (SELECT  PrevFULLBackupID = MAX(backup_set_id)  
 FROM    msdb.dbo.backupset  
 WHERE   ( QUOTENAME(database_name) = QUOTENAME(@dbname) OR  QUOTENAME(database_name) = QUOTENAME(rtrim(@dbname)))
   AND type = 'D' --full backup.  
   AND backup_set_id < @MaxFULLBackupID  
 GROUP BY database_name)  
  
  
IF @DaysSinceLastFullBackup IS NULL AND @TableDataOnly = 0  
 RETURN 1  
  
  
--Get last diff  
Select @MaxDIFFBackupID = backup_set_id, @DaysSinceLastDiffBackup = Datediff(dd,backup_start_date,GETDATE())  
from msdb.dbo.backupset where backup_set_id =  
 (SELECT  MaxFULLBackupID = MAX(backup_set_id)  
 FROM    msdb.dbo.backupset  
 WHERE  ( QUOTENAME(database_name) = QUOTENAME(@dbname) OR  QUOTENAME(database_name) = QUOTENAME(rtrim(@dbname)))
   AND type = 'I' --diff backup.  
 GROUP BY database_name)  
  
--Get previous to last diff  
Select @PrevDIFFBackupID = backup_set_id, @DaysSincePrevLastDiffBackup = Datediff(dd,backup_start_date,GETDATE())  
from msdb.dbo.backupset where backup_set_id =  
 (SELECT  PrevFULLBackupID = MAX(backup_set_id)  
 FROM    msdb.dbo.backupset  
 WHERE   ( QUOTENAME(database_name) = QUOTENAME(@dbname) OR  QUOTENAME(database_name) = QUOTENAME(rtrim(@dbname)))
   AND type = 'I' --diff backup.  
   AND backup_set_id < @MaxDIFFBackupID  
 GROUP BY database_name)  
  
  
IF @TableDataOnly = 1 and @MaxPercentageofLastFullBackup IS NOT NULL   
BEGIN  
  
 DECLARE @DBInfo TABLE (  
  DatabaseName VARCHAR(100),  
  BackupType VARCHAR(15),  
  BackupMB INT,  
  PercentofLastFullBackup INT,  
  BackupFinished DATETIME,  
  DaysSinceLastFull SMALLINT,  
  DaysSincePrevLastFull SMALLINT,  
  MinutesToBackup SMALLINT  
 )  
 INSERT  INTO @DBInfo (DatabaseName,BackupType,BackupMB,PercentofLastFullBackup,BackupFinished,DaysSinceLastFull,DaysSincePrevLastFull,MinutesToBackup)  
  SELECT  bup.database_name AS DatabaseName ,  
    BackupType = CASE bup.type WHEN 'D' THEN 'Full DB'  
     WHEN 'I' THEN 'Diff DB'  
     WHEN 'L' THEN 'Log'  
     WHEN 'F' THEN 'FileorFileGroup'  
     WHEN 'G' THEN 'Diff file'  
     WHEN 'P' THEN 'Partial'  
     WHEN 'Q' THEN 'Diff partial'  
     ELSE 'UNKNOWN'  
     END,  
    CAST(bup.backup_size / 1024 / 1024 AS INT) AS BackupMB ,  
    CASE WHEN bup.backup_finish_date > bup2.backup_finish_date THEN CAST((1-(bup2.backup_size-bup.backup_size)/bup2.backup_size)*100 AS INT) ELSE NULL END AS PercentofLastFullBackup ,  
    bup.backup_finish_date  AS BackupFinished,  
    DATEDIFF(dd, bup2.backup_finish_date, bup.backup_finish_date) AS DaysSinceLastFull ,  
    DATEDIFF(dd, bup3.backup_finish_date, bup.backup_finish_date) AS DaysSincePrevLastFull ,  
    DATEDIFF(mi,bup.backup_start_date, bup.backup_finish_date) as MinutesToBackup  
  FROM    msdb.dbo.backupset bup with (nolock)  
  LEFT JOIN msdb.dbo.backupset bup2  with (nolock) ON bup.database_name = bup2.database_name  
            AND bup2.backup_set_id = @MaxFULLBackupID  
  LEFT JOIN msdb.dbo.backupset bup3  with (nolock) ON bup.database_name = bup3.database_name  
            AND bup3.backup_set_id = @PrevFULLBackupID  
  WHERE   bup.backup_set_id >= @PrevFULLBackupID  
    AND (QUOTENAME(bup.database_name) = QUOTENAME(@dbname) OR QUOTENAME(bup.database_name) = QUOTENAME(rtrim(@dbname)))
  ORDER BY bup.backup_set_id DESC  
  
 IF @TableDataOnly = 1   
  SELECT * FROM  @DBInfo  
 ELSE   
  BEGIN  
   --If so much of the data has changed, we really should do a full backup.  
   IF @MaxPercentageofLastFullBackup IS NOT NULL   
   BEGIN  
    IF EXISTS ( SELECT  * FROM @DBInfo  
       WHERE   BackupType <> 'FULL DB'  
         AND PercentofLastFullBackup >= @MaxPercentageofLastFullBackup )   
     RETURN 1  
   END  
  
  END  
END  
  
--Return false if we have gone over threshold of days since last full backup.  
IF ISNULL(@DaysSinceLastFullBackup,10000) > @MaxDaysSinceLastFullBackup   
 RETURN 1  
ELSE  
 RETURN 0  
  
END
;
GO
