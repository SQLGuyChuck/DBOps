SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Secr_UserMigration
	@CurrentUser NVARCHAR(128),
	@NewUser NVARCHAR(128),
	@Database varchar(100) = NULL
AS
BEGIN
/*******************************************************************
**  Purpose: Duplicate user and their permissions (user may not even exist).
**	Will only return scripts where @NewUser doesn't have permission to.
**
**	Note: ***Print in Text display mode.***
**
**	Modified:
**	5/20/2009   Ganesh          Changed string to use the @newuser instead of current user.
**	7/6/2009	Chuck Lathrope	Bug fixes for grant statements. sp_Foreachdb replaced as 2000 char limit.
******************************************************************/
SET NOCOUNT ON

DECLARE @SC VARCHAR(4000)
		,@CMD VARCHAR(max)
		,@CMDSave VARCHAR(max)
		,@DBID int
		,@DBStatus int
		,@Incr smallint
		,@MaxIncr smallint
		,@DBMode varchar(40)
		,@StatusMsg varchar(100)
		,@tmpstr NVARCHAR(128)

DECLARE @DBList Table (ID smallint Identity(1,1), DBName varchar(100), [DBID] int, DBStatus int)

If @CurrentUser like '[%'
	Set @CurrentUser = RTRIM(REPLACE(REPLACE(@CurrentUser,']',''),'[',''))
If @NewUser like '[%'
	Set @NewUser = RTRIM(REPLACE(REPLACE(@NewUser,']',''),'[',''))	

CREATE TABLE #TempSecurables2 ([DBName] sysname,
				[State] VARCHAR(1000))	

SET @tmpstr = '** Generated ' + CONVERT (VARCHAR, GETDATE()) + ' on ' + @@SERVERNAME + ' */'
PRINT @tmpstr

PRINT '--##### Server level Privileges to User or User Group #####'

