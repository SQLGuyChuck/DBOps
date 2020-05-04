SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MissingIndexesFromPlanCache]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MissingIndexesFromPlanCache](
	[Incr_id] [int] IDENTITY(1,1) NOT NULL,
	[DatabaseName] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DatabaseID] [int] NOT NULL,
	[ObjectName] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[QueryPlan] [xml] NOT NULL,
	[DateCaptured] [smalldatetime] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Incr_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO
