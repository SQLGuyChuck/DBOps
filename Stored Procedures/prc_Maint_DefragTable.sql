SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
**		Name: prc_Maint_DefragTable
**		Desc: This Proc automatically reorganizes or rebuilds all partitions in a database that 
**		have an average fragmentation over @ReorganizeThresholdFloat percent. 
**		Executing this query requires the VIEW DATABASE STATE permission.
**		
**              
**		Return values: Error code.
** 
**		Called by:   Manually, or SQL job.
**              
**		Parameters:
**		Input							
**		@DatabaseName - Name of database to run maintenance on, must be provided.
**		[@TableName]  - Optional name of table to defragment.
**		[@ReorganizeThresholdPercent]			- Optional minimum percentage of fragmentation, 10 is default.
**		[@RebuildThresholdPercent]  - Optional percentage to Rebuild index instead of reorganize.
**		
**		Examples / test cases:
**		exec prc_Maint_DefragTable @DatabaseName='dbops', @ReorganizeThresholdPercent=80, @RebuildThresholdPercent=90
**		exec prc_Maint_DefragTable @DatabaseName='dbops', @TableName='party', @TableScanMode='sampled', @sortintempdb=1, @Debug = 1
**		exec prc_Maint_DefragTable @DatabaseName='dbops', @ReorganizeThresholdPercent=15, @RebuildThresholdPercent=30, @Debug = 1
**
**		Auth: Chuck Lathrope
**		Date: 10/18/2006
*******************************************************************************
**		Change History
*******************************************************************************
**		Date:		Author:				Description:
**		11/7/2006	Chuck Lathrope		Finished testing, added try catch for LOB caused error.
**		12/12/2008	Chuck Lathrope		Fixed bug of not reseting variables in cursor.
**		3/31/2011	Chuck Lathrope		Bug fix for online operations and DBAIndexes update skipped in debug mode.
**		9/26/2011	Chuck Lathrope		Add @SortinTempDB parameter.
*******************************************************************************

*******************************
SQL 2005 Use ONLY
*******************************

SELECT db_name(database_id), object_name(object_id), * 
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL , NULL, 'LIMITED')
WHERE index_type_desc <> 'HEAP'
AND avg_fragmentation_in_percent > 30.0

BOL snippet on Modes:
The mode (last parameter) in which the function is executed determines the level of scanning performed to obtain the statistical data that is used by the function.
Mode is specified as LIMITED, SAMPLED, or DETAILED. The function traverses the page chains for the allocation units that make up the specified 
partitions of the table or index. Unlike DBCC SHOWCONTIG that generally requires a shared (S) table lock, sys.dm_db_index_physical_stats requires 
only an Intent-Shared (IS) table lock, regardless of the mode that it runs in. For more information about locking, see Lock Modes. 

The LIMITED mode is the fastest and scans the smallest number of pages. It scans all pages for a heap, but only the parent-level pages for an index,
which are the pages above the leaf-level. 

The SAMPLED mode returns statistics based on a 1 percent sample of all the pages in the index or heap. If the index or heap has fewer than 
10,000 pages, DETAILED mode is used instead of SAMPLED. 

The DETAILED mode scans all pages and returns all statistics. 

The modes are progressively slower from LIMITED to DETAILED, because more work is performed in each mode. To quickly gauge the size or fragmentation
level of a table or index, use the LIMITED mode. It is the fastest and will not return a row for each nonleaf level in the IN_ROW_DATA allocation unit of the index.
exec prc_Maint_DefragTable 'namehost','party',20,30,1

--Same columns.
SELECT *
--	object_id AS objectid,
--	index_id AS indexid,
--	partition_number AS partitionnum,
--	avg_fragmentation_in_percent AS frag
FROM sys.dm_db_index_physical_stats (db_id('namehost'), object_id('customers'), NULL , NULL, 'detailed')
WHERE 1=1--avg_fragmentation_in_percent > 30
AND index_id > 0

SELECT *
--	object_id AS objectid,
--	index_id AS indexid,
--	partition_number AS partitionnum,
--	avg_fragmentation_in_percent AS frag
FROM sys.dm_db_index_physical_stats (db_id('namehost'), object_id('customers'), NULL , NULL, 'Limited')
WHERE 1=1--avg_fragmentation_in_percent > 30
AND index_id > 0

*/
CREATE OR ALTER PROCEDURE dbo.prc_Maint_DefragTable
	@DatabaseName sysname,
	@TableName sysname = NULL,
	@ReorganizeThresholdPercent int = 30,
	@RebuildThresholdPercent int = 60,
	@TableScanMode varchar(20) = 'Limited', --Can be limited,sampled, or detailed. Detailed is expensive operation.
	@SortinTempDB BIT = 0,
	@Debug bit = 0
