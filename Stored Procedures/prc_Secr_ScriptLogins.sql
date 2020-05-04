﻿SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[prc_Secr_ScriptLogins]
	@LoginsToIgnore VARCHAR(1000) = NULL, --Remove logins that we would like to not transfer.
	@Debug BIT = 0
AS
BEGIN
--Proc taken from MVP MCM who wrote a book on database mirroring
--http://www.sqlsoldier.com/wp/sqlserver/transferring-logins-to-a-database-mirror
--11/20/2015 Chuck Lathrope modified to just print from existing server.
SET NOCOUNT ON;

DECLARE	@MaxID INT,
	@CurrID INT,
	@SQL NVARCHAR(MAX),
	@LoginName sysname,
	@IsDisabled INT,
	@Type CHAR(1),
	@default_database_name SYSNAME,
	@is_policy_checked bit,
	@is_expiration_checked bit,
	@sid VARBINARY(85),
	@SIDString NVARCHAR(100),
	@PasswordHash VARBINARY(256),
	@PasswordHashString NVARCHAR(300),
	@RoleName sysname,
	@Machine sysname = @@SERVERNAME,
	@PermState NVARCHAR(60),
	@PermName sysname,
	@Class TINYINT,
	@MajorID INT,
	@LocalPasswordPolicy INT,
	@LocalExpirationChecked INT

DECLARE	@Logins TABLE (
	 LoginID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
	 [Name] sysname NOT NULL,
	 [SID] VARBINARY(85) NOT NULL,
	 IsDisabled INT NOT NULL,
	 default_database_name SYSNAME NOT NULL,
	 [Type] CHAR(1) NOT NULL,
	 PasswordHash VARBINARY(256) NULL,
	 modify_date DATETIME2,
	 is_policy_checked bit,
	 is_expiration_checked bit
	)
DECLARE	@Roles TABLE (
	 RoleID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
	 RoleName sysname NOT NULL,
	 LoginName sysname NOT NULL
	)
DECLARE	@Perms TABLE (
	 PermID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
	 LoginName sysname NOT NULL,
	 PermState NVARCHAR(60) NOT NULL,
	 PermName sysname NOT NULL,
	 Class TINYINT NOT NULL,
	 ClassDesc NVARCHAR(60) NOT NULL,
	 MajorID INT NOT NULL,
	 SubEndPointName sysname NULL
	)
DECLARE @LoginsToIgnoreTable TABLE (
	LoginName varchar(64)
	)

--Filter out users no longer in AD:
DECLARE @sp_validatelogins TABLE (
        [sid] VARBINARY(85) NOT NULL
        ,NTLogin SYSNAME NOT NULL
    )
INSERT INTO @sp_validatelogins
EXEC sp_validatelogins

--Populate table of logins that we would like to not transfer.
IF @LoginsToIgnore IS NOT NULL 
	INSERT INTO @LoginsToIgnoreTable (LoginName)
		SELECT REPLACE(REPLACE(REPLACE(RowValue,'[',''),']',''),'''','') 
		FROM dbo.GetDelimListasTable (@LoginsToIgnore, NULL)


-- Get all Windows logins from principal server
SET @SQL = 'Select P.name, P.sid, P.is_disabled, P.default_database_name, P.type, L.password_hash, p.modify_date, L.is_policy_checked, L.is_expiration_checked '
	+ CHAR(10) + 'From master.sys.server_principals P' + CHAR(10) 
	+ 'Left Join master.sys.sql_logins L On L.principal_id = P.principal_id' + CHAR(10)
	+ 'Where P.type In (''U'', ''G'', ''S'')' + CHAR(10)
	+ 'And P.[sid] <> 0x01' + CHAR(10) --sa account even if renamed
	+ 'And P.name Not Like ''##%''' + CHAR(10) 
	+ 'And P.name Not Like ''Builtin%''' + CHAR(10) 
	+ 'And P.name Not Like ''NT %''' + CHAR(10) 
	+ 'And CharIndex(''' + @Machine + '\'', P.name) = 0;';

