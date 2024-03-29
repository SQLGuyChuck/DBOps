IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'prc_Check_CodeAuditing' And ROUTINE_SCHEMA = 'dbo')
BEGIN
	EXEC('CREATE Procedure dbo.prc_Check_CodeAuditing as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.prc_Check_CodeAuditing.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.prc_Check_CodeAuditing.'
	END
END
GO

ALTER PROCEDURE dbo.prc_Check_CodeAuditing
	@person_to_notify varchar(1000) = 'alerts@yourdomainname.com'

AS
BEGIN
/******************************************************************************  
**  Name: prc_Check_CodeAuditing.sql  
**  Desc: This will send out an email with the list of common mistakes like
**        OpenQuery, Select into #, grant execute on and sp_oa
**    
*******************************************************************************  
**  Change History  
*******************************************************************************  
**  Date:		Author:			Description:  
**  01/13/2009  Ganesh			Created  
**  02/19/2011  Chuck Lathrope	Removed system, DBOPS and litespeed databases.
**	4/25/2011	Chuck Lathrope	Removed more databases.
**  12/8/2014	Chuck Lathrope  Added non-readable AG database check
*******************************************************************************/
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @tableHTML NVARCHAR(MAX)
		, @tableHTML1 NVARCHAR(MAX) 
		, @tableHTML2  NVARCHAR(MAX)
		, @subjectMsg varchar(250)
		, @incr int
		, @DBName varchar(80)
		, @rowcount int
		, @dsql varchar(8000)

	Create Table #OnlineDBs (incr int identity(1,1), dbname varchar(80))
	Create Table ##ObjectList (DBName varchar(80), ObjectName varchar(200), ObjectType varchar(80))

	IF CAST(REPLACE(SUBSTRING(CAST(SERVERPROPERTY('PRODUCTVERSION') AS VARCHAR), 1, 2), '.', '') AS TINYINT) > 10   
		Insert into #OnlineDBs (dbname)
		SELECT name
		FROM sys.databases d 
		LEFT JOIN sys.availability_replicas AS AR
		   ON d.replica_id = ar.replica_id
		LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
			ON ars.group_id = AR.group_id AND ars.replica_id = ar.replica_id
		LEFT JOIN sys.dm_hadr_database_replica_cluster_states AS dbcs
		   ON ars.replica_id = dbcs.replica_id and d.replica_id = dbcs.replica_id AND d.group_database_id = dbcs.group_database_id
		WHERE DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
		AND (ars.role = 1 OR ISNULL(AR.secondary_role_allow_connections,1) > 0) --Primary or able to read secondary db
		and database_id > 4
		and name not in ('dbops','scratchdb','reportservcr','reportservertempdb','litespeed','litespeedcentral')
		and name not like '%archive%'
	ELSE
		Insert into #OnlineDBs (dbname)
		SELECT name
		FROM sys.databases d 
		WHERE DATABASEPROPERTYEX([name], 'status') = 'ONLINE'  
		and database_id > 4
		and name not in ('dbops','scratchdb','reportservcr','reportservertempdb','litespeed','litespeedcentral')
		and name not like '%archive%'
	
	Select @rowcount = @@rowcount

	Set @incr = 1
	Select @dbname = dbname from #OnlineDBs where incr = @incr

	While @incr <= @rowcount
	Begin
		
		select @dsql = 'Insert into ##ObjectList (DBName, ObjectName, ObjectType)
		select ''' + @DBName + ''', [name], type_desc
		from ' + @DBName + '.sys.sql_modules m
		inner join ' + @DBName + '.sys.objects o on o.object_id = m.object_id
        inner join dbops.dbo.CodeAuditingIncludeList c
           on definition like ''%''+ c.Keyword + ''%'''
		Exec (@dsql)
		Set @incr = @incr + 1
		Select @dbname = dbname from #OnlineDBs where incr = @incr
	End

	Select * from ##ObjectList order by DBName, ObjectName, ObjectType

	SET @tableHTML1 =    
		N'<H3>List of Objects with common Mistakes like OpenQuery, Select into, grant execute on, sp_oa</H3>' +
		'<table border="1" cellpadding="0" cellspacing="0">' +    
		'<tr><th>DBName</th>' + '<th>Objectname</th>' +    
		'<th>ObjectType</th></tr>' +    
	   CAST ( ( select td = td.DBName, '',    
					   td = td.ObjectName, '',    
					   td = ObjectType    
	  from ##ObjectList td    
	  order by DBName, ObjectName, ObjectType asc    
	FOR XML PATH('tr'), TYPE     
	) AS NVARCHAR(MAX) ) 
	+ N'</table>' ;    

	SET @tableHTML2 =    
		N'<H3>List of Jobs with common Mistakes like OpenQuery, Select into, grant execute on, sp_oa</H3>' +
		'<table border="1" cellpadding="0" cellspacing="0">' +    
		'<th>SQL Job Name</th>' +    
		'<th>SQL Step Name</th></tr>' +    
	   CAST ( ( select td = j.name, '',    
					   td = step_name    
		from msdb.dbo.sysjobsteps s
		inner join msdb.dbo.sysjobs j on s.job_id = j.job_id 
		inner join dbo.CodeAuditingIncludeList c
		   on command like '%' + c.KeyWord + '%'  
	FOR XML PATH('tr'), TYPE     
	) AS NVARCHAR(MAX) ) 
	+ N'</table>' ;  

	SELECT @tableHTML = isnull(@tableHTML1,'') + isnull(@tableHTML2,'')

	select @subjectMsg = cast(@@ServerName as varchar(100)) + ' has objects/jobs has common mistakes ' 

	if exists (select 1 from ##ObjectList) or exists (select 1 from msdb.dbo.sysjobsteps s
		inner join msdb.dbo.sysjobs j on s.job_id = j.job_id 
		inner join dbo.CodeAuditingIncludeList c
		   on command like '%' + c.KeyWord + '%' )

	EXEC prc_InternalSendMail       
			@Address  = @person_to_notify,      
			@Subject = @subjectMsg,        
			@Body = @tableHTML, 
			@HTML  = 1

END
go
