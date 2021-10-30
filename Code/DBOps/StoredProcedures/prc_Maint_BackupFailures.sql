SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Maint_BackupFailures
as  
BEGIN

SET NOCOUNT ON
SELECT   j.job_id ,  
  getdate() as CaptureDate,  
  substring(h.server,1,30) ServerInstanceName,substring(j.[name] ,1,28) Jobname,message  
FROM     msdb.dbo.sysjobhistory h   
         INNER JOIN msdb.dbo.sysjobs j   
           ON h.job_id = j.job_id   
         INNER JOIN msdb.dbo.sysjobsteps s   
           ON j.job_id = s.job_id  
           AND h.step_id = s.step_id  
WHERE    h.run_status = 0 -- Failure   
  and j.name like'%backup%'  
         AND h.run_date >REPLACE(CONVERT(varchar(10),GETDATE(),20), '-', '' )-1  
ORDER BY h.instance_id DESC  

END
;
GO
