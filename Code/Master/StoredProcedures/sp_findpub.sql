USE master
GO
IF (OBJECT_ID('dbo.sp_findPub') IS NULL)
BEGIN
      EXEC('Create procedure dbo.sp_findPub  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
      IF (@@error = 0)
            PRINT 'Successfully created empty stored procedure dbo.sp_findPub.'
      ELSE
      BEGIN
            PRINT 'FAILED to create stored procedure dbo.sp_findPub.'
      END
END
GO

Alter Procedure dbo.sp_findPub @TableName varchar(130)
As
Begin
	Declare @SQL varchar(4000),@DbName varchar(100)
	Set @DbName=db_Name(Db_id())
	Set @SQL='Select Name from ' +@dbname +'.dbo.syspublications where PubId in (
		Select PubID from ' +@dbname +'.dbo.sysarticles where Name=' + char(39) + @TableName + char(39) + ')'
	Print @SQL
	exec (@SQL)
End
If @@microsoftversion/0x01000000 >= 9
Begin
	EXEC master.sys.sp_MS_marksystemobject 'sp_findPub'
End
go