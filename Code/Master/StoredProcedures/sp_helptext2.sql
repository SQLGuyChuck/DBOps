USE master;
GO

IF (OBJECT_ID('dbo.sp_helptext2') IS NULL)
BEGIN
	EXEC('Create procedure dbo.sp_helptext2 as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.sp_helptext2.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.sp_helptext2.'
	END
END
GO

/******************************************************************************
**		Name: sp_helptext2
**		Desc:
**    
**		Return values: For SQL 2012 tools, sp_helptext returns extra line feeds in grid view.
**
**		Called by:
**
**		Auth: http://stackoverflow.com/questions/11061642/sql-server-2012-sp-helptext-extra-lines-issue
**		Date: 1/3/2013 
*******************************************************************************
**		Change History
*******************************************************************************
**		Date:		Author:				Description:
**		
**    
*******************************************************************************/

ALTER PROCEDURE [dbo].[sp_helptext2] (
	 @ProcName NVARCHAR(256)
	)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE	@PROC_TABLE TABLE (X1 NVARCHAR(MAX))
	DECLARE	@ProcLines TABLE (
			PLID INT IDENTITY(1, 1),
			Line NVARCHAR(MAX)
		)
	
	DECLARE	@Proc NVARCHAR(MAX),
		@Procedure NVARCHAR(MAX)


	SELECT	@Procedure = 'SELECT DEFINITION FROM ' + DB_NAME()
			+ '.SYS.SQL_MODULES WHERE OBJECT_ID = OBJECT_ID('''
			+ @ProcName + ''')'

	INSERT	INTO @PROC_TABLE
			(X1)
			EXEC (@Procedure
				)

	SELECT	@Proc = X1
	FROM	@PROC_TABLE

	WHILE CHARINDEX(CHAR(13) + CHAR(10), @Proc) > 0
	BEGIN
		INSERT	@ProcLines
		SELECT	LEFT(@Proc, CHARINDEX(CHAR(13) + CHAR(10), @Proc) - 1)
		SELECT	@Proc = SUBSTRING(@Proc,
									CHARINDEX(CHAR(13) + CHAR(10), @Proc)
									+ 2, LEN(@Proc))
	END
--* inserts last line
	INSERT	@ProcLines
	SELECT	@Proc;

	SELECT	Line
	FROM	@ProcLines
	ORDER BY PLID
END

