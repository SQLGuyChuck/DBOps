SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SQLJob_Stopped_Log]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SQLJob_Stopped_Log](
	[SrNo] [int] IDENTITY(1,1) NOT NULL,
	[job_id] [uniqueidentifier] NOT NULL,
	[job_name] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[start_execution_date] [datetime] NOT NULL,
	[current_executed_step_id] [int] NOT NULL,
	[step_name] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Stopped_DateTime] [datetime] NOT NULL
) ON [PRIMARY]
END
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SQLJob_Stopped_Log_Stopped_DateTime]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SQLJob_Stopped_Log] ADD  CONSTRAINT [DF_SQLJob_Stopped_Log_Stopped_DateTime]  DEFAULT (getdate()) FOR [Stopped_DateTime]
END

GO
