SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ErrorLogs]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ErrorLogs](
	[ErrorDateTime] [datetime2(4)] NOT NULL,
	[ServerName] [varchar](80) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DatabaseName] [varchar](80) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ErrorNumber] [int] NULL,
	[ErrorSeverity] [tinyint] NULL,
	[ErrorState] [int] NULL,
	[ErrorProcedure] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ErrorLine] [smallint] NULL,
	[ErrorMessage] [varchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ProvidedProcName] [varchar](80) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Comments] [varchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
PRIMARY KEY CLUSTERED 
(
	[ErrorDateTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ErrorLogs_ErrorDateTime]') AND type = 'D')
BEGIN
	ALTER TABLE [dbo].[ErrorLogs] ADD CONSTRAINT [DF_ErrorLogs_ErrorDateTime] DEFAULT (sysdatetime()) FOR [ErrorDateTime]
END
GO
