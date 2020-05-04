SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Perf_Top_Longest_Running_Query_Fragment
	@ROWCOUNT SMALLINT = 50
AS
BEGIN
/******************************************************************************  
**  Name: prc_Perf_Top_Longest_Running_Query_Fragment.sql  
**  Desc: This will get list of TOP (@Rowcount) longest running query fragment either from
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
		, substring(st.text, (qs.statement_start_offset/2)+1, ((case qs.statement_end_offset when -1 then datalength(st.text) else qs.statement_end_offset end - qs.statement_start_offset)/2) + 1) as statement_text
		, qs.execution_count 
		, qs.max_elapsed_time		 
		, qs.total_elapsed_time
		, qs.total_elapsed_time / qs.execution_count as avg_elapsed_time
		, qs.last_elapsed_time
	from sys.dm_exec_query_stats as qs
	left join sys.dm_exec_cached_plans cp on qs.plan_handle = cp.plan_handle
	cross apply sys.dm_exec_sql_text(qs.sql_handle) as st
	OUTER APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa 
    WHERE pa.attribute = 'dbid'
	AND ISNULL(OBJECT_SCHEMA_NAME(objectid,st.dbid),'') <> 'sys'
	AND cp.objtype in ('proc','Prepared','Adhoc','Trigger','Check','Rule','View')
	order by max_elapsed_time desc

END;
GO
