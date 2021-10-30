SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DBCCHistory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DBCCHistory](
	[InsertID] [int] IDENTITY(1,1) NOT NULL,
	[InsertDate] [datetime] NULL,
	[DbId] [int] NULL,
	[DbFragId] [int] NULL,
	[DBName] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Error] [int] NULL,
	[Level] [int] NULL,
	[State] [int] NULL,
	[MessageText] [varchar](7000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[RepairLevel] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Status] [int] NULL,
	[ObjectId] [bigint] NULL,
	[IndexId] [int] NULL,
	[PartitionID] [bigint] NULL,
	[AllocUnitID] [bigint] NULL,
	[RidDbId] [int] NULL,
	[RidPruId] [int] NULL,
	[File] [int] NULL,
	[Page] [int] NULL,
	[Slot] [int] NULL,
	[RefDbId] [int] NULL,
	[RefPruId] [int] NULL,
	[RefFile] [int] NULL,
	[RefPage] [int] NULL,
	[RefSlot] [int] NULL,
	[Allocation] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[InsertID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__DBCCHisto__Inser__276EDEB3]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DBCCHistory] ADD  DEFAULT (getdate()) FOR [InsertDate]
END

GO
