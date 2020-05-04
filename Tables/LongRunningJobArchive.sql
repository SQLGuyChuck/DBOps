SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LongRunningJobArchive]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[LongRunningJobArchive](
	[JobName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[JobStepID] [tinyint] NULL,
	[JobStartTime] [datetime] NULL,
	[Hours] [int] NULL,
	[Minutes] [int] NULL,
	[Status] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
END
GO
SET ANSI_PADDING ON

GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[LongRunningJobArchive]') AND name = N'ci_LongRunningJobArchive_JobName_JobStepID_JobStartTime')
CREATE UNIQUE NONCLUSTERED INDEX [ci_LongRunningJobArchive_JobName_JobStepID_JobStartTime] ON [dbo].[LongRunningJobArchive]
(
	[JobName] ASC,
	[JobStepID] ASC,
	[JobStartTime] ASC,
	[Hours] ASC,
	[Minutes] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
