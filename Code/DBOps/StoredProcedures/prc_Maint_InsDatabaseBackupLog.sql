IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'prc_Maint_InsDatabaseBackupLog' And ROUTINE_SCHEMA = 'dbo')
BEGIN
	EXEC('CREATE Procedure dbo.prc_Maint_InsDatabaseBackupLog  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.prc_Maint_InsDatabaseBackupLog.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.prc_Maint_InsDatabaseBackupLog.'
	END
END
GO


ALTER PROCEDURE dbo.prc_Maint_InsDatabaseBackupLog
	@BackupType varchar(4)
	,@DatabaseID int
	,@DBName varchar(100)
	,@Operation varchar(35)
	,@NumberofFiles tinyint = NULL
	,@MaxTransferSizeKB int = NULL
	,@PhysicalLocation varchar(255) = NULL
	,@MirrorBackupLocation varchar(300) = NULL
	,@Success bit
	,@MessageText varchar(2000) = NULL
	,@BackupInitialized bit = NULL
	,@CompressionLevel tinyint = NULL
	,@SLSThrottle tinyint = NULL
	,@SLSAffinity tinyint = NULL
	,@SLSPriority tinyint = NULL
	,@SLSOptionalCommands varchar(400) = NULL
	,@EncryptionKey varchar(1024) = NULL

AS
BEGIN

/*************************************************************************
** Proc prc_Maint_InsDatabaseBackupLog
** Purpose: Log successful backup operations and verify results.
**
** Revision History:
** 7/14/2008	Chuck Lathrope	Created.
** 8/10/2008	Chuck Lathrope	Removed @LOGResultsTableName change to using a proc and leave as hardcoded in current db.
**								Added @NumberofFiles parameter.
** 11/25/2008	Chuck Lathrope  Added BackupLogID parameters and update instead of insert statement.
** 03/19/2009	Chuck Lathrope	Added @MaxTransferSizeKB and @SLSOptionalCommands parameters/logging capability.
** 10/08/2009	Chuck Lathrope	Removed @BackupLogId parameter.
*****************************************************************************************/
SET NOCOUNT ON

INSERT INTO DatabaseBackupLog (BackupType, DatabaseID, DatabaseName, Operation, NumberofFiles, BackupLocation, MirrorBackupLocation, Success, 
				MessageText, BackupInitialized, CompressionLevel, 
				LitespeedThrottlePercent, LitespeedCPUAffinity, LitespeedSQLPriority, EncryptionKey, MaxTransferSizeKB, LitespeedOptCommands)
Values (@BackupType, cast(@DatabaseID as varchar(5)), @DBName, @Operation, @NumberofFiles, @PhysicalLocation, @MirrorBackupLocation, @Success
		, @MessageText, cast(@BackupInitialized as char(1)), cast(@CompressionLevel as varchar(3))
		, cast(@SLSThrottle as varchar(3)), cast(@SLSAffinity as varchar(3)), cast(@SLSPriority as varchar(3))
		, @EncryptionKey, cast(@MaxTransferSizeKB as varchar(7)), @SLSOptionalCommands)

End
go

