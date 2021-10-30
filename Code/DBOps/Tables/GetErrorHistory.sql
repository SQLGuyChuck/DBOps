SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GetErrorHistory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[GetErrorHistory](
	HistoryID INT IDENTITY (1,1) PRIMARY KEY,
	[event_name] [varchar](50) NULL,
	[timestamp] [datetime2](7) NULL,
	[DatabaseName] [sysname] NULL,
	[database_id] [int] NULL,
	[error_message] [nvarchar](1000) NULL,
	[error] [int] NULL,
	[severity] [int] NULL,
	[sql_text] [xml] NULL,
	[client_app_name] [nvarchar](4000) NULL,
	[client_hostname] [nvarchar](4000) NULL,
	[username] [nvarchar](4000) NULL,
	[tsql_stack] [xml] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END

