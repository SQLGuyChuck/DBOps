use master
go
IF (OBJECT_ID('dbo.sp_insert') IS NULL)
      EXEC('Create procedure dbo.sp_insert  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
GO

/******************************************************************************  
**  Name: sp_insert  
**  Desc: Generate the insert statement for the given table 
**                
**  Return values: rows  
**   
**  exec sp_insert 'domainname',1
**                
**  Parameters:  
**  Input       
**  @TableName			  varchar(150)
**  @RemoveIdentityColumn  bit     
**  
*******************************************************************************  
**  Change History  
*******************************************************************************  
**  Date:		Author:			Description:  
**  10/15/2010	Chuck Lathrope	Created  
**  
*******************************************************************************/
Alter PROCEDURE dbo.sp_insert
		@TableName  varchar(150),
		@RemoveIdentityColumn  bit = 1
AS
BEGIN

DECLARE @dbname varchar(100),
        @CRLF char(2), @OID int, @Name varchar(130), @cols  varchar(max)

SELECT @dbname = db_name()
SELECT @CRLF = CHAR(13) + CHAR(10)

/* get the Object_id for the table */  
Select @OID = object_id(@TableName)  

If @OID is null  
Begin  
	Select SQL='Table Not Found'  
	Return  
End

IF @RemoveIdentityColumn = 0
	BEGIN
		Select @cols=substring((
				Select ',' as "*",[Name] as "*"
				From sys.columns (nolock) 
				where object_id=@OID
				For xml path('')
			),2,8192)

		SELECT 'INSERT INTO ' + @dbname + '.dbo.' + @TableName + ' (' +@cols + ')'  + @CRLF +
		'Select * from sometable'
	END
ELSE
	BEGIN
		Select @cols=substring((
			Select ',' as "*",[Column_Name] as "*"
			FROM INFORMATION_SCHEMA.COLUMNS AS isc
			WHERE isc.TABLE_NAME = @TableName
			AND COLUMNPROPERTY( OBJECT_ID(isc.TABLE_NAME),isc.COLUMN_NAME,'IsIdentity') = 0
			ORDER BY isc.TABLE_NAME, isc.ORDINAL_POSITION
			For xml path('')
		),2,8192)

		SELECT 'INSERT INTO ' + @dbname + '.dbo.' + @TableName + ' (' +@cols + ')'  + @CRLF +
		'Select * from sometable'

	END
END
go
EXEC sys.sp_MS_marksystemobject sp_insert
GO

