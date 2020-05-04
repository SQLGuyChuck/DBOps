SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[StatisticsHistory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[StatisticsHistory](
	[HistoryID] [bigint] IDENTITY(1,1) NOT NULL,
	[DBID] [smallint] NULL,
	[ObjectID] [int] NULL,
	[ObjectName] [nvarchar](774) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[StatsName] [nvarchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[last_updated] [datetime2](7) NULL,
	[rows] [bigint] NULL,
	[rows_sampled] [bigint] NULL,
	[unfiltered_rows] [bigint] NULL,
	[modification_counter] [bigint] NULL,
	[DateUpdated] [datetime2](7) NULL,
 CONSTRAINT [pk_StatisticsHistory_HistoryID] PRIMARY KEY CLUSTERED 
(
	[HistoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_StatisticsHistory_DateInserted]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[StatisticsHistory] ADD  CONSTRAINT [DF_StatisticsHistory_DateInserted]  DEFAULT (getdate()) FOR [DateUpdated]
END

GO
