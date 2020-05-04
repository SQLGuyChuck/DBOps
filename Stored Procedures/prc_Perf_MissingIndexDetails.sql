SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Perf_MissingIndexDetails 
	@DBName VARCHAR(128) = NULL
AS
BEGIN
/******************************************************************************
**  Name: prc_Perf_MissingIndexDetails
**  Desc: Gather missing index details from the dmv views for SQL 2008+
**
*******************************************************************************
**  Change History
*******************************************************************************
**  Date:		Author:			Description:
**  1/24/2013	Chuck Lathrope	Created
*******************************************************************************/
	SELECT db_name(mid.database_id) as DBName
		, object_name(mid.[object_id], mid.database_id) As ObjectName
		,'CREATE INDEX [missing_index_' + CONVERT (varchar, mig.index_group_handle) + '_' + CONVERT (varchar, mid.index_handle) 
		+ '_' + LEFT (PARSENAME(mid.statement, 1), 32) + ']'
		+ ' ON ' + mid.statement 
		+ ' (' + ISNULL (mid.equality_columns,'') 
		+ CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END 
		+ ISNULL (mid.inequality_columns, '')
		+ ')' 
		+ ISNULL (' INCLUDE (' + mid.included_columns + ')', '') AS create_index_statement
		, migs.avg_user_impact
		, migs.unique_compiles
		, migs.user_seeks
		, migs.user_scans
		, migs.last_user_seek
		, (select create_date from master.sys.databases where name = 'tempdb') as SQLStartUpDate
	FROM sys.dm_db_missing_index_groups mig
		INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
		INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
	WHERE (convert(float,migs.avg_user_impact) > 50 OR migs.avg_total_user_cost > 100)
		AND migs.avg_total_user_cost >= 1
		AND (@DBName IS NULL OR db_name(mid.database_id) LIKE @DBName)
	ORDER BY migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC
END;
GO
