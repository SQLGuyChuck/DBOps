SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ProcessParameter]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ProcessParameter](
	[ProcessParameterID] [int] IDENTITY(1,1) NOT NULL,
	[ProcessID] [smallint] NOT NULL,
	[ParameterName] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ParameterValue] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_ProcessParameter] PRIMARY KEY CLUSTERED 
(
	[ProcessParameterID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Process_ProcessParameter]') AND parent_object_id = OBJECT_ID(N'[dbo].[ProcessParameter]'))
ALTER TABLE [dbo].[ProcessParameter]  WITH CHECK ADD  CONSTRAINT [FK_Process_ProcessParameter] FOREIGN KEY([ProcessID])
REFERENCES [dbo].[Processes] ([ProcessID])
GO
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Process_ProcessParameter]') AND parent_object_id = OBJECT_ID(N'[dbo].[ProcessParameter]'))
ALTER TABLE [dbo].[ProcessParameter] CHECK CONSTRAINT [FK_Process_ProcessParameter]
GO
