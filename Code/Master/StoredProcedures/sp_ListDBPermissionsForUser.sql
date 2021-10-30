IF (OBJECT_ID('dbo.sp_ListDBPermissionsForUser') IS NULL)
BEGIN
	EXEC('create procedure dbo.sp_ListDBPermissionsForUser as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.sp_ListDBPermissionsForUser.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.sp_ListDBPermissionsForUser.'
	END
END
GO
/**********************************************************
** Purpose: Get all the permissions for a user based on current database.
** exec dbo.sp_ListDBPermissionsForUser 'userx'
***********************************************************/
Alter Procedure dbo.sp_ListDBPermissionsForUser
	@LoginName AS VARCHAR (50)
AS

--ServerRoles:
SELECT @@servername as ServerName, 'ServerRole' = SUSER_NAME(rm.role_principal_id), 'UserName' = lgn.name
from sys.server_role_members rm
Join sys.server_principals lgn on rm.member_principal_id = lgn.principal_id 
WHERE lgn.name = @LoginName
order by SUSER_NAME(rm.role_principal_id)

--Server access for non-sysadmin's:
SELECT @@servername as ServerName, 
	CASE WHEN p.state in ('G','W') THEN 'GRANT '
		WHEN p.state = 'D' THEN 'DENY '
		WHEN p.state = 'R' THEN 'REVOKE '
		ELSE 'UNKNOWN Permission Type ' END AS PermissionType
	, p.permission_name AS PermissionName
	, sp.name + CASE WHEN p.state = 'W' THEN ' (WITH GRANT Option)' ELSE '' END as UserName
	, sp.type_desc as UserNameType
FROM sys.server_principals sp 
LEFT JOIN sys.sql_logins sl on sl.principal_id = sp.principal_id
JOIN sys.server_permissions AS p ON p.grantee_principal_id = sp.principal_id 
WHERE sp.principal_id <> 2 --Public login account
AND sp.name = @LoginName
AND NOT EXISTS (SELECT 'ServerRole' = SUSER_NAME(rm.role_principal_id), 'MemberName' = lgn.name
   from sys.server_role_members rm
   Join sys.server_principals lgn on rm.member_principal_id = lgn.principal_id 
   where rm.role_principal_id >=3 AND rm.role_principal_id <=10 --sp_helpsrvrolemember provided values.
   AND SUSER_NAME(rm.role_principal_id) = 'sysadmin'
   AND lgn.name = sp.name)

--Database Roles:
SELECT user_name(role_principal_id) as DatabaseRole, user_name(member_principal_id) as SQLUserOrWindowsGroup, dp.type_desc as SecurityObjectType
FROM   sys.database_role_members rm
JOIN   sys.database_principals dp ON rm.member_principal_id = dp.principal_id
LEFT JOIN sys.server_principals sp on dp.sid = sp.sid
WHERE member_principal_ID <> 1 --DBO
AND user_name(member_principal_id) = @LoginName

--Get permissions based on role membership/user/public:
;WITH CTE_Roles (role_principal_id)
AS
    (
    SELECT role_principal_id
        FROM sys.database_role_members
        WHERE member_principal_id = USER_ID(@LoginName)
        UNION ALL
    SELECT drm.role_principal_id
        FROM sys.database_role_members drm
                INNER JOIN CTE_Roles CR
                ON drm.member_principal_id = CR.role_principal_id
    )
SELECT DISTINCT
  USER_NAME(CR.role_principal_id) PrincipalName,
  COALESCE(SO.type_desc, DPerms.class_desc) ObjectType,
  DPerms.state_desc + ' ' + DPerms.permission_name Permission,
  CASE DPerms.class_desc
	 WHEN 'SCHEMA' THEN CONVERT(sysname, (SELECT QUOTENAME(SCHEMA_NAME(DPerms.major_id)) FROM sys.schemas objects WHERE objects.schema_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 WHEN 'DATABASE' THEN CONVERT(sysname, QUOTENAME(DB_NAME())) COLLATE DATABASE_DEFAULT
	 WHEN 'OBJECT_OR_COLUMN' THEN CONVERT(sysname, ISNULL((SELECT QUOTENAME(SCHEMA_NAME(so.schema_id)) + '.' + QUOTENAME(so.[name]) + '.' + QUOTENAME(objects.name) FROM sys.columns objects WHERE objects.[object_id] = DPerms.major_id and objects.column_id = DPerms.minor_id), '[' + SCHEMA_NAME(so.schema_id) + '].[' + so.[name] + ']'))  COLLATE DATABASE_DEFAULT
	 WHEN 'DATABASE_PRINCIPAL' THEN CONVERT(sysname, (SELECT QUOTENAME(objects.name) FROM sys.database_principals objects WHERE objects.principal_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 WHEN 'ASSEMBLY' THEN CONVERT(sysname, (SELECT QUOTENAME(objects.name) FROM sys.assemblies objects WHERE objects.assembly_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 WHEN 'TYPE' THEN CONVERT(sysname, (SELECT QUOTENAME(objects.name) FROM sys.types objects WHERE objects.user_type_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 WHEN 'XML_SCHEMA_COLLECTION' THEN CONVERT(sysname, (SELECT QUOTENAME(objects.name) FROM sys.xml_schema_collections objects WHERE objects.xml_collection_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 WHEN 'MESSAGE_TYPE' THEN CONVERT(sysname, (SELECT QUOTENAME(objects.name) FROM sys.service_message_types objects WHERE objects.message_type_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 WHEN 'SERVICE' THEN CONVERT(sysname, (SELECT QUOTENAME(objects.name) FROM sys.services objects WHERE objects.service_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 WHEN 'SERVICE_CONTRACT' THEN CONVERT(sysname, (SELECT QUOTENAME(objects.name) FROM sys.service_contracts objects WHERE objects.service_contract_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 WHEN 'REMOTE_SERVICE_BINDING' THEN CONVERT(sysname, (SELECT distinct + QUOTENAME(objects.name) FROM sys.remote_service_bindings objects WHERE objects.remote_service_binding_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 WHEN 'ROUTE' THEN CONVERT(sysname, (SELECT QUOTENAME(objects.name) FROM sys.routes objects WHERE objects.route_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 WHEN 'FULLTEXT_CATALOG' THEN CONVERT(sysname, (SELECT QUOTENAME(objects.name) FROM sys.fulltext_catalogs objects WHERE objects.fulltext_catalog_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 WHEN 'SYMMETRIC_KEYS' THEN CONVERT(sysname, (SELECT distinct + QUOTENAME(objects.name) FROM sys.symmetric_keys objects WHERE objects.symmetric_key_id = DPerms.major_id AND symmetric_key_id <> 101)) COLLATE DATABASE_DEFAULT
	 WHEN 'CERTIFICATE' THEN CONVERT(sysname, (SELECT distinct + QUOTENAME(objects.name) FROM sys.certificates objects WHERE objects.certificate_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 WHEN 'ASYMMETRIC_KEY' THEN CONVERT(sysname, (SELECT QUOTENAME(objects.name) FROM sys.asymmetric_keys objects WHERE objects.asymmetric_key_id = DPerms.major_id)) COLLATE DATABASE_DEFAULT
	 ELSE CONVERT(sysname, 'UNKNOWN Check BOL') COLLATE DATABASE_DEFAULT
	 END AS ObjectName
FROM (
      SELECT role_principal_id
      FROM CTE_Roles
      UNION ALL
      SELECT USER_ID('public')
      UNION ALL
      SELECT USER_ID(@LoginName)) CR
  INNER JOIN sys.database_permissions DPerms ON CR.role_principal_id = DPerms.grantee_principal_id
  LEFT JOIN sys.objects SO ON DPerms.major_id = SO.OBJECT_ID
WHERE  DPerms.major_id >= 0
ORDER BY PrincipalName, ObjectType, ObjectName, Permission;
go

If @@microsoftversion/0x01000000 >= 9
Begin
	use master;
	EXEC master.sys.sp_MS_marksystemobject 'sp_ListDBPermissionsForUser'
End
go


