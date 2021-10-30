USE master
GO
IF (OBJECT_ID('dbo.sp_findtable') IS NULL)
BEGIN
      EXEC('Create procedure dbo.sp_findtable  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
      IF (@@error = 0)
            PRINT 'Successfully created empty stored procedure dbo.sp_findtable.'
      ELSE
      BEGIN
            PRINT 'FAILED to create stored procedure dbo.sp_findtable.'
      END
END
GO

/******************************************************************************  
**  File: $/Enom/SQL/DBA/StoredProcedures/sp_findtable.sql  
**  Name: sp_findtable  
**  Desc: This will get the list of tables with certain text in its name.  
**    
**                
**  Return values: rows with table name and isreplicated bit. 
**   
**  Called by:     
**                
**  Parameters:  
**  Input           
**  @TableName    
**  
**	E.g. exec sp_findtable '%customer%'
**
**  Auth: Ganesh Kaliaperumal  
**  Date: 07/22/2008  
*******************************************************************************  
**  Change History  
*******************************************************************************  
**  Date:       Author:               Description:  
**  07/25/2008  Ganesh Kaliaperumal   Creation  
**      
*******************************************************************************/
ALTER PROCEDURE dbo.sp_findtable
                 @TableName varchar(150)
		,@ReplicationInfo bit = 0
AS
BEGIN
DECLARE @dbname varchar(100),
        @sql    varchar(1000),
		@IsReplicated tinyint

Select @dbname = db_name()

Select @IsReplicated = Cast(DATABASEPROPERTYEX(@dbname, 'IsPublished') as tinyint)

If @IsReplicated = 0 or @ReplicationInfo = 0
Begin
	Select @sql  = 'SELECT distinct so.name FROM '+ @dbname + '.sys.sysobjects so(nolock) '+ 
				   'where so.type = ''u'' and so.[name] like ''' + @TableName  + ''''
	EXEC (@sql)
End
Else
Begin
	Select @sql  = 'SELECT distinct so.name,case when sa.dest_table is null then 0 else 1 end as IsReplicated FROM '+ @dbname + '.sys.sysobjects so (nolock) '+ 
				   '  left join '+ @dbname + '.dbo.sysarticles sa (nolock)  on sa.dest_table = so.[name] ' +
				   '  left join '+ @dbname + '.dbo.syspublications sp (nolock) on sa.pubid = sp.pubid ' +
				   'where so.type = ''u'' and so.[name] like ''' + @TableName  + ''''
	EXEC (@sql)
End

End
