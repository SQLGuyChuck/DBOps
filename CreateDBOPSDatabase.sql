USE Master;
IF NOT EXISTS(select * FROM sys.databases WHERE name='DBOPS')
BEGIN
	DECLARE @DataFile varchar(200)
		, @LogFile varchar(200)
		, @DSQL varchar(2000)

	exec master.dbo.xp_instance_regread 
		 @rootkey = 'HKEY_LOCAL_MACHINE',
		 @key = 'Software\Microsoft\MSSQLServer\MSSQLServer',
		 @value_name= 'DefaultData',
		 @value = @DataFile OUTPUT

	exec master.dbo.xp_instance_regread 
		 @rootkey = 'HKEY_LOCAL_MACHINE',
		 @key = 'Software\Microsoft\MSSQLServer\MSSQLServer',
		 @value_name= 'DefaultLog',
		 @value = @LogFile OUTPUT

	--This error will return if not changed from the default c:\ location.
	--RegQueryValueEx() returned error 2, 'The system cannot find the file specified.'
	--Msg 22001, Level 1, State 1


	----Uncomment this code and run from here if path is required:
	--DECLARE @DataFile varchar(200)
	--	, @LogFile varchar(200)
	--	, @DSQL varchar(2000)
	--Select @DataFile = 'C:\SQLData'


	--Set empty logfile to be same location as populated datafile.
	IF @DataFile IS NOT NULL and @LogFile IS NULL
		SET @LogFile = @DataFile

	IF RIGHT(RTRIM(@DataFile),1) <> '\'
		SET @DataFile = @DataFile + '\'

	IF RIGHT(RTRIM(@LogFile),1) <> '\'
		SET @LogFile = @LogFile + '\'

	SET @DSQL = 'CREATE DATABASE [DBOPS] ON PRIMARY 
	( NAME = N''DBOPS'', FILENAME = N'''+@DataFile+'DBOPS.mdf'' , FILEGROWTH = 51200KB )
	 LOG ON ( NAME = N''DBOPS_log'', FILENAME = N'''+@LogFile+'DBOPS_log.ldf'' , FILEGROWTH = 51200KB);
	ALTER DATABASE [DBOPS] SET ANSI_NULL_DEFAULT OFF ;
	ALTER DATABASE [DBOPS] SET ANSI_NULLS OFF ;
	ALTER DATABASE [DBOPS] SET ANSI_PADDING OFF;
	ALTER DATABASE [DBOPS] SET ANSI_WARNINGS OFF ;
	ALTER DATABASE [DBOPS] SET ARITHABORT OFF ;
	ALTER DATABASE [DBOPS] SET AUTO_CLOSE OFF ;
	ALTER DATABASE [DBOPS] SET AUTO_CREATE_STATISTICS ON ;
	ALTER DATABASE [DBOPS] SET AUTO_SHRINK OFF ;
	ALTER DATABASE [DBOPS] SET AUTO_UPDATE_STATISTICS ON ;
	ALTER DATABASE [DBOPS] SET RECOVERY SIMPLE ;
	ALTER DATABASE [DBOPS] SET PAGE_VERIFY CHECKSUM ;
	alter database DBOPS set trustworthy on;

	IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N''PRIMARY'') ALTER DATABASE [DBOPS] MODIFY FILEGROUP [PRIMARY] DEFAULT'

	IF @DSQL IS NOT NULL
	BEGIN
		EXEC (@DSQL)
		PRINT 'Database DBOPS CREATED'
	END
	ELSE 
	BEGIN
		SELECT 'Please provide a path for data and log file.'
		RAISERROR('Default database file paths aren''t provided. Please alter "Software\Microsoft\MSSQLServer\MSSQLServer"::DefaultData and ::DefaultLog.', 18, 18)
	END

	EXEC DBOPS..sp_changeDBOwner 'sa'
END
ELSE
	PRINT 'Database DBOPS already exists on server: ' + @@servername

-- NOW SIZE
IF EXISTS(select * FROM sys.databases WHERE name='DBOPS')
BEGIN
	IF EXISTS( select * FROM DBOPS.sys.database_files WHERE  NAME = N'DBOPS' AND (size*8) <512000 )
	BEGIN
		PRINT 'Altering DATA file to 500MB'
		ALTER DATABASE [DBOPS] MODIFY FILE ( NAME = N'DBOPS', SIZE = 512000KB )
	END

	IF EXISTS( select * FROM DBOPS.sys.database_files WHERE NAME = N'DBOPS_log' AND (size*8) <51200 )
	BEGIN
		PRINT 'Altering LOG file to 50MB'
		ALTER DATABASE [DBOPS] MODIFY FILE ( NAME = N'DBOPS_log', SIZE = 51200KB )
	END
END

