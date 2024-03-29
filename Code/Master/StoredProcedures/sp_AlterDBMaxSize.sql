
USE Master
GO

IF (OBJECT_ID('dbo.sp_AlterDBMaxSize') IS NULL)
BEGIN
	EXEC('create procedure dbo.sp_AlterDBMaxSize  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.sp_AlterDBMaxSize.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.sp_AlterDBMaxSize.'
	END
END
GO

/******************************************************************************
**		Name: sp_AlterDBMaxSize
**		Desc: Proc will set the Max Size of a user database with log file size 2 times greater.
**				It will also attempt to shrink the log file size down to half of max size
**				Or maxsize if spaceused is less than either.
**
*******************************************************************************
**		Change History
*******************************************************************************
**		Date:		Author:				Description:
**		3/29/2009	Chuck Lathrope		Removed permanent table. Check file size logic improved.
*******************************************************************************/

Alter Procedure dbo.sp_AlterDBMaxSize
	@DatabaseName varchar(128), 
	@MaxSize int,
	@Result tinyint output	-- 0: Success
							-- 1: Failure, try again.
							-- 2: Failed to alter data file size
							-- 3: Failed to alter log file size
							-- 4: Database doesn't exist or not ONLINE.
							-- 5: Too much space consumed in database, must delete data.
AS

Begin

Set NoCount On

Declare @dsql varchar(700),	@Err int
Declare @CurrentDataSize float, @CurrentDataSizeUsed float, 
	@CurrentLogSizeUsed float, @CurrentLogSize float 

If NOT Exists (Select name   
				From master..sysdatabases  
				Where DATABASEPROPERTYEX(name,'status') = 'ONLINE'  
				and name = @DatabaseName)
Begin
	Print 'Database not found, or not ONLINE.'
	Set @Result = 4
	Return
End

Create table #AvailSpace (DBName varchar(100), LogicalDBName varchar(100), Type_desc varchar(10), FileSizeMB int, AvailableSpaceMB  float)
Create table #ExecuteThis (ExecStatement varchar (300))

If CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR),1,2),'.','') as tinyint) = 8
Begin   
	create table #DataFiles(   
	Fileid int NOT NULL,   
	[FileGroup] int NOT NULL,   
	TotalExtents int NOT NULL,   
	UsedExtents int NOT NULL,   
	[Name] sysname NOT NULL,   
	[FileName] varchar(300) NOT NULL  
	)   

	set @Dsql = 'use [' + @DatabaseName + '] DBCC showfilestats'--Only data file info
	insert #DataFiles   
	exec(@Dsql)   

	insert into #AvailSpace (DBName, LogicalDBName, Type_desc, FileSizeMB, AvailableSpaceMB)  
	select @DatabaseName, Name, 'ROWS', TotalExtents*64/1024,
	(CAST(((TotalExtents*64)/1024.00) as numeric(9,2)) - CAST(((UsedExtents*64)/1024.00) as numeric(9,2))) as AvailableSpaceMB  
	from #DataFiles
End  
Else --SQL2005+
Begin  
	Set @Dsql = 'use [' + @DatabaseName + '] SELECT ''' + @DatabaseName + ''' as DBName, name as logicalname, Type_desc, cast(size/128.0 as int) as FileSizeMB, size/128.0 - FILEPROPERTY(name, ''SpaceUsed'')/128.0 AS AvailableSpaceMB'  
	 + ' FROM sys.database_files'   
	insert #AvailSpace   
	exec(@Dsql)   
End  

--Get log file space used information
Create table #tmplogspace (DatabaseName sysname, LogSizeMB float, LOGSpaceUsedPercentage float, Status bit)
insert #tmplogspace EXEC ('dbcc sqlperf(logspace) WITH NO_INFOMSGS')

Select @CurrentLogSize = LogSizeMB, @CurrentLogSizeUsed = (LOGSpaceUsedPercentage/100.0)*LogSizeMB
From #tmplogspace
Where DatabaseName = @DatabaseName

--Get sum of data files
Select @CurrentDataSize=SUM(FileSizeMB), @CurrentDataSizeUsed=SUM(AvailableSpaceMB)
From #AvailSpace
Where Type_desc = 'ROWS'


Set @Dsql = null

--///////////////////////////////
--LOG file Shrink
--///////////////////////////////
--What can we shrink file down to? Try best guess of half maxsize, then maxsize else don't modify.
If @CurrentLogSize > (@MaxSize/2) and @CurrentLogSizeUsed > @MaxSize/2
Begin
	--Get logicalname of log file.
	Select @dsql = 'Use [' + @DatabaseName + ']	Select ''DBCC ShrinkFile ('' + RTrim(Name) + '', ' + CONVERT(varchar, @MaxSize/2) + ') WITH NO_INFOMSGS''' +
	' From [' + @DatabaseName + '].dbo.sysfiles Where groupid = 0'
