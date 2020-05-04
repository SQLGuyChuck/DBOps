SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BlockingMonitorHistory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[BlockingMonitorHistory](
	[ident] [int] IDENTITY(1,1) NOT NULL,
	[spid] [varchar](30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[command] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[login] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[host] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[hostprc] [varchar](10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[endpoint] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[appl] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[dbname] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[prcstatus] [varchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[spid_] [varchar](30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[opntrn] [varchar](10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[trninfo] [varchar](30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[blklvl] [varchar](7) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[blkby] [varchar](30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[cnt] [varchar](10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[object] [nvarchar](520) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[rsctype] [varchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[locktype] [varchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[lstatus] [varchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ownertype] [varchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[rscsubtype] [varchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[waittime] [varchar](16) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[waittype] [varchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[spid__] [varchar](30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[cpu] [varchar](30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[physio] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[logreads] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[tempdb] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[now] [char](12) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[login_time] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[last_batch] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[trn_start] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[last_since] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[trn_since] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[clr] [char](3) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[nstlvl] [char](3) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[spid___] [varchar](30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[inputbuffer] [nvarchar](4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[current_sp] [nvarchar](400) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[curstmt] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[queryplan] [xml] NULL,
	[InsertTimeStamp] [datetime] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_BlockingMonitorHistory_InsertTimeStamp]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[BlockingMonitorHistory] ADD  CONSTRAINT [DF_BlockingMonitorHistory_InsertTimeStamp]  DEFAULT (getdate()) FOR [InsertTimeStamp]
END

GO
