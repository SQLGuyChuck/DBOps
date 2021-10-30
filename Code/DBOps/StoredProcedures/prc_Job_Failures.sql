CREATE OR ALTER PROCEDURE dbo.prc_Job_Failures
AS
BEGIN
SET NOCOUNT ON
SELECT   j.job_id ,  
  CAST(STR(h.run_date, 8, 0) AS DATETIME) + CAST(STUFF(STUFF(STR(h.run_time, 6, 0), 3, 0, ':'), 6, 0, ':') AS DATETIME) AS  RunDate,  
  @@ServerName ServerInstanceName  
  ,j.[name]  AS Jobname  
  ,LEFT(message, 500) Message  
    
FROM     msdb.dbo.sysjobhistory h   
         INNER JOIN msdb.dbo.sysjobs j   
           ON h.job_id = j.job_id   
         INNER JOIN msdb.dbo.sysjobsteps s   
           ON j.job_id = s.job_id  
           AND h.step_id = s.step_id  
WHERE    h.run_status = 0 -- Failure   
   AND h.run_date >REPLACE(CONVERT(VARCHAR(10),GETDATE()-1,20), '-', '' )  
END
