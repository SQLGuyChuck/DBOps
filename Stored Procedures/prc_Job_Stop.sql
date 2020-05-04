SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE dbo.prc_Job_Stop 
	@job_name SYSNAME,
	@Result INT = NULL OUTPUT --0 is success, all else is fail
WITH EXECUTE AS owner
AS
BEGIN
/******************************************************************************
**	Name: prc_Job_Stop
**	Desc: wrapper for msdb.dbo.sp_Stop_job, throws error for some failure types like bad job name
**	Usage:

	DECLARE @Result INT
	EXEC dbo.prc_Job_Stop 
		@job_name = 'Some Job Name',
		@Result = @Result OUTPUT
	SELECT @Result 'Result'

*******************************************************************************
**		Change History
*******************************************************************************
**	Date:		Author:			Description:
**
*******************************************************************************/
	EXEC @Result = msdb.dbo.sp_Stop_job @job_name = @job_name	
END
;
GO