End
Else If @CurrentLogSize > @MaxSize and @CurrentLogSizeUsed > @MaxSize
Begin
	--Get logicalname of log file.
	Select @dsql = 'Use [' + @DatabaseName + ']	Select ''DBCC ShrinkFile ('' + RTrim(Name) + '', ' + CONVERT(varchar, @MaxSize) + ') WITH NO_INFOMSGS''' +
	' From [' + @DatabaseName + '].dbo.sysfiles Where groupid = 0'
print @dsql
End
--Else do nothing as all is fine.

If @Dsql is not null
Begin
	Insert into #ExecuteThis
	Exec (@dsql)

	Select @Dsql = 'Use [' + @DatabaseName + '] ' + ExecStatement from #ExecuteThis
	Exec (@dsql)

	Select @Err = @@Error

	If @err <> 0 
	Begin 
		Print @err
		Set @Result = 3 
		Return
	End	
End

--Adjust Log file size.
Begin
	--Get logicalname of log file.
	Truncate table #ExecuteThis
	Select @dsql = 'Select ''ALTER DATABASE [' + @DatabaseName + '] MODIFY FILE (NAME = N'''''' + RTrim(Name) + '''''', MAXSIZE = ' + CONVERT(varchar, @MaxSize*2) + ')''' +
	' From [' + @DatabaseName + '].dbo.sysfiles Where groupid = 0'
	Insert into #ExecuteThis
	Exec (@dsql)
	
	Select @Dsql = ExecStatement from #ExecuteThis
	Exec (@dsql)

	Select @Err = @@Error

	If @err <> 0 
	Begin 
		Set @Result = 3 
		Return
	End	
End

Truncate table #ExecuteThis

--Check to make sure we have enough space in database to shrink to desired amount.
If (@CurrentDataSize-@CurrentDataSizeUsed) > @MaxSize
Begin
	Set @Result = 5
	Return
End


--///////////////////////////////
--Data file Shrink
--///////////////////////////////
--Shrink database first before trying to alter database as would generate error 5120 serverity 16.
If cast(@MaxSize as float) < @CurrentDataSize
Begin 
	Select @dsql = 'Use [' + @DatabaseName + ']	Select ''DBCC ShrinkFile ('' + RTrim(Name) + '', ' + CONVERT(varchar, @MaxSize) + ') WITH NO_INFOMSGS''' +
	' From [' + @DatabaseName + '].dbo.sysfiles Where groupid > 0'
	Insert into #ExecuteThis
	Exec (@dsql)

	Select @Dsql = 'Use [' + @DatabaseName + '] ' + ExecStatement from #ExecuteThis
	Exec (@dsql)
	Select @Err = @@Error

	If @err <> 0 
	Begin 
		Set @Result = 2
		Return
	End
End

Truncate table #ExecuteThis

--Modify Data file size
Select @dsql = 'Select ''ALTER DATABASE [' + @DatabaseName + '] MODIFY FILE (NAME = N'''''' + RTrim(Name) + '''''', MAXSIZE = ' + CONVERT(varchar, @MaxSize) + ')''' +
' From [' + @DatabaseName + '].dbo.sysfiles Where groupid > 0'
Insert into #ExecuteThis
Exec (@dsql)

Select @Dsql = ExecStatement from #ExecuteThis
Exec (@dsql)
Select @Err = @@Error

If @err <> 0 
Begin 
	Set @Result = 2
	Return
End

Set @Result = 0

End

go

