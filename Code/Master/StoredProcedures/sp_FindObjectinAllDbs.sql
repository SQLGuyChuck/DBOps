
USE master
GO
IF (OBJECT_ID('dbo.sp_FindObjectinAllDbs') IS NULL)
BEGIN
      EXEC('Create procedure dbo.sp_FindObjectinAllDbs  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
      IF (@@error = 0)
            PRINT 'Successfully created empty stored procedure dbo.sp_FindObjectinAllDbs.'
      ELSE
      BEGIN
            PRINT 'FAILED to create stored procedure dbo.sp_FindObjectinAllDbs.'
      END
END
GO

/******************************************************************************  
**  Name: sp_FindObjectinAllDbs  
**  Desc: This will find objects in all dbs with passed in search term. 
**    
**                
**  Return values: Rowset with Servername, DBName, SearchString, ObjectName
**   
**  Called by:     
**                
**  Parameters:  
**  Input           
**  @TableName    
**  
**	E.g. exec sp_FindObjectinAllDbs 'loginid'
**
**  Auth: Chuck Lathrope  
**  Date: 12/16/2008  
*******************************************************************************  
**  Change History  
*******************************************************************************  
**  Date:       Author:             Description: 
**  12/30/2008	Chuck Lathrope		Added like capability and new column to output.
**  2/18/2009	Chuck Lathrope		Add @IncludeMSShippedObjects parameter and default
**									to not include MS Shipped Objects.
**	3/18/2009	Chuck Lathrope		Add addition of finding columns with name search.
**  6/7/2011	Guru				Add brackets around DB name.
*******************************************************************************/

Alter Proc dbo.sp_FindObjectinAllDbs
	@Objectname varchar(150),
	@IncludeMSShippedObjects bit = 0
as  
Begin

Create table #storeresults (Servername varchar(70), DBName varchar(150), SearchString varchar(150), ObjectName varchar(150), ObjectType sysname, is_ms_shipped bit)
Declare @cmd varchar(1000)

Select @cmd = 'SELECT @@servername as servername, ''?'' as dbname,''' 
	+ @Objectname + ''' as SearchString, Name as ObjectName, type_desc as ObjectType ' +
	CASE When @IncludeMSShippedObjects = 1 THEN ',is_ms_shipped' ELSE '' END
	+ ' FROM [?].sys.objects WHERE Name like ''' + @Objectname + '''' +
	CASE When @IncludeMSShippedObjects = 0 THEN ' and is_ms_shipped = 0' ELSE '' END

--Add column information found
Select @cmd = @cmd + ' UNION ALL 
SELECT @@servername as servername, ''?'' as dbname,''' + @Objectname + ''' as SearchString, 
	Case When C.Name IS NULL Then o.Name Else o.Name + ''.'' + C.name END as ObjectName, 
	Case When C.Name IS NULL Then type_desc Else ''Column'' END as ObjectType ' +
	CASE When @IncludeMSShippedObjects = 1 THEN ',is_ms_shipped' ELSE '' END
	+ 'FROM [?].sys.objects o Left Join [?].sys.columns c on c.object_id = o.object_id
	WHERE (o.name like ''' + @Objectname + ''' or c.name like ''' + @Objectname + ''')' +
	CASE When @IncludeMSShippedObjects = 0 THEN ' and is_ms_shipped = 0' ELSE '' END

--Debug:
Print @cmd

If @IncludeMSShippedObjects = 1
Begin
	Insert into #storeresults (Servername, DBName, SearchString, ObjectName, ObjectType, is_ms_shipped)  
	exec sp_MSforeachdb @cmd  

	Select * from #storeresults  
End
Else
Begin
	Insert into #storeresults (Servername, DBName, SearchString, ObjectName, ObjectType)
	exec sp_MSforeachdb @cmd  
	
	Select Servername, DBName, SearchString, ObjectName, ObjectType from #storeresults  

End

End --Proc  

go

