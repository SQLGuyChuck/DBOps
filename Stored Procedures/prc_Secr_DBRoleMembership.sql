SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Secr_DBRoleMembership
as
BEGIN
/*******************************************************************
**  Purpose: Create matrix of server permissions per db and server role.
**	Modified:
**	11/29/2010	Chuck Lathrope	Got it to work and renamed.
******************************************************************/
SET NOCOUNT ON

DECLARE @dbname varchar(200)
DECLARE @mSql1  varchar(8000)

DECLARE @DBROLES table( DBName sysname, UserName varchar(100), db_owner varchar(3), db_accessadmin varchar(3), 
					 db_securityadmin varchar(3), db_ddladmin varchar(3), db_datareader varchar(3), db_datawriter varchar(3),
                     db_denydatareader varchar(3), db_denydatawriter varchar(3))
                     
DECLARE DBName_Cursor CURSOR FORWARD_ONLY FOR
	select name
	from  master.dbo.sysdatabases with (NOLOCK)
	where name not in ('dbops','model')
	Order by name
 
OPEN DBName_Cursor
 
FETCH NEXT FROM DBName_Cursor INTO @dbname
 
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @mSQL1 = '  
	SELECT '+''''+@dbName +''''+ ' as DBName ,UserName, '+char(13)+   '    
	Max(CASE RoleName WHEN ''db_owner''          THEN ''Yes'' ELSE '''' END) AS db_owner,
	Max(CASE RoleName WHEN ''db_accessadmin ''   THEN ''Yes'' ELSE '''' END) AS db_accessadmin ,
	Max(CASE RoleName WHEN ''db_securityadmin''  THEN ''Yes'' ELSE '''' END) AS db_securityadmin,
	Max(CASE RoleName WHEN ''db_ddladmin''       THEN ''Yes'' ELSE '''' END) AS db_ddladmin,
	Max(CASE RoleName WHEN ''db_datareader''     THEN ''Yes'' ELSE '''' END) AS db_datareader,
	Max(CASE RoleName WHEN ''db_datawriter''     THEN ''Yes'' ELSE '''' END) AS db_datawriter,
	Max(CASE RoleName WHEN ''db_denydatareader'' THEN ''Yes'' ELSE '''' END) AS db_denydatareader,
	Max(CASE RoleName WHEN ''db_denydatawriter'' THEN ''Yes'' ELSE '''' END) AS db_denydatawriter
	from (
	select b.name as USERName, c.name as RoleName
		from ' + @dbName+'.dbo.sysmembers a '+char(13)+
			  '     join '+ @dbName+'.dbo.sysusers  b '+char(13)+
		'     on a.memberuid = b.uid join '+@dbName +'.dbo.sysusers c
		   on a.groupuid = c.uid 
		   where b.name <> ''dbo''
		   and b.name not like ''##%'')s  
		   Group by USERName
	 order by UserName'

	Insert into @DBROLES ( DBName, UserName, db_owner, db_accessadmin, db_securityadmin, db_ddladmin, db_datareader, db_datawriter,
					 db_denydatareader, db_denydatawriter )
	Execute (@mSql1)

  FETCH NEXT FROM DBName_Cursor INTO @dbname
 END
 
CLOSE DBName_Cursor
DEALLOCATE DBName_Cursor

Select * from @DBROLES
END;
GO
