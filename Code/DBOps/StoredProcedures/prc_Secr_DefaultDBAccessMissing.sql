SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Secr_DefaultDBAccessMissing
AS
BEGIN
/**************************************************************************************
**  Procedure: prc_Secr_DefaultDBAccessMissing
**
**	Purpose: Find all users that have a default database where they can't connect to it.
**
**	12/03/2012	Matias Sincovich	Created
**	12/26/2012	Matias Sincovich	Added DB EXISTS validation
**	03/21/2013	Matias Sincovich	Modified to use on New Queue
**	06/10/2013	Matias Sincovich	Added database Offline validation
**  12/8/2014	Chuck Lathrope		Added non-readable AG database check
***************************************************************************************/
	SET NOCOUNT ON
	
	DECLARE @db NVARCHAR(512)
		, @script NVARCHAR(MAX)

	IF(OBJECT_ID('tempdb..#temp_principals') IS NOT NULL)
		drop table #temp_principals

	CREATE TABLE #temp_principals (
		[UserName] NVARCHAR(128) NULL,
		[sid] NVARCHAR(MAX) NULL,
		[default_database_name] NVARCHAR(512) NULL,
		[principal_id] [int] NULL,
		[Exist_in_DB] [int]
	) 

	INSERT INTO #temp_principals
		SELECT CONVERT(NVARCHAR(128), name) as UserName, master.dbo.fn_varbintohexstr(sid) as sid, CONVERT(NVARCHAR(512), default_database_name), principal_id, 0
		FROM master.sys.server_principals sp
		WHERE TYPE IN ('S' , 'U' , 'G')
		AND default_database_name <>'master'
		-- AND NOT IS SysAdmin
			AND NOT EXISTS(SELECT * FROM master.sys.server_role_members sr 
							WHERE sr.member_principal_id = sp.principal_id
								AND sr.role_principal_id = 3) 


	DECLARE cur_db_principals CURSOR FAST_FORWARD FOR
		SELECT DISTINCT default_database_name 
		FROM #temp_principals
		
	OPEN cur_db_principals
	FETCH NEXT FROM cur_db_principals INTO @db
	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		IF CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR),1, 2), '.', '') AS TINYINT) >= 12  
		IF NOT EXISTS(SELECT * 
			FROM sys.databases d 
			LEFT JOIN sys.availability_replicas AS AR
			   ON d.replica_id = ar.replica_id
			LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
				ON ars.group_id = AR.group_id AND ars.replica_id = ar.replica_id
			LEFT JOIN sys.dm_hadr_database_replica_cluster_states AS dbcs
			   ON ars.replica_id = dbcs.replica_id and d.replica_id = dbcs.replica_id AND d.group_database_id = dbcs.group_database_id
			WHERE DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
			AND (ars.role = 1 OR ISNULL(AR.secondary_role_allow_connections,1) > 0) --Primary or able to read secondary db
			AND d.name = @db)
		BEGIN
			UPDATE t
			SET Exist_in_DB = 0
			FROM #temp_principals t
			WHERE t.default_database_name = @db

			BREAK
		END
		ELSE
		IF NOT EXISTS(SELECT * 
			FROM sys.databases d 
			WHERE DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
			AND d.name = @db)
		BEGIN
			UPDATE t
			SET Exist_in_DB = 0
			FROM #temp_principals t
			WHERE t.default_database_name = @db

			BREAK
		END


		SET @script = ''
		SET @script = @script + ''
		SET @script = @script + 'UPDATE tmp '
		SET @script = @script + 'SET Exist_in_DB = CASE WHEN tmp.userName IS NULL THEN 0 ELSE 1 END '
		SET @script = @script + 'FROM [' + LTRIM(RTRIM(@db)) + '].sys.database_principals dp '
		SET @script = @script + '	LEFT JOIN #temp_principals tmp on tmp.sid = dp.sid '
		SET @script = @script + 'WHERE  Exist_in_DB NOT IN (1,2)'
		--SET @script = @script + 'WHERE dp.type IN (''S'' , ''U'' , ''G'') '
		EXEC (@script)

		
		FETCH NEXT FROM cur_db_principals INTO @db
	ENd -- WHILE
	CLOSE cur_db_principals
	DEALLOCATE cur_db_principals

	SELECT Username, sid, default_database_name, principal_id 
	FROM #temp_principals
	Where Exist_in_DB = 0

	DROP TABLE #temp_principals
END;

GO
