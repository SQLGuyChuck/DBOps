USE master
GO
IF (OBJECT_ID('dbo.sp_findcolumn') IS NULL)
BEGIN
      EXEC('Create procedure dbo.sp_findcolumn  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
      IF (@@error = 0)
            PRINT 'Successfully created empty stored procedure dbo.sp_findcolumn.'
      ELSE
      BEGIN
            PRINT 'FAILED to create stored procedure dbo.sp_findcolumn.'
      END
END
GO

/******************************************************************************  
**  Name: sp_findcolumn  
**  Desc: This will get list of tables having the input parameter as column.  
**    
**                
**  Return values: rows  
**   
**  Called by:     
**                
**  Parameters:  
**  Input       
**  @ColumnName
**  @ObjectType    
**  
**  Auth: Ganesh  
**  Date: 07/24/2008  
*******************************************************************************  
**  Change History  
*******************************************************************************  
**  Date:		Author:    Description:  
**      
*******************************************************************************/
ALTER PROCEDURE dbo.sp_findcolumn
						@ColumnName varchar(255),
						@ObjectType varchar(50) = NULL -- e.g. int, bigint, uniqueidentifier
AS
BEGIN

DECLARE @SQL varchar(1500),
		@OType      int

select @oType = xtype from systypes where name = @ObjectType


if @oType is not null
SELECT @SQL = ' SELECT object_name(object_id) as ObjectName, name ' + 
			  '	FROM sys.columns WHERE name LIKE ''' + @ColumnName + '''' +
			  ' AND object_name(object_id) NOT LIKE ''syncobj%''' + 
              ' AND system_type_id = isnull(' + CONVERT(varchar(5),@OType) + ', system_type_id)' + 
              ' ORDER BY object_name(object_id), name'
else
SELECT @SQL = ' SELECT object_name(object_id) as ObjectName, name ' + 
			  '	FROM sys.columns WHERE name LIKE ''' + @ColumnName + '''' +
			  ' AND object_name(object_id) NOT LIKE ''syncobj%''' + 
              ' ORDER BY object_name(object_id), name'

--PRINT (@SQL)
EXEC (@SQL)

END
