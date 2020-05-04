USE [DBOPS]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_Job_StepFailureAlert]  
                @person_to_notify VARCHAR(1000) = 'alerts@YourDomainNameHere.com'  
AS  
BEGIN  
/******************************************************************************    
**  Name: prc_Job_StepFailureAlert    
**  Desc: This will get list of failed job steps for 24 hour period.
**      
**  Return values: Sends out an email with the resultset.    
**  exec dbops.dbo.prc_Job_StepFailureAlert  
                @person_to_notify = 'chuck.lathrope@YourDomainNameHere.com'  
*******************************************************************************    
**  Change History    
*******************************************************************************    
**  Date:		Author:			Description:    
**  8/14/2013	Chuck Lathrope	Created
**  8/26/2013	Chuck Lathrope	Concatenate job step details messages to see all info logged.
**  8/28/2013	Chuck Lathrope	Change time to varchar for readability.
**  8/30/2013	Chuck Lathrope	Bug fix for next run date being 0. Shows as 1900 in HTML table.
** 07/31/2019	Michael C		Changed sysjobhistory to sysjobhistoryall
*******************************************************************************/  
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @tableHTML  NVARCHAR(MAX)
		, @SubjectMsg varchar(50)

SELECT @SubjectMsg = cast(@@ServerName as varchar(100)) + ' has job step failures in past 24 hrs.'

SET @tableHTML =      
    N'<table border="1" cellpadding="0" cellspacing="0">' + '<tr>' + 
	'<th>Job Name</th>' +      
    '<th>Step</th>' + 
	'<th>Error Message</th>' + 
	'<th>Start Time</th>' + 
	'<th>Run Duration</th>' + 
	'<th>Next Run</th></tr>' +      
   CAST ( ( 			
			SELECT td = sj.name, '',
			td = 'Step ' + CAST (jh.step_id AS VARCHAR(2)) + ': ' + jh.step_name, '', 
			td = ca.MessageList, '',
			td = CAST(msdb.dbo.agent_datetime(run_date,run_time) AS VARCHAR(20)), '',
			td = LEFT(STUFF((STUFF((REPLICATE('0', 6 - LEN(run_duration)))+ CONVERT(VARCHAR(6),run_duration),3,0,':')),6,0,':'),8), '',
			td = CAST((CASE WHEN sjs.next_run_date = 0 THEN '' ELSE msdb.dbo.agent_datetime(sjs.next_run_date,sjs.next_run_time) END ) AS VARCHAR(20))
			FROM msdb.dbo.sysjobhistoryall jh
			JOIN msdb.dbo.sysjobs sj ON sj.job_id = jh.job_id
			LEFT JOIN msdb.dbo.sysjobschedules sjs ON sj.job_id = sjs.job_id 
			LEFT JOIN msdb.dbo.sysschedules ss ON sjs.schedule_id = ss.schedule_id 
			CROSS APPLY ( SELECT RTRIM((SELECT N'' + ISNULL(sjh.message,'')
						FROM msdb.dbo.sysjobhistoryall sjh 
						WHERE sjh.job_id = jh.job_id
						AND sjh.run_date = jh.run_date
						AND sjh.run_time = jh.run_time
						AND sjh.step_id = jh.step_id
						AND run_status IN (0,4) --Failed or informational, respectively (values of 4 have what we want to aggregate for SSIS output.)
						AND message NOT LIKE '%DTSER_SUCCESS%'
						AND message NOT LIKE 'Started: %'
						ORDER BY instance_id
						FOR	XML PATH('') , TYPE).value('.', 'varchar(max)'))
						) ca ( MessageList)
			WHERE 1=1
			AND DATEDIFF(hh, (msdb.dbo.agent_datetime(run_date,run_time)), GETDATE()) < 24
			AND jh.step_id <> 0 --Full job output, ignoring as we want step info.
			AND jh.run_status = 0 
			ORDER BY sj.name
			FOR XML PATH('tr'), TYPE       
			) AS NVARCHAR(MAX) )   
+ N'</table>' ;      

IF @tableHTML IS NOT NULL
EXEC prc_InternalSendMail         
        @Address = @person_to_notify,
        @Subject = @SubjectMsg,          
        @Body = @tableHTML,   
        @HTML  = 1  

END  
;
GO


