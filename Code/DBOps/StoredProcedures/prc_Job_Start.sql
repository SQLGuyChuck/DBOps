SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Job_Start 
                @job_name SYSNAME,
                @Result INT = NULL OUTPUT --0 is success, all else is fail
WITH EXECUTE AS owner
AS
BEGIN
           
/******************************************************************************
**
**  Name: prc_Job_Start
**  Desc: wrapper for msdb.dbo.sp_start_job, throws error for some failure types like bad job name
**
*******************************************************************************
**	Change History
*******************************************************************************
**  Date:              Author:     Description:
**
*******************************************************************************/     
	EXEC @Result = msdb.dbo.sp_start_job @job_name = @job_name       
 
END
;
GO
