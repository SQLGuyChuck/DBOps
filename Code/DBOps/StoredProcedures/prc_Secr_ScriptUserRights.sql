SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Secr_ScriptUserRights
    @User NVARCHAR(128) = NULL ,
    @Database SYSNAME = NULL ,
    @IgnoreObjectRights TINYINT = 0 ,--If you don't care to script out server rights.
    @RemoveDBUserRightsOnly BIT = 0 ,--If you want to keep connect to server rights.
    @RemoveAllUserRights BIT = 0 ,--Remove everything user has rights to on the server.
    @Debug BIT = 0
AS 
/******************************************************************
**  Proc: prc_Secr_ScriptUserRights
**
**  Purpose: script out the security permissions for objects
**
--  All users: EXEC prc_Secr_ScriptUserRights  @IgnoreObjectRights = 1, @database = 'master', @debug = 1 , @user = 'sqluser', @debug = 1
**
--  One user: EXEC prc_Secr_ScriptUserRights 'sa', 'master'
**
**	Modified 3/6/2009 Chuck Lathrope 
**	--Reduced output text duplication. 
**	--Allowed disabled user use. 
**	--Allowed Public grant display.
**	--Added Server Connection rights.
**	--Added Account Creation text.
**	--Added database filter option
**	--Forced user to output in text mode in SMSS.
**	5/12/2010	Chuck Lathrope - Added DB Role assignments.
**	4/13/2011	Chuck Lathrope - Bug fix on filter to role assignments.
**	8/28/2012	Chuck Lathrope - Many bug fixes and code cleanup.
**	10/17/2012  Chuck Lathrope - Removed where clause for removing db_owner from report.
**	12/03/2012	Matias Sincovich - Remove filter for EXEC proc only on line 202.
**	12/8/2014	Chuck Lathrope		Added non-readable AG database check
**  TODO: FN_BUILTIN_PERMISSIONS('Object') is deprecated, need replacement.
******************************************************************/
    SET NOCOUNT ON

    DECLARE @SC VARCHAR(4000) ,
        @CursorOnObjects VARCHAR(4000) ,
        @CMD VARCHAR(MAX) ,
        @CMD1 VARCHAR(MAX) ,
        @RoleMembership VARCHAR(MAX) ,
        @RevokeUsersandSchemas VARCHAR(MAX),
        @DBNAME SYSNAME ,
		@tmpstr NVARCHAR(128),
		@sql1 NVARCHAR(MAX),
		@sql2 NVARCHAR(MAX),
		@sql3 NVARCHAR(MAX),
		@db sysname

    IF CAST(@RemoveDBUserRightsOnly AS TINYINT) + CAST(@RemoveAllUserRights AS TINYINT) = 2 
    BEGIN
        PRINT 'Conflicting parameters sent in.'
        RETURN
    END

    CREATE TABLE #TempSecurables2
        (
          [DBName] SYSNAME ,
          [State] VARCHAR(1000) ,
          [Grantee] SYSNAME ,
          [ObjectName] SYSNAME ,
          [ColumnName] SYSNAME
        )	
	-- These code segments are used for column level privileges
    IF OBJECT_ID('tempdb..##ScriptSecurityObjects') > 0 
        DROP TABLE ##ScriptSecurityObjects
    IF OBJECT_ID('tempdb..##ObjectAbbrev') > 0 
        DROP TABLE ##ObjectAbbrev
    IF OBJECT_ID('tempdb..##DBUserList') > 0 
        DROP TABLE ##DBUserList

    CREATE TABLE ##ObjectAbbrev
        (
          class_desc NVARCHAR(60) ,
          permission_name SYSNAME ,
          type CHAR(4) ,
          covering_permission_name SYSNAME ,
          parent_class_desc NVARCHAR(60) ,
          parent_covering_permission_name SYSNAME
        )

    CREATE TABLE ##DBUserList
        (
          DBName SYSNAME ,
          SecurityPrincipalName SYSNAME ,
          ServerPrincipalID INT
        )
        
	--This just gives us a lookup table from all the abbreviations your SQL Engine has.
    INSERT  INTO ##ObjectAbbrev
            SELECT  *
            FROM    FN_BUILTIN_PERMISSIONS('Object');

    CREATE TABLE ##ScriptSecurityObjects
        (
          DBName SYSNAME NOT NULL ,
          Id INT NULL ,
          Type1Code CHAR(6) COLLATE database_default NOT NULL ,
          ObjType CHAR(2) COLLATE database_default NULL ,
          ActionName VARCHAR(4) COLLATE Latin1_General_CI_AS_KS_WS NOT NULL ,
          ActionFullName NVARCHAR(60) COLLATE database_default NULL ,
          ActionCategory TINYINT NOT NULL ,
          ProtectTypeName CHAR(10) COLLATE database_default NULL ,
          ColId INT NULL ,
          OwnerName SYSNAME COLLATE database_default NOT NULL ,
          ObjectName SYSNAME COLLATE database_default NOT NULL ,
          GranteeId INT NOT NULL ,
          GrantorId INT NOT NULL ,
          GranteeName SYSNAME COLLATE database_default NOT NULL ,
          GrantorName SYSNAME COLLATE database_default NOT NULL ,
          ColumnName SYSNAME COLLATE database_default NULL
        )  
        
	CREATE TABLE #UserCreation (NAME sysname, CodetoRun varchar(1000))

    SET @tmpstr = '/** Generated ' + CONVERT (VARCHAR, GETDATE()) + ' on ' + @@SERVERNAME + ' */'
    PRINT @tmpstr
    
    SELECT  @CMD1 = 'USE [?];
