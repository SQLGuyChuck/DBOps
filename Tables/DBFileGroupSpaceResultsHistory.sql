SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DBFileGroupSpaceResultsHistory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DBFileGroupSpaceResultsHistory](
	[HistoryID] [int] IDENTITY(1,1) NOT NULL,
	[DateCaptured] [datetime2(4)] NOT NULL,
	[DBName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[FileGroupName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[FGSizeDesc] [char](3) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[FGSizeMB] [int] NULL,
	[FGFreeSpaceMB] [int] NULL,
	[FileType] [varchar](15) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[FGGrowthMB] [int] NULL,
	[FGFileCount] [smallint] NULL,
	[FGReadOnly] [bit] NULL,
	[PercentFree] [decimal](5, 1) NULL,
	[WarningLevel] [tinyint] NULL,
PRIMARY KEY CLUSTERED 
(
	[HistoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_DateCaptured_Getdate]') AND type = 'D')
BEGIN
	ALTER TABLE [dbo].[DBFileGroupSpaceResultsHistory] ADD  CONSTRAINT [DF_DateCaptured_Getdate]  DEFAULT (SYSDATETIME()) FOR [DateCaptured]
END

GO
