USE master;
GO

IF (OBJECT_ID('dbo.sp_TableSizeUsage') IS NULL)
BEGIN
	EXEC('Create procedure dbo.sp_TableSizeUsage as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.sp_TableSizeUsage.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.sp_TableSizeUsage.'
	END
END
GO

/*=================================================================================================

Author:     Richard Ding
Created:    Mar. 03, 2008

Purpose:    View object size

Parameters: 
  @DbName:            default is the current database
  @SchemaName:        default is null showing all schemas
  @ObjectName:        default is "%" including all objects in "LIKE" clause
  @TopClause:         default is null showing all objects. Can be "TOP N" or "TOP N PERCENT"
  @ObjectType:        default is "S", "U", "V", "SQ" and "IT". All objects that can be sized
  @ShowInternalTable: default is "Yes", when listing IT, the Parent excludes it in size 
  @OrderBy:           default is by object name, can be any size related column
  @UpdateUsage:       default is 0, meaning "do not run DBCC UPDATEUSAGE" 

Examples:

   EXEC dbo.sp_TableSizeUsage;
   EXEC dbo.sp_TableSizeUsage 'AdventureWorks', NULL, '%', NULL, 'U', 'No', 'T', 1;
   EXEC dbo.sp_TableSizeUsage NULL, NULL, NULL, NULL, 'U', 'Yes', N'U', 1;
   EXEC dbo.sp_TableSizeUsage 'AdventureWorks', '%', 'transfer%', NULL, 'U', 'Yes', 'N', 0;
   EXEC dbo.sp_TableSizeUsage 'AdventureWorks', NULL, NULL, N'Top 100 Percent', 'S', 'yes', N'N', 1;
   EXEC dbo.sp_TableSizeUsage 'AdventureWorks', NULL, 'xml_index_nodes_309576141_32000', NULL, 'IT', 'yes', 'N', 1;
   EXEC dbo.sp_TableSizeUsage 'TRACE', NULL, 'Vw_DARS_217_overnight_activity_11142007', ' top 10 ', 'v', 'yes', 'N', 0;
   EXEC dbo.sp_TableSizeUsage 'AdventureWorks', NULL, 'xml%', ' top 10 ', null, 'yes', 'N', 1;
   EXEC dbo.sp_TableSizeUsage 'AdventureWorks2008', NULL, 'sales%', NULL, '  ,,;  u  ;;;,,  v  ', 'No', N'N', 1;
   EXEC dbo.sp_TableSizeUsage NULL, NULL, NULL, N'Top 100 Percent', ' ;;Q, U;V,', N'Y', 1;

Renamed from sp_SOS
11/30/2009	Chuck Lathrope	Changed edition check.
12/28/2009	Chuck Lathrope	Change @Version to tinyint
10/15/2012	Chuck Lathrope	Removed deprecated Compute by function.
12/13/2012	Chuck Lathrope	Fixed the proc for longest database names and with strange characters using [].
2/25/2015	Chuck Lathrope	Added @Logresults parameter to log to table.
//=================================================================================================*/
ALTER PROCEDURE dbo.sp_TableSizeUsage
  @DbName VARCHAR(100) = NULL,  
  @SchemaName sysname = NULL,  
  @ObjectName sysname = N'%',  
  @TopClause nvarchar(20) = NULL,
  @ObjectType nvarchar(50) = NULL,  
  @ShowInternalTable nvarchar(3) = NULL, 
  @OrderBy nvarchar(100) = 'R',  
  @UpdateUsage bit = 0 ,
  @LogResults BIT = 0
AS
BEGIN

SET NOCOUNT ON;

--  Input parameter validity checking
DECLARE @SELECT nvarchar(2500), 
        @WHERE_Schema nvarchar(200),
        @WHERE_Object nvarchar(200), 
        @WHERE_Type nvarchar(200), 
        @WHERE_Final nvarchar(1000), 
        @ID int, 
        @Version TINYINT, 
        @String nvarchar(4000), 
        @Count bigint,
        @GroupBy nvarchar(450);

IF ISNULL(@OrderBy, N'N') NOT IN (N'', N'N', N'R', N'T', N'U', N'I', N'D', N'F', N'Y')
  BEGIN
    RAISERROR (N'Incorrect value for @OrderBy. Valid parameters are: 
      ''N''  -->  Listing by object name 
      ''R''  -->  Listing by number of records  
      ''T''  -->  Listing by total size 
      ''U''  -->  Listing by used portion (excluding free space) 
      ''I''  -->  Listing by index size 
      ''D''  -->  Listing by data size
      ''F''  -->  Listing by unused (free) space 
      ''Y''  -->  Listing by object type ',  16, 1)
    RETURN (-1)
  END;

--  Object Type Validation and Clean up
DECLARE @OTV nvarchar(10), @OTC nvarchar(10);
SELECT @OTV = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@ObjectType, 
              N'S, U, V, SQ, IT'), N' ', N''), N',', N''), N';', N''), N'SQ', N''), N'U', N''), 
              N'V', N''), N'IT', N''), N'S', N'');
