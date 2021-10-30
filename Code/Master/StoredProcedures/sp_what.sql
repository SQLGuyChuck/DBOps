USE master
GO
IF (OBJECT_ID('dbo.sp_what') IS NULL)
BEGIN
      EXEC('Create procedure dbo.sp_what  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
      IF (@@error = 0)
            PRINT 'Successfully created empty stored procedure dbo.sp_what.'
      ELSE
      BEGIN
            PRINT 'FAILED to create stored procedure dbo.sp_what.'
      END
END
GO

/********************
** Modified 8/30/2008 Chuck Lathrope
** 11/11/2008 Ganesh
					   Added job name and included optional parameter @blocked	
** 11/13/2008 Ganesh
					   Added additional field ActiveMinutes and replaced ISNULL to COALESCE
** 05/12/2009 Ganesh
					   Added additional input parameter for login name
** 09/01/10   Added dbName column to output
** 06/24/2013 Chuck		Removed background status tasks as they never provide useful info.
*********************/
ALTER PROCEDURE [dbo].[sp_what]
					@blocked bit = 0,
					@loginname sysname = null
as  
Begin

set nocount on  

declare  @loginame sysname, @spidlow int, @spidhigh int  
  
declare  @charMaxLenLoginName varchar(6), @charMaxLenDBName varchar(6),  
	@charMaxLenCPUTime varchar(10), @charMaxLenDiskIO varchar(10),  
	@charMaxLenHostName varchar(10), @charMaxLenProgramName varchar(10),  
	@charMaxLenLastBatch varchar(10), @charMaxLenCommand varchar(10)  

-- Capture consistent sysprocesses across SQL versions.

Create Table #tb1_sysprocesses (spid smallint,
	[status]	nchar(60),
	[hostname]	nchar(256),
	[DBName]	nvarchar(255),
	[program_name]	nchar(256),
	activeminutes bigint,
	cmd	nchar(32),
	cpu	int,
	physical_io	bigint,
	memusage bigint, 
	open_tran smallint,
	blocked	smallint,
	[dbid]	smallint,
	loginname	sysname,
	last_batch	datetime)

Insert into #tb1_sysprocesses (spid, [status], [DBName],hostname, [program_name],activeminutes, cmd,
cpu, physical_io, memusage, open_tran, blocked, [dbid], loginname, last_batch)
SELECT  spid, status, db_name(dbid) as [DBName], hostname,coalesce(j.name,[program_name]), datediff(second,last_batch,getdate())/60,cmd, cpu, physical_io, memusage, open_tran, blocked, dbid,  
	convert(sysname, rtrim(loginame)) as loginname, last_batch  
FROM master.sys.sysprocesses p with (nolock)
LEFT JOIN msdb..sysjobs j ON dbops.dbo.udf_sysjobs_getprocessid(j.job_id) = substring(p.program_name,32,8)
WHERE lower(status) NOT IN ( 'sleeping', 'background')
-- Screen out any rows  

DELETE #tb1_sysprocesses  
where (upper(cmd) IN ('AWAITING COMMAND', 'MIRROR HANDLER', 'LAZY WRITER' 
	,'CHECKPOINT SLEEP', 'RA MANAGER', 'TASK MANAGER')  
and  blocked = 0 )
or spid <= 50


--Clean up last_batch date values.
update #tb1_sysprocesses set last_batch = DATEADD(year,-10,GETDATE())   
where last_batch IS NULL 
or last_batch = '01/01/1901 00:00:00'   
or last_batch < '01/01/1950'

if @blocked = 0 and @loginname is not null
Select * from #tb1_sysprocesses
Where Blocked <> 0 and loginname like '%' + @loginname + '%'
Union ALL
Select * from #tb1_sysprocesses
Where Blocked = 0 and loginname like '%' + @loginname + '%'
Order by Blocked, spid
else if @blocked = 0
Select * from #tb1_sysprocesses
Where Blocked <> 0
Union ALL
Select * from #tb1_sysprocesses
Where Blocked = 0
Order by Blocked, spid
else
Select * from #tb1_sysprocesses
Where Blocked <> 0


drop table #tb1_sysprocesses

END --Proc