IF @Debug = 1
	PRINT @SQL

INSERT	INTO @Logins
		(Name,
		 SID,
		 IsDisabled,
		 default_database_name, 
		 Type,
		 PasswordHash,
		 modify_date,
		 is_policy_checked,
		 is_expiration_checked
		)
		EXEC sp_executesql @SQL;

--Remove invalid domain names or groups.
DELETE FROM @Logins
WHERE NAME IN (SELECT NTLogin FROM @sp_validatelogins)

--Remove logins that we want to ignore
DELETE FROM @Logins
WHERE Name IN (SELECT LoginName FROM @LoginsToIgnoreTable)

IF @Debug = 1
	SELECT * FROM @Logins

-- Get all roles from principal server
SET @SQL = 'Select RoleP.name, LoginP.name' + CHAR(10) 
	+ 'From master.sys.server_role_members RM' + CHAR(10) 
	+ 'Join master.sys.server_principals RoleP' + CHAR(10)
	+ 'On RoleP.principal_id = RM.role_principal_id' + CHAR(10)
	+ 'Join master.sys.server_principals LoginP' + CHAR(10)
	+ 'On LoginP.principal_id = RM.member_principal_id' + CHAR(10)
	+ 'Where LoginP.type In (''U'', ''G'', ''S'')' + CHAR(10)
	+ 'And LoginP.[sid] <> 0x01' + CHAR(10) --sa account even if renamed
	+ 'And LoginP.name Not Like ''##%''' + CHAR(10) 
	+ 'And LoginP.name Not Like ''Builtin%''' + CHAR(10) 
	+ 'And LoginP.name Not Like ''NT %''' + CHAR(10) 
	+ 'And RoleP.type = ''R''' + CHAR(10) 
	+ 'And CharIndex(''' + @Machine + '\'', LoginP.name) = 0;';

IF @Debug = 1
	PRINT @SQL

INSERT	INTO @Roles (RoleName, LoginName)
		EXEC sp_executesql @SQL;

--Remove invalid domain names or groups.
DELETE FROM @Roles
WHERE LoginName IN (SELECT NTLogin FROM @sp_validatelogins)

IF @Debug = 1
	SELECT * FROM @Roles

-- Get all explicitly granted permissions
SET @SQL = 'Select P.name Collate database_default,' + CHAR(10)
	+ '	SP.state_desc, SP.permission_name, SP.class, SP.class_desc, SP.major_id,' + CHAR(10) 
	+ '	SubEP.name Collate database_default' + CHAR(10) 
	+ 'From master.sys.server_principals P' + CHAR(10)
	+ 'Join master.sys.server_permissions SP' + CHAR(10) + CHAR(9)
	+ 'On SP.grantee_principal_id = P.principal_id' + CHAR(10) 
	+ 'Left Join master.sys.endpoints SubEP' + CHAR(10)
	+ 'On SubEP.endpoint_id = SP.major_id And SP.class = 105' + CHAR(10)
	+ 'Where P.[sid] <> 0x01' + CHAR(10)  --sa account even if renamed
	+ 'And P.name Not Like ''##%''' + CHAR(10) 
	+ 'And P.name Not Like ''Builtin%''' + CHAR(10) 
	+ 'And P.name Not Like ''NT %''' + CHAR(10) 
	+ 'And CharIndex(''' + @Machine + '\'', P.name) = 0;'

IF @Debug = 1
	PRINT @SQL

INSERT	INTO @Perms
		(LoginName,
		 PermState,
		 PermName,
		 Class,
		 ClassDesc,
		 MajorID,
		 SubEndPointName
		)
		EXEC sp_executesql @SQL;

--Remove invalid domain names or groups.
DELETE FROM @Perms
WHERE LoginName IN (SELECT NTLogin FROM @sp_validatelogins)

