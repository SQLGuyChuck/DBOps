USE master
GO
IF (OBJECT_ID('dbo.sp_FindStrInObJ') IS NULL)
BEGIN
      EXEC('Create procedure dbo.sp_FindStrInObJ  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
      IF (@@error = 0)
            PRINT 'Successfully created empty stored procedure dbo.sp_FindStrInObJ.'
      ELSE
      BEGIN
            PRINT 'FAILED to create stored procedure dbo.sp_FindStrInObJ.'
      END
END
GO


/*
-- 
--  By Fardad Kordmahaleh (far...@acm.org), Would u Email me if you use this sp and like it? 
--     8/13/03 Mostly Taken from Sp_Helptext 
-- 
--  sp_FindStrInObj 
-- 
--Finds a passed string in the body of all stored procedures (P), 
--user-defined functions (F), triggers (T) or views (V) of your current Database. 
-- 
--Syntax 
--sp_FindStrInObj [ @FindStr = ] 'SearchString' ,  [ @ObjList = ] 'ObjTypes' 
-- 
--Arguments 
-- 
--[ @FindStr = ] 'SearchString' 
-- 
--Is the string to be searched in the object types specified by the next argument. 
-- 
-- 
--[ @ObjList = ] 'ObjTypes'               'P', 'F' , 'T' , 'V' or any combination 
-- 
--Optional, Default will search all stored procedures (P),user-defined functions (F), triggers (T) 
--and views (V) of your current Database. Passing a string with 'P', 'F' , 'T' , 'V' or any 
--combination of all of them will search the passed object type(s).   
-- 
-- 
--Return Code Values 
--0 (success) or 1 (failure) 
-- 
--Remark: It does not work with Encrypted Stored procs 
-- Known Problem: For Objects that are not dbo owned, where sp_helptext does not work this proc does not work either 
--  I have encountered this problem in version 7 
-- Does not work if Sp_helpText fails 
-- 
-- Eaxamples: 
-- 
-- sp_FindStrInObj  '"' 
--      Finds all " characters in all stored procs, functions, triggers and views of the 
--         current database     
-- 
-- sp_FindStrInObj 'fardad'   , 'P' 
--      Finds all occurences of 'fardad' in all stored procs of the current database         
-- 
-- 
-- sp_FindStrInObj '01/15/02' , 'PT' 
--      Finds all occurences of '01/15/02' in all stored procs & Triggers of the current database     
-- 
*/

Alter procedure dbo.sp_FindStrInObJ
	 @FindStr char(110) =NULL 
	,@ObjList char(20)  = NULL 
	,@columnname sysname = NULL 
AS

set nocount on 

declare @dbname sysname 
,@BlankSpaceAdded   int 
,@BasePos       int 
,@CurrentPos    int 
,@TextLength    int 
,@LineId        int 
,@AddOnLen      int 
,@LFCR          int --lengths of line feed carriage return 
,@DefinedLength int 
/* NOTE: Length of @SyscomText is 4000 to replace the length of 
** text column in syscomments. 
** lengths on @Line, #CommentText Text column and 
** value for @DefinedLength are all 255. These need to all have 
** the same values. 255 was selected in order for the max length 
** display using down level clients 
*/ 
,@SyscomText    nvarchar(4000) 
,@Line          nvarchar(255) 


declare @MyLineNo   int, 
        @MaxLineNo   int, 
        @STRLoc      int, 
        @InstsFound int, 
        @TotInstsFound int, 
        @objname nvarchar(776), 
        @ObjtypeCd   char(2), 
        @ObjtypeDesc char(25), 
        @TotObjsfound int 


-- error  checking 
if @FindStr is NULL 
begin 
   select 'You must give me a string to find!!! Usage: sp_FindStrInObJ '+char(39) +'XYZ'+char(39)+' , '+char(39)+'FVP'+char(39) 
   return (1) 
end 


--init 
select @TotObjsfound=0 
, @TotInstsFound=0 
-- not using this so turn it off 
, @columnname = null 


--select @ObjList 
CREATE TABLE #Objlist (ObjType char(2), Desctxt char(25)) 
if @objList is Null  -- default is all values 
begin 
   insert #Objlist values ('FN', 'Function') 
   insert #Objlist values ('P' , 'Stored Procedure') 
   insert #Objlist values ('TR', 'Trigger') 
   insert #Objlist values ('V' , 'View') 
end 
else 
begin 
   if charindex('FN',@objList,0)<>0    insert #Objlist values ('FN', 'Function') 
   if charindex('F',@objList,0)<>0    insert #Objlist values ('FN', 'Function') 
   if charindex('Function',@objList,0)<>0    insert #Objlist values ('FN', 'Function') 
   if charindex('Fun',@objList,0)<>0    insert #Objlist values ('FN', 'Function') 

   if charindex('P',@objList,0)<>0     insert #Objlist values ('P','Stored Procedure') 
   if charindex('Proc',@objList,0)<>0     insert #Objlist values ('P','Stored Procedure') 
   if charindex('sp',@objList,0)<>0     insert #Objlist values ('P','Stored Procedure') 

   if charindex('TR',@objList,0)<>0    insert #Objlist values ('TR', 'Trigger') 
   if charindex('T',@objList,0)<>0    insert #Objlist values ('TR', 'Trigger') 
   if charindex('TRigger',@objList,0)<>0    insert #Objlist values ('TR', 'Trigger') 

   if charindex('V',@objList,0)<>0     insert #Objlist values ('V', 'View') 
   if charindex('View',@objList,0)<>0     insert #Objlist values ('V', 'View') 
   if charindex('Vu',@objList,0)<>0     insert #Objlist values ('V', 'View') 
end 


if (select count(*) from #Objlist) =0 
begin 
   select ' The object types you passed are not known, use P (procedure), F (Function), T (Trigger) or V (View)!!! Usage: sp_FindStrInObJ '+char(39) 
+'XYZ'+char(39)+' , '+char(39)+'FVP'+char(39) 
   return (1) 
end 

--select top 100 * from sysobjects where type in ('p','f','t','v')

DECLARE xxx CURSOR FOR 
  select name, type from sysobjects where type in (select objtype from #objlist) order by type, name 
  for read only 
OPEN xxx 
FETCH NEXT FROM xxx INTO @objname , @ObjtypeCd 
WHILE @@FETCH_STATUS = 0 
BEGIN 

	SELECT   @ObjtypeDesc = 
		  CASE  @ObjtypeCd 
			 WHEN 'FN' THEN  'User-defined Function' 
			 WHEN 'P' THEN   'Stored Proc' 
			 WHEN 'TR' THEN  'Trigger' 
			 WHEN 'V' THEN   'View' 
			 ELSE 'unknown Type, are we at SQL Server 2010!!!!' 
		  END 

	-- initializing 
	select @MyLineNo=0 
	, @MaxLineNo=0 
	, @STRLoc=0 
	, @InstsFound = 0 
	, @BlankSpaceAdded  =0 
	, @BasePos       =0 
	, @CurrentPos    =0 
	, @TextLength    =0 
	, @LineId        =0 
	, @AddOnLen      =0 
	, @LFCR          =0 
	, @DefinedLength =0 
	, @SyscomText      =Null --nvarchar(4000) 
	, @Line          = Null --nvarchar(255) 
	, @DefinedLength = 255 
	, @BlankSpaceAdded = 0 /*Keeps track of blank spaces at end of lines. Note Len function ignores 
								 trailing blank spaces*/ 
	CREATE TABLE #CommentText 
	(LineId int, [Text] nvarchar(255)) 


	/* 
	**  Make sure the @objname is local to the current database. 
	*/ 
	select @dbname = parsename(@objname,3) 


	if @dbname is not null and @dbname <> db_name() 
	begin 
		raiserror(15250,-1,-1) 
		return (1) 
	end 


	/* 
	**  See if @objname exists. 
	*/ 
	if (object_id(@objname) is null) 
	begin 
			select @dbname = db_name() 
			raiserror(15009,-1,-1,@objname,@dbname) 
			return (1) 
	end 


	/* 
	**  Find out how many lines of text are coming back, 
	**  and return if there are none. 
	*/ 
	if (select count(*) from syscomments c, sysobjects o where o.xtype not in ('S', 'U') 
		and o.id = c.id and o.id = object_id(@objname)) = 0 
			begin 
					raiserror(15197,-1,-1,@objname) 
					return (1) 
			end 
	if (select count(*) from syscomments where id = object_id(@objname) 
		and encrypted = 0) = 0 
			begin 
					raiserror(15471,-1,-1) 
					return (0) 
			end 


	DECLARE ms_crs_syscom  CURSOR LOCAL 
	FOR SELECT /*'Booo  2--> ' +*/ text FROM syscomments WHERE id = OBJECT_ID(@objname) and encrypted = 0 
			ORDER BY number, colid 
	FOR READ ONLY 

/* 
**  Else get the text. 
*/ 
SELECT @LFCR = 2 
, @LineId = 1 

OPEN ms_crs_syscom 

FETCH NEXT FROM ms_crs_syscom into @SyscomText 

WHILE @@fetch_status >= 0 
BEGIN 

    SELECT  @BasePos    = 1 
    ,  @CurrentPos = 1 
    ,  @TextLength = LEN(@SyscomText) 


    WHILE @CurrentPos  != 0 
    BEGIN 
        --Looking for end of line followed by carriage return 
        SELECT @CurrentPos =   CHARINDEX(char(13)+char(10), @SyscomText, @BasePos) 


        --If carriage return found 
        IF @CurrentPos != 0 
        BEGIN 
            /*If new value for @Lines length will be > then the 
            **set length then insert current contents of @line 
            **and proceed. 
            */ 
            While (isnull(LEN(@Line),0) + @BlankSpaceAdded + @CurrentPos- @BasePos + @LFCR) > @DefinedLength 
            BEGIN 
                SELECT @AddOnLen = @DefinedLength-(isnull(LEN(@Line),0) + @BlankSpaceAdded) 
                INSERT #CommentText VALUES 
                ( @LineId, 
                  isnull(@Line, N'') + isnull(SUBSTRING(@SyscomText, @BasePos, @AddOnLen), N'')) 
                SELECT @Line = NULL, @LineId = @LineId + 1, 
                       @BasePos = @BasePos + @AddOnLen, @BlankSpaceAdded = 0 
            END 
            SELECT @Line    = isnull(@Line, N'') + isnull(SUBSTRING (@SyscomText, @BasePos, @CurrentPos-@BasePos + @LFCR), N'') 
            SELECT @BasePos = @CurrentPos+2 
            INSERT #CommentText VALUES( @LineId, @Line ) 
            SELECT @LineId = @LineId + 1 
            SELECT @Line = NULL 
        END 
        ELSE 
        --else carriage return not found 
        BEGIN 
            IF @BasePos <= @TextLength 
            BEGIN 
                /*If new value for @Lines length will be > then the 
                **defined length 
                */ 
                While (isnull(LEN(@Line),0) + @BlankSpaceAdded + @TextLength- @BasePos+1 ) > @DefinedLength 
                BEGIN 
                    SELECT @AddOnLen = @DefinedLength - (isnull(LEN(@Line),0) + @BlankSpaceAdded) 
                    INSERT #CommentText VALUES 
                    ( @LineId, 
                      isnull(@Line, N'') + isnull(SUBSTRING(@SyscomText, @BasePos, @AddOnLen), N'')) 
                    SELECT @Line = NULL, @LineId = @LineId + 1, 
                        @BasePos = @BasePos + @AddOnLen, @BlankSpaceAdded = 0 
                END 
                SELECT @Line = isnull(@Line, N'') + isnull(SUBSTRING (@SyscomText, @BasePos, @TextLength-@BasePos+1 ), N'') 
                if LEN(@Line) < @DefinedLength and charindex(' ', @SyscomText, @TextLength+1 ) > 0 
                BEGIN 
                    SELECT @Line = @Line + ' ', @BlankSpaceAdded = 1 
                END 
            END 
        END 
    END 


   FETCH NEXT FROM ms_crs_syscom into @SyscomText 
END 


IF @Line is NOT NULL 
    INSERT #CommentText VALUES( @LineId, @Line ) 


--select  lineid, Text from #CommentText order by LineId 


select @MyLineNo=0 
	, @InstsFound = 0 
select @MaxLineNo= max(lineid) from #CommentText 

WHILE @MyLineNo <= @MaxLineNo 
BEGIN 
   select @STRLoc=charindex(ltrim(rtrim(@FindStr)),text,0) from #CommentText   
where Lineid = @MyLineNo 
   if ( @STRLoc <> 0)   
   begin 
--    select  lineid as 'Line No', Text as 'Line' from #CommentText  where Lineid = @MyLineNo order by LineId 
      select  ltrim(rtrim(str(lineid))) as 'Line No', ltrim(rtrim(Text)) 
as 'Line' from #CommentText  where Lineid = @MyLineNo order by LineId 
      select @InstsFound = @InstsFound + 1 
   end 
   select @MyLineNo = @MyLineNo + 1 
END 


select @TotInstsFound = @TotInstsFound + @InstsFound 


if ( @InstsFound > 0)   
begin 
   select str(@InstsFound)+' Instance(s) of >'+ltrim(rtrim(@FindStr))+'< were 
found in '+rtrim(@ObjtypeDesc)+': '+@objname+' in '+db_name()+char(10)+char(10) 
+char(10)+char(10) 
--   select char(10)+char(10)+char(10) 
   select @TotObjsfound = @TotObjsfound + 1 
end 
--else 
--begin 
--   select 'No Instance(s) of >'+ltrim(rtrim(@FindStr))+'< were found in '+rtrim(@ObjtypeDesc)+'(s) in '+db_name() 
--   select char(10)+char(10)+char(10) 
--end 

CLOSE  ms_crs_syscom 
DEALLOCATE      ms_crs_syscom 

DROP TABLE      #CommentText 

FETCH NEXT FROM xxx INTO @objname , @ObjtypeCd 
END 

CLOSE xxx 
DEALLOCATE xxx 

select distinct desctxt as 'The object(s) searched were of the following types: ' from #objlist 

drop table #Objlist 

select 'Total of '+ltrim(rtrim(str(@TotInstsFound)))+' Instance(s) of >'+ltrim 
(rtrim(@FindStr))+'< were found in '+ltrim(rtrim(str(@TotObjsfound)))+' Object 
(s), in '+db_name()+' database.' as 'SUMMARY:' 


return (0) 
GO 




