USE [DBOPS]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_Job_RunHistory]
    @MaxJobHistoryRows INT = 50,  
    @NameInclude VARCHAR(100)  = NULL,  
    @NameExclude VARCHAR(100)  = NULL,
    @DaysofHistory INT = 3 
AS  
BEGIN
/*********************************************************************************  
* Created: 12/15/2010 Chuck Lathrope  
* Purpose: Get job history of matching/non-matching job names with duration and run status.  
*  
* Example Use:  
* EXEC prc_Job_RunHistory @MaxJobHistoryRows=10, @NameInclude = '%OBje%'  
*
*******************************************************************************    
**  Change History    
*******************************************************************************    
**  Date:		Author:			Description:    
**  12/15/2010	Chuck Lathrope	Created
**  07/31/2019	Michael C		Changed sysjobhistory to sysjobhistoryall
*********************************************************************************/
	SET NOCOUNT ON
	               
	SELECT o.Name, o.job_id, o.RunDate, o.Duration, SUBSTRING(message,1,CHARINDEX('.',message,1)) AS Status, o.message
	 FROM
	(SELECT O.name AS [Name]  
	 ,O.job_id  
		, CAST(ISNULL(SUBSTRING(CONVERT(VARCHAR(8),T.run_date),1,4) + '-'  
		+        SUBSTRING(CONVERT(VARCHAR(8),T.run_date),5,2) + '-'  
		+        SUBSTRING(CONVERT(VARCHAR(8),T.run_date),7,2),'')  
		+' '+ ISNULL(SUBSTRING(CONVERT(VARCHAR(7),T.run_time+1000000),2,2) + ':'  
		+        SUBSTRING(CONVERT(VARCHAR(7),T.run_time+1000000),4,2) + ':'  
		+        SUBSTRING(CONVERT(VARCHAR(7),T.run_time+1000000),6,2),'') AS DATETIME)AS RunDate  
		, ISNULL(SUBSTRING(CONVERT(VARCHAR(7),T.run_duration+1000000),2,2) + ':'  
		+        SUBSTRING(CONVERT(VARCHAR(7),T.run_duration+1000000),4,2) + ':'  
		+        SUBSTRING(CONVERT(VARCHAR(7),T.run_duration+1000000),6,2),'') AS [Duration]  
		, ISNULL(T.run_status,'') AS [Status]  
		,T.message
		, ROW_NUMBER() OVER(PARTITION BY o.job_id ORDER BY o.Job_id)  AS row_num
	FROM msdb.dbo.sysjobs AS O  
		LEFT JOIN msdb.dbo.sysjobhistoryall AS T ON O.job_id = T.job_id  
	WHERE 1 =1
	 AND T.run_date IS NOT NULL
	 AND t.step_id = 0
	 --AND (@JobStatus = 0 OR CHARINDEX('succeeded',T.message,1) = 0)  
		AND (@NameInclude IS NULL OR O.name LIKE @NameInclude)  
		AND (@NameExclude IS NULL OR O.name NOT LIKE @NameExclude) 
		AND CAST(ISNULL(SUBSTRING(CONVERT(VARCHAR(8),T.run_date),1,4) + '-'  
		+        SUBSTRING(CONVERT(VARCHAR(8),T.run_date),5,2) + '-'  
		+        SUBSTRING(CONVERT(VARCHAR(8),T.run_date),7,2),'')  AS DATETIME) > GETDATE()-@DaysofHistory
	) O
	WHERE row_num <= @MaxJobHistoryRows
	ORDER BY name, o.RunDate DESC  

END;
GO


