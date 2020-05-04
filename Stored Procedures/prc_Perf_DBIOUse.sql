SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Perf_DBIOUse (
	 @IgnoreRowCountCheck BIT = 0
	)
AS
BEGIN
/*************************************************************************************************
**	Name: prc_Perf_DBIOUse
**	Desc: Get File IO information for all database files.
**  Taken from Inside SQL Server 2005 T-SQL Querying.
**  
**	Created 8-21-2006	Chuck Lathrope
*************************************************************************************************/

	SET NOCOUNT ON;

	WITH	DBIO
		AS (SELECT	DB_NAME(IVFS.database_id) AS db,
					CASE WHEN MF.type = 1 THEN 'log'
							ELSE 'data'
					END AS file_type,
					SUM(IVFS.num_of_bytes_read
						+ IVFS.num_of_bytes_written) AS io,
					SUM(IVFS.io_stall) AS io_stall
			FROM		sys.dm_io_virtual_file_stats(NULL, NULL) AS IVFS
			JOIN		sys.master_files AS MF ON IVFS.database_id = MF.database_id
												AND IVFS.file_id = MF.file_id
			GROUP BY	DB_NAME(IVFS.database_id),
					MF.type
			)
	SELECT	ROW_NUMBER() OVER (ORDER BY io_stall DESC) AS rn,
			db,
			file_type,
			CAST(1. * io / (1024 * 1024) AS DECIMAL(12, 2)) AS io_mb,
			CAST(io_stall / 1000. AS DECIMAL(12, 2)) AS io_stall_s,
			CAST(100. * io_stall / SUM(io_stall) OVER () AS DECIMAL(10,
														2)) AS io_stall_pct
	FROM	DBIO
	ORDER BY io_stall DESC

END --Proc creation.

;
GO