As

BEGIN

SET NOCOUNT ON;

DECLARE @partitioncount bigint
	, @schemaname nvarchar(130)
	, @objectname nvarchar(130)
	, @indexname nvarchar(130)
	, @partitionnum bigint
	, @partitions bigint
	, @frag float
	, @command varchar(4000)
	, @ReorganizeThresholdFloat float
	, @RebuildThresholdFloat float
	, @dbid int
	, @TableID bigint
	, @objectid int
	, @indexid int
	, @ServerEdition varchar(50)
	, @DateStamp datetime
	, @error int
	, @DefragCount int
	, @UpdateDSQL varchar(400);


SET @ServerEdition = Cast(SERVERPROPERTY ('edition') as varchar(50));
SET @DateStamp = Getdate();

--Required for this proc: @DatabaseName parameter
SET @dbid = DB_ID(@DatabaseName);

If @TableName is Not Null
Begin
	SELECT @TableID = OBJECT_ID(@DatabaseName + '.dbo.' + @TableName);
	If @TableID is Null
	Begin
		Raiserror('Table not found!',16,1)
		Return 1
	End
End

If @dbid is Null
Begin
	Raiserror('Database not found!',16,1)
	Return 1
End


SELECT @ReorganizeThresholdFloat=COALESCE(cast(@ReorganizeThresholdPercent as float), 30.0) 
		,@RebuildThresholdFloat=COALESCE(cast(@RebuildThresholdPercent as float), 60.0)


-- Conditionally select tables and indexes from the sys.dm_db_index_physical_stats view 
-- and convert object and index IDs to names.

--Populate logging table DBAIndexStats.
Insert into DBAIndexStats (DatabaseID, ObjectID, IndexID, PartitionNum, IndexType, IndexDepth, IndexLevel, PageCount, FragPercentage, RebuildThreshold)
SELECT 
	database_id as DatabaseID,
	[object_id] AS ObjectID,
	index_id AS IndexID,
	partition_number AS PartitionNum,
	index_type_desc as IndexType,
	index_depth as IndexDepth,
	index_level as IndexLevel,
	Page_Count as PageCount,
	avg_fragmentation_in_percent AS FragPercentage,
	cast(@RebuildThresholdFloat as int) as RebuildThreshold
FROM sys.dm_db_index_physical_stats (@dbid, @TableID, NULL , NULL, @TableScanMode)

Select @error = @@error
If @error <> 0
Begin
	Print 'DBAIndexStats insert @@error is: ' + cast(@error as varchar(5))
End

Set @UpdateDSQL = 'Use ' + @DatabaseName + '; 
Update s
Set Databasename = db_name(databaseid)
  , ObjectName = object_name(objectid)
  , IndexName = i.name
from DBOPS.dbo.DBAIndexStats s, sys.indexes i
where s.objectid = i.object_id
and s.indexid = i.index_id
and databaseid = db_id(''' + @DatabaseName + ''')
and DatabaseName is NULL'

If @Debug = 1 
Begin
	Print @UpdateDSQL
End

--Update DBAIndexStats table.
Begin
	Exec (@UpdateDSQL)
	Select @error = @@error --catching typos in dynamic sql.
END

If @Debug = 1 and @error <> 0
Begin
	Print 'DBAIndexStats @@error is: ' + cast(@error as varchar(5))
End

Create Table #PhysicalStats (
	objectid int,
	indexid int,
	partitionnum int,
	frag float)

Create Clustered Index IDXTemp_PhysicalStats on #PhysicalStats (objectid, indexid, partitionnum, Frag)

Insert into #PhysicalStats (objectid, indexid, partitionnum, frag)
SELECT
	object_id AS objectid,
	index_id AS indexid,
	partition_number AS partitionnum,
	avg_fragmentation_in_percent AS frag
FROM sys.dm_db_index_physical_stats (@dbid, @TableID, NULL , NULL, @TableScanMode)
WHERE avg_fragmentation_in_percent > @ReorganizeThresholdFloat 
AND index_id > 0 -- 0 is a heap. --Alter index won't do anything useful, need to create clustered index then drop clustered index.
AND page_count > 100

Select @DefragCount = @@RowCount

If @DefragCount = 0
Begin
	Print 'Nothing to defragment.'
	Set @Error = 0
	GOTO ProcError
End

