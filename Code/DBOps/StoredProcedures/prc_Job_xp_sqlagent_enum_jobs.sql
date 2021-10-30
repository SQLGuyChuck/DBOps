SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Job_xp_sqlagent_enum_jobs
	@showName bit = 0
AS
BEGIN
	IF (@showName = 0)
		EXEC  master.dbo.xp_sqlagent_enum_jobs 1,''
	ELSE
	BEGIN
		declare @temp table
		(
			  [Job ID]	varbinary(256)
			, [Last Run Date]	int
			, [Last Run Time]	int
			, [Next Run Date]	int
			, [Next Run Time]	int
			, [Next Run Schedule ID]	int
			, [Requested To Run]	int 
			, [Request Source]	varchar(256) null
			, [Request Source ID]	varchar(256) null
			, [Running]	int
			, [Current Step]	int
			, [Current Retry Attempt]	int
			, [State]	int
		)

		insert @temp
			EXEC  master.dbo.xp_sqlagent_enum_jobs 1,''

		select 
			cast([Job ID] as uniqueidentifier) as [Job ID]
			,b.name
			, [Last Run Date]	
			, [Last Run Time]	
			, [Next Run Date]	
			, [Next Run Time]	
			, [Next Run Schedule ID]	
			, [Requested To Run]	
			, [Request Source]	
			, [Request Source ID]	
			, [Running]	
			, [Current Step]	
			, [Current Retry Attempt]	
			, [State]
		FROM @temp a 
			join msdb.dbo.sysjobs b on a.[job id] = b.job_id
	END
END;
;
GO
