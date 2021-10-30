SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/******************************************************************************  
**  File: /DBOPS/Functions/udf_SysJobs_GetProcessid.sql  
**  Desc: This will get name of the Job
**                
**  Parameters:  
**  @job_id
**  
--SELECT 
--	p.spid, 
--	j.name, 
--	p.program_name, 
--	replace(substring(p.program_name,67,7), ')', '') as Step,
--	isnull(DATEDIFF(mi, p.last_batch, getdate()), 0) [MinutesRunning], 
--	last_batch, 
--	enabled
--FROM master..sysprocesses p
--JOIN msdb..sysjobs j ON dbops.dbo.udf_sysjobs_getprocessid(j.job_id) = substring(p.program_name,32,8)
--WHERE program_name like 'SQLAgent - TSQL JobStep (Job %'
**
*******************************************************************************  
**  Change History  
*******************************************************************************  
**  Date:  Author:    Description:  
**      
*******************************************************************************/

CREATE FUNCTION dbo.udf_SysJobs_GetProcessid(@job_id uniqueidentifier)
RETURNS VARCHAR(8)
AS
BEGIN
RETURN (substring(left(@job_id,8),7,2) +
		substring(left(@job_id,8),5,2) +
		substring(left(@job_id,8),3,2) +
		substring(left(@job_id,8),1,2))
END
;
GO
