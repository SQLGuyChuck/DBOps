USE MASTER
GO

IF NOT EXISTS (select * from sys.types where name ='PageIDs')
create type PageIDs as TABLE
(database_id int,
file_id int,
page_id varchar(30) )
go


Create OR ALTER procedure dbo.sp_GetObjectNames 
	@Tab PageIDs READONLY  -- we use the user defined type
WITH RECOMPILE
as
set nocount on
/*
--Example Use:
declare @t PageIDs
 
insert into @t values 
    (7,1,'1791917')
	--, (20,1,'10224')
    --, (20,1,'50851')
 
exec sp_GetObjectNames @t

database_id	file_id	page_id	objectName
7	1	1791917	GroupRules
*/

-- Create a temp table with one more field
-- objectName
select database_id,file_id,page_id,
        cast('' as varchar(100)) as objectName
        into #tmpResult
from @Tab
 
    declare @database_id int
    declare @file_id int
    declare @page_id varchar(20)
    declare @sql varchar(100)
    declare @objName varchar(100)
 
-- Temp table variable for the insert/exec
declare @tabtmp table
(parentObject varchar(100),
 [Object] varchar(150),
 Field varchar(100),
 value varchar(100) )
 
-- cursor over the temp table
-- we need to execute the dbcc page
-- for each row in our temp table
declare ct cursor for 
    select database_id,file_id,page_id
        from #tmpResult
 
open ct
fetch next from ct into @database_id,@file_id,@page_id
while @@FETCH_STATUS=0
begin
       -- DBCC Page is built as string
       select @sql='DBCC PAGE(' + cast(@database_id as varchar(100)) + 
                ',' + cast(@file_id as varchar(100)) + ',' + @page_id + ') with tableresults'
 
         -- insert into temp table variable
         -- the executio of the string
         insert into @tabtmp
            exec(@sql)
 
        -- Retrieve from the temp table variable
        -- the object name of this page
        select @objName=object_name(value,@database_id) from @tabtmp
            where field='Metadata: ObjectId'
 
        -- Update the temp table with the object name
        update #tmpResult set objectName=@objName
            where current of ct
 
        -- Clear the temp variable and
        -- get the next record
        delete @tabtmp 
        fetch next from ct into @database_id,@file_id,@page_id
end
        close ct
        deallocate ct
    -- Return the result
    select * from #tmpResult

go

