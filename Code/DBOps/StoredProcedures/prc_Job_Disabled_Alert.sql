USE [DBOPS]
GO
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_Job_Disabled_Alert] 
@Exceptionlist varchar(4000) = null

AS
BEGIN
-- ======================================================================================
-- Author:		Michael Capobianco
-- Create date: 12/23/2019
-- Description:	Alerts DBA team when a 'DBA: %' Job is disabled. Exception list must be comma delited
/*
 Run Example: 
 exec DBOPS.[dbo].[prc_Job_Disabled_Alert] 
 @ExceptionList = 'DBA: Cycle Errorlog, DBA: Check Access Permissions'
*/
-- Change History:
-- Change Date	Change By	Ticket#		Short change description
-- 12/23/2019	MichaelC	19100 		Created
-- ======================================================================================

declare  
@msg varchar(max)
,@subject_content VARCHAR(255) = @@SERVERNAME +' - Job Disabled'

if exists
(
	select * from msdb.dbo.sysjobs 
	where name like 'DBA: %' 
	and enabled = 0
	and name not in 
	(
		select rtrim(ltrim(value)) 
		from STRING_SPLIT (@ExceptionList, ',')  
	)
)
BEGIN

	SET @msg = CONCAT('DBA job disabled on ', @@SERVERNAME, '
Re-enable the job or modify the  @ExceptionList parameter for this alterting job.');
	EXEC msdb.dbo.sp_notify_operator 
	@profile_name = N'alerts@YourDomainNameHere.com', 
	@name = N'IT Ops', 
	@subject = @subject_content, 
	@body = @msg;

END

END
GO
