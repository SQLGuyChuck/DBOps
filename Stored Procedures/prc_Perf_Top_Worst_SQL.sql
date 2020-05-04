SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Perf_Top_Worst_SQL
  @DBNAME VARCHAR(128) = '<not supplied>'  
      ,@ROWCOUNT SMALLINT = 50  
      ,@ORDERBY VARCHAR(4) = 'AIO'
AS  
BEGIN

/******************************************************************************    
**  Name: prc_Perf_Top_Worst_SQL    
**  
--Name: usp_Worst_TSQL  
--Description: This stored procedure displays the top worst performing queries based on CPU, Execution Count,   
--             I/O and Elapsed_Time as identified using DMV information.  This can be display the worst   
--             performing queries from an instance, or database perspective.   The number of records shown,  
--             the database, and the sort order are identified by passing pararmeters.  
  
--Parameters:  There are three different parameters that can be passed to this procedures: @DBNAME, @ROWCOUNT  
--             and @ORDERBY.  The @DBNAME is used to constraint the output to a specific database.  If    
--             when calling this SP this parameter is set to a specific database name then only statements   
--             that are associated with that database will be displayed.  If the @DBNAME parameter is not set  
--             then this SP will return rows associated with any database.  The @ROWCOUNT parameter allows you   
--             to control the number of rows returned by this SP.  If this parameter is used then only the   
--             TOP x rows, where x is equal to @ROWCOUNT will be returned, based on the @ORDERBY parameter.  
--             The @ORDERBY parameter identifies the sort order of the rows returned in descending order.    
--             This @ORDERBY parameters supports the following type: CPU, AE, TE, EC or AIO, TIO, ALR, TLR, ALW, TLW, APR, and TPR   
--             where "ACPU" represents Average CPU Usage  
--                   "TCPU" represents Total CPU usage   
--                   "AE"   represents Average Elapsed Time  
--                   "TE"   represents Total Elapsed Time  
--                   "EC"   represents Execution Count  
--                   "AIO"  represents Average IOs  
--                   "TIO"  represents Total IOs   
--                   "ALR"  represents Average Logical Reads  
--                   "TLR"  represents Total Logical Reads                
--                   "ALW"  represents Average Logical Writes  
--                   "TLW"  represents Total Logical Writes  
--                   "APR"  represents Average Physical Reads  
--                   "TPR"  represents Total Physical Read  
  
--Typical execution calls  
     
--   Top 6 statements in the AdventureWorks database base on Average CPU Usage:  
--      EXEC usp_Worst_TSQL @DBNAME='AdventureWorks',@ROWCOUNT=6,@ORDERBY='ACPU';  
     
--   Top 100 statements order by Average IO   
--      EXEC usp_Worst_TSQL @ROWCOUNT=100,@ORDERBY='ALR';   
  
--   Show top all statements by Average IO   
--      EXEC usp_Worst_TSQL;  
  
*******************************************************************************    
**  Change History    
*******************************************************************************    
**  Date:  Author:   Description:    
**  03/23/2009  Ganesh   Created    
**  09/05/2012  Matias Sincovich   Space removed from names
*******************************************************************************/  
-- Check for valid @ORDERBY parameter  
IF ((SELECT CASE WHEN   
          @ORDERBY in ('ACPU','TCPU','AE','TE','EC','AIO','TIO','ALR','TLR','ALW','TLW','APR','TPR')   
             THEN 1 ELSE 0 END) = 0)  
BEGIN   
   -- abort if invalid @ORDERBY parameter entered  
   RAISERROR('@ORDERBY parameter not APCU, TCPU, AE, TE, EC, AIO, TIO, ALR, TLR, ALW, TLW, APR or TPR',11,1)  
   RETURN  
 END  
 SELECT TOP (@ROWCOUNT)   
         COALESCE(DB_NAME(st.dbid),   
                  DB_NAME(CAST(pa.value AS INT))+'*',   
                 'Resource') AS [DatabaseName]    
         -- find the offset of the actual statement being executed  
         ,SUBSTRING(text,   
                   CASE WHEN statement_start_offset = 0   
							OR statement_start_offset IS NULL    
                           THEN 1    
                           ELSE statement_start_offset/2 + 1 END,   
                   CASE WHEN statement_end_offset = 0   
                          OR statement_end_offset = -1    
                          OR statement_end_offset IS NULL    
                           THEN LEN(text)    
                           ELSE statement_end_offset/2 END -   
                     CASE WHEN statement_start_offset = 0   
                            OR statement_start_offset IS NULL   
                             THEN 1    
                             ELSE statement_start_offset/2  END + 1   
                  )  AS [Statement]    
         ,OBJECT_SCHEMA_NAME(st.objectid,dbid) [SchemaName]   
         ,OBJECT_NAME(st.objectid,dbid) [ObjectName]     
         ,objtype [CachedPlanobjtype]   
         ,execution_count [ExecutionCount]    
         ,(total_logical_reads + total_logical_writes + total_physical_reads )/execution_count [AverageIOs]   
         ,total_logical_reads + total_logical_writes + total_physical_reads [TotalIOs]    
         ,total_logical_reads/execution_count [AvgLogicalReads]   
         ,total_logical_reads [TotalLogicalReads]    
         ,total_logical_writes/execution_count [AvgLogicalWrites]    
         ,total_logical_writes [TotalLogicalWrites]    
         ,total_physical_reads/execution_count [AvgPhysicalReads]   
         ,total_physical_reads [TotalPhysicalReads]     
         ,total_worker_time / execution_count [AvgCPU]   
         ,total_worker_time [TotalCPU]   
         ,total_elapsed_time / execution_count [AvgElapsedTime]   
         ,total_elapsed_time  [TotalElaspedTime]   
         ,last_execution_time [LastExecutionTime]    
    FROM sys.dm_exec_query_stats qs    
    JOIN sys.dm_exec_cached_plans cp ON qs.plan_handle = cp.plan_handle   
    CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st   
    OUTER APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa   
    WHERE attribute = 'dbid' AND    
     CASE when @DBNAME = '<not supplied>' THEN '<not supplied>'  
                               ELSE COALESCE(DB_NAME(st.dbid),   
                                          DB_NAME(CAST(pa.value AS INT)) + '*',   
                                          'Resource') END  
                                    IN (RTRIM(@DBNAME),RTRIM(@DBNAME) + '*')    
        
    ORDER BY CASE   
                WHEN @ORDERBY = 'ACPU' THEN total_worker_time / execution_count   
                WHEN @ORDERBY = 'TCPU'  THEN total_worker_time  
                WHEN @ORDERBY = 'AE'   THEN total_elapsed_time / execution_count  
                WHEN @ORDERBY = 'TE'   THEN total_elapsed_time    
                WHEN @ORDERBY = 'EC'   THEN execution_count  
                WHEN @ORDERBY = 'AIO'  THEN (total_logical_reads + total_logical_writes + total_physical_reads) / execution_count    
                WHEN @ORDERBY = 'TIO'  THEN total_logical_reads + total_logical_writes + total_physical_reads  
                WHEN @ORDERBY = 'ALR'  THEN total_logical_reads  / execution_count  
                WHEN @ORDERBY = 'TLR'  THEN total_logical_reads   
                WHEN @ORDERBY = 'ALW'  THEN total_logical_writes / execution_count  
                WHEN @ORDERBY = 'TLW'  THEN total_logical_writes    
                WHEN @ORDERBY = 'APR'  THEN total_physical_reads / execution_count   
                WHEN @ORDERBY = 'TPR'  THEN total_physical_reads  
           END DESC  
END;
;
GO
