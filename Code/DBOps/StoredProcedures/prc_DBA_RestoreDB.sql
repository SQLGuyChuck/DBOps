
USE DBOPS
go

IF (OBJECT_ID('dbo.prc_DBA_RestoreDB') IS NULL)
BEGIN
	EXEC('create procedure dbo.prc_DBA_RestoreDB  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.prc_DBA_RestoreDB.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.prc_DBA_RestoreDB.'
	END
END
GO

PRINT 'Altering Procedure: dbo.prc_DBA_RestoreDB'
GO

--http://www.mssqltips.com/sqlservertip/2287/automate-a-database-restore/
--3/11/2013		Chuck Lathrope - Litespeed 6.52 compatibility and bug fixes.
--3/20/2012		Chuck Lathrope - Add more print statements and header read failure error handling
Alter procedure dbo.prc_DBA_RestoreDB
	@dbname			varchar(150) = NULL,	-- DB to be backed up
	@SourceServer	varchar(100) = NULL,	-- DB that we get msdb backup info from. Only needed if restorepaths is blank.
	@restorepaths	varchar(max) = '',		-- Path(s) to the files containing backups to be restored from, semi-colon delimited, if any...if not
											-- passed, we try to grab information from MSDB instead
	@moveLogsTo		varchar(max) = '',		-- Path to location that log files for the database being restored should be moved to...
	@moveDataTo		varchar(max) = '',		-- Path(s) to location(s) that data files for the database being restored should be moved to...semi-colon delimited list...
											-- if more data files exist than paths are passed, data files are simply restored in a round-robin fashion to the locations
											-- specified...if more paths are specified here than there are data files, the first paths listed are used up to the # of data
											-- files, then the other paths are simply ignored...
	@fileFilGroupPageString varchar(max) = '', -- Is a string of either a file, filegroup, or page string that will be used (if passed) as the <file_or_filegroup_or_pages>
											-- portion of the restore string - should match the proper format as outlined in BOL for this section exactly, since we basically just
											-- append here. The format as of me writing this is as follows:
											/*
												<file_or_filegroup_or_pages> ::=
												{ 
												   FILE = { logical_file_name_in_backup }
												   | FILEGROUP = { logical_filegroup_name } }
													  | PAGE = 'fileNumber:page [ ,...n ]'  
												}
											*/
	@newDbName		varchar(150) = NULL,	-- Name of the restored database - if left default/null, the @dbname is used...
	@filePattern	varchar(150) = '*',		-- Pattern of files to match for within the @restorepaths - by default, is everything (i.e. *) -
											-- only valid if a value is specified for @restorepaths
	@stopAt			datetime = NULL,			-- Date/time to stop at within the restore, if specified...
	@opts			int = 0					-- Options that drive execution for the proc
											-- 1 bit -		If set, execution is suppressed and the strings are simply output...
											-- 2 bit -		If set, recovery is performed at the end of all restores...by default, db is left in norecovery state...
											-- 4 bit -		If set, LiteSpeed is used for recovery statements...
											-- 8 bit -		If set, we'll forcefully drop existing connections to the db in order to allow restore prior to restoring...
											-- 16 bit -		If set, we will NOT use diff backups in the restore, only full and tlog backups...
											-- 32 bit -		If set, CHECKSUM is used for the restore - this is only valid if a native restore is used...
											-- 64 bit -		If set, PAGE level restore is used, and the pages to be restored are built from the data in the suspect_pages table
											-- 128 bit -	If set, and a value is set in @restorepath, we will try to find a time/date stamp within
											--				the name of each file found in the @restorepath matching @filePattern - we will simply
											--				try to find 14 concurrent numbers within the name to signify as such...
											-- 256 bit -	If set and the 1 bit is not set (i.e. we are executing), errors raised during the execution
											--				of the restore statements will be silently captured and reported without re-raising back to
											--				the calling code. Error number and message will be output as a print statement, but no error
											--				will be raised...
/*
-- Restore the testDb database, suppressing actual execution, using data from msdb, not performing
-- recovery, native restore, and the most efficient path
exec dbo.prc_DBA_RestoreDBB @dbname = 'testDb', @opts = 1;

-- Same thing, only instead of using data in MSDB, use the 2 specified locations for any .bak file
-- starting with 'testDb'
exec dbo.prc_DBA_RestoreDBB @dbname = 'testDb', @restorepaths = 'c:\temp;\\backupServerB\backupShare\testDb;', 
			@filePattern = 'testDb*.bak', @opts = 1;

-- Same thing, only use LiteSpeed syntax...
exec dbo.prc_DBA_RestoreDBB @dbname = 'testDb', @restorepaths = 'c:\temp;\\backupServerB\backupShare\testDb;', @opts = 5;

-- How about changing the name on restore?
exec dbo.prc_DBA_RestoreDBB @dbname = 'testDb', @newDbName = 'testDb_newName', 
			@restorepaths = 'c:\temp;\\backupServerB\backupShare\testDb;', 
			@opts = 5;

-- What about moving the log/data files around? Here we will place data files for the database in the
-- 4 specified locations (semi-colon delimited) - if there are less than 4 data files, they will simply
-- be placed in the locations in the order specified up to the number of data files there are (so, if
-- there were 2 data files, 1 would go to M:\SqlData and 1 to N:\SqlData). If there are more than 4
-- data files, they will continue to round-robin among the specified locations in order specified
-- until there are no more files (so, with 7 data files, you'd end up with 2 in M,N,O and 1 in P)
exec dbo.prc_DBA_RestoreDBB @dbname = 'testDb', @newDbName = 'testDb_newName', 
			@restorepaths = 'c:\temp;\\backupServerB\backupShare\testDb;', 
			@moveLogsTo = 'l:\SqlLogs\',
			@moveDataTo = 'm:\SqlData\;n:\SqlData\;o:\SqlData\;p:\SqlData',
			@opts = 5;

-- Want to stop at a particular point?
exec dbo.prc_DBA_RestoreDBB @dbname = 'testDb', @newDbName = 'testDb_newName', 
			@restorepaths = 'c:\temp;\\backupServerB\backupShare\testDb;', 
			@moveLogsTo = 'l:\SqlLogs\',
			@moveDataTo = 'm:\SqlData\;n:\SqlData\;o:\SqlData\;p:\SqlData',
			@stopAt = '2008-07-29 15:52:20.310',
			@opts = 5;

-- Same thing, only ignore the use of an DIFFERENTIAL backups
exec dbo.prc_DBA_RestoreDBB @dbname = 'testDb', @newDbName = 'testDb_newName', 
			@restorepaths = 'c:\temp;\\backupServerB\backupShare\testDb;', 
			@moveLogsTo = 'l:\SqlLogs\',
			@moveDataTo = 'm:\SqlData\;n:\SqlData\;o:\SqlData\;p:\SqlData',
			@stopAt = '2008-07-29 15:52:20.310',
			@opts = 21;

-- Perform recovery at the end of the restore process...
exec dbo.prc_DBA_RestoreDBB @dbname = 'testDb', @newDbName = 'testDb_newName', 
			@restorepaths = 'c:\temp;\\backupServerB\backupShare\testDb;', 
			@moveLogsTo = 'l:\SqlLogs\',
			@moveDataTo = 'm:\SqlData\;n:\SqlData\;o:\SqlData\;p:\SqlData',
			@stopAt = '2008-07-29 15:52:20.310',
			@opts = 23;

-- Force existing users out of the new database prior to restoring...
exec dbo.prc_DBA_RestoreDBB @dbname = 'testDb', @newDbName = 'testDb_newName', 
			@restorepaths = 'c:\temp;\\backupServerB\backupShare\testDb;', 
			@moveLogsTo = 'l:\SqlLogs\',
			@moveDataTo = 'm:\SqlData\;n:\SqlData\;o:\SqlData\;p:\SqlData',
			@stopAt = '2008-07-29 15:52:20.310',
			@opts = 31;

-- Perform a PAGE level restore, getting the pages to be restored from the msdb
-- suspectpages database table...
exec dbo.prc_DBA_RestoreDBB @dbname = 'testDb', @opts = 65;

*/
as
set nocount on;
set transaction isolation level read uncommitted;

if len(isnull(@dbname,'')) = 0 begin
	print 'Please supply a db name in @DBName parameter.';
	RETURN 1;
end

-- Cleanup as necessary...
if object_id('tempdb..#dbrestore') > 0--select * from tempdb..#dbrestore
	drop table #dbrestore;
if object_id('tempdb..#files') > 0--select * from tempdb..#files
	drop table #files;


----Testing:
----go
--Declare
--	@dbname			varchar(150) ,	-- DB to be backed up
--	@SourceServer	varchar(100) , 
--	@restorepaths	varchar(max) = '',		-- Path(s) to the files containing backups to be restored from, semi-colon delimited, if any...if not
--											-- passed, we try to grab information from MSDB instead
--	@moveLogsTo		varchar(max) = '',		-- Path to location that log files for the database being restored should be moved to...
--	@moveDataTo		varchar(max) = '',		-- Path(s) to location(s) that data files for the database being restored should be moved to...semi-colon delimited list...
--											-- if more data files exist than paths are passed, data files are simply restored in a round-robin fashion to the locations
--											-- specified...if more paths are specified here than there are data files, the first paths listed are used up to the # of data
--											-- files, then the other paths are simply ignored...
--	@fileFilGroupPageString varchar(max) = '', -- Is a string of either a file, filegroup, or page string that will be used (if passed) as the <file_or_filegroup_or_pages>
--											-- portion of the restore string - should match the proper format as outlined in BOL for this section exactly, since we basically just
--											-- append here. The format as of me writing this is as follows:
--											/*
--												<file_or_filegroup_or_pages> ::=
--												{ 
--												   FILE = { logical_file_name_in_backup }
--												   | FILEGROUP = { logical_filegroup_name } }
--													  | PAGE = 'fileNumber:page [ ,...n ]'  
--												}
--											*/
--	@newDbName		varchar(150) = null,	-- Name of the restored database - if left default/null, the @dbname is used...
--	@filePattern	varchar(150) = '*',		-- Pattern of files to match for within the @restorepaths - by default, is everything (i.e. *) -
--											-- only valid if a value is specified for @restorepaths
--	@stopAt			datetime = null,			-- Date/time to stop at within the restore, if specified...
--	@opts			int = 0	

--Select @dbname ='testdb', @SourceServer='demand_studios_titles', @restorepaths='\\sjl01na01-1b.prod.dm.local\studios_db_backups\VSTUDIODB\demand_studios_titles',@filepattern='VSTUDIODB.demand_studios_titles.Full.20130320-07.47.SLS',
--	@moveDataTo = 'I:\SQLData', @moveLogsTo ='K:\SQLLog', @opts=31

-- Table that creates the sql data for the actual restore operation
create table #dbrestore (id int, textdata varchar(max));
-- List of all the files that are potentially included in the restore
create table #files	(pkid int identity(1,1), pathAndFileName varchar(max), filname varchar(max), backupEndDate datetime, 
					fileNumber int, sortval varchar(150), groupval varchar(150), backupType smallint);

