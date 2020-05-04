SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Config_DatabaseObjects
AS
BEGIN
/*
**	31/18/2013	Matias Sincovich	Deleted temp table
**	07/01/2013	Matias Sincovich	Use sys.objects instead of sys.Objects for Case sensitive databases 
*/
	set nocount on
	declare @SQLString varchar(max)
	declare @Name varchar(256) 

	DECLARE db_cursor CURSOR FOR  
		SELECT name 
		--	select *
		FROM master..sysdatabases 
		WHERE name NOT IN ('master','model','msdb','tempdb')
			AND DATABASEPROPERTYEX(name, 'Status') ='ONLINE'
		ORDER BY name

	SET @SQLString = ''

	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @name   
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		--select @name
		
			IF @SQLString <> ''
				SET @SQLString = @SQLString + CHAR(13) + 'UNION' + CHAR(13)

			select @SQLString = @SQLString +' SELECT
									 name COLLATE SQL_Latin1_General_CP1_CI_AS as name
									,Object_ID as ObjectId
									,type COLLATE SQL_Latin1_General_CP1_CI_AS as type
									,type_desc COLLATE SQL_Latin1_General_CP1_CI_AS as type_desc
									,create_date
									,modify_date
									,is_ms_shipped
									,'''+@name +''' COLLATE SQL_Latin1_General_CP1_CI_AS as DatabaseName
								FROM ['+ @name + '].sys.objects WHERE is_ms_shipped <>1 and type <> ''S'''

		FETCH NEXT FROM db_cursor INTO @name   
	END   

	CLOSE db_cursor   
	DEALLOCATE db_cursor 
	--PRINT @SQLString
	begin try
		EXEC (@SQLString)
	end try
	begin catch
		PRINT @SQLString
		select 'Error encountered while retreiving data(LINE: ' + CONVERT(VARCHAR(10),ERROR_LINE())+ ' )' as name
		, 0 as ObjectID
		,'E' as type
		, 'Error' as type_Desc
		, getdate() as create_date
		, getdate() as modify_date
		, 0 as is_ms_shipped
		, NULL as DatabaseName

	end catch
END;
;
GO