--Remove logins that we want to ignore
DELETE FROM @Perms
WHERE LoginName IN (SELECT LoginName FROM @LoginsToIgnoreTable)

IF @Debug = 1
	SELECT * FROM @Perms

---------------------------------
--Start Login Sync
---------------------------------
SELECT	@MaxID = MAX(LoginID),
		@CurrID = 1
FROM	@Logins;

WHILE @CurrID <= @MaxID
BEGIN
	SELECT	@LoginName = Name,
			@IsDisabled = IsDisabled,
			@Type = [Type],
			@SID = [SID],
			@PasswordHash = PasswordHash,
			@default_database_name = default_database_name,
			@is_policy_checked = is_policy_checked,
			@is_expiration_checked = is_expiration_checked
	FROM	@Logins
	WHERE	LoginID = @CurrID;
	

	BEGIN

		PRINT 'Starting on Login: ' + @LoginName

		SELECT @LocalPasswordPolicy = is_policy_checked
			,@LocalExpirationChecked = is_expiration_checked
		FROM sys.sql_logins
		WHERE name = @LoginName
		AND is_policy_checked = 1

		SET @SQL = 'ALTER Login ' + QUOTENAME(@LoginName)
		SET @PasswordHashString = '0x' + CAST('' AS XML).value('xs:hexBinary(sql:variable("@PasswordHash"))',
															'nvarchar(300)');
		SET @SQL = @SQL + ' With Password = ' + @PasswordHashString + ' HASHED ' 
		--Temporarily change password policy for password change.
			+ CASE WHEN @is_policy_checked = 1 OR @LocalPasswordPolicy = 1 THEN ', CHECK_POLICY=OFF' ELSE '' END
			+ CASE WHEN @is_expiration_checked = 1 OR @LocalExpirationChecked = 1 THEN ', CHECK_EXPIRATION=OFF' ELSE '' END 
			+ ';'
		--Now reset password policy flags. Error on side of remote host has correct policy settings.
		IF @is_policy_checked = 1 --Only case that triggers the need to reset policy options.
			SELECT @SQL = @SQL + 'ALTER Login ' + QUOTENAME(@LoginName) + ' WITH ' 
				+ CASE WHEN @is_policy_checked = 1 THEN ' CHECK_POLICY=ON' ELSE '' END
				+ CASE WHEN @is_expiration_checked = 1 THEN ', CHECK_EXPIRATION=ON' ELSE '' END 
				+ ';'

		IF @Debug = 0
		BEGIN
			BEGIN TRY
				PRINT @SQL;
			END TRY
			BEGIN CATCH
			    SELECT
					ERROR_NUMBER() AS ErrorNumber
					,ERROR_SEVERITY() AS ErrorSeverity
					,ERROR_STATE() AS ErrorState
					,ERROR_LINE() AS ErrorLine
			        ,ERROR_MESSAGE() AS ErrorMessage;
				PRINT @SQL
			END CATCH
		END
		ELSE
		BEGIN
			PRINT @SQL;
		END
	END--@UpdatePasswords

	IF NOT EXISTS ( SELECT	1
					FROM	sys.server_principals
					WHERE	name = @LoginName )
	BEGIN
		PRINT 'Creating Login ' + QUOTENAME(@LoginName)
		SET @SQL = 'Create Login ' + QUOTENAME(@LoginName)
		IF @Type IN ('U', 'G')
		BEGIN
			SET @SQL = @SQL + ' From Windows;'
		END
		ELSE
		BEGIN
			SET @PasswordHashString = '0x' + CAST('' AS XML).value('xs:hexBinary(sql:variable("@PasswordHash"))',
															  'nvarchar(300)');
			
			SET @SQL = @SQL + ' With Password = ' + @PasswordHashString
				+ ' HASHED, ';
			
			SET @SIDString = '0x' + CAST('' AS XML).value('xs:hexBinary(sql:variable("@SID"))',
														  'nvarchar(100)');
			SET @SQL = @SQL + 'SID = ' + @SIDString 

			IF EXISTS (SELECT * FROM sys.databases WHERE [name] = @default_database_name)
				SET @SQL = @SQL + ', DEFAULT_DATABASE = [' + @default_database_name + '];'

		END

		IF @Debug = 0
		BEGIN
			BEGIN TRY
				PRINT @SQL;
			END TRY
			BEGIN CATCH
			    SELECT
					ERROR_NUMBER() AS ErrorNumber
					,ERROR_SEVERITY() AS ErrorSeverity
					,ERROR_STATE() AS ErrorState
					,ERROR_LINE() AS ErrorLine
			        ,ERROR_MESSAGE() AS ErrorMessage;
				PRINT @SQL
			END CATCH
		END
		ELSE
		BEGIN
			PRINT @SQL;
		END
		
		IF @IsDisabled = 1
		BEGIN
			SET @SQL = 'Alter Login ' + QUOTENAME(@LoginName) + ' Disable;'
			IF @Debug = 0
			BEGIN
				BEGIN TRY
					PRINT @SQL;
				END TRY
				BEGIN CATCH
			    SELECT
					ERROR_NUMBER() AS ErrorNumber
					,ERROR_SEVERITY() AS ErrorSeverity
					,ERROR_STATE() AS ErrorState
					,ERROR_LINE() AS ErrorLine
			        ,ERROR_MESSAGE() AS ErrorMessage;
				PRINT @SQL
				END CATCH
			END
			ELSE
			BEGIN
				PRINT @SQL;
			END
		END
	END
	
	SELECT @CurrID = @CurrID + 1
	, @LocalPasswordPolicy = NULL
	, @is_expiration_checked = NULL
	, @is_policy_checked = NULL
	, @PasswordHashString = NULL
	, @LocalExpirationChecked = NULL
	, @SIDString = NULL
	, @SID = NULL

