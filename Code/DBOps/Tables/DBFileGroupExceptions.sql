SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DBFileGroupExceptions]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DBFileGroupExceptions](
	[DBName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[FileGroupName] [varchar](150) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PercentFree] [decimal](5, 1) NULL,
	[ExceptionDate] [datetime] NOT NULL,
	[ExceptionReason] [varchar](500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
END
GO
SET ANSI_PADDING ON

GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DBFileGroupExceptions]') AND name = N'CIDX_DBFileGroupExceptions_DBName_FileGroupName')
CREATE UNIQUE CLUSTERED INDEX [CIDX_DBFileGroupExceptions_DBName_FileGroupName] ON [dbo].[DBFileGroupExceptions]
(
	[DBName] ASC,
	[FileGroupName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_DBFileGroupExceptions_FileGroupName]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DBFileGroupExceptions] ADD  CONSTRAINT [DF_DBFileGroupExceptions_FileGroupName]  DEFAULT ('Primary') FOR [FileGroupName]
END

GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_DBFileGroupExceptions_ExceptionDate]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DBFileGroupExceptions] ADD  CONSTRAINT [DF_DBFileGroupExceptions_ExceptionDate]  DEFAULT (getdate()) FOR [ExceptionDate]
END

GO
