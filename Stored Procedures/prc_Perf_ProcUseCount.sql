SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Perf_ProcUseCount 
AS
BEGIN
/******************************************************************************
**		Name: prc_Perf_ProcUseCount
**		Desc: Return values: Recordset of Execution Count since last reboot of all non-replication procs.
**
**		Auth: Chuck Lathrope
**		Date: 7/1/2010
*******************************************************************************
**		Change History
*******************************************************************************
**		Date:		Author:				Description:
**		
*******************************************************************************/
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT DB_NAME(st.dbid) DNS
      ,OBJECT_SCHEMA_NAME(st.objectid,dbid) SchemaName
      ,cp.objtype as ObjectType
      ,OBJECT_NAME(st.objectid,dbid) StoredProcedure
      ,max(cp.usecounts) Execution_count
FROM sys.dm_exec_cached_plans cp
        CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
WHERE DB_NAME(st.dbid) is not null 
	AND OBJECT_NAME(objectid,st.dbid) NOT LIKE 'sp_MS%'
GROUP BY cp.plan_handle, 
	DB_NAME(st.dbid),
	OBJECT_SCHEMA_NAME(objectid,st.dbid), 
	cp.objtype,
	OBJECT_NAME(objectid,st.dbid) 
ORDER BY max(cp.usecounts) desc

END --Proc creation.

;
GO
