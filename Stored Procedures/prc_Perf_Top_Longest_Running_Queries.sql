SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Perf_Top_Longest_Running_Queries
	@ROWCOUNT SMALLINT = 50
AS
BEGIN

/******************************************************************************  
**  Name: prc_Perf_Top_Longest_Running_Queries.sql  
**  Desc: This will get list of TOP (@Rowcount) longest running stored procedure either from
**        the repository or current.
**    
**  Return values: Displays the resultset.  
**  
*******************************************************************************  
**  Change History  
*******************************************************************************  
**  Date:		Author:			Description:  
**  01/12/2009  Ganesh			Created  
**  07/08/2010	Chuck Lathrope	Removed sys schema objects. Changed name. Added @Rowcount parameter.
**								Removed DMVsnapshot and @State.
*******************************************************************************/

	SELECT TOP (50) 		
		COALESCE(DB_NAME(st.dbid), DB_NAME(CAST(pa.value AS INT)) + '*', 'Resource') DBName
		,OBJECT_SCHEMA_NAME(objectid,st.dbid) SchemaName
		,OBJECT_NAME(objectid,st.dbid) ObjectName
		,cp.objtype ObjectType
		,substring(st.text, (qs.statement_start_offset/2)+1, ((case qs.statement_end_offset when -1 then datalength(st.text) else qs.statement_end_offset end - qs.statement_start_offset)/2) + 1) as statement_text
		,max(cp.usecounts) execution_count
		,max(qs.max_elapsed_time) max_elapsed_time
		,sum(qs.total_elapsed_time) total_elapsed_time
		,sum(qs.total_elapsed_time) / max(cp.usecounts) avg_elapsed_time
		,max(qs.last_elapsed_time) last_elapsed_time
	FROM sys.dm_exec_query_stats qs 
	JOIN sys.dm_exec_cached_plans cp on qs.plan_handle = cp.plan_handle
	CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
	OUTER APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa 
    WHERE pa.attribute = 'dbid'
	AND ISNULL(OBJECT_SCHEMA_NAME(objectid,st.dbid),'') <> 'sys'
	AND cp.objtype in ('proc','Prepared','Adhoc','Trigger','Check','Rule','View')
	group by COALESCE(DB_NAME(st.dbid), DB_NAME(CAST(pa.value AS INT)) + '*', 'Resource'),OBJECT_SCHEMA_NAME(objectid,st.dbid), OBJECT_NAME(objectid,st.dbid),cp.objtype,substring(st.text, (qs.statement_start_offset/2)+1, ((case qs.statement_end_offset when -1 then datalength(st.text) else qs.statement_end_offset end - qs.statement_start_offset)/2) + 1)
	order by sum(qs.total_elapsed_time) desc
END;
GO
