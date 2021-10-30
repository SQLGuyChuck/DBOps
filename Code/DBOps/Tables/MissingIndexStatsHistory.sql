SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MissingIndexStatsHistory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MissingIndexStatsHistory](
	[HistoryID] [int] IDENTITY(1,1) NOT NULL,
	[DBName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ObjectName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[create_index_statement] [nvarchar](4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[avg_user_impact] [float] NULL,
	[unique_compiles] [bigint] NULL,
	[user_seeks] [bigint] NULL,
	[user_scans] [bigint] NULL,
	[last_user_seek] [datetime] NULL,
	[SQLStartUpDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[HistoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