IF LEN(@OTV) <> 0    --  only allow comma, semi colon and space around S,U,V,SQ,IT
  BEGIN
    RAISERROR (N'Parameter error. Choose ''S'', ''U'', ''V'', ''SQ'', ''IT'' or any combination of them, 
separated by space, comma or semicolon.
  S   ->   System table;
  U   ->   User table;
  V   ->   Indexed view;
  SQ  ->   Service Queue;
  IT  ->   Internal Table',  16, 1)
    RETURN (-1)
  END
ELSE    --  passed validation
  BEGIN
    SET @OTC = UPPER(REPLACE(REPLACE(REPLACE(ISNULL(@ObjectType,N'S,U,V,SQ,IT'),N' ',N''),N',',N''),N';',N''))
    SELECT @ObjectType = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL
               (@ObjectType, N'S,U,V,SQ,IT'),N',',N''),N';',N''),N'SQ',N'''QQ'''),N'IT',N'''IT'''),N'S',
                             N'''S'''),N'U',N'''U'''),N'V',N'''V'''),N'QQ',N'SQ'),N' ',N''),N'''''',N''',''')
  END

----  common  ----
SELECT @DbName = ISNULL(@DbName, DB_NAME()), 
       @Version = CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR),1,2),'.','') as tinyint),
       @OrderBy = N'ORDER BY [' + 
                    CASE ISNULL(@OrderBy, N'N') 
                      WHEN N'N' THEN N'Object Name] ASC ' 
                      WHEN N'R' THEN N'Rows] DESC, [Object Name] ASC '
                      WHEN N'T' THEN N'Total(MB)] DESC, [Object Name] ASC '
                      WHEN N'U' THEN N'Used(MB)] DESC, [Object Name] ASC '
                      WHEN N'I' THEN N'Index(MB)] DESC, [Object Name] ASC '
                      WHEN N'D' THEN N'Data(MB)] DESC, [Object Name] ASC ' 
                      WHEN N'F' THEN N'Unused(MB)] DESC, [Object Name] ASC '
                      WHEN N'Y' THEN N'Type] ASC, [Object Name] ASC ' 
                    END;

-------------------  SQL 2k5+ ------------------------------------------------------
IF @Version >= 9
BEGIN
	SELECT @String = N' 
IF OBJECT_ID (''tempdb.dbo.##BO'', ''U'') IS NOT NULL
  DROP TABLE dbo.##BO 

CREATE TABLE dbo.##BO (
  ID int identity,
  DOI bigint null,        -- Daughter Object Id
  DON sysname null,       -- Daughter Object Name
  DSI int null,           -- Daughter Schema Id
  DSN sysname null,       -- Daughter Schema Name
  DOT varchar(10) null,   -- Daughter Object Type
  DFN sysname null,       -- Daughter Full Name
  POI bigint null,        -- Parent Object Id
  PON sysname null,       -- Parent Object Name
  PSI bigint null,        -- Parent Schema Id
  PSN sysname null,       -- Parent Schema Name
  POT varchar(10) null,   -- Parent Object Type
  PFN sysname null        -- Parent Full Name
) 

INSERT INTO dbo.##BO (DOI, DSI, DOT, POI)
  SELECT object_id, schema_id, type, Parent_object_id 
FROM [' + @DbName + N'].sys.objects o WHERE type IN (''S'',''U'',''V'',''SQ'',''IT'') 
USE [' + @DbName + N'] 
UPDATE dbo.##BO SET DON = object_name(DOI), DSN = schema_name(DSI), POI = CASE POI WHEN 0 THEN DOI ELSE POI END
UPDATE dbo.##BO SET PSI = o.schema_id, POT = o.type FROM sys.objects o JOIN dbo.##BO t ON o.object_id = t.POI
UPDATE dbo.##BO SET PON = object_name(POI), PSN = schema_name(PSI), DFN = DSN + ''.'' + DON, 
                    PFN = schema_name(PSI)+ ''.'' + object_name(POI)
