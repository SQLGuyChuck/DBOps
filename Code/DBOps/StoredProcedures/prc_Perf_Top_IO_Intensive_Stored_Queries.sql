SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Perf_Top_IO_Intensive_Stored_Queries
	@ROWCOUNT SMALLINT = 50
AS
BEGIN
/******************************************************************************  
**  Name: prc_Perf_Top_IO_Intensive_Stored_Queries.sql  
**  Desc: This will get list of TOP (@Rowcount) I/O Intensive Stored Procedure either from
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
		COALESCE(DB_NAME(st.dbid), DB_NAME(CAST(pa.value AS INT)) + '*', 'Resource') DBName
		,OBJECT_SCHEMA_NAME(objectid,st.dbid) SchemaName
		,OBJECT_NAME(objectid,st.dbid) ObjectName
		,cp.objtype ObjectType
		,substring(st.text, (qs.statement_start_offset/2)+1, ((case qs.statement_end_offset when -1 then datalength(st.text) else qs.statement_end_offset end - qs.statement_start_offset)/2) + 1) as statement_text
		,max(cp.usecounts) execution_count
		,sum(qs.total_physical_reads + qs.total_logical_reads + qs.total_logical_writes) total_IO
		,sum(qs.total_physical_reads + qs.total_logical_reads + qs.total_logical_writes) / (max(cp.usecounts)) avg_total_IO
		,sum(qs.total_physical_reads) total_physical_reads
		,CAST(sum(qs.total_physical_reads) / (max(cp.usecounts) * 1.0) AS NUMERIC(15,2)) avg_physical_read    
		,sum(qs.total_logical_reads) total_logical_reads
		,CAST(sum(qs.total_logical_reads) / (max(cp.usecounts) * 1.0) AS NUMERIC(15,2)) avg_logical_read  
		,sum(qs.total_logical_writes) total_logical_writes
		,CAST(sum(qs.total_logical_writes) / (max(cp.usecounts) * 1.0) AS NUMERIC(15,2)) avg_logical_writes  
	FROM sys.dm_exec_query_stats qs 
	JOIN sys.dm_exec_cached_plans cp on qs.plan_handle = cp.plan_handle
	CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
	OUTER APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa 
	WHERE pa.attribute = 'dbid' 
	AND ISNULL(OBJECT_SCHEMA_NAME(objectid,st.dbid),'') <> 'sys'
	and cp.objtype in ('proc','Prepared','Adhoc','Trigger','Check','Rule','View')
	group by COALESCE(DB_NAME(st.dbid), DB_NAME(CAST(pa.value AS INT)) + '*', 'Resource'),OBJECT_SCHEMA_NAME(objectid,st.dbid), OBJECT_NAME(objectid,st.dbid), cp.objtype, substring(st.text, (qs.statement_start_offset/2)+1, ((case qs.statement_end_offset when -1 then datalength(st.text) else qs.statement_end_offset end - qs.statement_start_offset)/2) + 1)
	order by sum(qs.total_physical_reads + qs.total_logical_reads + qs.total_logical_writes) desc
END
;
GO
