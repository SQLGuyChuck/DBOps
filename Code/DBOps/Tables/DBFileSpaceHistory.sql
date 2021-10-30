SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID('dbo.DBFileSpaceHistory', 'U') IS NULL
BEGIN

CREATE TABLE [dbo].[DBFileSpaceHistory](
	[DBFileSpaceHistoryID] [int] IDENTITY(1,1) NOT NULL,
	[DBName] [sysname] NOT NULL,
	[FileGroupName] [varchar](150) NULL,
	[LogicalFilename] [nvarchar](520) NOT NULL,
	[FileSizeMB] [int] NULL,
	[FreeSpaceMB] [int] NULL,
	[DriveTotalGB] [smallint] NULL,
	[DriveAvailableGB] [smallint] NULL,
	[DrivePercentUsed] [decimal](5, 2) NULL,
	[DateCollected] [datetime2](2) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[DBFileSpaceHistoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]


IF NOT EXISTS (select * from sys.default_constraints dc
	join sys.columns c on c.column_id = dc.parent_column_id
	and c.name = 'DateCollected')

ALTER TABLE [dbo].[DBFileSpaceHistory] ADD  DEFAULT (sysdatetime()) FOR [DateCollected]
END