-- Index...
create unique clustered index ixc__#files__pkid__dbRestoreProc on #files (pkid);
create nonclustered index ixc__#files__sortVal_backupType__dbRestoreProc on #files (sortval,backupType);
create nonclustered index ixc__#files__groupval__dbRestoreProc on #files (groupval);

-- List of files captured from a 'restore filelistonly' operation
declare @filelist table (LogicalName nvarchar(128), PhysicalName nvarchar(260), Type char(1), FileGroupName nvarchar(128), 
				Size numeric(20,0), MaxSize numeric(20,0), FileId bigint, CreateLSN numeric(25,0), DropLSN numeric(25,0), UniqueId uniqueidentifier,
				ReadOnlyLSN numeric(25,0), ReadWriteLSN numeric(25,0), BackupSizeInBytes bigint,
				SourceBlockSize int, FileGroupId int, LogGroupGUID uniqueidentifier, DifferentialBaseLSN numeric(25,0), DifferentialBaseGUID uniqueidentifier,
				IsReadOnly bit, IsPresent bit,TDEThumbprint varbinary(32));

-- List of files for litespeed filelist only operation.
declare @filelist_ls table (LogicalName nvarchar(128), PhysicalName nvarchar(260), Type char(1), FileGroupName nvarchar(128), 
				Size numeric(20,0), MaxSize numeric(20,0), FileId bigint, BackupSizeInBytes bigint, FileGroupId int)


