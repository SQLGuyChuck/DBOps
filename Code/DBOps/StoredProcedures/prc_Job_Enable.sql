SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE dbo.prc_Job_Enable 
	@job_name SYSNAME,
	@Result INT = NULL OUTPUT --0 is success, all else is fail
WITH EXECUTE AS owner
AS
BEGIN
/******************************************************************************
**  Name: prc_Job_Enable
**	Desc: Start a job - for use by non-privileged users.
**
*******************************************************************************
**		Change History
*******************************************************************************
**	Date:		Author:			TFS:	Description:
**
*******************************************************************************/	
	SET NOCOUNT ON
	EXEC @Result = msdb.dbo.sp_update_job @job_name = @job_name,@enabled = 1
    
END
;
GO