'
	EXEC (@String)

	SELECT 
	@WHERE_Type = CASE WHEN ISNULL(@ShowInternalTable, N'Yes') = N'Yes' THEN N't.DOT ' ELSE N't.POT ' END,  
	@SELECT = N'USE [' + @DbName + N'] 
  SELECT ' + ISNULL(@TopClause, N'TOP 100 PERCENT ') + 
      N' CASE WHEN ''' + isnull(@ShowInternalTable, N'Yes') + N''' = ''Yes'' THEN CASE t.DFN WHEN t.PFN THEN t.PFN 
          ELSE t.DFN + '' (''+ t.PFN + '')'' END ELSE t.PFN END AS ''Object Name'', 
         ' + @WHERE_Type + N' AS ''Type'',
         SUM (CASE WHEN ''' + isnull(@ShowInternalTable, N'Yes') + N''' = ''Yes'' THEN 
           CASE WHEN (ps.index_id < 2 ) THEN ps.row_count ELSE 0 END
             ELSE CASE WHEN (ps.index_id < 2 and t.DON = t.PON) THEN ps.row_count ELSE 0 END END) AS ''Rows'',
         SUM (CASE WHEN t.DON NOT LIKE ''fulltext%'' OR t.DON LIKE ''fulltext_index_map%'' 
                THEN ps.reserved_page_count ELSE 0 END)* 8.000/1024 AS ''Total(MB)'',
         SUM (CASE WHEN t.DON NOT LIKE ''fulltext%'' OR t.DON LIKE ''fulltext_index_map%'' 
                THEN ps.reserved_page_count ELSE 0 END 
              - CASE WHEN t.DON NOT LIKE ''fulltext%'' OR t.DON LIKE ''fulltext_index_map%'' THEN 
                  ps.used_page_count ELSE 0 END)* 8.000/1024 AS ''Unused(MB)'',
	     SUM (CASE WHEN t.DON NOT LIKE ''fulltext%'' OR t.DON LIKE ''fulltext_index_map%'' 
                THEN ps.used_page_count ELSE 0 END)* 8.000/1024 AS ''Used(MB)'',
         SUM (CASE WHEN t.DON NOT LIKE ''fulltext%'' OR t.DON LIKE ''fulltext_index_map%'' 
                THEN ps.used_page_count ELSE 0 END
              - CASE WHEN t.POT NOT IN (''SQ'',''IT'') AND t.DOT IN (''IT'') and ''' + isnull(@ShowInternalTable, N'Yes')
                + N''' = ''No'' THEN 0 ELSE CASE WHEN (ps.index_id<2) 
                  THEN (ps.in_row_data_page_count+ps.lob_used_page_count+ps.row_overflow_used_page_count)
			    ELSE ps.lob_used_page_count + ps.row_overflow_used_page_count END END) * 8.000/1024 AS ''Index(MB)'',
	     SUM (CASE WHEN t.POT NOT IN (''SQ'',''IT'') AND t.DOT IN (''IT'') and ''' + isnull(@ShowInternalTable, N'Yes') 
	            + N''' = ''No'' THEN 0 ELSE CASE WHEN (ps.index_id<2) 
	              THEN (ps.in_row_data_page_count+ps.lob_used_page_count+ps.row_overflow_used_page_count)
			  ELSE ps.lob_used_page_count + ps.row_overflow_used_page_count END END) * 8.000/1024 AS ''Data(MB)''
    FROM sys.dm_db_partition_stats ps INNER JOIN dbo.##BO t
      ON ps.object_id = t.DOI 
',
	@ObjectType = CASE WHEN ISNULL(@ShowInternalTable, N'Yes') = N'Yes' THEN N'''IT'',' + ISNULL(@ObjectType, N'''S'',''U'', 
					''V'', ''SQ'', ''IT''') ELSE ISNULL(@ObjectType, N'''S'', ''U'', ''V'', ''SQ'', ''IT''') END,
	@WHERE_Schema = CASE WHEN ISNULL(@ShowInternalTable, N'Yes') = N'Yes' THEN N' t.DSN ' ELSE N' t.PSN ' END, -- DSN or PSN
	@WHERE_Object = CASE WHEN ISNULL(@ShowInternalTable, N'Yes') = N'Yes' THEN N' t.DON LIKE ''' + ISNULL(@ObjectName, N'%')
					+ ''' OR t.PON LIKE ''' + ISNULL(@ObjectName, N'%') + N''' ' 
					ELSE N' t.pon LIKE ''' + ISNULL(@ObjectName, N'%') + N''' ' END,      -- DON or PON
	@WHERE_Final = N' WHERE (' + @WHERE_Schema + N' LIKE ''' + ISNULL(@SchemaName, N'%') + N''' OR ' + @WHERE_Schema + 
				   N' = ''sys'') AND (' + @WHERE_Object + N' ) AND ' + @WHERE_Type + N' IN (' + @ObjectType + N') ',
	@GroupBy = N'GROUP BY CASE WHEN ''' + ISNULL(@ShowInternalTable, N'Yes') + N''' = ''Yes'' THEN CASE t.DFN WHEN t.PFN 
				THEN t.PFN ELSE t.DFN + '' (''+ t.PFN + '')'' END ELSE t.PFN END, ' + @WHERE_Type + N''
	SELECT @String =  @SELECT + @WHERE_Final + @GroupBy + @OrderBy
	 -- SELECT @String AS 'STRING'
END

-----  common  ------
IF OBJECT_ID(N'tempdb.dbo.##FO', N'U') IS NOT NULL
  DROP TABLE dbo.##FO;

CREATE TABLE dbo.##FO (
    ID int identity, 
    [Object Name] sysname, 
    [Type] varchar(2),
    [Rows] bigint, 
    [Total(MB)] dec(10,3), 
    [-] nchar(1), 
    [Unused(MB)] dec(10,3), 
    [==] nchar(2), 
    [Used(MB)] dec(10,3), 
    [=] nchar(1), 
    [Index(MB)] dec(10,3), 
    [+] nchar(1), 
    [Data(MB)] dec(10,3) );

INSERT INTO dbo.##FO ([Object Name], [Type], [Rows], [Total(MB)],[Unused(MB)],[Used(MB)],[Index(MB)],[Data(MB)])
  EXEC (@String);

SELECT @Count = COUNT(*) FROM dbo.##FO;

IF @Count = 0
  BEGIN
    RAISERROR (N'No records were found matching your criteria.',  16, 1)
    RETURN (-1)
  END
ELSE    -- There is at least one record
  BEGIN
    --  Run DBCC UPDATEUSAGE to correct wrong values 
    IF ISNULL(@UpdateUsage, 0) = 1 
      BEGIN
        SELECT @ObjectName = N'', @ID = 0 
          WHILE 1 = 1
		        BEGIN
		          SELECT TOP 1 @ObjectName = CASE WHEN [Object Name] LIKE N'%(%' THEN 
                     SUBSTRING([Object Name], 1, CHARINDEX(N'(', [Object Name])-2) ELSE [Object Name] END
                      , @ID = ID FROM dbo.##FO WHERE ID > @ID ORDER BY ID ASC
		          IF @@ROWCOUNT = 0
		            BREAK
              PRINT N'==> DBCC UPDATEUSAGE (' + @DbName + N', ''' + @ObjectName + N''') WITH COUNT_ROWS' 
			        DBCC UPDATEUSAGE (@DbName, @ObjectName) WITH COUNT_ROWS
              PRINT N''
		        END

          PRINT N''
        TRUNCATE TABLE dbo.##FO
        INSERT INTO dbo.##FO ([Object Name], [Type], [Rows], [Total(MB)],[Unused(MB)],
                              [Used(MB)],[Index(MB)],[Data(MB)]) EXEC (@String)
      END
    ELSE
      PRINT N'(Warning: Run "DBCC UPDATEUSAGE" on suspicious objects. It may incur overhead on big databases.)'
    PRINT N''

    IF @LogResults = 0 
	BEGIN
	    UPDATE dbo.##FO SET [-] = N'-', [==] = N'==', [=] = N'=', [+] = N'+'

		SELECT [Object Name], [Type], [Rows], [Total(MB)],[-], [Unused(MB)],[==], [Used(MB)],[=],
				[Index(MB)],[+],[Data(MB)] 
		FROM dbo.##FO ORDER BY ID ASC 
    END
	ELSE
		INSERT INTO dbops.dbo.DBTableSizeHistory (DBName, ObjectName,Type,Rows,TotalMB,UnusedMB,UsedMB,IndexMB,DataMB)
		SELECT ISNULL(@DbName,DB_NAME()), [Object Name], [Type], [Rows], [Total(MB)], [Unused(MB)], [Used(MB)], [Index(MB)],[Data(MB)] 
		FROM dbo.##FO
  END

END --Proc
go