-- List of header data captured from a 'restore headeronly' operation
DECLARE @headerdata table (BackupName nvarchar(128), BackupDescription nvarchar(255), BackupType smallint, ExpirationDate datetime,
		Compressed tinyint, Position smallint, DeviceType tinyint, UserName nvarchar(128), ServerName nvarchar(128), DatabaseName nvarchar(128),
		DatabaseVersion int, DatabaseCreationDate datetime, BackupSize numeric(20,0), FirstLSN numeric(25,0), LastLSN numeric(25,0),
		CheckpointLSN numeric(25,0), DatabaseBackupLSN numeric(25,0), BackupStartDate datetime, BackupFinishDate datetime, 
		SortOrder smallint, CodePage smallint, UnicodeLocaleId int, UnicodeComparisonStyle int, CompatabilityLevel tinyint,
		SoftwareVendorId int, SoftwareVersionMajor int, SoftwareVersionMinor int, SoftwareVersionBuild int, MachineName nvarchar(128),
		Flags int, BindingID uniqueidentifier, RecoveryForkID uniqueidentifier, Collation nvarchar(128), FamilyGUID uniqueidentifier,
		HasBulkLoggedData bit, IsSnapshot bit, IsReadOnly bit, IsSingleUser bit, HasBackupChecksums bit, IsDamaged bit, BeginsLogChain bit,
		HasIncompleteMetaData bit, IsForceOffline bit, IsCopyOnly bit, FirstRecoveryForkID uniqueidentifier, ForkPointLSN numeric(25,0),
		RecoveryModel nvarchar(60), DifferentialBaseLSN numeric(25,0), DifferentialBaseGUID uniqueidentifier, BackupTypeDescription nvarchar(60),
		BackupSetGUID uniqueidentifier,CompressedBackupSize int);

DECLARE @LitespeedHeader TABLE (FileNumber INT, BackupFormat VARCHAR(128), Guid UNIQUEIDENTIFIER,BackupName VARCHAR(256), BackupDescription VARCHAR(128),
		BackupType VARCHAR(128), ExpirationDate DATETIME, Compressed TINYINT, [Position] SMALLINT, DeviceType TINYINT, UserName VARCHAR(128),
		[ServerName] VARCHAR(128), DatabaseName VARCHAR(128), DatabaseVersion INT, DatabaseCreationDate DATETIME, BackupSize NUMERIC(20, 0),
		FirstLsn NUMERIC(25, 0), LastLsn NUMERIC(25, 0), CheckpointLsn NUMERIC(25, 0), DifferentialBaseLsn NUMERIC(25, 0), BackupStartDate DATETIME,
		BackupFinishDate DATETIME, SortOrder SMALLINT,[Codepage] SMALLINT, CompatibilityLevel TINYINT, SoftwareVendorId INT, 
		SoftwareVersionMajor INT, SoftwareVersionMinor INT,SoftwareVersionBuild INT, MachineName VARCHAR(128), BindingId UNIQUEIDENTIFIER,
		RecoveryForkId UNIQUEIDENTIFIER, ENCRYPTION INT, IsCopyOnly VARCHAR(128))


-- Temporary holding location for parsed input data
declare @tempdata table (pkid int identity(1,1), textdata varchar(max));
-- List of locations to move data/logs to
declare @newDataLocations table (pkid int identity(1,1), textdata varchar(max));

