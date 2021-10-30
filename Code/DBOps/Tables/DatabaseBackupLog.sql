IF OBJECT_ID('dbo.DatabaseBackupLog', 'U') IS NULL
BEGIN
CREATE TABLE [dbo].[DatabaseBackupLog](
	[BackupLogID] [bigint] IDENTITY(1,1) NOT NULL,
	[BackupType] [varchar](4) NULL,
	[DatabaseID] [smallint] NULL,
	[DatabaseName] [varchar](100) NOT NULL,
	[Operation] [varchar](35) NOT NULL,
	[NumberofFiles] [tinyint] NULL,
	[BackupLocation] [varchar](255) NULL,
	[Success] [bit] NOT NULL,
	[MessageText] [varchar](2000) NULL,
	[BackupInitialized] [bit] NULL,
	[CompressionLevel] [tinyint] NULL,
	[LitespeedThrottlePercent] [tinyint] NULL,
	[LitespeedCPUAffinity] [tinyint] NULL,
	[LitespeedSQLPriority] [tinyint] NULL,
	[EncryptionKey] [varchar](1024) NULL,
	[LogTimeStamp] [datetime] NOT NULL,
	[MaxTransferSizeKB] [int] NULL,
	[LitespeedOptCommands] [varchar](400) NULL,
	[MirrorBackupLocation] [varchar](300) NULL,
 CONSTRAINT [pk_DatabaseBackupLog_BackupLogID] PRIMARY KEY CLUSTERED 
(
	[BackupLogID] ASC
) ON [PRIMARY]
) ON [PRIMARY]
ALTER TABLE [dbo].[DatabaseBackupLog] ADD  CONSTRAINT [DF_DatabaseBackupLog_LogTimeStamp]  DEFAULT (getdate()) FOR [LogTimeStamp]

END
GO
