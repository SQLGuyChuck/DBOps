SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE dbo.prc_Job_Disable 
	@job_name SYSNAME,
	@Result INT = NULL OUTPUT --0 is success, all else is fail
WITH EXECUTE AS owner
AS
BEGIN
/******************************************************************************
**  Name: prc_Job_Disable
**	Desc: Disable job for non-privileged users.
**              
*******************************************************************************
**	Change History
*******************************************************************************
**	Date:		Author:			TFS:	Description:
**
*******************************************************************************/
	SET NOCOUNT ON
	EXEC @Result = msdb.dbo.sp_update_job @job_name = @job_name,@enabled = 0
    
END
;
GO
