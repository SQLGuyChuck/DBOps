SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Perf_Top_Memory_Intensive_Queries
	@ROWCOUNT SMALLINT = 50
AS
BEGIN
/******************************************************************************  
**  Name: prc_Perf_Top_Memory_Intensive_Queries.sql  
**  Desc: This will get list of TOP (@Rowcount) Memory Intensive Stored Procedure either from
**        the repository or current.
**
*******************************************************************************  
**  Change History  
*******************************************************************************  
**  Date:		Author:			Description:  
**  01/12/2009  Ganesh			Created 
**  03/22/2009	Ganesh			Modified for the current database context 
**  07/08/2010	Chuck Lathrope	Removed sys schema objects. Changed name. Added @Rowcount parameter.
**								Removed DMVsnapshot and @State.
*******************************************************************************/
	SELECT TOP (@Rowcount)
		COALESCE(DB_NAME(st.dbid), DB_NAME(CAST(pa.value AS INT)) + '*', 'Resource') DBName
		,OBJECT_SCHEMA_NAME(objectid,st.dbid) SchemaName
		,OBJECT_NAME(objectid,st.dbid) ObjectName
		,substring(st.text, (qs.statement_start_offset/2)+1, ((case qs.statement_end_offset when -1 then datalength(st.text) else qs.statement_end_offset end - qs.statement_start_offset)/2) + 1) as statement_text
		,total_logical_reads
		,qs.execution_count AS 'Execution Count', total_logical_reads/qs.execution_count AS 'AvgLogicalReads'
		,qs.execution_count/(CASE WHEN DATEDIFF(Second, qs.creation_time, GetDate()) = 0 THEN 1 ELSE DATEDIFF(Second, qs.creation_time, GetDate()) END) AS 'Calls/Second'
		,qs.total_worker_time/qs.execution_count AS 'AvgWorkerTime'
		,qs.total_worker_time AS 'TotalWorkerTime'
		,qs.total_elapsed_time/qs.execution_count AS 'AvgElapsedTime'
		,qs.total_logical_writes
		,qs.max_logical_reads
		,qs.max_logical_writes
		,qs.total_physical_reads
		,DATEDIFF(Minute, qs.creation_time, GetDate()) AS 'Age in Cache(min)'
	FROM sys.dm_exec_query_stats AS qs
	CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
	OUTER APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa 
    WHERE pa.attribute = 'dbid'
	AND ISNULL(OBJECT_SCHEMA_NAME(objectid,st.dbid),'') <> 'sys'
	ORDER BY total_logical_reads DESC

END;
GO
