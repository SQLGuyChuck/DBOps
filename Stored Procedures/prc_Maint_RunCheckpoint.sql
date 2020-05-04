SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE dbo.prc_Maint_RunCheckpoint
	@PercentinUse Varchar(2) = '20' --As a varchar to make coding easier.
AS 
BEGIN   
/******************************************************************************    
**  Name: prc_Maint_RunCheckpoint    
**  Desc: It runs checkpoint command against a db if over @PercentinUse % log space in use.
**      
**  Return values: Nothing   
**
*******************************************************************************    
**  Change History    
*******************************************************************************    
**  Date:		Author:			Description:    
**  08/16/2013	Chuck Lathrope  Created
*******************************************************************************/  
SET NOCOUNT ON  

CREATE TABLE #Commands
    (
      Command VARCHAR(max)
    )  

DECLARE @Pointer INT ,
    @SQL VARCHAR(max)

SET @Pointer = 1  

DECLARE @DBList TABLE
    (
      ID INT IDENTITY(1, 1) ,
      CommandToRun VARCHAR(max)
    )
	  
DECLARE @Checkpoints TABLE
    (
      ID INT IDENTITY(1, 1) ,
      CommandToRun VARCHAR(max)
    )  

INSERT  INTO @DBList ( CommandToRun )
SELECT  'USE [' + [name] + '] 
SELECT ''USE [' + [name] + '];Checkpoint''
FROM sys.database_files f (NOLOCK) 
WHERE type_desc = ''log''
AND ((size/128.0)-(size/128.0 - FILEPROPERTY(f.name, ''SpaceUsed'')/128.0))*100./(size/128.0) > ' + @PercentinUse + '
AND (size/128.0) > 1000'
FROM    master.sys.sysdatabases
WHERE   DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
AND DBID > 4

WHILE @Pointer <= ( SELECT MAX(ID) FROM @DBList ) 
BEGIN  

    SELECT  @SQL = CommandToRun
    FROM    @DBList
    WHERE   ID = @Pointer  

	--Print @SQL
    INSERT  INTO #Commands ( Command )
    EXEC ( @SQL )  

    SET @Pointer = @Pointer + 1  
END  

IF EXISTS (SELECT * FROM #Commands)
BEGIN
	--Now to run the checkpoint commands:
	SELECT @Pointer = 1, @SQL = NULL

	INSERT  INTO @Checkpoints ( CommandToRun )
	Select Command from #Commands

	WHILE @Pointer <= ( SELECT MAX(ID) FROM @Checkpoints ) 
	BEGIN  

		SELECT  @SQL = CommandToRun
		FROM    @Checkpoints
		WHERE   ID = @Pointer  

		--Just so you can see what was run:
		SELECT @SQL as SQLRun

		EXEC ( @SQL )  

		SET @Pointer = @Pointer + 1  
	END  
END
END--proc  
;
GO
