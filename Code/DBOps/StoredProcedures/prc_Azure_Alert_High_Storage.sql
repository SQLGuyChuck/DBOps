USE DBOPS
GO
CREATE OR ALTER PROCEDURE [dbo].[prc_Azure_Alert_High_Storage] @percent_threshold int
AS
BEGIN
-- ======================================================================================
-- Author:		Michael Capobianco
-- Create date: 07/12/2019
-- Description:	Alerts DBA team on high Azure storage capacity
/*
 Run Example: exec DBOPS.[dbo].prc_Azure_Alert_High_Storage
*/
-- Change History:
-- Change Date	Change By	Sprint#	Ticket#		Short change description
-- 07/12/2019	MichaelC			CLOUD-1198 	Created
-- 07/15/2019	MichaelC			Cloud-1198	Added @percent_threshold parameter
-- ======================================================================================
DECLARE @storage_perc FLOAT
	,@msg nvarchar(MAX)
	,@subject_content VARCHAR(500) = @@SERVERNAME +' - Storage limit alert'

SELECT TOP 1 @storage_perc = LEFT((storage_space_used_mb / reserved_storage_mb)*100, 5)
FROM MASTER.sys.server_resource_stats ORDER BY start_time DESC

IF(@storage_perc >= @percent_threshold)
	BEGIN
		SET @msg = CONCAT('Storage is reaching high capacity on ', @@SERVERNAME, '
		Storage capacity: ', @storage_perc, '%
		Consider upgrading the instance or freeing space.');
		EXEC msdb.dbo.sp_notify_operator 
		@profile_name = N'alerts@YourDomainNameHere.com', 
		@name = N'PagerDuty', 
		@subject = @subject_content, 
		@body = @msg;

	END
ELSE
	IF(@storage_perc >= @percent_threshold)
	BEGIN
		SET @msg = CONCAT('Storage is reaching high capacity on ', @@SERVERNAME, '
		Storage capacity: ', @storage_perc, '%
		Consider upgrading the instance or freeing space.');
		EXEC msdb.dbo.sp_notify_operator 
		@profile_name = N'alerts@YourDomainNameHere.com', 
		@name = N'IT Ops', 
		@subject = @subject_content, 
		@body = @msg;

	END
END
GO