-- Local var init...
declare	@workingpaths	varchar(max),
		@sql			nvarchar(max),
		@dir			varchar(max),
		@cmd			varchar(8000),
		@i				int,
		@n				int,
		@l				int,
		@minId			int,
		@latestFullSortVal	varchar(150),
		@groupVal		varchar(150),
		@sortVal		varchar(150),
		@fileName		varchar(max),
		@pathAndName	varchar(max),
		@moveLogSql		varchar(max),
		@moveDataSql	varchar(max),
		@stopAtChar		char(23);

-- Format incoming data
select	@dbname = ltrim(rtrim(@dbname)),
		@restorepaths = isnull(ltrim(rtrim(@restorepaths)),''),
		@opts = isnull(@opts,0),
		@sql = N'',
		@moveLogSql = '',
		@moveDataSql = '',
		@stopAt = case when @stopAt > 0 then @stopAt else null end,
		@fileFilGroupPageString = case when len(@fileFilGroupPageString) > 0 then @fileFilGroupPageString when @opts & 64 = 64 then '' else '' end;

-- Format additional data...
select	@newDbName = case when len(@newDbName) > 0 then ltrim(rtrim(@newDbName)) else @dbname end,
		@stopAtChar = case when @stopAt > 0 then convert(char(25), @stopAt, 121) else null end,
		@filePattern = case when len(@restorepaths) > 0 then ltrim(rtrim(@filePattern)) else null end;

-- Ensure we have \ ending paths
if len(@moveLogsTo) > 0
	select @moveLogsTo = @moveLogsTo + case when right(@moveLogsTo,1) = '\' then '' else '\' end;

