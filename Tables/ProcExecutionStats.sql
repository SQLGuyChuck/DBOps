SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ProcExecutionStats]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ProcExecutionStats](
	[DBName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[SchemaName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[StoredProcedure] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[TableName] [nvarchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[execution_count] [int] NULL,
	[total_cpu_time] [bigint] NULL,
	[total_IO] [bigint] NULL,
	[total_physical_reads] [bigint] NULL,
	[total_logical_reads] [bigint] NULL,
	[total_logical_writes] [bigint] NULL,
	[total_elapsed_time] [bigint] NULL,
	[avg_cpu_time] [numeric](34, 14) NULL,
	[avg_total_IO] [bigint] NULL,
	[avg_physical_read] [numeric](34, 14) NULL,
	[avg_logical_read] [numeric](34, 14) NULL,
	[avg_logical_writes] [numeric](34, 14) NULL,
	[avg_elapsed_time] [bigint] NULL,
	[ProjectedImpact] [decimal](6, 4) NULL,
	[MissingIndexFlag] [int] NOT NULL,
	[AuditDate] [datetime] NULL
) ON [PRIMARY]
END
GO
SET ANSI_PADDING ON

GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ProcExecutionStats]') AND name = N'ix_ProcExecutionStats_DBName_storedprocedure')
CREATE NONCLUSTERED INDEX [ix_ProcExecutionStats_DBName_storedprocedure] ON [dbo].[ProcExecutionStats]
(
	[DBName] ASC,
	[StoredProcedure] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__ProcExecu__Audit__4AB81AF0]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ProcExecutionStats] ADD  DEFAULT (getdate()) FOR [AuditDate]
END

GO
