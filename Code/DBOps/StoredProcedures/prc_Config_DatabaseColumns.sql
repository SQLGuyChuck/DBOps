SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Config_DatabaseColumns
	@Filter varchar(1000) = NULL
AS
BEGIN
/*
**	12/27/2012	Matias Sincovich	distribution and ReportServer database Filter added to correct issues. Corrected DataTypes and DatabaseName use.
**	02/01/2013	Matias Sincovich	Corrected join between sys.columns and sys.types
**	03/21/2013	Matias Sincovich	Deleted #TempTable
*/

	DECLARE @SQLString NVARCHAR(MAX) 
		, @Name NVARCHAR(512)

	IF @Filter IS NOT NULL
		SET @Filter = '%' + @Filter + '%'
	 
	DECLARE db_cursor_columns CURSOR FAST_FORWARD FOR 
		SELECT s.name
		FROM master..sysdatabases s
		WHERE name NOT IN ('master','model','msdb','tempdb','distribution')
			AND name not like 'ReportServer%'
		ORDER BY name

	SET @SQLString = ''

	OPEN db_cursor_columns 
	FETCH NEXT FROM db_cursor_columns INTO @name 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		--select @name 
		IF DATABASEPROPERTYEX(@name, 'Status') ='ONLINE' 
		BEGIN
			IF @SQLString <> ''
				SET @SQLString = @SQLString + CHAR(13) + 'UNION ALL ' + CHAR(13)

			SELECT @SQLString = @SQLString + 'SELECT  sc.object_id, sc.name as Column_Name
									, st.name as Column_type
									, sc.max_length, sc.precision
									, NULLIF(sc.scale, 0 ) as scale
									, NULLIF(sc.column_id, 0 ) as column_id
									, is_identity
									, sc.is_nullable
									, sd.definition as Default_value
									, ''' + @name + ''' as DatabaseName
							FROM ['+ @name + '].sys.columns sc
								LEFT JOIN ['+ @name + '].sys.default_constraints sd ON sc.object_id = sd.[parent_object_id] 
																		AND sc.column_id = sd.parent_column_id 
								INNER JOIN ['+ @name + '].sys.types st on st.system_type_id = sc.system_type_id  and sc.user_type_id = st.user_type_id
							WHERE @FilterParam is NULL or
									sc.name like @FilterParam ' + CHAR (13)
							
		END -- IF DATABASEPROPERTYEX(@name, 'Status') ='ONLINE'
		
		FETCH NEXT FROM db_cursor_columns INTO @name	END -- WHILE @@FETCH_STATUS = 0
	 
	CLOSE db_cursor_columns
	DEALLOCATE db_cursor_columns
	SET @SQLString = @SQLString + 'ORDER BY 9 ,1 ,2'
	BEGIN TRY 
		--PRINT @SQLString

		EXEC sp_executesql @SQLString, N'@FilterParam varchar(2000)', @FilterParam = @Filter
	END TRY 
	BEGIN CATCH 
		PRINT ERROR_MESSAGE()
		SELECT 0 , CONVERT(VARCHAR(256),ERROR_MESSAGE()), 'Error', 0 , NULL, NULL, 0, NULL, NULL, NULL, NULL

	END CATCH
	 
END;
;
GO