-- Get page restore data if needed...use a mask of 68 since we can't use this with a LiteSpeed restore currently...
if @opts & 68 = 64 begin
	select	@fileFilGroupPageString = @fileFilGroupPageString + 
				case when len(@fileFilGroupPageString) > 0 then ',' else '' end + 
				cast(file_id as varchar(10)) + ':' + cast(page_id as varchar(25))
	from	msdb.dbo.suspect_pages p
	where	p.database_id = db_id(@dbname)
	and		p.event_type not in(4,5,7)

	select	@fileFilGroupPageString = 'PAGE=''' + @fileFilGroupPageString + '''';

end

-- Init data
select	@workingpaths = @restorepaths;

-- Get the data needed for building the restore strings
if len(@restorepaths) > 0 begin
	-- Parse the specified restore path list into a table set
	while charindex(';', @workingpaths) > 0 begin
		insert	@tempdata (textdata)
		select	rtrim(ltrim(substring(@workingpaths, 1, charindex(';', @workingpaths) - 1)))

		-- Trim the list down
		select	@workingpaths = substring(@workingpaths, charindex(';', @workingpaths) + 1, len(@workingpaths))
	end -- while charindex(';', @workingpaths)

	-- Get the last DB in there if needed
	if len(@workingpaths) > 0
		insert	@tempdata (textdata)
		select	rtrim(ltrim(@workingpaths))

	-- Ensure we have a path delimiter...
	update	@tempdata
	set		textdata = textdata + '\'
	where	right(textdata,1) <> '\';

-- No path(s) specified, build from msdb if possible
end else begin
	select @n = null, @i = null;
	select @sql = N'select	top 1 @i = backup_set_id
					from	msdb.dbo.backupset
					where	database_name = @dbname
					and		type = ''D''
					and		is_snapshot = 0
					and		is_copy_only = 0
					and		backup_finish_date is not null
					and		((backup_start_date <= @stopAt)
							or (@stopAt is null))
					order by backup_finish_date desc, backup_set_id desc;

					select	top 1 @n = backup_set_id
					from	msdb.dbo.backupset
					where	database_name = @dbname
					and		type = ''I''
					and		is_snapshot = 0
					and		is_copy_only = 0
					and		backup_finish_date is not null
					and		backup_set_id > @i
					order by backup_finish_date desc, backup_set_id desc;

					if ((@opts & 16 = 16) or (coalesce(@n,-1) < @i))
						select @n = @i;';
	exec sp_executesql @sql, N'@dbname varchar(250), @opts int, @i int output, @n int output, @stopAt datetime', @dbname, @opts, @i output, @n output, @stopAt;
	
	If @opts & 1 = 1
	Print @sql

	select @sql = N'with backupPathList (backupId, position, singleDevice, backupType, fileNumber, backupEndDate) as (
						select	b.backup_set_id, f.family_sequence_number as position,
								coalesce(f.physical_device_name,f.logical_device_name) as singleDevice,
								b.type as backupType, b.position as fileNumber, backup_finish_date as backupEndDate
						from	' + quotename(@SourceServer) + '.msdb.dbo.backupset b --with(nolock)
						join	' + quotename(@SourceServer) + '.msdb.dbo.backupmediafamily f --with(nolock)
						on		b.media_set_id = f.media_set_id
						where	b.database_name = @dbname
						and		b.is_snapshot = 0
						and		b.is_copy_only = 0
						and		b.backup_finish_date is not null
					)
					insert	#files (pathAndFileName, filname, fileNumber, sortval, groupval, backupEndDate)
					select	singleDevice, 
							right(singleDevice, charindex(''\'',reverse(singleDevice),1) - 1), 
							fileNumber,
							right(''000000000000'' + cast(backupId as varchar(10)), 10), 
							cast(backupId as varchar(10)), backupEndDate
					from	backupPathList
					where	((backupId = @i)
							or (backupId >= @n))
					' + case when @opts & 16 = 16 then 'and backupType <> ''I'' ' else '' end + '
					order by backupId;';
	exec sp_executesql @sql, N'@dbname varchar(250), @i int, @n int', @dbname, @i, @n;

	If @opts & 1 = 1
		Print @sql

end	-- else, if len(@restorepaths) > 0

-- Ensure we have something(s) to restore from
if ((select count(*) from @tempdata) = 0) and ((select count(*) from #files) = 0) begin
	raiserror('No restore data was found for database [%s] and path(s) specified [%s]. Please correct and try again.', 16, 1, @dbname,@restorepaths)
	goto finished
end

-- Get the move to data locations if needed...
if len(@moveDataTo) > 0 begin
	-- Parse the specified restore path list into a table set
	while charindex(';', @moveDataTo) > 0 begin
		insert	@newDataLocations (textdata)
		select	rtrim(ltrim(substring(@moveDataTo, 1, charindex(';', @moveDataTo) - 1)))

		-- Trim the list down
		select	@moveDataTo = substring(@moveDataTo, charindex(';', @moveDataTo) + 1, len(@moveDataTo))
	end -- while charindex(';', @workingpaths)

	-- Get the last location if needed...
	if len(@moveDataTo) > 0
		insert	@newDataLocations (textdata)
		select	rtrim(ltrim(@moveDataTo));

	-- Ensure we have  a path delimiter...
	update	@newDataLocations
	set		textdata = textdata + '\'
	where	right(textdata,1) <> '\';
end

-- If we are restoring from a filelist and not the system tables, figure out the sort order for these suckers...
if len(@restorepaths) > 0 begin
	select	@i = 1, @n = max(pkid)
	from	@tempdata;

	-- Get all the files from the directories in question...
	while @i <= @n begin
		select	@dir = textdata
		from	@tempdata
		where	pkid = @i;
		
		select	@cmd = 'dir /B /A-D "' + @dir + case when len(@filePattern) > 0 then @filePattern else '' end + '"';
		
		insert	#files (filname)
		exec	xp_cmdshell @cmd;

		If @opts & 1 = 1
			Select @cmd
		
		update	#files
		set		pathAndFileName = @dir + filname
		where	pathAndFileName is null;
		
		select	@i = @i+1;
	end

	If @opts & 1 = 1
		Select '' as Predelete, * from #files

	-- Cleanup the list...
	delete	#files
	where	(filname is null
			or lower(filname) like('%file not found%')
			or lower(filname) like('%cannot find the%'));

	If @opts & 1 = 1
		Select '' as AfterFilesNull, * from #files

	-- Remove diffs (if possible) if we're supposed to try to do so and we are using a date/time grouping (otherwise we pull from the restore header)
	if @opts & 144 = 144
		delete	#files
		where	((filname like ('%[_-~!$.]diff[_-~!$.]%'))
				or (filname like('%.dif'))
				or (filname like('diff[_-~!$.]%')));

	-- Ensure we have something(s) to restore from
	if not exists(select * from #files) begin
		raiserror('No restore data was found for database [%s] and path(s) specified [%s]. Please correct and try again.', 16, 1, @dbname,@restorepaths)
		goto finished
	end

	select @minId = min(pkid), @i = null from #files;

	-- if we got a file...
	if @minId > 0 begin

		-- If the caller flagged for us to try and use a date/time stamp within the files as the grouping/sorting value, do
		-- so - otherwise we drop into each file to determine the grouping and sorting...	
		if @opts & 128 = 128 
		begin
			-- Now, with the files, find a spot in the filename that is the date/time stamp...we basically will simply look for
			-- a spot with at least 14 concurrent numeric values, preceeded by an underscore, and followed by more digits and a dot and extension...
			select	@i = patindex('%[_-~!$.][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%[.]%', filname) + 1, @l = len(filname)
			from	#files
			where	pkid = @minId;

			if @i > 1 begin
				select	@n = charindex('.',filname,@i)
				from	#files
				where	pkid = @minId;
				
				if @n = 0
					select	@n = charindex('_',filname,@i)
					from	#files
					where	pkid = @minId;

				if @n = 0
					select	@n = charindex('-',filname,@i)
					from	#files
					where	pkid = @minId;
					
				select	@n = case when @n > 0 then (@n-@i) else len(filname) end
				from	#files
				where	pkid = @minId;

				update	#files
				set		groupval = substring(filname,(@i + (len(filname) - @l)),@n),
						sortval = substring(filname,(@i + (len(filname) - @l)),@n) + filname;

			end else begin
				print 'No DATETIME stamp value could be found in the file names - no special sorting will be applied';
			end

			-- Get the latest full backup sort value...
			select	@latestFullSortVal = max(sortval)
			from	#files
			where	((filname like ('%[_-~!$.]full[_-~!$.]%'))
					or (filname like('%.ful'))
					or (filname like('full[_-~!$.]%')));

		end else begin	-- if @opts & 128 = 128...not using a date/time stamp to specify grouping, drop into each file
			select @i = min(pkid), @n = max(pkid) from #files;

			-- Go through each file using the MediaSetID value as the group...
			while @i <= @n begin
				select	@pathAndName = pathAndFileName, @fileName = filname
				from	#files
				where	pkid = @i;

				if @@rowcount > 0 begin
					-- Get the header data...
					delete	@headerdata;
					select	@sql =	case 
										when @opts & 4 = 4 then 'exec master.dbo.xp_restore_headeronly @filename = ''' + @pathAndName + ''';'
										else 'restore headeronly from disk = ''' + @pathAndName + ''''
									end
					If @opts & 1 = 1
						Select @Sql					

					-- LiteSpeed insert differs slightly...
					if @opts & 4 = 4 begin
						begin try
							insert	@headerdata (UnicodeComparisonStyle/* LS FileNumber*/, HasIncompleteMetaData,/*LS BackupFormat - backwards compatibility for LS*/ BackupSetGUID, BackupName, BackupDescription, BackupType, ExpirationDate, Compressed, Position, DeviceType, UserName,--
							ServerName, DatabaseName, DatabaseVersion, DatabaseCreationDate, BackupSize, FirstLSN, DatabaseBackupLSN, CheckpointLSN,
							DifferentialBaseLSN, BackupStartDate, BackupFinishDate, SortOrder, CodePage, CompatabilityLevel, SoftwareVendorId,
							SoftwareVersionMajor, SoftwareVersionMinor, SoftwareVersionBuild, MachineName, BindingID, RecoveryForkID, HasBackupChecksums,/*LS Encryption bit*/ IsCopyOnly)

							exec	(@sql);
						end try
						begin catch
							-- Could be a native restore using liteSpeed...try normal...
							PRINT 'Failed to get litespeed header info, trying native just in case.'
							select	@sql = 'restore headeronly from disk = ''' + @pathAndName + ''''
							insert	@headerdata
							exec	(@sql);
						end catch

					end else begin	-- no LiteSpeed...
						insert	@headerdata
						exec	(@sql);
					end

					If NOT EXISTS (Select * from @headerdata)
					Begin
						Print 'No header data inserted into table. Could be corrupt backup file.'
						RAISERROR ('No header data inserted into table. Could be corrupt backup file.', 16,1)
						Goto Finished
					End

					If @opts & 1 = 1
						Select * from @headerdata

					-- First delete the existing record...
					delete	#files where pkid = @i;

					-- Insert all the files from this file...
					insert	#files (pathAndFileName, filname, fileNumber, sortval, groupval, backupType, backupEndDate)
					select	@pathAndName, @fileName, Position, 
							cast(DatabaseBackupLSN as varchar(50)) + '_' + cast(replace(replace(replace(replace(convert(varchar(50), BackupFinishDate, 121),'-',''),':',''),'.',''),' ','') as char(17)) + '_' + cast(Position as varchar(15)),
							cast(BackupSetGUID as char(36)),
							BackupType, BackupFinishDate
					from	@headerdata
					where	DatabaseName = @dbname
					and		((@opts & 16 = 0)			-- Either we are using diffs, or...
							or (@opts & 16 = 16 and BackupType not in(5,6,8)));	-- we aren't and this isn't a diff...

				end -- if @@rowcount > 0 begin

				select @i = @i + 1;
			end -- while @i <= @n begin

			-- Get the latest full backup sort value...
			select	@latestFullSortVal = max(sortval)
			from	#files
			where	backupType = 1;

		end	-- if @opts & 128 = 128

	end	-- if @minId > 0

	-- Remove everything before the most recent full backup...
	
	If @opts & 1 = 1
	Select '' as BeforePurge, * from #files

	delete	#files
	where	sortval < @latestFullSortVal;

	If @opts & 1 = 1
	Select '' as AfterPurge, * from #files

	-- If we didn't group by...
	update	#files
	set		groupval = cast(pkid as varchar(50))
	where	groupval is null;

	-- If we are using diffs, try to find the latest diff backup (if we can) and remove any tlog backups
	if @opts & 16 = 0 begin
		-- Find the latest diff backup, and delete any diff/log backups prior to that set...
		if exists(select * from #files where backupType > 0) begin
			select	top 1 @groupVal = groupval, @sortVal = sortval
			from	#files
			where	backupType = 5
			order by sortval desc;

			delete	#files
			where	sortval < @sortVal
			and		groupval <> @groupVal
			and		backupType in(5,2);

		end else begin
			select	top 1 @groupVal = groupval, @sortVal = sortval
			from	#files
			where	((filname like ('%[_-~!$.]diff[_-~!$.]%'))
					or (filname like('%.dif'))
					or (filname like('diff[_-~!$.]%')))
			order by sortval desc;

			delete	#files
			where	sortval < @sortVal
			and		groupval <> @groupVal
			and		((filname like ('%[_-~!$.]diff[_-~!$.]%'))
					or (filname like('%.dif'))
					or (filname like('diff[_-~!$.]%'))
					or (filname like('%[_-~!$.]log[_-~!$.]%'))
					or (filname like('log[_-~!$.]%'))
					or (filname like('%.trn'))
					);
		end

	end	-- if @opts & 16 = 0

end	-- if len(@restorepaths) > 0 

-- If we didn't group successfully...
update	#files
set		groupval = cast(pkid as varchar(50))
where	groupval is null;

-- If we need to move log or data, build list to do so now...
if (len(@moveLogsTo) > 0) or ((select count(*) from @newDataLocations) > 0) begin
	select @minId = min(pkid) from #files;
	
	select	@sql =	case 
						when @opts & 4 = 4 then 'exec master.dbo.xp_restore_filelistonly @filename = ''' + pathAndFileName + ''';'
						else 'restore filelistonly from disk = ''' + pathAndFileName + ''''
					end
	from	#files
	where	pkid = @minId;

	If @opts & 1 = 1
	Print @SQL

	if @opts & 4 = 4 begin
		-- Using LiteSpeed
		insert	@filelist_ls (LogicalName, PhysicalName, Type, FileGroupName, Size, MaxSize,FileId,BackupSizeInBytes,FileGroupId)
		exec	(@sql);				

		--Move data from LS table to native table to make coding easy.
		Insert into @filelist (LogicalName, PhysicalName, Type, FileGroupName, Size, MaxSize,FileId,BackupSizeInBytes,FileGroupId)
		Select * from @filelist_ls

		--Should not be needed in LS 6.52 +
		--update	f
		--set		FileId = rn
		--from	@filelist f
		--join	(select row_number() over (order by LogicalName) as rn, LogicalName as lName from @filelist f2) f3
		--on		f.LogicalName = f3.lName;		
		
	end else begin
		-- not using LiteSpeed
		insert	@filelist
		exec	(@sql);
	end
	
	If @opts & 1 = 1
		Select * from @filelist

	-- Do we need to move logs?
	if len(@moveLogsTo) > 0
		select	@moveLogSql = @moveLogSql + 
					case when len(@moveLogSql) > 0 then ',' else '' end +  
					case when @opts & 4 = 4 then ' @with = ''move ''''' else ' move ''' end + LogicalName + 
					case when @opts & 4 = 4 then ''''' to ''' else ''' to ''' end +  
					case when @opts & 4 = 4 then '''' else '' end + @moveLogsTo + @newDbName + 
					case when (select count(*) from @filelist where Type = 'L') > 1 then cast(FileId as varchar(5)) else '' end +
					'.ldf' +
					case when @opts & 4 = 4 then '''''''' else '''' end
		from	@filelist 
		where	Type = 'L';

	If @opts & 1 = 1
		Print @movelogsto
			
	-- Do we need to move data files?
	if exists(select * from @newDataLocations) begin
		-- If we have data locations, ensure we have as many data location records as we have files to move...
		while (select count(*) from @filelist where Type <> 'L') > (select count(*) from @newDataLocations)
			insert	@newDataLocations (textdata)
			select	textdata
			from	@newDataLocations
			order by pkid;

		-- Build the move to string for data files
		select	@moveDataSql = @moveDataSql + 
					case when len(@moveDataSql) > 0 then ', ' + char(13) + char(10) else '' end +  
					case when @opts & 4 = 4 then ' @with = ''move ''''' else '  move ''' end + f.LogicalName + 
					case when @opts & 4 = 4 then ''''' to ''' else ''' to ''' end + 
					case when @opts & 4 = 4 then '''' else '' end + l.textdata + 
					case when id = 1 then @newDbName + '.mdf' else LogicalName + '.ndf' end +
					case when @opts & 4 = 4 then '''''''' else '''' end
		from	(
				select	row_number() over(order by FileId) as id, LogicalName, FileId
				from	@filelist
				where	Type <> 'L'
				) f
		join	@newDataLocations l
		on		f.id = l.pkid;

		If @opts & 1 = 1
			Print @MoveDataSQL
	end