declare  @grantee  integer
' + CASE WHEN @USER IS NOT NULL
       THEN 'select @grantee = database_principal_id(''' + @user + ''' ) '
       ELSE 'select @grantee = null'
  END
+ ' 
INSERT ##DBUserList (DBName, SecurityPrincipalName, ServerPrincipalID)
SELECT  QUOTENAME(DB_NAME()) AS DBName, dp.name AS SecurityPrincipalName, sp.principal_id
FROM    sys.database_principals dp 
LEFT JOIN sys.server_principals sp on dp.sid = sp.sid
WHERE dp.type <> ''R''
AND dp.name NOT IN (''dbo'',''GUEST'',''sys'',''INFORMATION_SCHEMA'')

INSERT ##ScriptSecurityObjects  
( dbname,Id ,Type1Code ,ObjType,ActionName,ActionCategory,ProtectTypeName,ColId,OwnerName,ObjectName,GranteeId,GrantorId,GranteeName,GrantorName,ColumnName)  
SELECT ''[?]'',sysp.major_id,case when sysp.type in (''RF'',''SL'',''UP'') then ''1Regul''else ''2Simpl''end ,obj.type collate database_default 
	,sysp.type collate database_default,sysp.class, sysp.state collate database_default ,sysp.minor_id ,schema_name(obj.schema_id),obj.name 
	,sysp.grantee_principal_id ,sysp.grantor_principal_id,user_name(sysp.grantee_principal_id),user_name(sysp.grantor_principal_id),''.''  
FROM sys.database_permissions sysp  join sys.all_objects obj on obj.object_id = sysp.major_id  
WHERE sysp.class = 1 and (@grantee is null or sysp.grantee_principal_id = @grantee) 
AND obj.type in(''U'',''TF'',''V'',''IF'')
AND user_name(sysp.grantee_principal_id) <> ''public''

IF EXISTS (SELECT * FROM ##ScriptSecurityObjects) 
BEGIN
	UPDATE t SET ColumnName = ''(All)'' FROM ##ScriptSecurityObjects t WHERE ColId = 0 AND Type1Code = ''1Regul''
	AND NOT EXISTS (SELECT * FROM ##ScriptSecurityObjects col WHERE col.Id = t.Id 
	AND col.ColId > 0 AND col.GranteeId = t.GranteeId AND col.GrantorId = t.GrantorId AND col.ActionName = t.ActionName) 
	UPDATE ##ScriptSecurityObjects 
	SET ColumnName = CASE ColumnName WHEN ''(All)'' THEN ''(All+New)'' ELSE ''(New)'' END  
	WHERE ColId = 0 AND ObjType = ''U'' AND Type1Code = ''1Regul'' 
	UPDATE ##ScriptSecurityObjects SET ColumnName = col_name(Id,ColId) WHERE Type1Code=''1Regul'' AND ColId > 0 AND dbname = ''[''+ db_name()+ '']''
END
delete from ##ScriptSecurityObjects where ProtectTypeName = ''R''  
UPDATE ##ScriptSecurityObjects SET ActionFullName = ISNULL(permission_name collate database_default, ActionName)
	,ProtectTypeName = CASE ProtectTypeName WHEN ''G'' THEN ''Grant'' WHEN ''D'' THEN ''Deny'' WHEN ''W'' THEN ''Grant_WGO'' END  
FROM ##ScriptSecurityObjects t LEFT JOIN ##ObjectAbbrev t2 on t.ActionName collate database_default = t2.type
'

    SELECT  @RoleMembership = 'USE [?];
SELECT ''Use [?];'';
WITH perms_cte
as
(
	    SELECT  USER_NAME(principal_id) AS principal_name, principal_id
		FROM    sys.database_principals
)
SELECT ''EXEC sp_addrolemember N'''''' + rm.role_name + '''''', N'''''' + rm.member_principal_name + ''''''''
FROM    perms_cte p
right JOIN (
		select role_principal_id, dp.type_desc as principal_type_desc, member_principal_id,user_name(member_principal_id) as member_principal_name,user_name(role_principal_id) as role_name, sp.name as login
		from    sys.database_role_members rm
		INNER   JOIN sys.database_principals dp ON     rm.member_principal_id = dp.principal_id
		left	Join sys.server_principals sp on dp.sid = sp.sid
) rm
ON     rm.role_principal_id = p.principal_id
WHERE rm.member_principal_name = ' + COALESCE(CHAR(39) + @User + CHAR(39), 'rm.member_principal_name') + '
AND rm.member_principal_name <> ''dbo''
AND rm.member_principal_name NOT LIKE ''##%''
order by  rm.member_principal_name'


--Get user rights into processing table.
    SET @CMD = 'USE [?] 
--Priviledges for objects
SELECT ''[?]'', CASE WHEN (b.state_desc COLLATE database_default) = ''GRANT_WITH_GRANT_OPTION'' THEN ''GRANT'' 
ELSE (b.state_desc COLLATE database_default) END + '' '' 
+ b.permission_name + '' ON ['' + c.name + ''].['' + a.name + ''] TO '' + QUOTENAME(p.name) +
CASE STATE WHEN ''W'' THEN '' WITH GRANT OPTION'' ELSE '''' END, p.name,'''',''''
FROM sys.all_objects a, sys.database_permissions b, sys.schemas c, sys.database_principals p
WHERE a.OBJECT_ID = b.major_id 
AND c.Name <> ''sys''
AND a.schema_id = c.schema_id
AND b.grantee_principal_id=p.principal_id
AND p.name <> ''sa'' and p.principal_id < 16384 and p.name not like ''##%''
AND p.Name = ' + COALESCE(CHAR(39) + @User + CHAR(39), 'p.name')

   SET @RevokeUsersandSchemas = 'USE [?]
