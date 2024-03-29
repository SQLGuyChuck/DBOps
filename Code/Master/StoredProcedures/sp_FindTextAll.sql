USE [master]
GO

IF (OBJECT_ID('dbo.sp_FindTextAll') IS NULL)
BEGIN
	EXEC('create procedure dbo.sp_FindTextAll  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error <> 0)
		PRINT 'FAILED to create empty stored procedure dbo.sp_FindTextAll.'
END
GO

/*
-- Created 6/27/2007 Chuck Lathrope
-- Updated 4/3/2008 Chuck Lathrope, search all databases for objects in SQL 2005.
-- 6/30/2010 Chuck Lathrope Added quotename function to db name.

-- Purpose: Find text in procs, functions, triggers, constraints, and sql jobs.

-- Does not find text in object names like this would when proper db is active:
	--declare @FindThis varchar(255)
	--set @FindThis = 'webhosts'
	--select type_desc, [name], 'ObjectName Only' as step_name 
	--from sys.objects
	--where [name] = @FindThis
	--order by type_desc, name

-- Does not attempt to trim % signs from passed in variable, which is okay, as it won't affect results.
	--If patindex ('%', @FindThis) > 0 
	--Print 'Percent found, replacing'
	--Print @FindThis

sp_FindTextAll 'findtext'
*/

Alter Procedure dbo.sp_FindTextAll @FindThis nvarchar(255)
as
begin

Set nocount on
--SQL 2000:
If @@microsoftversion/0x01000000 < 9
Begin 
	Select [name] as ObjectName
		, case xtype 
			when 'P ' then 'SQL_STORED_PROCEDURE'
			when 'TR' then 'SQL_TRIGGER'
			when 'U ' then 'USER_TABLE'
			when 'V ' then 'VIEW'
			when 'UQ' then 'UNIQUE_CONSTRAINT'
			when 'S ' then 'SYSTEM_TABLE'
			when 'IF' then 'SQL_INLINE_TABLE_VALUED_FUNCTION'
			when 'IT' then 'INTERNAL_TABLE'
			when 'D ' then 'DEFAULT_CONSTRAINT'
			when 'F ' then 'FOREIGN_KEY_CONSTRAINT'
			when 'PK' then 'PRIMARY_KEY_CONSTRAINT'
			when 'C ' then 'CHECK_CONSTRAINT'
			when 'TF' then 'SQL_TABLE_VALUED_FUNCTION'
			when 'FN' then 'SQL_SCALAR_FUNCTION'
			else xtype
			end as ObjectType
	from syscomments c
	inner join sysobjects o on o.id = c.id
	where text like '%' + @FindThis + '%'
	and encrypted = 0

	Select Distinct 'SQL Job Step' as type_desc, j.name, step_name
	from msdb.dbo.sysjobsteps s
	inner join msdb.dbo.sysjobs j
		on s.job_id = j.job_id 
	where command like '%' + @FindThis + '%'  
End

--SQL 2005
If @@microsoftversion/0x01000000 >= 9
Begin 

	Declare @incr int
	Declare @DBName varchar(80)
		, @rowcount int
		, @dsql varchar(8000)

	Create Table #OnlineDBs (incr int identity(1,1), dbname varchar(80))
	Create Table ##ObjectList (DBName varchar(80), ObjectName varchar(200), ObjectType varchar(80))

	Insert into #OnlineDBs (dbname)
	select QUOTENAME(name) from sys.databases
	where state_desc = 'ONLINE'
	and database_id not in (2,3)

	Select @rowcount = @@rowcount

	Set @incr = 1
	Select @dbname = dbname from #OnlineDBs where incr = @incr

	While @incr <= @rowcount
	Begin
		
		select @dsql = 'Insert into ##ObjectList (DBName, ObjectName, ObjectType)
		select ''' + @DBName + ''', [name], type_desc
		from ' + @DBName + '.sys.sql_modules m
		inner join ' + @DBName + '.sys.objects o on o.object_id = m.object_id
		where definition like ''%' + @FindThis + '%''' 
		--Print @dsql
		Exec (@dsql)
		Set @incr = @incr + 1
		Select @dbname = dbname from #OnlineDBs where incr = @incr
	End

	Select * from ##ObjectList order by DBName, ObjectName, ObjectType

	Drop Table #OnlineDBs 
	Drop Table ##ObjectList

	select j.name as SQLJobName, step_name 
	from msdb.dbo.sysjobsteps s
	inner join msdb.dbo.sysjobs j on s.job_id = j.job_id 
	where command like '%' + @FindThis + '%'


End

End -- Proc
go

If @@microsoftversion/0x01000000 >= 9
EXEC master.sys.sp_MS_marksystemobject sp_FindTextAll
go


