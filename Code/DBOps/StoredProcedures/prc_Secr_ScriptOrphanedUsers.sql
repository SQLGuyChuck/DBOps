SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Secr_ScriptOrphanedUsers 
					@Database sysname = NULL,
					@Debug bit = 0
AS
BEGIN
/******************************************************************
*  prc_Secr_ScriptOrphanedUsers
*
*  Example usage EXEC prc_Secr_ScriptOrphanedUsers @Database = 'Master', @debug=1
*
*  Created 3/22/2009 Ganesh
*  
******************************************************************
*	Modified:
*	4/27/2009	Chuck Lathrope	Script out drop user statements for all but db/app roles.
*	4/28/2009	Chuck Lathrope	Added schema drop and schema transfers.
*								Warning: schema transfers act like sp_rename and don't update object text!
*****************************************************************/
SET NOCOUNT ON

DECLARE @SC VARCHAR(8000), @CMD VARCHAR(8000), @DBNAME sysname

If object_id('tempdb..#ObjectPermissions') > 0
	Drop Table #ObjectPermissions

CREATE TABLE #ObjectPermissions (DBScript VARCHAR(1000))	

SET @CMD = 'USE [?]
IF DB_ID(''?'') > 4 
Select ''Use [?]''
Union ALL
SELECT distinct ''ALTER AUTHORIZATION ON SCHEMA::'' + QUOTENAME(name) + '' TO dbo''
FROM sys.schemas
WHERE schema_id between 5 and 16383
AND name not in (Select Name from sys.server_principals)
AND name in (Select name from sys.database_principals Where type_desc NOT IN ( ''DATABASE_ROLE'',''APPLICATION_ROLE''))
UNION ALL
SELECT ''--Schema transfers act like sp_rename and do NOT update object text!
ALTER SCHEMA dbo TRANSFER '' + QUOTEName(s.name) + ''.'' + QUOTEName(o.name)
FROM sys.all_objects o 
join sys.schemas s on s.schema_id = o.schema_id
WHERE s.schema_id > 4
and type NOT in (''C'',''D'',''F'',''IT'',''PK'',''S'',''SQ'',''UQ'')
Union ALL
Select ''--Possible schema ownership issues: DatabaseName = '' +CATALOG_NAME+ '', SCHEMA_NAME = '' +SCHEMA_NAME+ '', SCHEMA_OWNER = ''+Quotename(SCHEMA_OWNER)+'' Fix: 
Alter authorization on schema::'' + QUOTENAME(SCHEMA_NAME) + '' to '' + QUOTENAME(SCHEMA_NAME) as Fix
From information_schema.schemata
Where SCHEMA_NAME <> SCHEMA_OWNER
and SCHEMA_OWNER <> ''dbo''
UNION ALL
SELECT distinct ''drop schema '' + QUOTENAME(name)
FROM sys.schemas
WHERE schema_id between 5 and 16383
AND name not in (Select Name from sys.server_principals)
AND name in (Select name from sys.database_principals Where type_desc NOT IN ( ''DATABASE_ROLE'',''APPLICATION_ROLE''))
UNION ALL
SELECT Distinct ''drop user '' + QUOTENAME(name)
FROM sys.database_principals
WHERE Name NOT IN (Select Name from sys.server_principals)
AND type_desc NOT IN (''DATABASE_ROLE'',''APPLICATION_ROLE'')
AND principal_id > 4'

IF @Database IS NOT NULL
BEGIN
	SET @CMD = REPLACE(@CMD,'[?]', + QUOTENAME(@Database) )
	INSERT INTO #ObjectPermissions
	EXEC (@CMD)
END
ELSE
BEGIN
	INSERT INTO #ObjectPermissions
	EXEC master.dbo.sp_MSforeachdb @command1=@CMD
END

IF @Debug = 1
	Print @CMD

SELECT * FROM #ObjectPermissions t
END;
GO
