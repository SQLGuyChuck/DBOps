USE DBOPS
GO
IF OBJECT_ID('dbo.DBA_BlockingInfo', 'U') IS NULL
BEGIN
CREATE TABLE [dbo].[DBA_BlockingInfo](
	[ident] [int] IDENTITY(1,1) NOT NULL,
	[spid] [varchar](30) NOT NULL,
	[command] [varchar](32) NULL,
	[login] [sysname] NULL,
	[host] [nvarchar](128) NULL,
	[hostprc] [varchar](10) NULL,
	[endpoint] [sysname] NULL,
	[appl] [nvarchar](128) NULL,
	[dbname] [sysname] NULL,
	[prcstatus] [varchar](60) NULL,
	[spid_] [varchar](30) NULL,
	[opntrn] [varchar](10) NULL,
	trninfo varchar(30) NULL,
	[blklvl] [varchar](7) NULL,
	[blkby] [varchar](30) NULL,
	[cnt] [varchar](10) NULL,
	[object] [nvarchar](520) NULL,
	[rsctype] [varchar](60) NULL,
	[locktype] [varchar](60) NULL,
	[lstatus] [varchar](60) NULL,
	[ownertype] [varchar](60) NULL,
	[rscsubtype] [varchar](60) NULL,
	[waittime] [varchar](16) NULL,
	[waittype] [varchar](60) NULL,
	[spid__] [varchar](30) NULL,
	[cpu] [varchar](30) NULL,
	[physio] [varchar](50) NULL,
	[logreads] [varchar](50) NULL,
	tempdb varchar(50) NULL,
	[now] [char](12) NULL,
	[login_time] [varchar](20) NULL,
	[last_batch] [varchar](20) NULL,
	trn_start varchar(20) NULL,
	[last_since] [varchar](20) NULL,
	trn_since varchar(20) NULL,
	[clr] [char](3) NULL,
	[nstlvl] [char](3) NULL,
	[spid___] varchar(30) NULL,
	[inputbuffer] [nvarchar](4000) NULL,
	[current_sp] [nvarchar](400) NULL,
	[curstmt] [nvarchar](max) NULL,
	[queryplan] [xml] NULL,
	[InsertTimeStamp] [datetime] NULL
) ON [PRIMARY]

ALTER TABLE dbo.DBA_BlockingInfo ADD CONSTRAINT
	DF_DBA_BlockingInfo_InsertTimeStamp DEFAULT getdate() FOR InsertTimeStamp
END

GO
