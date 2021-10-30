
USE [master];
GO
IF ( OBJECT_ID('dbo.sp_foreachdb') IS NULL ) 
    BEGIN
        EXEC('create procedure dbo.sp_foreachdb  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
        IF ( @@error = 0 ) 
            PRINT 'Successfully created empty stored procedure dbo.sp_foreachdb.'
        ELSE 
            BEGIN
                PRINT 'FAILED to create stored procedure dbo.sp_foreachdb.'
            END
    END
GO
/******************************************************************************************************
**  From: http://www.mssqltips.com/sqlservertip/2201/making-a-more-reliable-and-flexible-spmsforeachdb/
**  Modified:
**  8/29/2012   Chuck Lathrope  Not include insert exec as I get nested insert exec errors with some processes.
**	12/8/2014	Chuck Lathrope	Added non-readable AG database check
******************************************************************************************************/
ALTER PROCEDURE dbo.sp_foreachdb
   @command             NVARCHAR(MAX),
   @replace_character   NCHAR(1)       = N'?',
   @print_dbname        BIT            = 0,
   @print_command_only  BIT            = 0,
   @suppress_quotename  BIT            = 0
   --,
   --@system_only         BIT            = NULL,
   --@user_only           BIT            = NULL,
   --@name_pattern        NVARCHAR(300)  = N'%', 
   --@database_list       NVARCHAR(MAX)  = NULL,
   --@recovery_model_desc NVARCHAR(120)  = NULL,
   --@compatibility_level TINYINT        = NULL,
   --@state_desc          NVARCHAR(120)  = N'ONLINE',
   --@is_read_only        BIT            = 0,
   --@is_auto_close_on    BIT            = NULL,
   --@is_auto_shrink_on   BIT            = NULL,
   --@is_broker_enabled   BIT            = NULL
AS
BEGIN
   SET NOCOUNT ON;

   DECLARE
       @sql    NVARCHAR(MAX),
       @dblist NVARCHAR(MAX),
       @db     NVARCHAR(300),
       @i      INT;

   --IF @database_list > N''
   --BEGIN
   --    ;WITH n(n) AS 
   --    (
   --        SELECT ROW_NUMBER() OVER (ORDER BY s1.name) - 1
   --         FROM sys.objects AS s1 
   --         CROSS JOIN sys.objects AS s2
   --    )
   --    SELECT @dblist = REPLACE(REPLACE(REPLACE(x,'</x><x>',','),
   --        '</x>',''),'<x>','')
   --    FROM 
   --    (
   --        SELECT DISTINCT x = 'N''' + LTRIM(RTRIM(SUBSTRING(
   --         @database_list, n,
   --         CHARINDEX(',', @database_list + ',', n) - n))) + ''''
   --         FROM n WHERE n <= LEN(@database_list)
   --         AND SUBSTRING(',' + @database_list, n, 1) = ','
   --         FOR XML PATH('')
   --    ) AS y(x);
   --END

   CREATE TABLE #x(db NVARCHAR(300));

   --SET @sql = N'SELECT name FROM sys.databases WHERE 1=1'
   --    + CASE WHEN @system_only = 1 THEN 
   --        ' AND database_id IN (1,2,3,4)' 
   --        ELSE '' END
   --    + CASE WHEN @user_only = 1 THEN 
   --        ' AND database_id NOT IN (1,2,3,4)' 
   --        ELSE '' END
   --    + CASE WHEN @name_pattern <> N'%' THEN 
   --        ' AND name LIKE N''%' + REPLACE(@name_pattern, '''', '''''') + '%''' 
   --        ELSE '' END
   --    + CASE WHEN @dblist IS NOT NULL THEN 
   --        ' AND name IN (' + @dblist + ')' 
   --        ELSE '' END
   --    + CASE WHEN @recovery_model_desc IS NOT NULL THEN
   --        ' AND recovery_model_desc = N''' + @recovery_model_desc + ''''
   --        ELSE '' END
   --    + CASE WHEN @compatibility_level IS NOT NULL THEN
   --        ' AND compatibility_level = ' + RTRIM(@compatibility_level)
   --        ELSE '' END
   --    + CASE WHEN @state_desc IS NOT NULL THEN
   --        ' AND state_desc = N''' + @state_desc + ''''
   --        ELSE '' END
   --    + CASE WHEN @is_read_only IS NOT NULL THEN
   --        ' AND is_read_only = ' + RTRIM(@is_read_only)
   --        ELSE '' END
   --    + CASE WHEN @is_auto_close_on IS NOT NULL THEN
   --        ' AND is_auto_close_on = ' + RTRIM(@is_auto_close_on)
   --        ELSE '' END
   --    + CASE WHEN @is_auto_shrink_on IS NOT NULL THEN
   --        ' AND is_auto_shrink_on = ' + RTRIM(@is_auto_shrink_on)
   --        ELSE '' END
   --    + CASE WHEN @is_broker_enabled IS NOT NULL THEN
   --        ' AND is_broker_enabled = ' + RTRIM(@is_broker_enabled)
   --        ELSE '' END;

   --INSERT #x EXEC sp_executesql @sql;
   
   INSERT #x (db)
   SELECT name FROM sys.databases
   
   DECLARE c CURSOR 
       LOCAL FORWARD_ONLY STATIC READ_ONLY
       FOR SELECT name FROM sys.databases d 
			LEFT JOIN sys.availability_replicas AS AR
			   ON d.replica_id = ar.replica_id
			LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
				ON ars.group_id = AR.group_id AND ars.replica_id = ar.replica_id
			LEFT JOIN sys.dm_hadr_database_replica_cluster_states AS dbcs
			   ON ars.replica_id = dbcs.replica_id and d.replica_id = dbcs.replica_id AND d.group_database_id = dbcs.group_database_id
			WHERE DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
			AND (ars.role = 1 OR ISNULL(AR.secondary_role_allow_connections,1) > 0) --Primary or able to read secondary db
			ORDER BY name

   OPEN c;

   FETCH NEXT FROM c INTO @db;

   WHILE @@FETCH_STATUS = 0
   BEGIN
       SET @sql = REPLACE(@command, @replace_character, @db);

       BEGIN
           EXEC sp_executesql @sql;
       END

       FETCH NEXT FROM c INTO @db;
   END

   CLOSE c;
   DEALLOCATE c;
END
GO 
