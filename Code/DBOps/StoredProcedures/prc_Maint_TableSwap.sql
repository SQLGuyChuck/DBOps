IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'prc_Maint_TableSwap' And ROUTINE_SCHEMA = 'dbo')
BEGIN
	EXEC('CREATE Procedure dbo.prc_Maint_TableSwap as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.prc_Maint_TableSwap.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.prc_Maint_TableSwap.'
	END
END
GO

ALTER PROCedure dbo.prc_Maint_TableSwap
	@ExistingTable as sysname
	,@OfflineTable as sysname
AS
Begin

/*************************************************************************************** 
**
**  Desc: Disconnect all users that are connected to the passed in table.
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
--exec prc_Maint_TableSwap @DBName, @ExistingTable, @OfflineTable
**
*******************************************************************************************
**		Change History
*******************************************************************************************
**	Date:		Author:				Description:
**	2/3/2009	Chuck Lathrope		Added 'Object' as type to prevent certain error conditions for sp_rename.
*******************************************************************************************/
set nocount on

Declare @spid int
		,@command varchar(50)
		,@ObjID int
		,@ObjID2 int
		,@dsql varchar(1000)
		,@errmsg varchar(150)
		,@RowCount int
		,@SQL varchar(1000)

Select @ObjID = object_id(@ExistingTable)
Select @ObjID2 = object_id(@OfflineTable)


If object_id(@ExistingTable) is null
Begin
	Set @errmsg = 'OfflineTable "'+@ExistingTable+'" does not exist for table swap.'
	RAISERROR (@errmsg, -- Message text.
		   16, -- Severity.
		   1 -- State.
		   );
	Return
End

If object_id(@OfflineTable) is null
Begin
	Set @errmsg = 'OfflineTable "'+@OfflineTable+'" does not exist for table swap.'
	RAISERROR (@errmsg, -- Message text.
		   16, -- Severity.
		   1 -- State.
		   );
	Return
End


--This code below forces proc and table to be in same database.
If object_id(@ExistingTable + '_old') is not null
Begin
	SELECT @RowCount=st.row_count
	FROM sys.dm_db_partition_stats st
	WHERE index_id < 2
	and Object_id = object_id(@ExistingTable + '_old')

	If @RowCount = 0
	Begin
		Set @SQL = 'Drop table ' + @ExistingTable + '_old'
		Print @SQL
		Exec (@SQL)
	End
	Else
	Begin
		Set @errmsg = 'OfflineTable "'+@ExistingTable+'_old" exists in database and has (' + ISNULL(@Rowcount , 'NULL')+ ') data rows, stopped rename to prevent possible dataloss.'
		RAISERROR (@errmsg, -- Message text.
			   16, -- Severity.
			   1 -- State.
			   );
		Return
	End
End

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

Set @Dsql = 'exec sp_rename @objname=''' + @ExistingTable + ''' , @newname = ''' + @ExistingTable + '_old'''
Exec (@dsql)

If @@error = 0
Begin
	Set @Dsql = 'exec sp_rename @objname=''' + @OfflineTable + ''' , @newname = ''' + @ExistingTable + ''', @objtype =''OBJECT'' '
	Exec (@dsql)

	Set @Dsql = 'exec sp_rename @objname=''' + @ExistingTable + '_old' + ''' , @newname = ''' + @OfflineTable + ''', @objtype =''OBJECT'' '
	Exec (@dsql)
End

End --Proc
