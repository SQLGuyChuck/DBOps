SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE dbo.prc_Perf_MissingIndexesFromPlanCache
    @lastExecuted_inDays    INT = 7
    , @minExecutionCount      INT = 7
    , @logResults             BIT = 0
    , @displayResults         BIT = 0
 
AS
BEGIN
/*********************************************************************************
    Name:       prc_Perf_MissingIndexesFromPlanCache
    Purpose:    Retrieves stored procedures with missing indexes in their
                cached query plans.
                @lastExecuted_inDays = number of days old the cached query plan
                                       can be to still appear in the results;
                                       the HIGHER the number, the longer the
                                       execution time.
                @minExecutionCount = minimum number of executions the cached
                                     query plan can have to still appear 
                                     in the results; the LOWER the number,
                                     the longer the execution time.
                @logResults = store results in MissingIndexesFromPlanCache
                @displayResults = return results to the caller
                
    Notes:      This is not 100% guaranteed to catch all missing indexes in
                a stored procedure.  It will only catch it if the stored proc's
                query plan is still in cache.  Run regularly to help minimize
                the chance of missing a proc.
 
    Date        User    Description
    ----------------------------------------------------------------------------
    2009-03-02  MFU     Initial Release for public consumption
    2010-08-22	CAL		Renamed from MissingIndexesFromPlanCache_sp. Killed transaction.
    2011-10-04  CAL		If tables had more than one missing index, insert into table table failed. 
    	Added execution_count to display only output.  
*********************************************************************************
    Exec dbo.prc_Perf_MissingIndexesFromPlanCache
          @lastExecuted_inDays  = 30
        , @minExecutionCount    = 5
        , @logResults           = 1
        , @displayResults       = 1;
*********************************************************************************/
SET NOCOUNT ON;
 
BEGIN

--Testing
--DECLARE  @lastExecuted_inDays    INT = 7
--, @minExecutionCount      INT = 7
--, @logResults             BIT = 0
--, @displayResults         BIT = 0
--End testing

    DECLARE @currentDateTime SMALLDATETIME = GETDATE();
 
    DECLARE @plan_handles TABLE
    (
        plan_handle     VARBINARY(64)   Not Null
          ,execution_count int       
    );
 
    CREATE TABLE #missingIndexes
    (
          databaseID    INT             Not Null
        , objectID      INT             Not Null
        , execution_count INT      
        , query_plan    xml             Not Null
    );
 
    /* Retrieve distinct plan handles to minimize dm_exec_query_plan lookups */
    INSERT INTO @plan_handles
    SELECT DISTINCT plan_handle, execution_count
    FROM sys.dm_exec_query_stats
    WHERE last_execution_time > DATEADD(DAY, -@lastExecuted_inDays, @currentDateTime)
        And execution_count > @minExecutionCount;

    WITH xmlNameSpaces (
        DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
    )

    /* Retrieve our query plan's XML if there's a missing index */
    INSERT INTO #missingIndexes
    SELECT deqp.[dbid]
        , deqp.objectid
        , ph.execution_count      
        , deqp.query_plan 
    FROM @plan_handles AS ph
    Cross Apply sys.dm_exec_query_plan(ph.plan_handle) AS deqp 
    WHERE deqp.query_plan.exist('//MissingIndex') = 1
        And deqp.objectid IS Not Null;

    /* Do we want to store the results of our process? */
    IF @logResults = 1
    BEGIN
        INSERT INTO dbo.MissingIndexesFromPlanCache (DatabaseName, DatabaseID, ObjectName, QueryPlan, DateCaptured)
        EXECUTE sp_msForEachDB 'Use [?]; 
                                Select ''?'' as DatabaseName
                                    , mi.DatabaseID
                                    , schema_name(o.schema_id) + ''.'' + Object_Name(o.object_id) as ObjectName
                                    , mi.query_plan as QueryPlan
                                    , GetDate() as DateCaptured
                                From sys.objects As o 
                                Join #missingIndexes As mi 
                                    On o.object_id = mi.objectID 
                                Where databaseID = DB_ID();';
    END
    /* We're not logging it, so let's display it */
    ELSE
    BEGIN
        EXECUTE sp_msForEachDB 'Use [?]; 
                                Select ''?'' as DatabaseName
                                    , mi.DatabaseID
                                    , schema_name(o.schema_id) + ''.'' + Object_Name(o.object_id) as ObjectName
                                    , mi.query_plan as QueryPlan
                                    , GetDate() as DateCapture
                                From sys.objects As o 
                                Join #missingIndexes As mi 
                                    On o.object_id = mi.objectID 
                                Where databaseID = DB_ID();';
    END;

    /* See above; this part will only work if we've logged our data. */
    IF @displayResults = 1 And @logResults = 1
    BEGIN
        SELECT *
        FROM dbo.MissingIndexesFromPlanCache
        WHERE DateCaptured >= @currentDateTime;
    END;

END;
GO
