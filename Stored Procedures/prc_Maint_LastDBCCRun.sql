SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--Pulled from internet 10/1/2012
CREATE OR ALTER PROCEDURE dbo.prc_Maint_LastDBCCRun AS
BEGIN   
   SET NOCOUNT ON;
   CREATE TABLE #temp (          
       ParentObject     VARCHAR(255)
       , [Object]       VARCHAR(255)
       , Field          VARCHAR(255)
       , [Value]        VARCHAR(255)   
   )   
   
   CREATE TABLE #DBCCResults (
        ServerName           VARCHAR(255)
        , DBName             VARCHAR(255)
        , LastCleanDBCCDate  DATETIME   
    )   
    
    EXEC master.dbo.SP_MSFOREACHDB       
           @Command1 = 'USE [?] INSERT INTO #temp EXECUTE (''DBCC DBINFO WITH TABLERESULTS'')'
           , @Command2 = 'INSERT INTO #DBCCResults SELECT @@SERVERNAME, ''?'', value FROM #temp WHERE field = ''dbi_dbccLastKnownGood'''
           , @Command3 = 'TRUNCATE TABLE #temp'   
   
   --Delete duplicates due to a bug in SQL Server 2008
   
  ;WITH DBCC_CTE AS
   (
       SELECT ROW_NUMBER() OVER (PARTITION BY ServerName, DBName, LastCleanDBCCDate ORDER BY LastCleanDBCCDate) RowID
       FROM #DBCCResults
   )
   DELETE FROM DBCC_CTE WHERE RowID > 1;
   
    SELECT        
           ServerName       
           , DBName       
           , CASE LastCleanDBCCDate 
                   WHEN '1900-01-01 00:00:00.000' THEN 'Never ran DBCC CHECKDB' 
                   ELSE CAST(LastCleanDBCCDate AS VARCHAR) END AS LastCleanDBCCDate    
   FROM #DBCCResults   
   
   DROP TABLE #temp, #DBCCResults;
END
;
GO
