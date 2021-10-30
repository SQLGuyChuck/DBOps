SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LongRunningJobIgnoreList]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[LongRunningJobIgnoreList](
	[JobName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[StepName] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MinutesToIgnore] [smallint] NULL,
	[DateAdded] [datetime] NULL
) ON [PRIMARY]
END
GO
SET ANSI_PADDING ON

GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[LongRunningJobIgnoreList]') AND name = N'ci_LongRunningJobIgnoreList_JobName_StepName')
CREATE UNIQUE CLUSTERED INDEX [ci_LongRunningJobIgnoreList_JobName_StepName] ON [dbo].[LongRunningJobIgnoreList]
(
	[JobName] ASC,
	[StepName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__LongRunni__Minut__3D5E1FD2]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[LongRunningJobIgnoreList] ADD  DEFAULT ((-1)) FOR [MinutesToIgnore]
END

GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__LongRunni__DateA__3E52440B]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[LongRunningJobIgnoreList] ADD  DEFAULT (getdate()) FOR [DateAdded]
END

GO
