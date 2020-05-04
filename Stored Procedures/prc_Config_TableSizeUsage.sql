SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Config_TableSizeUsage
AS
BEGIN
/******************************************************************************************              
** Procedure: prc_Check_FileGroupSpace              
**                
** Purpose: This proc returns all the User tables on all databases with the rowcount, totalMB, indexMB, dataMB, unusedMB
**
*******************************************************************************
**  Created  08/22/2013 Chuck Lathrope
*******************************************************************************
**  Altered		By				Description
**  12/8/2014	Chuck Lathrope  Added non-readable AG database check
**  12/18/2015  Chuck Lathrope  Limited to primary and fully readable AG databases.
*******************************************************************************************/    

	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	              
	DECLARE @script nvarchar(max), @Database varchar(1000), @scriptFinal nvarchar(max)

	IF CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR), 1, 2), '.', '') AS TINYINT) > 10   
		DECLARE DatabaseCursor CURSOR FOR  
			SELECT d.name 
			FROM sys.databases d 
			LEFT JOIN sys.availability_replicas AS AR
			   ON d.replica_id = ar.replica_id
			LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
				ON ars.group_id = AR.group_id AND ars.replica_id = ar.replica_id
			LEFT JOIN sys.dm_hadr_database_replica_cluster_states AS dbcs
			   ON ars.replica_id = dbcs.replica_id and d.replica_id = dbcs.replica_id AND d.group_database_id = dbcs.group_database_id
			WHERE DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
			AND (ars.role = 1 OR ISNULL(AR.secondary_role_allow_connections,2) = 2) --Primary or able to read secondary db, no read-intent only dbs.
			AND database_id > 4
	ELSE
		DECLARE DatabaseCursor CURSOR FOR  
		SELECT d.name 
		FROM sys.databases d 
		WHERE DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
		and database_id > 4

	--List of db's done, let's get the rest done.
	SET @script = ''
	SET @scriptFinal = ''

	OPEN DatabaseCursor  
	FETCH NEXT FROM DatabaseCursor INTO @Database  
	WHILE @@FETCH_STATUS = 0  
	BEGIN             

		SET @script = 'SELECT ''' + @Database + ''' COLLATE SQL_Latin1_General_CP1_CI_AS as DatabaseName,
						c.name COLLATE SQL_Latin1_General_CP1_CI_AS  as SchemaName,
						CONVERT(VARCHAR(128), t.NAME) COLLATE SQL_Latin1_General_CP1_CI_AS  AS ObjectName,
						CONVERT(BIGINT, p.rows ) AS RowCounts,
						CONVERT(DECIMAL(10,2), CONVERT(DECIMAL(14,2), SUM(a.total_pages) * 8.00 )/1024.00) as TotalMB, 
						CONVERT(DECIMAL(10,2), CONVERT(DECIMAL(14,2), SUM(a.data_pages) * 8.00 )/1024.00) as DataMB, 
						CONVERT(DECIMAL(10,2), CONVERT(DECIMAL(14,2), SUM(a.used_pages) * 8.00 - SUM(a.data_pages) * 8.00) /1024.00) as IndexMB,
						CONVERT(DECIMAL(10,2), CONVERT(DECIMAL(14,2), (SUM(a.total_pages) - SUM(a.used_pages)) * 8.00 )/1024.00) as UnusedMB
					FROM 
						[' + @Database + '].sys.tables t
					INNER JOIN      
						[' + @Database + '].sys.indexes i ON t.OBJECT_ID = i.object_id
					INNER JOIN 
						[' + @Database + '].sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
					INNER JOIN 
						[' + @Database + '].sys.allocation_units a ON p.partition_id = a.container_id
					INNER JOIN 
						[' + @Database + '].sys.schemas c on c.schema_id = t.schema_id
					GROUP BY 
						t.Name, p.Rows, c.name' + CHAR(13) 
			
		IF @scriptFinal <> ''
			SET @scriptFinal = @scriptFinal + 'UNION ALL' + CHAR(13) 

		SET @scriptFinal = @scriptFinal + @script
		--PRINT @script
		FETCH NEXT FROM DatabaseCursor INTO @Database 
	END 
	
	CLOSE DatabaseCursor                
	DEALLOCATE DatabaseCursor

	SET @scriptFinal = @scriptFinal + CHAR(13) + 'ORDER BY TotalMB, Databasename, SchemaName, ObjectName'
	EXEC (@scriptFinal)
	
END;

GO
