SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--From Paul Randal sqlskills.com
CREATE OR ALTER FUNCTION dbo.udf_IsDBInFullRecovery ( @DBName sysname )
RETURNS BIT
AS
BEGIN
    DECLARE @IsReallyFull  BIT
    , @LastLogBackupLSN NUMERIC (25,0)
    , @RecoveryModel  TINYINT;

    SELECT @LastLogBackupLSN = [last_log_backup_lsn]
    FROM sys.database_recovery_status
    WHERE [database_id] = DB_ID (@DBName);

    SELECT @RecoveryModel = [recovery_model]
    FROM sys.databases
    WHERE [database_id] = DB_ID (@DBName);

    IF (@RecoveryModel = 1 AND @LastLogBackupLSN IS NOT NULL)
        SELECT @IsReallyFull = 1
    ELSE
        SELECT @IsReallyFull = 0;

    RETURN (@IsReallyFull);
END;
;
GO
