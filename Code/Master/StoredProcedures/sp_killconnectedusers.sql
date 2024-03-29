USE master
GO
IF (OBJECT_ID('dbo.sp_killconnectedusers') IS NULL)
BEGIN
      EXEC('Create procedure dbo.sp_killconnectedusers  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
      IF (@@error = 0)
            PRINT 'Successfully created empty stored procedure dbo.sp_killconnectedusers.'
      ELSE
      BEGIN
            PRINT 'FAILED to create stored procedure dbo.sp_killconnectedusers.'
      END
END
GO

/*************************************************************************** 
-- 	Disconnect all users that are connected to the passed in database except yourself
***************************************************************************/

Alter Procedure dbo.sp_killconnectedusers
	@dbname as sysname
AS
Begin

set nocount on

Declare @version varchar(1000)
		,@spid int
		,@command varchar(50)
		,@currentspid int

Select @version = @@version, @currentspid = @@spid

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
  SPID2 INT ,
  RequestID int NULL) 

INSERT #sp_who2 EXEC sp_who2 

declare cs_kill cursor fast_forward
for select spid from #sp_who2
where dbname = @dbname
and spid <> @currentspid
and spid > 50

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
