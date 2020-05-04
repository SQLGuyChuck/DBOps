SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Perf_Top_CPU_Intensive_Queries
	@ROWCOUNT SMALLINT = 50
AS
BEGIN
/******************************************************************************  
**  Name: prc_Perf_Top_CPU_Intensive_Queries.sql  
**  Desc: This will get list of TOP (@Rowcount) CPU Intensive Stored Procedure either from
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
	-- TOP (@Rowcount) CPU Intensive
	SELECT TOP (@Rowcount)  
		COALESCE(DB_NAME(st.dbid), DB_NAME(CAST(pa.value AS INT)) + '*', 'Resource') DBName
		  ,OBJECT_SCHEMA_NAME(objectid,st.dbid) SchemaName
		  ,OBJECT_NAME(objectid,st.dbid) ObjectName
		  ,cp.objtype ObjectType
		  ,substring(st.text, (qs.statement_start_offset/2)+1, ((case qs.statement_end_offset when -1 then datalength(st.text) else qs.statement_end_offset end - qs.statement_start_offset)/2) + 1) as statement_text
		  ,max(cp.usecounts) Execution_count
		  ,sum(qs.total_worker_time) total_cpu_worker_time
		  ,CAST(sum(qs.total_worker_time) / (max(cp.usecounts) * 1.0) AS NUMERIC(15,1))  avg_cpu_worker_time
	FROM sys.dm_exec_cached_plans cp 
	join sys.dm_exec_query_stats qs on cp.plan_handle = qs.plan_handle
	CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
	OUTER APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa 
	WHERE pa.attribute = 'dbid'
	AND ISNULL(OBJECT_SCHEMA_NAME(objectid,st.dbid),'') <> 'sys'
	AND cp.objtype in ('proc','Prepared','Adhoc','Trigger','Check','Rule','View')
	group by COALESCE(DB_NAME(st.dbid), DB_NAME(CAST(pa.value AS INT)) + '*', 'Resource'),OBJECT_SCHEMA_NAME(objectid,st.dbid), OBJECT_NAME(objectid,st.dbid),cp.objtype, substring(st.text, (qs.statement_start_offset/2)+1, ((case qs.statement_end_offset when -1 then datalength(st.text) else qs.statement_end_offset end - qs.statement_start_offset)/2) + 1)
	order by sum(qs.total_worker_time) desc

END
;
GO
