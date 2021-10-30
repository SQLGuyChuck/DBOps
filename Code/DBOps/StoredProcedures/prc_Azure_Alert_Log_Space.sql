USE [DBOPS]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET NOCOUNT ON
GO


CREATE OR ALTER   PROCEDURE [dbo].[prc_Azure_Alert_Log_Space]
@threshold_medium float = 80.0
,@threshold_high float = 95.0
AS
BEGIN

-- ======================================================================================
-- Author:		Michael Capobianco
-- Create date: 10/07/2019
-- Description:	Alerts DBA team of low log free space. We can make this smarter by specifying which database in the future.
/*
 Run Example: exec [dbo].[prc_Azure_Alert_Log_Space] @threshold_medium = 80.0, @threshold_high = 95.0
*/
-- Change History:
-- Change Date	Change By	Short change description
-- 10/07/2019	MichaelC	Created
-- 10/09/2019	MichaelC	Modified with DBCC SQLPERF
-- ======================================================================================

DECLARE @msg nvarchar(MAX)
	,@subject_content VARCHAR(500) = 'Prod Well-Being Instance - Log file space warning'

IF OBJECT_ID('tempdb..#logspace') IS NOT NULL DROP TABLE #logspace;   

CREATE TABLE #logspace
( [dbname] sysname
, logSizeMB float
, logSpaceUsedPct float
, Status int);

INSERT INTO #logspace
EXEC ('DBCC SQLPERF(LOGSPACE);')

IF EXISTS(
	select 1 from #logspace
	where logSpaceUsedPct > @threshold_high
	and dbname in ('YourDomainNameHere', 'master', 'msdb') --Only critical databases for Pager Duty
)
	begin
		SET @msg = '[CRITICAL] Database log file space is running out for a critical database on Prod Well-Being Instance'

		EXEC msdb.dbo.sp_notify_operator 
		@profile_name = N'alerts@YourDomainNameHere.com', 
		@name = N'PagerDuty', 
		@subject = @subject_content, 
		@body = @msg;
	end

IF EXISTS(
select 1 from #logspace
where dbname not in ('tempdb')
and logSpaceUsedPct > @threshold_medium
)
	begin
		SET @msg = 'Database log file space is running out for a database on Prod Well-Being Instance'

		EXEC msdb.dbo.sp_notify_operator 
		@profile_name = N'alerts@YourDomainNameHere.com', 
		@name = N'IT Ops', 
		@subject = @subject_content, 
		@body = @msg;
	end

end

GO