' + --Add schema transfers if a user is passed in.
CASE WHEN ISNULL(@RemoveDBUserRightsOnly, 0) = 1 OR ISNULL(@RemoveAllUserRights, 0) = 1
THEN
'
--User with owned schemas to transfer to dbo
SELECT ''[?]'',''ALTER SCHEMA dbo TRANSFER ['' + c.name + ''].''+ a.name + '';'',c.name
FROM sys.all_objects a, sys.schemas c
WHERE a.schema_id = c.schema_id
AND c.name = ' + COALESCE(CHAR(39) + ISNULL(@User,'') + CHAR(39), '')
ELSE '' END
 + '
UNION ALL
--User with no schemas
SELECT ''[?]'',type_desc,name
FROM sys.database_principals
WHERE name <> ''sa'' and principal_id < 16384 
AND name not like ''##%'' 
AND name = ' + COALESCE(CHAR(39) + @User + CHAR(39), 'name')

	--Execute the dynamic sql statements to populate the global temp tables.
    IF @Database IS NOT NULL 
    BEGIN
        SET @CMD = REPLACE(@CMD, '[?]', '[' + @Database + ']')
        INSERT  INTO #TempSecurables2
			EXEC ( @CMD )
    END
    ELSE 
    BEGIN
		--Hopefully more reliable and doesn't ERROR compared TO sp_msforeachdb
		DECLARE c CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT  name
			FROM sys.databases d 
			LEFT JOIN sys.availability_replicas AS AR
			   ON d.replica_id = ar.replica_id
			LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
				ON ars.group_id = AR.group_id AND ars.replica_id = ar.replica_id
			LEFT JOIN sys.dm_hadr_database_replica_cluster_states AS dbcs
			   ON ars.replica_id = dbcs.replica_id and d.replica_id = dbcs.replica_id AND d.group_database_id = dbcs.group_database_id
			WHERE DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
			AND (ars.role = 1 OR ISNULL(AR.secondary_role_allow_connections,1) > 0) --Primary or able to read secondary db
			ORDER BY name

		OPEN c;

		FETCH NEXT FROM c INTO @db;

		WHILE @@FETCH_STATUS = 0 
			BEGIN
				SET @sql1 = REPLACE(@CMD, '?', @db);
			                
				BEGIN
					INSERT  INTO #TempSecurables2
							EXEC sp_executesql @sql1;
				END

				FETCH NEXT FROM c INTO @db;
			END

		CLOSE c;
		DEALLOCATE c;
    END


    IF EXISTS ( SELECT  1 FROM ##ScriptSecurityObjects ) 
    INSERT  INTO #TempSecurables2
        SELECT  dbname ,
                CASE WHEN ColumnName IN ( '(All+New)', '(All)', '.' )
                        THEN 'GRANT ' + ActionFullName + ' ON ['
                            + OwnerName + '].[' + ObjectName + '] TO '
                            + QUOTENAME(GranteeName)
                        ELSE 'GRANT ' + ActionFullName + ' ON ['
                            + OwnerName + '].[' + ObjectName + '] (['
                            + ColumnName + ']) TO '
                            + QUOTENAME(GranteeName)
                END ,
                GranteeName ,
                ObjectName ,
                ColumnName
        FROM    ##ScriptSecurityObjects

    PRINT '--##### Server level Privileges to User or User Group #####'

    INSERT INTO #UserCreation (NAME, CodetoRun)
    SELECT  sp.NAME,'Create LOGIN [' + sp.name + '] '
            + CASE WHEN sp.type = 'S'
                   THEN 'WITH PASSWORD=N''You_Must_Update'', '--Add Password_hash here in future.
                   WHEN sp.type IN ( 'G', 'U' ) THEN 'FROM WINDOWS WITH '
                   ELSE ''
              END--limited in where clause below to groups 
            + 'DEFAULT_DATABASE=[' + sp.default_database_name + '],'
            + COALESCE(' DEFAULT_LANGUAGE = [' + sp.default_language_name + ']', '')
            + CASE WHEN sp.type_desc = 'SQL_LOGIN'
                   THEN ', CHECK_EXPIRATION='
                        + CASE WHEN sl.is_policy_checked = 1 THEN 'ON'
                               ELSE 'OFF'
                          END + ', CHECK_POLICY='
                        + CASE WHEN sl.is_expiration_checked = 1 THEN 'ON'
                               ELSE 'OFF'
                          END
                   ELSE ''
              END + ';' --+ CHAR(10)
            + CASE WHEN sp.is_disabled = 1
                   THEN CHAR(10) + 'ALTER LOGIN [' + sp.name + ']' + ' DISABLE;'
                   ELSE ''
              END
            + CHAR(10) AS CodetoRun --select * 
    FROM    sys.server_principals sp
            LEFT JOIN sys.sql_logins sl ON sl.principal_id = sp.principal_id
    WHERE   sp.principal_id <> 2 --Public login account
            AND sp.type IN ( 'S', 'G', 'U' )
            AND sp.name = ISNULL(@user, sp.name)
            AND sp.name NOT LIKE '##%'
    UNION ALL
	--Server permissions
    SELECT  sp.name, CASE WHEN p.state IN ( 'G', 'W' ) THEN 'GRANT '
                 WHEN p.state = 'D' THEN 'DENY '
                 WHEN p.state = 'R' THEN 'REVOKE '
                 ELSE 'UNKNOWN State '
            END + p.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS
            + ' TO [' + sp.name + ']'
            + CASE WHEN p.state = 'W' THEN ' WITH GRANT'
                   ELSE ''
              END + ';' AS CodetoRun
    FROM    sys.server_principals sp
            LEFT JOIN sys.sql_logins sl ON sl.principal_id = sp.principal_id
            JOIN sys.server_permissions AS p ON p.grantee_principal_id = sp.principal_id
    WHERE   CLASS = 100 --Ignore Endpoints and Server-Principal's
            AND sp.principal_id <> 2 --Public login account
            AND sp.type IN ( 'S', 'G', 'U' )
            AND sp.name = ISNULL(@user, sp.name)
            AND sp.name NOT LIKE '##%'


	IF @RemoveAllUserRights <> 1
	BEGIN
	    SELECT  'USE Master' + CHAR(10) + 'GO' + CHAR(10)
	    UNION ALL
		SELECT CodetoRun
		FROM #UserCreation a
		WHERE EXISTS (SELECT * FROM ##DBUserList t WHERE a.NAME = t.SecurityPrincipalName AND t.DBName = ISNULL(QUOTENAME(@Database),t.DBName)
						AND t.ServerPrincipalID IS NOT NULL)
	END


--TODO: Need to remove user from all databases they have access to.
    IF @RemoveAllUserRights = 1 --We are dropping user 
        SELECT  'USE Master' + CHAR(10) + 'GO' + CHAR(10) + 'Drop LOGIN ['
                + sp.name + '] ' + CHAR(10) + 'GO' + CHAR(10)
        FROM    sys.server_principals sp
                LEFT JOIN sys.sql_logins sl ON sl.principal_id = sp.principal_id
        WHERE   sp.principal_id <> 2 --Public login account
                AND sp.type IN ( 'S', 'G', 'U' )
                AND sp.name = ISNULL(@user, sp.name)

	--Print out values based on captured data.
    IF @Database IS NOT NULL 
    BEGIN
        SET @CMD1 = REPLACE(@CMD1, '[?]', '[' + @Database + ']')
        EXEC (@CMD1)
            
        SET @RoleMembership = REPLACE(@RoleMembership, '[?]', '[' + @Database + ']')
        EXEC (@RoleMembership)
    END
    ELSE 
    BEGIN
		--Hopefully more reliable and doesn't ERROR compared TO sp_msforeachdb
		DECLARE c CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT  name
			FROM sys.databases d 
			LEFT JOIN sys.availability_replicas AS AR
			   ON d.replica_id = ar.replica_id
			LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
				ON ars.group_id = AR.group_id AND ars.replica_id = ar.replica_id
			LEFT JOIN sys.dm_hadr_database_replica_cluster_states AS dbcs
			   ON ars.replica_id = dbcs.replica_id and d.replica_id = dbcs.replica_id AND d.group_database_id = dbcs.group_database_id
			WHERE DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
			AND (ars.role = 1 OR ISNULL(AR.secondary_role_allow_connections,1) > 0) --Primary or able to read secondary db
			ORDER BY name

		OPEN c;

		FETCH NEXT FROM c INTO @db;

		WHILE @@FETCH_STATUS = 0 
			BEGIN
				SET @sql2 = REPLACE(@CMD1, '?', @db);
				SET @sql3 = REPLACE(@RoleMembership, '?', @db);
			                
				BEGIN
					EXEC sp_executesql @sql2;
					EXEC sp_executesql @sql3;
			            
				END

				FETCH NEXT FROM c INTO @db;
			END

		CLOSE c;
		DEALLOCATE c;
    END

	/*************************
	GRANTING Permissions
	*************************/ 
    IF ISNULL(@RemoveDBUserRightsOnly, 0) = 0 AND ISNULL(@RemoveAllUserRights, 0) = 0
    BEGIN
        PRINT '--##### ALTER PROCedures/Functions, Table and Column Level Privileges to the User #####'

        IF @Debug = 1 
            PRINT 'Create all users on server on just the provided database'
                
        DECLARE CursorOnDatabases CURSOR FORWARD_ONLY FOR
            SELECT DISTINCT
                    GRANTEE ,
                    DBName
            FROM    #TempSecurables2
            WHERE   DBName = ISNULL(@DBNAME, DBName)
                    AND grantee = ISNULL(@User, grantee)
            ORDER BY grantee ASC
        OPEN CursorOnDatabases 
        FETCH NEXT FROM CursorOnDatabases INTO @User, @DBName
        WHILE @@FETCH_STATUS = 0 
            BEGIN
                DECLARE CursorOnUsers CURSOR
                FOR
                    SELECT DISTINCT
                            'USE ' + ts2.DBName + CHAR(10) + 'GO'
                            + CHAR(10) + 'Create User '
                            + QUOTENAME(RTRIM(@User)) + ' FOR LOGIN '
                            + QUOTENAME(RTRIM(@User)) + CHAR(10) + 'GO'
                    FROM    #TempSecurables2 ts2
                    WHERE   DBName = ISNULL(@DBNAME, DBName)
                            AND grantee = ISNULL(@User, grantee)
                                
                OPEN CursorOnUsers 
                FETCH NEXT FROM CursorOnUsers INTO @SC
                --Object permissions:
				WHILE @@FETCH_STATUS = 0 
					BEGIN 
						PRINT @SC
						DECLARE CursorOnObjects CURSOR FORWARD_ONLY
						FOR
							SELECT  RTRIM(ts2.[State]) + ';'
							FROM    #TempSecurables2 ts2
							WHERE   DBName = ISNULL(@DBNAME, DBName)
									AND grantee = ISNULL(@User, grantee)
						OPEN CursorOnObjects  
						FETCH NEXT FROM CursorOnObjects INTO @SC
						WHILE @@FETCH_STATUS = 0 
							BEGIN 
								IF @SC NOT IN ( 'WINDOWS_USER;',
												'SQL_USER;',
												'CERTIFICATE_MAPPED_USER;',
												'WINDOWS_GROUP;',
												'APPLICATION_ROLE;',
												'DATABASE_ROLE;',
												'ASYMMETRIC_KEY_MAPPED_USER;' ) 
									AND @IgnoreObjectRights = 0 
									PRINT @SC
								FETCH NEXT FROM CursorOnObjects INTO @SC
							END
						CLOSE CursorOnObjects 
						DEALLOCATE CursorOnObjects
						FETCH NEXT FROM CursorOnUsers INTO @SC
					END
				CLOSE CursorOnUsers 
				DEALLOCATE CursorOnUsers
				FETCH NEXT FROM CursorOnDatabases INTO @User, @DBName
            END
        CLOSE CursorOnDatabases 
        DEALLOCATE CursorOnDatabases
	
    END
    ELSE 
	/*************************
	REVOKING Permissions
	*************************/ 
    IF ISNULL(@RemoveDBUserRightsOnly, 0) = 1 OR ISNULL(@RemoveAllUserRights, 0) = 1
        BEGIN
            PRINT '--##### Revoking Procedures/Functions, Table and Column Level Privileges to the User #####'

            IF @Debug = 1 
                PRINT 'Remove user and permissions from ALL databases'
            DECLARE CursorOnDatabases CURSOR
            FOR
                SELECT DISTINCT
                        GRANTEE ,
                        DBName
                FROM    #TempSecurables2
                WHERE   DBName = ISNULL(@DBNAME, DBName)
                        AND grantee = ISNULL(@User, grantee)
                ORDER BY DBName ASC
            OPEN CursorOnDatabases 
            FETCH NEXT FROM CursorOnDatabases INTO @User, @DBName
            WHILE @@FETCH_STATUS = 0 
                BEGIN
                    DECLARE CursorOnUsers CURSOR
                    FOR
                        SELECT DISTINCT
                                'USE ' + ts2.DBName + CHAR(10) + 'GO'
                                + CHAR(10)
                        FROM    #TempSecurables2 ts2
                        WHERE   DBName = ISNULL(@DBNAME, DBName)
                                AND grantee = ISNULL(@User, grantee)
                    OPEN CursorOnUsers 
                    FETCH NEXT FROM CursorOnUsers INTO @SC
                    WHILE @@FETCH_STATUS = 0 
                        BEGIN 
                            PRINT @SC
		
                            DECLARE CursorOnObjects CURSOR
                            FOR
                                SELECT  REPLACE(RTRIM(ts2.[State]),
                                                'GRANT', 'REVOKE') + ';'
                                FROM    #TempSecurables2 ts2
                                WHERE   DBName = ISNULL(@DBNAME, DBName)
                                        AND grantee = ISNULL(@User,
                                                            grantee)
                            OPEN CursorOnObjects  
                            FETCH NEXT FROM CursorOnObjects INTO @SC
                            WHILE @@FETCH_STATUS = 0 
                                BEGIN 
                                    IF @SC NOT IN ( 'WINDOWS_USER;',
                                                    'SQL_USER;',
                                                    'CERTIFICATE_MAPPED_USER;',
                                                    'WINDOWS_GROUP;',
                                                    'APPLICATION_ROLE;',
                                                    'DATABASE_ROLE;',
                                                    'ASYMMETRIC_KEY_MAPPED_USER;' ) 
                                        PRINT @SC
                                    FETCH NEXT FROM CursorOnObjects INTO @SC
                                END
                            CLOSE CursorOnObjects 
                            DEALLOCATE CursorOnObjects
                            FETCH NEXT FROM CursorOnUsers INTO @SC
                        END
                    CLOSE CursorOnUsers 
                    DEALLOCATE CursorOnUsers

					--Drop schema from database if exists
                    PRINT 'If Exists (Select * from sys.schemas where name = '''
                        + @User + ''')
DROP SCHEMA [' + @User + '];'
					--Drop user from database
                    PRINT 'If Exists (Select * from sys.database_principals where name = '''
                        + @User + ''')
DROP USER [' + @User + '];'

                    FETCH NEXT FROM CursorOnDatabases INTO @User, @DBName
                END
            CLOSE CursorOnDatabases 
            DEALLOCATE CursorOnDatabases
        END

    IF @Debug = 1 
    BEGIN
        PRINT '@CMD = ' + @CMD
        PRINT '@CMD1 = ' + @CMD1 + CHAR(10) + 'SELECT * FROM ##ScriptSecurityObjects' + CHAR(10) + 'SELECT * FROM ##DBUserList'
        PRINT '@RoleMembership = ' + @RoleMembership
        SELECT * FROM #TempSecurables2
        SELECT * FROM #UserCreation
    END

GO
