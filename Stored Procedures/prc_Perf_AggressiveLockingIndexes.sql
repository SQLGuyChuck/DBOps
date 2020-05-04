SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE dbo.prc_Perf_AggressiveLockingIndexes
AS
BEGIN
/*
**	This proc returns the TOP aggressive indexes on all the databases for the current server.
	The filters are:
		1.	More than 1000 page_lock_wait_count or row_lock_wait_count 
		2.	More than 5 minutes of total row_lock + page_lock 
		3.	DISTINCT TOP 10 AVG row_lock and page_lock

** 02/14/2013	Matias Sincovich	Created
*/
--Aggressive Locking Indexes - Those that wait often on latches (finding the data) and locking (state of the data)
--There is serious contention for these indexes. This is affecting the application by slowing it down waiting on other processes.
--Is there excessive use of serializable transactions? Maybe use READPAST hint instead for SELECT statements.
	SELECT TOP (100)
		DB_NAME(o.database_id) DatabaseName,
		OBJECT_SCHEMA_NAME(o.object_id, o.database_id) SchemaName,
		OBJECT_NAME(o.object_id, o.database_id) ObjectName,
		o.index_id,
		i.name as IndexName,
		--o.partition_number, 
		o.range_scan_count ,
		o.page_lock_wait_count, 
		o.page_lock_wait_in_ms,
		o.row_lock_wait_count,
		o.row_lock_wait_in_ms,
		o.page_latch_wait_count,
		o.page_latch_wait_in_ms,
		o.page_io_latch_wait_count,
		o.page_io_latch_wait_in_ms,
		o.page_lock_wait_in_ms/NULLIF(o.page_lock_wait_count,0) as AVG_page_lock_wait,
		o.row_lock_wait_in_ms/NULLIF(o.row_lock_wait_count,0) as AVG_row_lock_wait,
		o.index_lock_promotion_attempt_count,
		o.index_lock_promotion_count,
		case o.page_lock_wait_count when 0 then 0 else o.page_lock_wait_in_ms/o.page_lock_wait_count End
		+ case o.row_lock_wait_count when 0 then 0 else o.row_lock_wait_in_ms/o.row_lock_wait_count end 
		+ case o.page_latch_wait_count when 0 then 0 else o.page_latch_wait_in_ms/o.page_latch_wait_count End
		+ case o.page_io_latch_wait_count when 0 then 0 else o.page_io_latch_wait_in_ms/o.page_io_latch_wait_count end as total_avg
	--FROM sys.dm_db_index_operational_stats (NULL, NULL, NULL, NULL) o
	FROM sys.dm_db_index_operational_stats (DB_ID(), NULL, NULL, NULL) o
	INNER JOIN sys.indexes i ON i.object_id = o.object_id AND i.index_id = o.index_id
	where --index_id = 0 AND
	OBJECT_NAME(o.object_id, o.database_id) <> 'syspublications' AND
	OBJECTPROPERTY(o.object_id,'IsUserTable') = 1 AND
	( (o.page_latch_wait_count > 1000 OR o.page_io_latch_wait_count > 2000 OR o.page_lock_wait_count > 1000 OR o.row_lock_wait_count > 1000 )--High latch or lock waits
			OR (o.page_lock_wait_in_ms + o.row_lock_wait_in_ms)/1000/60>2--Number of minutes total it waited.
		)
	--AND DB_NAME(o.database_id) not in ('tempdb','msdb', 'master')
	ORDER BY total_avg DESC, o.index_lock_promotion_attempt_count DESC
END;
GO
