SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DBTableSizeHistory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DBTableSizeHistory](
	[DBTableSizeHistoryID] [int] IDENTITY(1,1) NOT NULL,
	[DBName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ObjectName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Type] [varchar](2) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Rows] [bigint] NULL,
	[TotalMB] [decimal](10, 3) NULL,
	[UnusedMB] [decimal](10, 3) NULL,
	[UsedMB] [decimal](10, 3) NULL,
	[IndexMB] [decimal](10, 3) NULL,
	[DataMB] [decimal](10, 3) NULL,
	[DateLogged] [datetime] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[DBTableSizeHistoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__DBTableSi__DateL__55009F39]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DBTableSizeHistory] ADD  DEFAULT (getdate()) FOR [DateLogged]
END

GO
