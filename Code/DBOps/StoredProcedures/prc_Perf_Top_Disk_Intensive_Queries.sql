SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE dbo.prc_Perf_Top_Disk_Intensive_Queries
	@ROWCOUNT SMALLINT = 50
AS
BEGIN
/******************************************************************************  
**  Name: prc_Perf_Top_Disk_Intensive_Queries.sql  
**  Desc: This will get list of TOP (@Rowcount) Disk Intensive Stored Procedure either from
**        the repository or current.
**    
*******************************************************************************  
**  Change History  
*******************************************************************************  
**  Date:		Author:			Description:  
**  01/12/2009  Ganesh			Created  
**  07/08/2010	Chuck Lathrope	Removed sys schema objects. Changed name. Added @Rowcount parameter.
**								Removed DMVsnapshot and @State.
*******************************************************************************/
	SELECT TOP (@Rowcount)
		DB_NAME(st.database_id) DBName
		,OBJECT_SCHEMA_NAME(st.OBJECT_ID,st.database_id) SchemaName
		,OBJECT_NAME(st.OBJECT_ID,st.database_id) as ObjectName
		,st.page_latch_wait_count
		,st.page_latch_wait_in_ms		
		,st.page_io_latch_wait_count
		,st.page_io_latch_wait_in_ms
		,st.range_scans
		,st.index_lookups 
		,st.row_lock_count
		,st.row_lock_wait_count
		,CAST (100.0 * row_lock_wait_count / (1 + row_lock_count) AS NUMERIC(15,2)) AS pct_lockwait
		,st.row_lock_wait_in_ms
		,CAST (1.0 * row_lock_wait_in_ms / (1 + row_lock_wait_count) AS NUMERIC(15,2)) AS avg_row_lock_wait_in_ms
	from (select database_id, OBJECT_ID, ROW_NUMBER() over (partition by database_id order by sum(page_latch_wait_count+page_io_latch_wait_in_ms) desc) as ROW_NUMBER
			,SUM(page_latch_wait_count) as page_latch_wait_count
			,SUM(page_latch_wait_in_ms) as page_latch_wait_in_ms
			,SUM(page_io_latch_wait_count) as page_io_latch_wait_count
			,SUM(page_io_latch_wait_in_ms) as page_io_latch_wait_in_ms
			,SUM(range_scan_count) as range_scans
			,SUM(singleton_lookup_count) as index_lookups 
			,SUM(row_lock_count) as row_lock_count
			,SUM(row_lock_wait_count ) as row_lock_wait_count
			,SUM(row_lock_wait_in_ms) as row_lock_wait_in_ms
			from sys.dm_db_index_operational_stats(null, null,null, null) 
			where page_latch_wait_count+page_io_latch_wait_count > 0
			and database_id <> 2
			group by database_id, OBJECT_ID ) as st
   where ISNULL(OBJECT_SCHEMA_NAME(object_id,st.database_id),'') <> 'sys'
   order by page_latch_wait_count+page_io_latch_wait_count desc
   
END

;
GO
