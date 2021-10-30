IF OBJECT_ID('dbo.DBLogFileAllocation', 'U') IS NULL
BEGIN
	CREATE TABLE [dbo].[DBLogFileAllocation](
		[DBName] [sysname] NOT NULL,
		[LogicalFileName] [sysname] NOT NULL,
		[FileSizeMB] [int] NULL,
		[UsedSpaceMB] [numeric](18, 0) NULL,
		[DateStamp] [datetime] NULL,
		[Notes] [varchar](1000) NULL
	) ON [PRIMARY];

	ALTER TABLE [dbo].[DBLogFileAllocation] ADD  DEFAULT (getdate()) FOR [DateStamp]
END
GO
