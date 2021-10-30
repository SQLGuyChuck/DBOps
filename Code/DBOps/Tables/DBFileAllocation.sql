IF OBJECT_ID('dbo.DBFileAllocation', 'U') IS NULL
BEGIN
CREATE TABLE [dbo].[DBFileAllocation](
	[ServerName] [varchar](30) NOT NULL,
	[DBName] [sysname] NOT NULL,
	[FileGroupName] [varchar](150) NULL,
	[LogicalFileName] [sysname] NOT NULL,
	[Filename] [nvarchar](520) NOT NULL,
	[FileSizeMB] [int] NULL,
	[FreeSpaceMB] [numeric](18, 0) NULL,
	[FileType] [varchar](15) NULL,
	[MaxSize] [int] NULL,
	[Growth] [int] NULL,
	[GrowthUnit] [varchar](2) NULL,
	[Compatibility] [varchar](7) NULL,
	[RecoveryMode] [varchar](11) NULL,
	[Trustworthy] [bit] NULL,
	[DBChaining] [bit] NULL,
	[FullText] [bit] NULL,
	[RO] [bit] NULL,
	[Sparse] [bit] NULL,
	[DateCollected] [datetime] NOT NULL default (getdate())
) ON [PRIMARY];
END
