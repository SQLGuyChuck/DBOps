SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DBAIndexStats]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DBAIndexStats](
	[DatabaseID] [int] NULL,
	[DatabaseName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ObjectID] [int] NULL,
	[ObjectName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[IndexID] [int] NULL,
	[IndexName] [varchar](80) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[IndexType] [varchar](40) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[IndexDepth] [int] NULL,
	[IndexLevel] [int] NULL,
	[PageCount] [int] NULL,
	[PartitionNum] [int] NULL,
	[FragPercentage] [float] NULL,
	[RebuildThreshold] [int] NULL,
	[DateCollected] [datetime] NULL
) ON [PRIMARY]
END
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DBAIndexStats]') AND name = N'CIDX_DBAIndexStats_DatabaseID_ObjectID_IndexID_Partitionnum_DateCollected')
CREATE CLUSTERED INDEX [CIDX_DBAIndexStats_DatabaseID_ObjectID_IndexID_Partitionnum_DateCollected] ON [dbo].[DBAIndexStats]
(
	[DatabaseID] ASC,
	[ObjectID] ASC,
	[IndexID] ASC,
	[PartitionNum] ASC,
	[DateCollected] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DBAIndexStats]') AND name = N'NCIDX_DBAIndexStats_DataBaseName_ObjectName_IndexName')
CREATE NONCLUSTERED INDEX [NCIDX_DBAIndexStats_DataBaseName_ObjectName_IndexName] ON [dbo].[DBAIndexStats]
(
	[DatabaseName] ASC,
	[ObjectName] ASC,
	[IndexName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DBAIndexStats]') AND name = N'NCIDX_DBAIndexStats_FragPercentage')
CREATE NONCLUSTERED INDEX [NCIDX_DBAIndexStats_FragPercentage] ON [dbo].[DBAIndexStats]
(
	[FragPercentage] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__DBAIndexS__DateC__24927208]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DBAIndexStats] ADD  DEFAULT (getdate()) FOR [DateCollected]
END

GO
