USE master
GO
IF (OBJECT_ID('dbo.sp_killconnectedstaleusers') IS NULL)
BEGIN
	EXEC('Create procedure dbo.sp_killconnectedstaleusers  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.sp_killconnectedstaleusers.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.sp_killconnectedstaleusers.'
	END
END
GO

/*************************************************************************** 
-- 	disconnect all users that are connected to the passed in database
-- exec sp_killconnectedstaleusers 'idxuser'
***************************************************************************/

ALTER PROCEDURE dbo.sp_killconnectedstaleusers @login AS VARCHAR(20)
AS
BEGIN

	SET NOCOUNT ON

	CREATE TABLE #who (
		 spid VARCHAR(5) NULL,
		 status VARCHAR(50) NULL,
		 loginname VARCHAR(50) NULL,
		 hostname VARCHAR(50) NULL,
		 blk VARCHAR(5) NULL,
		 dbname VARCHAR(50) NULL,
		 cmd VARCHAR(50) NULL,
		 CPUTime VARCHAR(15) NULL,
		 DISKIO VARCHAR(15) NULL,
		 LASTBatch VARCHAR(50) NULL,
		 ProgramName VARCHAR(50) NULL,
		 SPID2 VARCHAR(5) NULL,
		 request_id VARCHAR(50) NULL
		)

	DECLARE	@spid INT
	DECLARE	@command VARCHAR(50)

	INSERT	INTO #who
			(spid,
			 status,
			 loginname,
			 hostname,
			 blk,
			 dbname,
			 cmd,
			 CPUTime,
			 DISKIO,
			 LASTBatch,
			 ProgramName,
			 SPID2,
			 request_id
			)
			EXEC sp_who2


	DECLARE cs_kill CURSOR READ_ONLY FAST_FORWARD
	FOR
	SELECT	spid
	FROM	#who
	WHERE	loginname = @login
			AND status = 'sleeping'

	OPEN cs_kill 

	FETCH NEXT FROM cs_kill INTO @spid

	WHILE @@fetch_status = 0
	BEGIN
		SET @command = 'kill ' + CONVERT(VARCHAR, @spid)
		EXEC (@command)
		FETCH NEXT FROM cs_kill INTO @spid
	END

	CLOSE cs_kill
	DEALLOCATE cs_kill
	DROP TABLE #who

END