--Account creation
SELECT 'USE Master;' + CHAR(10) + 'Create LOGIN [' + @NewUser + '] '
	+ CASE WHEN CHARINDEX('\',@NewUser,1) = 0 THEN 'WITH PASSWORD=N''You_Must_Update'', '
		   WHEN CHARINDEX('\',@NewUser,1) > 0 THEN 'FROM WINDOWS WITH '
	  ELSE '' END--limited in where clause below to groups 
	+ 'DEFAULT_DATABASE=[' + sp.default_database_name 
	+ ']' + COALESCE(', DEFAULT_LANGUAGE = [' + sp.default_language_name + ']' , '')
	+ CASE WHEN CHARINDEX('\',@NewUser,1) = 0 THEN ', CHECK_EXPIRATION=' 
		+ CASE WHEN sl.is_policy_checked = 1 THEN 'ON' ELSE 'OFF' END 
		+ ', CHECK_POLICY='	+ CASE WHEN sl.is_expiration_checked = 1 THEN 'ON' ELSE 'OFF' END 
	  ELSE '' END 
	+ CHAR(10) + 'GO' + CHAR(10) 
	+ CASE WHEN sp.is_disabled = 1 THEN 'ALTER LOGIN [' + @NewUser + ']' + ' DISABLE' + CHAR(10) + 'GO' ELSE '' END 
FROM sys.server_principals sp 
LEFT JOIN sys.sql_logins sl on sl.principal_id = sp.principal_id
WHERE sp.principal_id <> 2 --Public login account
AND sp.type in ('S','G','U')
AND sp.name = @CurrentUser
AND NOT EXISTS (SELECT * FROM sys.server_principals isp 
				WHERE isp.principal_id <> 2 --Public login account
				AND isp.type in ('S','G','U')
				AND isp.name = @NEWUser)
UNION ALL
--Server permissions
SELECT CASE WHEN p.state in ('G','W') THEN 'GRANT '
		WHEN p.state = 'D' THEN 'DENY '
		WHEN p.state = 'R' THEN 'REVOKE '
		ELSE 'UNKNOWN state ' END
	+ p.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS + ' TO [' + @NewUser+ ']' + CASE WHEN p.state = 'W' THEN ' WITH GRANT' ELSE '' END
	+ CHAR(10) + 'GO' + CHAR(10) 
FROM sys.server_principals sp 
JOIN sys.server_permissions AS p ON p.grantee_principal_id = sp.principal_id 
WHERE CLASS = 100 --Ignore Endpoints and Server-Principal's
AND sp.principal_id <> 2 --Public login account
AND sp.type in ('S','G','U')
AND sp.name = @CurrentUser
AND NOT EXISTS (SELECT * FROM sys.server_principals isp 
				JOIN sys.server_permissions AS ip ON ip.grantee_principal_id = isp.principal_id 
				WHERE CLASS = 100 --Ignore Endpoints and Server-Principal's
				AND isp.principal_id <> 2 --Public login account
				AND isp.type in ('S','G','U')
				AND isp.name = @NEWUser
				AND ip.permission_name = p.permission_name)

--Privileges for Objects, Tables, and Columns.
SET @CMD = 'USE [?]
SELECT ''[?]'', CASE WHEN (b.state_desc COLLATE database_default) = ''GRANT_WITH_GRANT_OPTION'' THEN ''GRANT'' ELSE (b.state_desc COLLATE database_default) END
+ '' '' + b.permission_name + '' ON ['' + c.name + ''].['' + a.name + ''] TO [' + @NewUser + ']'' + CASE STATE WHEN ''W'' THEN '' WITH GRANT OPTION'' ELSE '''' END
FROM sys.all_objects a, sys.database_permissions b, sys.schemas c WHERE a.OBJECT_ID = b.major_id AND a.schema_id = c.schema_id
AND c.Name <> ''sys''
AND USER_NAME(b.grantee_principal_id) = ''' + @CurrentUser + '''
AND NOT EXISTS (SELECT * FROM sys.all_objects ia, sys.database_permissions ib, sys.schemas ic WHERE ia.OBJECT_ID = ib.major_id AND ia.schema_id = ic.schema_id
AND ic.Name <> ''sys'' AND USER_NAME(ib.grantee_principal_id) = ''' + @NewUser + '''
AND ia.OBJECT_ID = a.OBJECT_ID AND ia.schema_id = a.schema_id) ORDER BY c.name
SELECT ''[?]'', ''GRANT '' + privilege_type + '' ON ['' + table_schema + ''].['' + table_name + ''] ('' + column_name + '') TO [' + @NewUser + ']'' + CASE IS_GRANTABLE WHEN ''YES'' THEN '' WITH GRANT OPTION'' ELSE '''' END
FROM INFORMATION_SCHEMA.COLUMN_PRIVILEGES cp WHERE cp.grantee = ''' + @CurrentUser + '''
AND NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMN_PRIVILEGES icp WHERE icp.grantee = ''' + @NewUser + '''
AND icp.table_catalog=cp.table_catalog
AND icp.table_schema=cp.table_schema
AND icp.table_name=cp.table_name
AND icp.column_name=cp.column_name
AND icp.privilege_type=cp.privilege_type)
AND NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_PRIVILEGES itp
	WHERE itp.grantee=''' + @CurrentUser + '''
	AND itp.table_catalog=cp.table_catalog
	AND itp.table_schema=cp.table_schema
	AND itp.table_name=cp.table_name
	AND itp.privilege_type=cp.privilege_type)'

IF @Database IS NOT NULL
BEGIN
	SET @CMD = REPLACE(@CMD,'[?]','[' + @Database + ']')
	INSERT INTO #TempSecurables2
	EXEC (@CMD)
END
ELSE
BEGIN
	Set @CMDSave = @CMD

	Insert into @DBList (DBName, [DBID], DBStatus)
	SELECT name, dbid, status
	FROM master..sysdatabases
	WHERE [name] NOT IN ('tempdb', 'model')

	Select @MaxIncr = @@RowCount, @Incr = 1

	While @Incr <= @MaxIncr
	BEGIN
		--Set variables
		SELECT @Database = DBName, @DBID = [DBID], @DBStatus = DBStatus
		From @DBList
		Where ID = @Incr

		Set @CMD = REPLACE(@CMDSave,'[?]','[' + @Database + ']')

		--Check Database Accessibility
		SELECT @DBMode = 'OK'

		IF DATABASEPROPERTY(@Database, 'IsDetached') > 0 
			SELECT @DBMode = 'Detached'
		ELSE IF DATABASEPROPERTY(@Database, 'IsInLoad') > 0 
			SELECT @DBMode = 'Loading'
		ELSE IF DATABASEPROPERTY(@Database, 'IsNotRecovered') > 0 
			SELECT @DBMode = 'Not Recovered'
		ELSE IF DATABASEPROPERTY(@Database, 'IsInRecovery') > 0 
			SELECT @DBMode = 'Recovering'
		ELSE IF DATABASEPROPERTY(@Database, 'IsSuspect') > 0 
			SELECT @DBMode = 'Suspect'
		ELSE IF DATABASEPROPERTY(@Database, 'IsOffline') > 0  	
			SELECT @DBMode = 'Offline'
		ELSE IF DATABASEPROPERTY(@Database, 'IsEmergencyMode') > 0 
			SELECT @DBMode = 'Emergency Mode'
		ELSE IF DATABASEPROPERTY(@Database, 'IsShutDown') > 0 
			SELECT @DBMode = 'Shut Down (problems during startup)'

		IF @DBMode <> 'OK'
		BEGIN
			Set @StatusMsg = 'Skipping database ' + @Database + ' - Database is in '  + @DBMode + ' state.'
			PRINT @StatusMsg
			Goto NextDB
		END

		--Put Code here for executing on each of the databases.
		INSERT INTO #TempSecurables2
		EXEC (@CMD)
		
		NextDB:
		Set @Incr = @Incr + 1
	END

END

PRINT '--##### Procedures/Functions, Table and Column Level Privileges to the User #####'

DECLARE cSC CURSOR FOR SELECT DISTINCT 'USE ' + ts2.DBName + CHAR(10) + 'GO' + CHAR(10) + 'If NOT Exists (Select * from sys.database_principals where name = ''' + @NewUser + ''')
Create User ' + QUOTENAME(RTRIM(@NewUser)) + ' FOR LOGIN ' + QUOTENAME(RTRIM(@NewUser)) + CHAR(10) + 'GO',DBName  FROM #TempSecurables2 ts2
OPEN cSC 
FETCH NEXT FROM cSC INTO @SC,@Database
WHILE @@FETCH_STATUS = 0 
	BEGIN 
		PRINT @SC
			DECLARE cSCO CURSOR FOR SELECT RTRIM(ts2.[State]) + ';'  FROM #TempSecurables2 ts2 where DBName = @Database
			OPEN cSCO  
			FETCH NEXT FROM cSCO INTO @SC
			WHILE @@FETCH_STATUS = 0 
				BEGIN 
					PRINT @SC
					FETCH NEXT FROM cSCO INTO @SC
				END
			CLOSE cSCO 
			DEALLOCATE cSCO
		FETCH NEXT FROM cSC INTO @SC,@Database
	END
CLOSE cSC 
DEALLOCATE cSC
END--PROC
;
GO
