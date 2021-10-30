USE Master
GO
IF object_id('sp_TableRowCount') IS NULL EXEC ('CREATE PROCEDURE dbo.sp_TableRowCount AS PRINT ''somehow proc wasnt updated''')
GO

ALTER PROCEDURE dbo.sp_TableRowCount
	@objname nvarchar(776)		-- the table to get rowcount from
AS

	SET NOCOUNT ON 
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT object_name(object_id) AS TableName, partition_number, row_count
	FROM sys.dm_db_partition_stats
	WHERE OBJECT_ID >= 100
	AND index_id IN (0,1)
	AND OBJECT_ID = OBJECT_ID(@objname)
go

exec sys.sp_MS_marksystemobject 'sp_TableRowCount'
GO
