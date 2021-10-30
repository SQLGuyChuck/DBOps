Use master
Go
IF (OBJECT_ID('dbo.sp_tableswap') IS NULL)
BEGIN
      EXEC('Create procedure dbo.sp_tableswap  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
      IF (@@error = 0)
            PRINT 'Successfully created empty stored procedure dbo.sp_tableswap.'
      ELSE
      BEGIN
            PRINT 'FAILED to create stored procedure dbo.sp_tableswap.'
      END
END
GO

/*************************************************************************************** 
**
**  Purpose: Disconnect all users that are connected to the passed in table.
**			 Swap tables using rename function.
**
** Example Usage:
--declare 	 @DBName as sysname, @ExistingTable as sysname
--	,@OfflineTable as sysname
--
--Set @DBName = 'master'
--Set @ExistingTable = 'deletemetest'
--Set @OfflineTable = 'deletemetestnew'
--
--exec sp_tableswap @DBName, @ExistingTable, @OfflineTable
**
**		Auth: Chuck Lathrope
**		Date: 2/2/2008
*******************************************************************************************
**		Change History
*******************************************************************************************
**		Date:		Author:				Description:
**	2/3/2009		Chuck Lathrope		Added 'Object' as type to prevent certain error conditions for sp_rename.
*******************************************************************************************/

Alter Procedure dbo.sp_tableswap
	@DBName as sysname
	,@ExistingTable as sysname
	,@OfflineTable as sysname
AS
Begin

set nocount on

Declare @spid int
		,@command varchar(50)
		,@ObjID int
		,@ObjID2 int
		,@dsql varchar(1000)
		,@objectname varchar(150)
		,@errmsg varchar(150)
		,@RowCount int
		,@SQL varchar(1000)

Set @ObjectName = @dbname + '.dbo.' + @ExistingTable
Select @ObjID = object_id(@ObjectName)

Set @ObjectName = @dbname + '.dbo.' + @OfflineTable
Select @ObjID2 = object_id(@ObjectName)

If @ObjID is null or @ObjID = 0
Begin
    RAISERROR ('ObjectID not found', -- Message text.
           16, -- Severity.
           1 -- State.
           );
	Return
End

--This code below forces proc and table to be in same database.
--If object_id(@ExistingTable + '_old') is not null
--Begin
--	SELECT @RowCount=st.row_count
--	FROM sys.dm_db_partition_stats st
--	WHERE index_id < 2
--	and Object_id = object_id(@ExistingTable + '_old')
--
--	If @RowCount = 0
--	Begin
--		Set @SQL = 'Drop table ' + @DBName + '.dbo.' + @ExistingTable + '_old'
--		Exec (@SQL)
--	End
--	Else
--	Begin
--		Set @errmsg = 'OfflineTable "'+@ExistingTable+'_old" exists in database and has data, stopped rename to prevent possible dataloss.'
--		RAISERROR (@errmsg, -- Message text.
--			   16, -- Severity.
--			   1 -- State.
--			   );
--		Return
--	End
--End

create table #lock (spid int, dbid int, objId int, IndId int, Type varchar(50), Resource varchar(500) null, Mode varchar(10) null,
Status varchar(20))
insert into #lock (spid, dbid, objId, IndId, [Type], Resource, Mode, Status)
exec sp_lock

declare cs_kill cursor forward_only read_only
for select distinct spid from #lock where ObjID = @ObjID or ObjID = @ObjID2

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
drop table #lock

Set @Dsql = 'exec sp_rename @objname=''' + @ExistingTable + ''' , @newname = ''' + @ExistingTable + '_old'', @objtype =''OBJECT'' '
Exec (@dsql)

If @@error = 0
Begin
	Set @Dsql = 'exec sp_rename @objname=''' + @OfflineTable + ''' , @newname = ''' + @ExistingTable + ''', @objtype =''OBJECT'' '
	Exec (@dsql)
	Set @Dsql = 'exec sp_rename @objname=''' + @ExistingTable + '_old' + ''' , @newname = ''' + @OfflineTable + ''', @objtype =''OBJECT'' '
	Exec (@dsql)
End


End --Proc
