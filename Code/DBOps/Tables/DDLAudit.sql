SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DDLAudit]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DDLAudit](
	[AuditID] [int] IDENTITY(1,1) NOT NULL,
	[SchemaName] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[OriginalLogin] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[SystemUser] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ObjectName] [nvarchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[UserName] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[TriggeringEvent] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[SqlCommand] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DatabaseName] [nvarchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DateTriggered] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_Audit] PRIMARY KEY CLUSTERED 
(
	[AuditID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO
