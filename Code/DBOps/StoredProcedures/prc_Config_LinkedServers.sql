CREATE OR ALTER PROCEDURE dbo.prc_Config_LinkedServers
AS
BEGIN
	DECLARE @query varchar(MAX)
	SET @query = ''
	
	SET @query = 'SELECT name,product,provider,provider_string,connect_timeout
		, query_timeout,is_linked,is_remote_login_enabled, is_rpc_out_enabled
		, is_data_access_enabled, is_collation_compatible
		, uses_remote_collation, collation_name,lazy_schema_validation
		, is_publisher, is_subscriber,is_nonsql_subscriber'
	
	IF (CONVERT(decimal(5,2),LEFT(Cast(SERVERPROPERTY('ProductVersion') As Varchar), 4)) > 9 )  
		SET @query = @query + ' , is_remote_proc_transaction_promotion_enabled '
	ELSE
		SET @query = @query + ' , NULL as is_remote_proc_transaction_promotion_enabled '
	
	SET @query = @query + ' , modify_date
				FROM master.sys.servers
				WHERE is_system = 0 '
	
	EXEC (@query)
END;
GO