end	-- if (len(@moveLogsTo) > 0) or ((select count(*) from @newDataLocations) > 0)

-- Need to combine any grouped sets...
if exists(select groupval from #files group by groupval having count(*) > 1) begin
	declare groupCursor cursor local fast_forward for
		select	min(pkid), groupval
		from	#files
		group by groupval
		having count(*) > 1;
	open groupCursor;
	
	while 1=1 begin
		fetch next from groupCursor into @i, @groupVal;
		
		if @@fetch_status <> 0
			break;
		
		select	@sql = '';
		
		-- Build the full from clause for this particular group...
		select	@sql = @sql + case when len(@sql) > 0 then ''', ' + char(13) + char(10) + '   ' +
								case when @opts & 4 = 4 then '@filename = ''' else 'disk = ''' end else ''
							end + pathAndFileName
		from	#files
		where	groupval = @groupVal
		order by pkid;

		If @opts & 1 = 1
			Print @sql
				
		-- Update this group's main string
		update	#files
		set		pathAndFileName = @sql
		where	pkid = @i;
		
		-- Remove all others but the main for this group
		delete	#files
		where	groupval = @groupVal
		and		pkid <> @i;
	end
	
	close groupCursor;
	deallocate groupCursor;
end	-- if exists(select groupval from #files group by groupval having count(*) > 1)

-- If we should be disconnecting clients, build string to do so now...
if @opts & 8 = 8
	insert	#dbrestore (id, textdata)
	select	1,	'if db_id(''' + @newDbName + ''') > 0 ' + char(13) + char(10) +
				'   alter database ' + @newDbName + ' set read_only with rollback immediate;';

select	@i = count(*)
from	#dbrestore with(nolock);

-- Build the restore strings...
if @opts & 4 = 4
	-- Using LiteSpeed...
	insert	#dbrestore (id, textdata)
	select	(a.rownum + (a.rownum - 1)),
			'exec master.dbo.' +
			case
				when backupType = 2 then 'xp_restore_log '
				when filname like('%[_-~!$.]log[_-~!$.]%') then 'xp_restore_log '
				when filname like('log[_-~!$.]%') then 'xp_restore_log '
				when filname like('%.trn') then 'xp_restore_log '
				else 'xp_restore_database '
			end + char(13) + char(10) +
			'   @database = ''' + @newDbName + ''', ' + char(13) + char(10) +
			'   @filename = ''' + pathAndFileName + ''',' + char(13) + char(10) + 
			'   @logging = 0, ' + char(13) + char(10) + 
			'   @filenumber = ' + cast(coalesce(fileNumber,1) as varchar(25)) + ', ' + char(13) + char(10) + 
			CASE WHEN @opts & 2 = 2 THEN '   @with = ''recovery'', ' 
				ELSE '   @with = ''norecovery'', '  END
			+ char(13) + char(10) + 
			'   @with = ''replace''' +
			case when len(@stopAtChar) > 0 then ', ' + char(13) + char(10) + '   @with = ''stopat = ''''' + @stopAtChar + '''''''' else '' end +
			case when len(@moveLogSql) > 0 then ', ' + char(13) + char(10) + '     ' + @moveLogSql else '' end +
			case when len(@moveDataSql) > 0 then ', ' + char(13) + char(10) + @moveDataSql else '' end +
			';'
	from	(
			select	(row_number() over (order by sortval,pkid) + @i) as rownum, fileNumber, filname, pathAndFileName, backupType 
			from	#files
			) a;
else
	-- Not using LiteSpeed...
	insert	#dbrestore (id, textdata)
	select	(a.rownum + (a.rownum - 1)),
			'restore ' +
			case 
				when backupType = 2 then 'log '
				when filname like('%[_-~!$.]log[_-~!$.]%') then 'log '
				when filname like('log[_-~!$.]%') then 'log '
				when filname like('%.trn') then 'log '
				else 'database '
			end + @newDbName + ' ' +
			case -- Need to use the page/file setting when this is NOT a log backup...and we've specified a value...
				when len(@fileFilGroupPageString) > 0 then 
					case
						when backupType = 2 then ''
						when filname like('%[_-~!$.]log[_-~!$.]%') then ''
						when filname like('log[_-~!$.]%') then ''
						when filname like('%.trn') then ''
						else char(13) + char(10) + '   ' + @fileFilGroupPageString + ' ' + char(13) + char(10) 
					end
				else '' 
			end +
			'from ' + char(13) + char(10) + 
			'   disk = ''' + pathAndFileName + '''' + char(13) + char(10) + 
			'   with file = ' + cast(coalesce(fileNumber,1) as varchar(25)) + 
			CASE WHEN @opts & 2 = 2 THEN ', recovery, replace' 
				ELSE ', norecovery, replace'  END +
			case when @opts & 32 = 32 then ', checksum' else '' end +
			case when len(@stopAtChar) > 0 then ', stopat = ''' + @stopAtChar + '''' else '' end + 
			case when len(@moveLogSql) > 0 then ', ' + char(13) + char(10) + '     ' + @moveLogSql else '' end +
			case when len(@moveDataSql) > 0 then ', ' + char(13) + char(10) + @moveDataSql else '' end +
			';'
	from	(
			select	(row_number() over (order by sortval,pkid) + @i) as rownum, fileNumber, filname, pathAndFileName, backupType
			from	#files
			) a;

-- Put in GO's between each statement if we aren't executing...
if @opts & 1 = 1
	insert	#dbrestore (id,textdata)
	select	id + 1, 'GO '
	from	#dbrestore;

select	@i = max(id)
from	#dbrestore;

	
-- Output results if desired...
if @opts & 1 = 1
	select textdata from #dbrestore order by id;

-- Execute if appropriate...
if @opts & 1 = 0 begin
	declare restoreSql cursor local fast_forward for
		select textdata from #dbrestore order by id;

	open restoreSql;

	-- Process each restore...
	while 1=1 begin
		fetch next from restoreSql into @sql;

		-- Break when all done...
		if @@fetch_status <> 0
			break;

		-- If we are to trap/eat errors, execute within try/catch, otherwise
		-- simply execute so errors are spit out to the client...
		if @opts & 256 = 256 begin
			-- Execute...
			begin try
				exec (@sql);
			end try
			begin catch
				print '!!!!!!!!!!!!!!! ERROR START !!!!!!!!!!!!!!!';
				print '   Message: ' + quotename(error_message());
				print '   Number: ' + quotename(cast(error_number() as varchar(50)));
				print '   Statement: [' + left(isnull(@sql,'<NULL>'),1000) + ']';
				print '!!!!!!!!!!!!!!! ERROR STOP  !!!!!!!!!!!!!!!';
			end catch
		end else begin
			exec (@sql);
		end

	end	-- while 1=1 begin

end	-- if @opts & 1 = 0 begin

finished:

-- Close cursor as needed...
if cursor_status('local', 'restoreSql') >= 0 begin
	close restoreSql;
	deallocate restoreSql;
end
if cursor_status('local', 'groupCursor') >= 0 begin
	close groupCursor;
	deallocate groupCursor;
end



