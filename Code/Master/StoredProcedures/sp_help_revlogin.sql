USE master
GO
IF (OBJECT_ID('dbo.sp_help_revlogin') IS NULL)
BEGIN
	EXEC('Create procedure dbo.sp_help_revlogin  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.sp_help_revlogin.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.sp_help_revlogin.'
	END
END
GO


ALTER PROCEDURE dbo.sp_help_revlogin
	@login_name sysname = NULL
AS
--http://support.microsoft.com/kb/918992
DECLARE	@name sysname,
	@type VARCHAR(1),
	@hasaccess INT,
	@denylogin INT,
	@is_disabled INT,
	@PWD_varbinary VARBINARY(256),
	@PWD_string VARCHAR(514),
	@SID_varbinary VARBINARY(85),
	@SID_string VARCHAR(514),
	@tmpstr VARCHAR(1024),
	@is_policy_checked VARCHAR(3),
	@is_expiration_checked VARCHAR(3),
	@defaultdb sysname
 
IF (@login_name IS NULL)
	DECLARE login_curs CURSOR
	FOR
	SELECT	p.sid,
			p.name,
			p.type,
			p.is_disabled,
			p.default_database_name,
			l.hasaccess,
			l.denylogin
	FROM	sys.server_principals p
	LEFT JOIN sys.syslogins l ON (l.name = p.name)
	WHERE	p.type IN ('S', 'G', 'U')
			AND p.name <> 'sa'
ELSE
	DECLARE login_curs CURSOR
	FOR
	SELECT	p.sid,
			p.name,
			p.type,
			p.is_disabled,
			p.default_database_name,
			l.hasaccess,
			l.denylogin
	FROM	sys.server_principals p
	LEFT JOIN sys.syslogins l ON (l.name = p.name)
	WHERE	p.type IN ('S', 'G', 'U')
			AND p.name = @login_name
OPEN login_curs

FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @is_disabled,
	@defaultdb, @hasaccess, @denylogin
IF (@@fetch_status = -1)
BEGIN
	PRINT 'No login(s) found.'
	CLOSE login_curs
	DEALLOCATE login_curs
	RETURN -1
END
SET @tmpstr = '/* sp_help_revlogin script '
PRINT @tmpstr
SET @tmpstr = '** Generated ' + CONVERT (VARCHAR, GETDATE()) + ' on '
	+ @@SERVERNAME + ' */'
PRINT @tmpstr
PRINT ''
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		PRINT ''
		SET @tmpstr = '-- Login: ' + @name
		PRINT @tmpstr
		IF (@type IN ('G', 'U'))
		BEGIN -- NT authenticated account/group

			SET @tmpstr = 'CREATE LOGIN ' + QUOTENAME(@name)
				+ ' FROM WINDOWS WITH DEFAULT_DATABASE = [' + @defaultdb + ']'
		END
		ELSE
		BEGIN -- SQL Server authentication
        -- obtain password and sid
			SET @PWD_varbinary = CAST(LOGINPROPERTY(@name, 'PasswordHash') AS varbinary(256))
			EXEC sp_hexadecimal @PWD_varbinary, @PWD_string OUT
			EXEC sp_hexadecimal @SID_varbinary, @SID_string OUT
 
        -- obtain password policy state
			SELECT	@is_policy_checked = CASE is_policy_checked
										   WHEN 1 THEN 'ON'
										   WHEN 0 THEN 'OFF'
										   ELSE NULL
										 END
			FROM	sys.sql_logins
			WHERE	NAME = @name
			SELECT	@is_expiration_checked = CASE is_expiration_checked
											   WHEN 1 THEN 'ON'
											   WHEN 0 THEN 'OFF'
											   ELSE NULL
											 END
			FROM	sys.sql_logins
			WHERE	NAME = @name
 
			SET @tmpstr = 'CREATE LOGIN ' + QUOTENAME(@name)
				+ ' WITH PASSWORD = ' + @PWD_string + ' HASHED, SID = '
				+ @SID_string + ', DEFAULT_DATABASE = [' + @defaultdb + ']'

			IF (@is_policy_checked IS NOT NULL)
			BEGIN
				SET @tmpstr = @tmpstr + ', CHECK_POLICY = '
					+ @is_policy_checked
			END
			IF (@is_expiration_checked IS NOT NULL)
			BEGIN
				SET @tmpstr = @tmpstr + ', CHECK_EXPIRATION = '
					+ @is_expiration_checked
			END
		END
		IF (@denylogin = 1)
		BEGIN -- login is denied access
			SET @tmpstr = @tmpstr + '; DENY CONNECT SQL TO ' + QUOTENAME(@name)
		END
		ELSE
			IF (@hasaccess = 0)
			BEGIN -- login exists but does not have access
				SET @tmpstr = @tmpstr + '; REVOKE CONNECT SQL TO '
					+ QUOTENAME(@name)
			END
		IF (@is_disabled = 1)
		BEGIN -- login is disabled
			SET @tmpstr = @tmpstr + '; ALTER LOGIN ' + QUOTENAME(@name)
				+ ' DISABLE'
		END
		PRINT @tmpstr
	END

	FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @is_disabled,
		@defaultdb, @hasaccess, @denylogin
END
CLOSE login_curs
DEALLOCATE login_curs
RETURN 0
GO
