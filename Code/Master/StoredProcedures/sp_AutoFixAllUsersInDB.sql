USE master;
GO

IF (OBJECT_ID('dbo.sp_AutoFixAllUsersInDB') IS NULL)
BEGIN
	EXEC('Create procedure dbo.sp_AutoFixAllUsersInDB as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.sp_AutoFixAllUsersInDB.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.sp_AutoFixAllUsersInDB.'
	END
END
GO

ALTER PROCEDURE dbo.sp_AutoFixAllUsersInDB
AS
BEGIN

    DECLARE @AutoFixCommand NVARCHAR(MAX)
    SET @AutoFixCommand = ''

    SELECT --dp.[name], dp.[sid] AS [DatabaseSID], sp.[sid] AS [ServerSID],
       @AutoFixCommand = @AutoFixCommand + ' '
         + 'EXEC sp_change_users_login ''Auto_Fix'', ''' + dp.[name] + ''';'-- AS [AutoFixCommand]
    FROM sys.database_principals dp
    INNER JOIN sys.server_principals sp
        ON dp.[name] = sp.[name] COLLATE DATABASE_DEFAULT
    WHERE dp.[type_desc] IN ('SQL_USER', 'WINDOWS_USER', 'WINDOWS_GROUP')
    AND sp.[type_desc] IN ('SQL_LOGIN', 'WINDOWS_LOGIN', 'WINDOWS_GROUP')
    AND dp.[sid] <> sp.[sid]

    IF (@AutoFixCommand <> '')
    BEGIN
        PRINT 'Fixing users in database: ' + DB_NAME()
        PRINT @AutoFixCommand
        EXEC(@AutoFixCommand)
        PRINT ''
    END
END
GO
EXEC sys.sp_MS_marksystemobject 'sp_AutoFixAllUsersInDB'

