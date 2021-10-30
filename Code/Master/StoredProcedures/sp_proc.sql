USE master
GO
IF (OBJECT_ID('dbo.sp_Proc') IS NULL)
BEGIN
	EXEC('create procedure dbo.sp_Proc  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.sp_Proc.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.sp_Proc.'
	END
END
GO

ALTER PROCEDURE dbo.sp_Proc @ProcName VARCHAR(250)
AS
	BEGIN
		SET NOCOUNT ON 
		CREATE TABLE #list (
			 ID INT IDENTITY(1, 1),
			 Name VARCHAR(255),
			 DataType VARCHAR(255),
			 LengthVal VARCHAR(255),
			 isOutput BIT DEFAULT (0),
			 HasDefault BIT DEFAULT (0),
			 DefaultValue VARCHAR(MAX)
			)
		DECLARE	@Out VARCHAR(MAX),
			@CRLF VARCHAR(4),
			@SQL NVARCHAR(MAX)
		SET @CRLF = CHAR(13) + CHAR(10)

		DECLARE	@Results TABLE (Results VARCHAR(MAX))
		INSERT	INTO @Results
				(Results)
		VALUES	('')


		SET @SQL = 'Insert into #list  (Name,DataType,LengthVal,isOutput,HasDefault,DefaultValue)
select	 name,type_name(user_type_id),case when type_name(user_type_id) NOT in (''varchar'',''char'',''nvarchar'',''nchar'',''varbinary'',''binary'') then null
								when max_length =-1 and type_name(user_type_id) in (''varchar'',''char'',''nvarchar'',''nchar'',''varbinary'',''binary'') then ''(max)''
								else ''('' + cast(max_length as varchar) + '')'' end,
	is_output,
	has_default_value,
	cast(default_value as varchar(max))
	from ' + DB_NAME() + '.sys.all_parameters (nolock)
	where object_id = object_id(' + CHAR(39) + @ProcName + CHAR(39) + ')
	order by parameter_id'

		EXEC (@SQL)

		--build the declare:
		SET @Out = '--- variable declares --------------------------------------------------------'
			+ @CRLF
		SELECT	@Out = @Out + 'DECLARE '
				+ REPLACE(STUFF((SELECT	',' AS "*",
										[Name] + ' ' + ISNULL(DataType, '')
										+ ISNULL([LengthVal], '') AS "*"
								 FROM	#list (NOLOCK)
								 ORDER BY ID ASC
								FOR
								 XML PATH('')
								), 1, 1, ''), ',', ',' + @CRLF) + @CRLF + @CRLF
		IF @Out IS NOT NULL
			UPDATE	@Results
			SET		Results = Results + @Out 

		--build any defaults
		SET @Out = '--- set input values --------------------------------------------------------'
			+ @CRLF
		SELECT	@Out = @Out + 'Select '
				+ REPLACE(STUFF((SELECT	',' AS "*",
										[Name] + '='
										+ CASE WHEN DataType IN ('varchar',
															  'char',
															  'nvarchar',
															  'nchar',
															  'varbinary',
															  'binary',
															  'datetime',
															  'uniqueidentifier',
															  'xml')
											   THEN CHAR(39) + SPACE(1)
													+ CHAR(39)
											   ELSE 'null'
										  END AS "*"
								 FROM	#list (NOLOCK)
								 WHERE	isOutput = 0
								 ORDER BY ID ASC
								FOR
								 XML PATH('')
								), 1, 1, ''), ',', ',' + @CRLF) + @CRLF + @CRLF

		IF @Out IS NOT NULL
			UPDATE	@Results
			SET		Results = Results + @Out 


		--build execution script
		SET @Out = '--- execution --------------------------------------------------------'
			+ @CRLF
		SELECT	@Out = @Out + 'exec ' + @ProcName + ' '
				+ REPLACE(STUFF((SELECT	',' AS "*",
										[Name] + '=' + [Name]
										+ CASE WHEN isOutput = 1
											   THEN ' OUTPUT'
											   ELSE ''
										  END AS "*"
								 FROM	#list (NOLOCK)
								 ORDER BY ID ASC
								FOR
								 XML PATH('')
								), 1, 1, ''), ',', ',' + @CRLF) + @CRLF
				+ @CRLF

		IF @Out IS NOT NULL
			UPDATE	@Results
			SET		Results = Results + @Out 

		--build select for outputs
		SET @Out = '--- returned values --------------------------------------------------------'
			+ @CRLF
		SELECT	@Out = @Out + 'Select '
				+ REPLACE(STUFF((SELECT	',' AS "*",
										REPLACE([Name], '@', '') + '='
										+ [Name] AS "*"
								 FROM	#list (NOLOCK)
								 WHERE	isOutput = 1
								 ORDER BY ID ASC
								FOR
								 XML PATH('')
								), 1, 1, ''), ',', ',' + @CRLF) + @CRLF
				+ @CRLF
		IF @Out IS NOT NULL
			UPDATE	@Results
			SET		Results = Results + @Out 

		SELECT	Results
		FROM	@Results
	END

 