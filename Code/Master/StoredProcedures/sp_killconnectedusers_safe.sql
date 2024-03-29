USE master
GO
IF (OBJECT_ID('dbo.sp_killconnectedusers_safe') IS NULL)
BEGIN
      EXEC('Create procedure dbo.sp_killconnectedusers_safe  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
      IF (@@error = 0)
            PRINT 'Successfully created empty stored procedure dbo.sp_killconnectedusers_safe.'
      ELSE
      BEGIN
            PRINT 'FAILED to create stored procedure dbo.sp_killconnectedusers_safe.'
      END
END
GO

--Modified 8/6/2008 Chuck Lathrope Don't kill replication, SQL Agent, Bulk Insert and your own spid.
--10/2/2008 Chuck Lathrope, sp_who2 now adds REQUESTID column for SQL 2005.
alter Procedure dbo.sp_killconnectedusers_safe
	@dbname as sysname
AS
Begin

set nocount on
/*************************************************************************** 
-- 	disconnect all users that are connected to the passed in database except Replication, SQL jobs, Bulk Inserts.
***************************************************************************/

Declare @version varchar(1000)
		,@spid int
		,@command varchar(50)
		,@currentspid int
		,@MSSQLVer   TINYINT

Select @version = @@version, @currentspid = @@spid, @MSSQLVer = SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR),1,2);

CREATE TABLE #sp_who2 (
  SPID INT,
  Status VARCHAR(1000) NULL,
  Login SYSNAME NULL,
  HostName SYSNAME NULL,
  BlkBy SYSNAME NULL,
  DBName SYSNAME NULL,
  Command VARCHAR(1000) NULL,
  CPUTime INT NULL,
  DiskIO INT NULL,
  LastBatch VARCHAR(1000) NULL,
  ProgramName VARCHAR(1000) NULL,
  SPID2 INT) 

IF @MSSQLVer >= 9
	Alter Table #sp_who2 Add REQUESTID INT 

INSERT #sp_who2 EXEC sp_who2 

declare cs_kill cursor fast_forward
for select spid from #sp_who2
where dbname = @dbname
and spid >= 50
and spid <> @currentspid
and ProgramName NOT like 'Replication%'
and ProgramName NOT like 'SQLAgent%'
and Command <> 'BULK INSERT     '--Replication snapshots.
AND Command <> 'CREATE INDEX    '--Replication snapshots.

open cs_kill 
 
fetch next from cs_kill into @spid
 
while @@fetch_status = 0
 
 begin
 set @command = 'kill ' + convert(varchar, @spid)
 exec (@command)
 fetch next from cs_kill into @spid
 end
 
close cs_kill
deallocate cs_kill
drop table #sp_who2

End --Proc
