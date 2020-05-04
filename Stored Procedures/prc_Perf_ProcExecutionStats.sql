SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Perf_ProcExecutionStats
AS
BEGIN
/******************************************************************************
**  Name: prc_Perf_ProcExecutionStats
**  Desc: Gather all distinct plans in cache that have been executed in past 30 days,
**		  log only proc's that get executed and aggregate useful stats. If missing index
**		  info is available, get that also. Log to table ProcExecutionStats.
**	No results returned.
**
*******************************************************************************
**  Change History
*******************************************************************************
**  Date:		Author:			Description:
**  1/24/2013	Chuck Lathrope	Created
*******************************************************************************/
	SET NOCOUNT ON
	
	DECLARE	@currentDateTime SMALLDATETIME; 
	SET @currentDateTime = GETDATE(); 

	IF (OBJECT_ID('tempdb..#projectedImpact') IS NOT NULL)
		DROP TABLE #projectedImpact

	IF OBJECT_ID('tempdb..#missingIndexes') > 0
		DROP TABLE #missingIndexes

	DECLARE	@plan_handles TABLE (
			plan_handle VARBINARY(64) NOT NULL
		); 

	CREATE TABLE #missingIndexes (
			databaseID INT NOT NULL,
			objectID INT NULL,
			query_plan XML NOT NULL
		); 

	/* Retrieve distinct plan handles to minimize dm_exec_query_plan lookups */ 

	INSERT	INTO @plan_handles
	SELECT DISTINCT
			plan_handle --select *
	FROM	sys.dm_exec_query_stats
	WHERE	last_execution_time > DATEADD(DAY, -30, @currentDateTime)
			AND execution_count > 20; 
	WITH XMLNAMESPACES ( DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan' 
	)

	/* Retrieve our query plan's XML if there's a missing index */ 
	INSERT	INTO #missingIndexes
	SELECT	deqp.[dbid],
			deqp.objectid,
			deqp.query_plan
	FROM	@plan_handles AS ph
	CROSS APPLY sys.dm_exec_query_plan(ph.plan_handle) AS deqp
	WHERE	deqp.query_plan.exist('//MissingIndex') = 1
			AND dbid IS NOT NULL;

	WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	SELECT DISTINCT
			DB_NAME(databaseID) AS dbname,
			OBJECT_NAME(objectID, databaseID) AS spname,
			p.query_plan.value(N'(sp:ShowPlanXML/sp:BatchSequence/sp:Batch/sp:Statements/sp:StmtSimple/sp:QueryPlan/sp:MissingIndexes/sp:MissingIndexGroup/sp:MissingIndex/@Table)[1]',
								'NVARCHAR(256)') AS TableName,
			p.query_plan.value(N'(/sp:ShowPlanXML/sp:BatchSequence/sp:Batch/sp:Statements/sp:StmtSimple/sp:QueryPlan/sp:MissingIndexes/sp:MissingIndexGroup/@Impact)[1]',
								'DECIMAL(6,4)') AS ProjectedImpact
	--,ColumnGroup.value('./@Usage', 'NVARCHAR(256)') AS ColumnGroupUsage
	--,ColumnGroupColumn.value('./@Name', 'NVARCHAR(256)') AS ColumnName
	INTO	#projectedImpact
	FROM	#missingIndexes p
	--CROSS APPLY p.query_plan.nodes('/sp:ShowPlanXML/sp:BatchSequence/sp:Batch/sp:Statements/sp:StmtSimple/sp:QueryPlan/sp:MissingIndexes/sp:MissingIndexGroup/sp:MissingIndex/sp:ColumnGroup')
	--AS t1 (ColumnGroup)
	--CROSS APPLY t1.ColumnGroup.nodes('./sp:Column') AS t2 (ColumnGroupColumn)
	WHERE	p.query_plan.exist(N'/sp:ShowPlanXML/sp:BatchSequence/sp:Batch/sp:Statements/sp:StmtSimple/sp:QueryPlan//sp:MissingIndexes') = 1

	INSERT	INTO dbo.ProcExecutionStats
			(DBName,
				SchemaName,
				StoredProcedure,
				TableName,
				execution_count,
				total_cpu_time,
				total_IO,
				total_physical_reads,
				total_logical_reads,
				total_logical_writes,
				total_elapsed_time,
				avg_cpu_time,
				avg_total_IO,
				avg_physical_read,
				avg_logical_read,
				avg_logical_writes,
				avg_elapsed_time,
				ProjectedImpact,
				MissingIndexFlag
			)
	SELECT	DB_NAME(st.dbid) DBName,
			OBJECT_SCHEMA_NAME(objectid, st.dbid) SchemaName,
			OBJECT_NAME(objectid, st.dbid) StoredProcedure,
			p.TableName AS TableName,
			MAX(cp.usecounts) execution_count,
			SUM(qs.total_worker_time) total_cpu_time,
			SUM(qs.total_physical_reads + qs.total_logical_reads
				+ qs.total_logical_writes) total_IO,
			SUM(qs.total_physical_reads) total_physical_reads,
			SUM(qs.total_logical_reads) total_logical_reads,
			SUM(qs.total_logical_writes) total_logical_writes,
			SUM(qs.total_elapsed_time) total_elapsed_time,
			SUM(qs.total_worker_time) / (MAX(cp.usecounts) * 1.0) avg_cpu_time,
			SUM(qs.total_physical_reads + qs.total_logical_reads
				+ qs.total_logical_writes) / (MAX(cp.usecounts)) avg_total_IO,
			SUM(qs.total_physical_reads) / (MAX(cp.usecounts) * 1.0) avg_physical_read,
			SUM(qs.total_logical_reads) / (MAX(cp.usecounts) * 1.0) avg_logical_read,
			SUM(qs.total_logical_writes) / (MAX(cp.usecounts) * 1.0) avg_logical_writes,
			SUM(qs.total_elapsed_time) / MAX(cp.usecounts) avg_elapsed_time,
			p.ProjectedImpact,
			CASE WHEN p.TableName IS NULL THEN 0
					ELSE 1
			END AS MissingIndexFlag
	FROM	sys.dm_exec_query_stats qs
	CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
	JOIN	sys.dm_exec_cached_plans cp ON qs.plan_handle = cp.plan_handle
	LEFT JOIN #projectedImpact p ON p.spname = OBJECT_NAME(objectid, st.dbid)
	WHERE	DB_NAME(st.dbid) IS NOT NULL
			AND cp.objtype = 'proc'
	GROUP BY DB_NAME(st.dbid),
			OBJECT_SCHEMA_NAME(objectid, st.dbid),
			OBJECT_NAME(objectid, st.dbid),
			p.TableName,
			p.ProjectedImpact
	ORDER BY SUM(qs.total_physical_reads + qs.total_logical_reads + qs.total_logical_writes) DESC

END

;
GO