If @Debug = 1
	Select * from #PhysicalStats

-- Declare the cursor for the list of partitions to be processed.
DECLARE partitions CURSOR FOR SELECT * FROM #PhysicalStats;

DECLARE @dsql nvarchar (500)
DECLARE @sysobjects as nvarchar(100)
DECLARE @sysschemas as nvarchar(100)
DECLARE @sysindexes as nvarchar(100)
DECLARE @syspartitions as nvarchar(100)

--The sysfile table is a system table that every db has.
SET @sysobjects = N'[' + @DatabaseName + '].sys.objects'
SET @sysschemas = N'[' + @DatabaseName + '].sys.schemas'
SET @sysindexes = N'[' + @DatabaseName + '].sys.indexes'
SET @syspartitions = N'[' + @DatabaseName + '].sys.partitions'

-- Open the cursor.
OPEN partitions;

FETCH NEXT FROM partitions INTO @objectid, @indexid, @partitionnum, @frag;

-- Loop through the partitions.
WHILE @@FETCH_STATUS = 0
BEGIN

	-- Create sp_execute statement to return variables populated with object info from database passed in, dynamically.
	SET @dsql = N'SELECT @objectnameOut = QUOTENAME(o.name), @schemanameOut = QUOTENAME(s.name) FROM ' 
			+ @sysobjects + N' AS o JOIN ' + @sysschemas + N' as s ON s.schema_id = o.schema_id WHERE o.object_id = ' 
			+ cast(@objectid as nvarchar(20))

	EXEC sp_executesql @dsql, N'@objectnameOut sysname output, @schemanameOut sysname output'
						, @objectnameOut = @objectname Output
						, @schemanameOut = @schemaname Output

	--Index info:
	SET @dsql = N'SELECT @sysindexesOut = QUOTENAME(name) FROM ' 
			+ @sysindexes + N' WHERE object_id = ' + cast(@objectid as nvarchar(20)) + N' AND index_id = ' + cast(@indexid as nvarchar(20))

	EXEC sp_executesql @dsql, N'@sysindexesOut sysname output'
						, @sysindexesOut = @indexname Output

	--Partition info:
	SET @dsql = N'SELECT @syspartitionsOut = count (*) FROM ' 
			+ @syspartitions + N' WHERE object_id = ' + cast(@objectid as nvarchar(20)) + N' AND index_id = ' + cast(@indexid as nvarchar(20))

	EXEC sp_executesql @dsql, N'@syspartitionsOut sysname output'
						, @syspartitionsOut = @partitioncount Output

	IF @frag < @RebuildThresholdFloat
		SET @command = 'ALTER INDEX ' + @indexname + ' ON ' + @databasename + '.' + @schemaname + '.' + @objectname + ' REORGANIZE '
	IF @frag >= @RebuildThresholdFloat
	BEGIN
		SET @command = 'ALTER INDEX ' + @indexname + ' ON ' + @databasename + '.' + @schemaname + '.' + @objectname + ' REBUILD '
		IF @ServerEdition like 'Enterprise Edition%' AND @SortinTempDB = 1
			SET @command = @command + ' WITH (ONLINE = ON, SORT_IN_TEMPDB = ON)'
		ELSE IF @ServerEdition like 'Enterprise Edition%' AND @SortinTempDB = 0
			SET @command = @command + ' WITH (ONLINE = ON)'
		ELSE IF @SortinTempDB = 1
			SET @command = @command + ' WITH (SORT_IN_TEMPDB = ON)'
	END
	IF @partitioncount > 1
		SET @command = @command + ' PARTITION=' + CAST(@partitionnum AS nvarchar(10));

	If @Debug = 0 
		Begin Try
			EXEC (@command) --Msg 2725 is error # when index contains LOB object. Can't do online Rebuild.
		End Try
		Begin Catch
			Select @Error = ERROR_NUMBER()

			If @Error = 2725
			Begin
				Set @Command = Replace(@Command, 'WITH (ONLINE = ON)', '')
				Exec (@Command)
			End
			Else 
				GOTO ProcError
		End Catch
	Else 
		PRINT @command
    
--Reset variables
	Select @objectid = NULL, @indexid = NULL, @partitionnum = NULL, @frag = NULL
	
	FETCH NEXT FROM partitions
       INTO @objectid, @indexid, @partitionnum, @frag
END

-- Close and deallocate the cursor.
CLOSE partitions
DEALLOCATE partitions

ProcError:
-- Drop the temporary table.
DROP TABLE #PhysicalStats
Return (@Error)
END
;
GO
