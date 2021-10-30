SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Perf_ObjectUseCount (
@DBName sysname,
@ObjectName varchar(100) 
)
--Can be either proc, view, or trigger.
--Looks at plan cache, so if not there, then this can't be used.
--WITH EXECUTE AS OWNER --If you want to grant non sysadmin user to see results.
AS
BEGIN
	SELECT sum(cast(cp.usecounts as bigint)) Execution_count
	FROM sys.dm_exec_cached_plans cp
		 CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
	WHERE DB_NAME(st.dbid) = @DBName
	AND st.objectid = object_id(@ObjectName)
	GROUP BY OBJECT_NAME(objectid,st.dbid)

--	IF @@Rowcount = 0 --Will be true for those that don't have permission.
--	Select 'Object is not in SQL Plan Cache. You will have to use profiler.'
END;
GO
