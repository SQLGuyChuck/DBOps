use master
go
IF (OBJECT_ID('dbo.sp_Select') IS NULL)
      EXEC('Create procedure dbo.sp_Select  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
GO

ALTER Procedure sp_Select  
 @TableName varchar(130)  
AS  
Begin  
Declare @OID int,@Name varchar(130),@SQL varchar(max)  
DECLARE @cols  varchar(max)

  Set @SQL='Select ' 
/* get the Object_id for the table */  
 Select @OID = object_id(@TableName)  
  
 If @OID is null  
 Begin  
  /* return the results in a column called SQL */  
  Select SQL='Table Not Found'  
  Return  
 End  


Select @cols=substring((
			Select ',' as "*",[Name] as "*"
			From syscolumns (nolock)
			where id=@OID
			For xml path('')
		),2,8192)

--Print @Cols
 /* Now we need to pull the extra comma off the end */  
 Select @SQL=@SQL + ' ' + @cols
 Select @SQL=@SQL + ' FROM ' + @TableName  
 Select SQL=@SQL  

/*  
 Select @SQL='Select '  
  
 DECLARE table_Cursor CURSOR Local Fast_Forward FOR Select Name from syscolumns where Id=@OID order by colid  
 OPEN table_cursor     /*open the cursor*/  
 FETCH NEXT FROM table_cursor INTO @Name /*Get the 1st row*/  
 WHILE @@fetch_status=0   /*set into loop until no more data can be found*/  
 BEGIN  
  IF not @@fetch_status = -2  
  BEGIN  
   Select @SQL=@SQL + @Name + ', '    
  END  
  FETCH NEXT FROM table_cursor INTO @Name /* get the next row*/  
 END  
 Close table_cursor  
 DEALLOCATE table_cursor  
  
 /* Now we need to pull the extra comma off the end */  
 Select @SQL=substring(@SQL,1,Datalength(@SQL) - 2)  
  
 Select @SQL=@SQL + ' FROM ' + @TableName  
  
 /* return the results */  
 */ 

End