END

--Start Role Sync
SELECT	@MaxID = MAX(RoleID),
		@CurrID = 1
FROM	@Roles;

WHILE @CurrID <= @MaxID
BEGIN
	SELECT	@LoginName = LoginName,
			@RoleName = RoleName
	FROM	@Roles
	WHERE	RoleID = @CurrID;

	BEGIN
		PRINT 'Exec sp_addsrvrolemember @rolename = ''' + @RoleName + ''',';
		PRINT '		@loginame = ''' + @LoginName + ''';';
	END

	SET @CurrID = @CurrID + 1;
END

--Start Permissions Sync
SELECT	@MaxID = MAX(PermID),
		@CurrID = 1
FROM	@Perms;

WHILE @CurrID <= @MaxID
BEGIN
	SELECT	@PermState = PermState,
			@PermName = PermName,
			@Class = Class,
			@LoginName = LoginName,
			@MajorID = MajorID,
			@SQL = PermState + SPACE(1) + PermName + SPACE(1)
			+ CASE Class
				WHEN 101 THEN 'On Login::' + QUOTENAME(LoginName)
				WHEN 105
				THEN 'On ' + ClassDesc + '::' + QUOTENAME(SubEndPointName)
				ELSE ''
			  END + ' To ' + QUOTENAME(LoginName) + ';'
	FROM	@Perms
	WHERE	PermID = @CurrID;
	
	SET @SQL = 'use Master; ' + @SQL
	BEGIN
		IF @Debug = 0
		BEGIN
			BEGIN TRY
				PRINT @SQL;
			END TRY
			BEGIN CATCH
			    SELECT
					ERROR_NUMBER() AS ErrorNumber
					,ERROR_SEVERITY() AS ErrorSeverity
					,ERROR_STATE() AS ErrorState
					,ERROR_LINE() AS ErrorLine
			        ,ERROR_MESSAGE() AS ErrorMessage;
				PRINT @SQL
			END CATCH
		END
		ELSE
		BEGIN
			PRINT @SQL;
		END
	END

	SET @CurrID = @CurrID + 1;
END;
END--PROC

GO
