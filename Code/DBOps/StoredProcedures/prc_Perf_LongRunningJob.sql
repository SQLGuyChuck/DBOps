SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER   PROCEDURE [dbo].[prc_Perf_LongRunningJob]  
                @MaxMinutes int = 60,  
                @person_to_notify varchar(1000) = 'alerts@YourDomainNameHere.com'  
AS  
BEGIN  

/******************************************************************************    
**  Name: prc_Perf_LongRunningJob    
**  Desc: This will get list of jobs running for more than @MaxMinutes minutes 
**		and exclude those listed in LongRunningJobIgnoreList table.
**      
**  Return values: Sends out an email with the resultset.    
**  exec prc_Perf_LongRunningJob  @MaxMinutes = 60,  
                @person_to_notify = 'ITOPS@YourDomainNameHere.com'  
*******************************************************************************    
**  Change History    
*******************************************************************************    
**  Date:		Author:			Description:    
**  11/27/2010	Chuck Lathrope	Utilized new column LongRunningJobIgnoreList.MinutesToIgnore
**  08/15/2013	Chuck Lathrope  Added (ja.run_requested_date + 2) > msdb.dbo.agent_datetime(xp.last_run_date,xp.last_run_time)
**									For job entries where server failed while job was running.
**  10/22/2018        Michael C Updated to use Instance Description process prameter in subject line
*******************************************************************************/  
SET NOCOUNT ON

DECLARE @tableHTML  NVARCHAR(MAX)
		, @subjectMsg varchar(50)
		, @rowcount smallint 
    ,@InstanceDescription varchar(200)
  
if object_id('tempdb..#tempjobs') <> 0  
 drop table #tempjobs  
  
Create table #tempjobs (  
JobName sysname,  
JobStep varchar(20),  
LastBatch datetime,  
MinutesRunning int,  
enabled tinyint)  
  
if object_id('tempdb..#xp_results') <> 0  
 drop table #xp_results  
  
CREATE TABLE #xp_results     
(    
  job_id uniqueidentifier NOT NULL,    
  last_run_date int NOT NULL,    
  last_run_time int NOT NULL,    
  next_run_date int NOT NULL,    
  next_run_time int NOT NULL,    
  next_run_schedule_id int NOT NULL,    
  requested_to_run int NOT NULL, -- BOOL    
  request_source int NOT NULL,    
  request_source_id sysname COLLATE database_default NULL,    
  running int NOT NULL, -- BOOL    
  current_step int NOT NULL,    
  current_retry_attempt int NOT NULL,    
  job_state int NOT NULL    
)    
    
INSERT INTO #xp_results    
EXEC master.dbo.xp_sqlagent_enum_jobs 1, ''    
  
Insert into #tempjobs (  
	JobName,  
	JobStep,  
	LastBatch,  
	MinutesRunning,  
	enabled)  
SELECT j.name as Jobname, current_step as JobStep, ja.run_requested_date as LastBatch, 
	isnull(DATEDIFF(mi, ja.run_requested_date, getdate()), 0) as MinutesRunning, j.enabled  
FROM #xp_results xp  
JOIN msdb..sysjobs j on j.job_id = xp.job_id  
	AND (j.name not like 'Backup%' 
	and j.name not like 'qcm%' --Quest Capacity Manager
	and j.name not like '%restore%')  
JOIN msdb..sysjobactivity ja on j.job_id = ja.job_id  
JOIN msdb..syscategories sc ON sc.category_id = j.category_id  
	AND sc.name not like 'REPL-%' --Ignore replication as these are typically continuous
where xp.job_state = 1
AND ja.stop_execution_date IS NULL
AND ja.start_execution_date IS NOT NULL
--For cases where entries exist in ja that are orphaned from server restart, give 2 day factor of safety:
AND (ja.run_requested_date + 2) > msdb.dbo.agent_datetime(xp.last_run_date,xp.last_run_time) 
AND isnull(DATEDIFF(mi, ja.run_requested_date, getdate()), 0) > @MaxMinutes  

--Remove exceptions after the fact to prevent long running query above.
delete t  
from #tempjobs t   
join dbops.dbo.LongRunningJobIgnoreList list on t.JobName like list.jobname + '%'-- Lookup table has to be populated according to server names  
where MinutesToIgnore = -1 OR MinutesRunning <= MinutesToIgnore

select @rowcount = count(*) from #tempjobs 
  
If @rowcount = 0   
	Goto NoRows  
  
select @InstanceDescription = dbops.dbo.udf_GetProcessParameter ('Admin','Instance Description')

select @subjectMsg = @InstanceDescription + ' has jobs running more than ' + convert(varchar(25),@MaxMinutes) + ' minutes.'
 
SET @tableHTML =      
    N'<table border="1" cellpadding="0" cellspacing="0">' +      
    '<tr>' + '<th>Job Name</th>' +      
    '<th>Step</th>' + '<th>Minutes Running</th>' + '<th>Last Batch</th></tr>' +      
   CAST ( ( select td = td.JobName, '',      
                   td = td.JobStep, '',      
                   td = td.MinutesRunning, '',      
                   td = LastBatch      
			  from #tempjobs td      
			  order by td.JobName asc      
			FOR XML PATH('tr'), TYPE       
			) AS NVARCHAR(MAX) )   
+ N'</table>' ;      

EXEC prc_InternalSendMail         
        @Address = @person_to_notify,
        @Subject = @subjectMsg,          
        @Body = @tableHTML,   
        @HTML  = 1  

NoRows:  
Drop table #tempjobs  
  
END;
GO
