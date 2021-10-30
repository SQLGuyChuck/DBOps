-- Script must not be run in a transaction
SET IMPLICIT_TRANSACTIONS OFF
IF @@TRANCOUNT > 0 ROLLBACK TRAN
GO

-- Options that are saved with object definition
SET QUOTED_IDENTIFIER ON		-- Required to call methods on XML type
SET ANSI_NULLS ON				-- All queries use IS NULL check
go

use msdb
go

if not exists (select * from sys.schemas where name = 'MS_PerfDashboard')
	exec('create schema MS_PerfDashboard')
go

if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_WaitTypeCategory'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_WaitTypeCategory
go

create function MS_PerfDashboard.fn_WaitTypeCategory(@wait_type nvarchar(60)) 
returns varchar(60)
as
begin
	declare @category nvarchar(60)
	select @category = 
		case 
			when @wait_type like N'LCK_M_%' then N'Lock'
			when @wait_type like N'LATCH_%' then N'Latch'
			when @wait_type like N'PAGELATCH_%' then N'Buffer Latch'
			when @wait_type like N'PAGEIOLATCH_%' then N'Buffer IO'
			when @wait_type like N'RESOURCE_SEMAPHORE_%' then N'Compilation'
			when @wait_type = N'SOS_SCHEDULER_YIELD' then N'Scheduler Yield'
			when @wait_type in (N'LOGMGR', N'LOGBUFFER', N'LOGMGR_RESERVE_APPEND', N'LOGMGR_FLUSH', N'WRITELOG') then N'Logging'
			when @wait_type in (N'ASYNC_NETWORK_IO', N'NET_WAITFOR_PACKET') then N'Network IO'
			when @wait_type in (N'CXPACKET', N'EXCHANGE') then N'Parallelism'
			when @wait_type in (N'RESOURCE_SEMAPHORE', N'CMEMTHREAD', N'SOS_RESERVEDMEMBLOCKLIST') then N'Memory'
			when @wait_type like N'CLR_%' or @wait_type like N'SQLCLR%' then N'CLR'
			when @wait_type like N'DBMIRROR%' or @wait_type = N'MIRROR_SEND_MESSAGE' then N'Mirroring'
			when @wait_type like N'XACT%' or @wait_type like N'DTC_%' or @wait_type like N'TRAN_MARKLATCH_%' or @wait_type like N'MSQL_XACT_%' or @wait_type = N'TRANSACTION_MUTEX' then N'Transaction'
			when @wait_type like N'SLEEP_%' or @wait_type in(N'LAZYWRITER_SLEEP', N'SQLTRACE_BUFFER_FLUSH', N'WAITFOR', N'WAIT_FOR_RESULTS') then N'Sleep'
			else N'Other'
		end

	return @category
end
go
GRANT EXECUTE ON MS_PerfDashboard.fn_WaitTypeCategory TO public
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_QueryTextFromHandle'), 'IsTableFunction') = 1
	drop function MS_PerfDashboard.fn_QueryTextFromHandle
go

CREATE function MS_PerfDashboard.fn_QueryTextFromHandle(@handle varbinary(64), @statement_start_offset int, @statement_end_offset int)
RETURNS @query_text TABLE (database_id smallint, object_id int, encrypted bit, query_text nvarchar(max))
begin
	if @handle is not null
	begin
		declare @start int, @end int
		declare @dbid smallint, @objectid int, @encrypted bit
		declare @batch nvarchar(max), @query nvarchar(max)

		-- statement_end_offset is zero prior to beginning query execution (e.g., compilation)
		select 
			@start = isnull(@statement_start_offset, 0), 
			@end = case when @statement_end_offset is null or @statement_end_offset = 0 then -1
						else @statement_end_offset 
					end

		select @dbid = t.dbid, 
			@objectid = t.objectid, 
			@encrypted = t.encrypted, 
			@batch = t.text 
		from sys.dm_exec_sql_text(@handle) as t

		select @query = case 
				when @encrypted = cast(1 as bit) then N'encrypted text' 
				else ltrim(substring(@batch, @start / 2 + 1, ((case when @end = -1 then datalength(@batch) 
							else @end end) - @start) / 2))
			end

		-- Found internal queries (e.g., CREATE INDEX) with end offset of original batch that is 
		-- greater than the length of the internal query and thus returns nothing if we don't do this
		if datalength(@query) = 0
		begin
			select @query = @batch
		end

		insert into @query_text (database_id, object_id, encrypted, query_text) 
		values (@dbid, @objectid, @encrypted, @query)
	end

	return
end
go
GRANT SELECT ON MS_PerfDashboard.fn_QueryTextFromHandle TO public
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_hexstrtovarbin'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_hexstrtovarbin
go

create function MS_PerfDashboard.fn_hexstrtovarbin(@input varchar(8000)) 
returns varbinary(8000) 
as 
begin 
	declare @result varbinary(8000)

	if @input is not null
	begin
		declare @i int, @l int 

		select @result = 0x, @l = len(@input) / 2, @i = 2 
	
		while @i <= @l 
		begin 
			set @result = @result + 
			cast(cast(case lower(substring(@input, @i*2-1, 1)) 
				when '0' then 0x00 
				when '1' then 0x10 
				when '2' then 0x20 
				when '3' then 0x30 
				when '4' then 0x40 
				when '5' then 0x50 
				when '6' then 0x60 
				when '7' then 0x70 
				when '8' then 0x80 
				when '9' then 0x90 
				when 'a' then 0xa0 
				when 'b' then 0xb0 
				when 'c' then 0xc0 
				when 'd' then 0xd0 
				when 'e' then 0xe0 
				when 'f' then 0xf0 
				end as tinyint) | 
			cast(case lower(substring(@input, @i*2, 1)) 
				when '0' then 0x00 
				when '1' then 0x01 
				when '2' then 0x02 
				when '3' then 0x03 
				when '4' then 0x04 
				when '5' then 0x05 
				when '6' then 0x06 
				when '7' then 0x07 
				when '8' then 0x08 
				when '9' then 0x09 
				when 'a' then 0x0a 
				when 'b' then 0x0b 
				when 'c' then 0x0c 
				when 'd' then 0x0d 
				when 'e' then 0x0e 
				when 'f' then 0x0f 
				end as tinyint) as binary(1)) 
		set @i = @i + 1 
		end 
	end

	return @result 
end 
go
GRANT EXECUTE ON MS_PerfDashboard.fn_hexstrtovarbin TO public
go


if object_id('MS_PerfDashboard.usp_CheckDependencies', 'P') is not null
	drop procedure MS_PerfDashboard.usp_CheckDependencies
go

create procedure MS_PerfDashboard.usp_CheckDependencies
as
begin
	declare @Version nvarchar(100)
	declare @MajorVer tinyint, @MinorVer tinyint, @BuildNum smallint
	declare @dec1 int, @dec2 int, @dec3 int

	select @Version = convert(nvarchar(100), serverproperty('ProductVersion'))
	select @dec1 = charindex('.', @Version)
	select @dec2 = charindex('.', @Version, @dec1 + 1)
	select @dec3 = case when charindex('.', @Version, @dec2 + 1) = 0 then len(@Version) + 1 else charindex('.', @Version, @dec2 + 1) end

	select @MajorVer = convert(tinyint, substring(@Version, 1, @dec1 - 1)), 
		@MinorVer = convert(tinyint, substring(@Version, @dec1 + 1, @dec2 - @dec1 - 1)),
		@BuildNum = convert(smallint, substring(@Version, @dec2 + 1, @dec3 - @dec2 - 1))
	
	select @MajorVer as major_version, 
		@MinorVer as minor_version, 
		@BuildNum as build_number,
		convert(nvarchar(128), SERVERPROPERTY('MachineName')) + 
			CASE WHEN convert(nvarchar(128), SERVERPROPERTY('InstanceName')) IS NOT NULL THEN N'\' + convert(nvarchar(128), SERVERPROPERTY('InstanceName'))
			ELSE N''
			END as ServerInstance,
		@Version as ProductVersion,
		serverproperty('ProductLevel') as ProductLevel,
		serverproperty('Edition') as Edition

	if not (@MajorVer > 9 or (@MajorVer = 9 and @MinorVer > 0) or (@MajorVer = 9 and @MinorVer = 0 and @BuildNum >= 3026))
	begin
		RAISERROR('The target server being monitored via the Performance Dashboard must be running SQL Server 2005 Service Pack 2 (build 9.00.3026) or later.  This server is running version %s', 18, 1, @Version)
	end
end
go
grant execute on MS_PerfDashboard.usp_CheckDependencies to public
go


if object_id('MS_PerfDashboard.usp_Main_GetCPUHistory', 'P') is not null
	drop procedure MS_PerfDashboard.usp_Main_GetCPUHistory
go

create procedure MS_PerfDashboard.usp_Main_GetCPUHistory
as
begin

	DECLARE @SQLString nvarchar(500);
	DECLARE @ParmDefinition nvarchar(500);
	DECLARE @ts_now bigint;
	DECLARE @IntVariable int;

	IF (@@microsoftversion / 0x1000000 & 0xff) > 9  --[VersionMajor]
		SET @SQLString = N'SELECT @ts_nowOUT = ms_ticks from sys.dm_os_sys_info';
	ELSE
		SET @SQLString = N'SELECT @ts_nowOUT = cpu_ticks / convert(float, cpu_ticks_in_ms) from sys.dm_os_sys_info'

	SET @ParmDefinition = N'@ts_nowOUT bigint OUTPUT';
	EXECUTE sp_executesql
	  @SQLString,
	  @ParmDefinition,
	  @ts_nowOUT = @ts_now OUTPUT;

		
	select top 15 record_id,
		dateadd(ms, -1 * (@ts_now - [timestamp]), GetDate()) as EventTime, 
		SQLProcessUtilization,
		SystemIdle,
		100 - SystemIdle - SQLProcessUtilization as OtherProcessUtilization
	from (
		select 
			record.value('(./Record/@id)[1]', 'int') as record_id,
			record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') as SystemIdle,
			record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') as SQLProcessUtilization,
			timestamp
		from (
			select timestamp, convert(xml, record) as record 
			from sys.dm_os_ring_buffers 
			where ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
			and record like '%<SystemHealth>%') as x
		) as y 
	order by record_id desc
end
go
grant execute on MS_PerfDashboard.usp_Main_GetCPUHistory to public
go


if object_id('MS_PerfDashboard.usp_Main_GetMiscInfo', 'P') is not null
	drop procedure MS_PerfDashboard.usp_Main_GetMiscInfo
go

create procedure MS_PerfDashboard.usp_Main_GetMiscInfo
as
begin
	select 
		(select count(*) from sys.traces) as running_traces,
		(select count(*) from sys.databases) as number_of_databases,
		(select count(*) from sys.dm_db_missing_index_group_stats) as missing_index_count,
		(select waiting_tasks_count from sys.dm_os_wait_stats where wait_type = N'SQLCLR_QUANTUM_PUNISHMENT') as clr_quantum_waits,
		(select count(*) from sys.dm_os_ring_buffers where ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' and record like N'%<NonYieldSchedBegin>%') as non_yield_count,
		(select cpu_count from sys.dm_os_sys_info) as number_of_cpus,
		(select scheduler_count from sys.dm_os_sys_info) as number_of_schedulers
	end
go
grant execute on MS_PerfDashboard.usp_Main_GetMiscInfo to public
go


if object_id('MS_PerfDashboard.usp_Main_GetSessionInfo', 'P') is not null
	drop procedure MS_PerfDashboard.usp_Main_GetSessionInfo
go
--Altered per http://blogs.msdn.com/b/sqlserverfaq/archive/2010/05/27/sql-server-performance-dashboard-reports-in-ssms-introduction-install-datediff-error-amp-modified-for-sql-2008.aspx
create procedure MS_PerfDashboard.usp_Main_GetSessionInfo
as
begin
    select count(*) as num_sessions,
        sum(convert(bigint, s.total_elapsed_time)) as total_elapsed_time,
        sum(convert(bigint, s.cpu_time)) as cpu_time, 
        sum(convert(bigint, s.total_elapsed_time)) - sum(convert(bigint, s.cpu_time)) as wait_time,
        sum(convert(bigint, CAST ( DATEDIFF ( minute, login_time, getdate()) AS BIGINT)*60000 + DATEDIFF ( millisecond, DATEADD ( minute,DATEDIFF ( minute, login_time, getdate() ), login_time ),getdate() ))) - sum(convert(bigint, s.total_elapsed_time)) as idle_connection_time,
        case when sum(s.logical_reads) > 0 then (sum(s.logical_reads) - isnull(sum(s.reads), 0)) / convert(float, sum(s.logical_reads))
			else NULL
			end as cache_hit_ratio
    from sys.dm_exec_sessions s
    where s.is_user_process = 0x1
end
go
grant execute on MS_PerfDashboard.usp_Main_GetSessionInfo to public
go


if object_id('MS_PerfDashboard.usp_Main_GetRequestInfo', 'P') is not null
	drop procedure MS_PerfDashboard.usp_Main_GetRequestInfo
go

create procedure MS_PerfDashboard.usp_Main_GetRequestInfo
as
begin
	select count(r.request_id) as num_requests,
		sum(convert(bigint, r.total_elapsed_time)) as total_elapsed_time,
		sum(convert(bigint, r.cpu_time)) as cpu_time,
		sum(convert(bigint, r.total_elapsed_time)) - sum(convert(bigint, r.cpu_time)) as wait_time,
		case when sum(r.logical_reads) > 0 then (sum(r.logical_reads) - isnull(sum(r.reads), 0)) / convert(float, sum(r.logical_reads))
			else NULL
			end as cache_hit_ratio
	from sys.dm_exec_requests r
		join sys.dm_exec_sessions s on r.session_id = s.session_id
	where s.is_user_process = 0x1
end
go
grant execute on MS_PerfDashboard.usp_Main_GetRequestInfo to public
go


if object_id('MS_PerfDashboard.usp_Main_GetRequestWaits', 'P') is not null
	drop procedure MS_PerfDashboard.usp_Main_GetRequestWaits
go

create procedure MS_PerfDashboard.usp_Main_GetRequestWaits
as
begin
	SELECT 
		r.session_id, 
		MS_PerfDashboard.fn_WaitTypeCategory(r.wait_type) AS wait_category, 
		r.wait_type, 
		r.wait_time
	FROM sys.dm_exec_requests AS r 
		INNER JOIN sys.dm_exec_sessions AS s ON r.session_id = s.session_id
	WHERE r.wait_type IS NOT NULL  
		AND s.is_user_process = 0x1
end
go
GRANT EXECUTE ON MS_PerfDashboard.usp_Main_GetRequestWaits TO public
go



if object_id('MS_PerfDashboard.usp_GetPageDetails', 'P') is not null
	drop procedure MS_PerfDashboard.usp_GetPageDetails
go

create procedure MS_PerfDashboard.usp_GetPageDetails @wait_resource varchar(100)
as
begin
	declare @database_id smallint, @file_id smallint, @page_no int
	declare @t TABLE (ParentObject varchar(256), Object varchar(256), Field varchar(256), VALUE sql_variant)

	declare @colon1 int, @colon2 int
	select @colon1 = charindex(':', @wait_resource)
	select @colon2 = charindex(':', @wait_resource, @colon1 + 1)
	select @database_id = substring(@wait_resource, 1, @colon1 - 1)
	select @file_id = substring(@wait_resource, @colon1 + 1, @colon2 - @colon1 - 1)
	select @page_no = substring(@wait_resource, @colon2 + 1, 100)
	
	BEGIN TRY
		insert into @t exec sp_executesql N'dbcc page(@database_id, @file_id, @page_no) with tableresults', N'@database_id smallint, @file_id smallint, @page_no int', @database_id, @file_id, @page_no
	END TRY
	BEGIN CATCH
		--do nothing
	END CATCH
	
	select @database_id as database_id, 
		quotename(db_name(@database_id)) as database_name,
		@file_id as file_id,
		@page_no as page_no,
		convert(int, [Metadata: ObjectId]) as [object_id], 
		quotename(object_schema_name(convert(int, [Metadata: ObjectId]), @database_id)) + N'.' + quotename(object_name(convert(int, [Metadata: ObjectId]), @database_id)) as [object_name],
		convert(smallint, [Metadata: IndexId]) as [index_id],
		convert(int, [m_level]) as page_level,
		case convert(int, [m_type])
			when 1 then N'Data Page'
			when 2 then N'Index Page'
			when 3 then N'Text Mix Page'
			when 4 then N'Text Tree Page'
			when 8 then N'GAM Page'
			when 9 then N'SGAM Page'
			when 10 then N'IAM Page'
			when 11 then N'PFS Page'
			else convert(nvarchar(10), [m_type])	-- other types intentionally omitted
		end as page_type
	from (select * from @t where ParentObject = 'PAGE HEADER:' and 
			Field IN ('Metadata: ObjectId', 'Metadata: IndexId', 'm_objId (AllocUnitId.idObj)', 'm_level', 'm_type')) as x
		pivot (min([VALUE]) for Field in ([Metadata: ObjectId], [Metadata: IndexId], [m_level], [m_type])) as z
end
go
GRANT EXECUTE ON MS_PerfDashboard.usp_GetPageDetails TO public
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.usp_GetPlanGuideDetails'), 'IsProcedure') = 1
	drop procedure MS_PerfDashboard.usp_GetPlanGuideDetails
go

create procedure MS_PerfDashboard.usp_GetPlanGuideDetails @database_name nvarchar(128), @plan_guide_name nvarchar(128)
as
begin
	if (LEFT(@database_name, 1) = N'[' and RIGHT(@database_name, 1) = N']')
	begin
		select @database_name = substring(@database_name, 2, len(@database_name) - 2)
	end

	if (LEFT(@plan_guide_name, 1) = N'[' and RIGHT(@plan_guide_name, 1) = N']')
	begin
		select @plan_guide_name = substring(@plan_guide_name, 2, len(@plan_guide_name) - 2)
	end

	if db_id(@database_name) is not null
	begin
		declare @cmd nvarchar(4000)
		select @cmd = N'select * from [' + @database_name + N'].[sys].[plan_guides] where name = @P1'

		exec sp_executesql @cmd, N'@P1 nvarchar(128)', @plan_guide_name
	end
	else
	begin
		-- return empty result set
		select * from [sys].[plan_guides] where 0 = 1
	end
end
go

grant execute on MS_PerfDashboard.usp_GetPlanGuideDetails to public
go




if OBJECTPROPERTY(object_id('MS_PerfDashboard.usp_TransformShowplanXMLToTable'), 'IsProcedure') = 1
	drop procedure MS_PerfDashboard.usp_TransformShowplanXMLToTable
go

CREATE PROCEDURE MS_PerfDashboard.usp_TransformShowplanXMLToTable @plan_handle nvarchar(256), @stmt_start_offset int, @stmt_end_offset int, @fDebug bit = 0x0
AS
BEGIN
	SET NOCOUNT ON

	declare @plan nvarchar(max)
	declare @dbid int, @objid int
	declare @xml_plan xml
	declare @error int

	declare @output TABLE (
		node_id int, 
		parent_node_id int, 
		relevant_xml_text nvarchar(max), 
		stmt_text nvarchar(max), 
		logical_op nvarchar(128), 
		physical_op nvarchar(128), 
		output_list nvarchar(max), 
		avg_row_size float, 
		est_cpu float, 
		est_io float, 
		est_rows float, 
		est_rewinds float, 
		est_rebinds float, 
		est_subtree_cost float,
		warnings nvarchar(max))

	BEGIN TRY
		-- handle may be invalid now, or XML may be too deep to convert
		select @dbid = p.dbid, @objid = p.objectid, @plan = p.query_plan from sys.dm_exec_text_query_plan(msdb.MS_PerfDashboard.fn_hexstrtovarbin(@plan_handle), @stmt_start_offset, @stmt_end_offset) as p
		select @xml_plan = convert(xml, @plan)

		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		insert into @output 
		select nd.node_id,
			x.parent_node_id,
			case when @fDebug = 0x1 then 
							case 
								when x.parent_node_id is null then @plan 
								else convert(nvarchar(max), x.plan_node) 
							end
					else NULL
					end as relevant_xml_text,
			nd.stmt_text, 
			nd.logical_op, 
			nd.physical_op, 
			nd.output_list, 
			nd.avg_row_size, 
			nd.est_cpu, 
			nd.est_io, 
			nd.est_rows, 
			nd.est_rewinds, 
			nd.est_rebinds, 
			nd.est_subtree_cost,
			nd.warnings
		from (select 
				splan.row.query('.') as plan_node,
				splan.row.value('../../@NodeId', 'int') as parent_node_id
			from (select @xml_plan as query_plan) as p
				cross apply p.query_plan.nodes('//sp:RelOp') as splan (row)) as x
				cross apply MS_PerfDashboard.fn_ShowplanRowDetails(plan_node) as nd
		order by isnull(parent_node_id, -1) asc

		-- Statements such as WAITFOR, etc may not have a RelOp so just show the statement type if available
		if @@rowcount = 0
		begin
			;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
			insert into @output (stmt_text) select isnull(@xml_plan.value('(//@StatementType)[1]', 'nvarchar(max)'), N'Unknown Statement')
		end
	END TRY
	BEGIN CATCH
		select @error = ERROR_NUMBER()
-- 		select 
-- 			cast(NULL as int) as node_id, 
-- 			cast(NULL as int) as parent_node_id,
-- 			cast(NULL as nvarchar(max)) as relevant_xml_text,
-- 			cast(NULL as nvarchar(max)) as stmt_text,
-- 			cast(NULL as nvarchar(128)) as logical_op,
-- 			cast(NULL as nvarchar(128)) as physical_op,
-- 			cast(NULL as nvarchar(max)) as output_list,
-- 			cast(NULL as float) as avg_row_size,
-- 			cast(NULL as float) as est_cpu,
-- 			cast(NULL as float) as est_io,
-- 			cast(NULL as float) as est_rows,
-- 			cast(NULL as float) as est_rewinds,
-- 			cast(NULL as float) as est_rebinds,
-- 			cast(NULL as float) as est_subtree_cost,
-- 			cast(NULL as nvarchar(max)) as warnings
-- 		where 0 = 1
	END CATCH

	-- This may be an empty set if there was an exception caught above
	SELECT
		node_id,
		parent_node_id, 
		relevant_xml_text, 
		stmt_text, 
		logical_op, 
		physical_op, 
		output_list, 
		avg_row_size, 
		est_cpu, 
		est_io, 
		est_rows, 
		est_rewinds, 
		est_rebinds, 
		est_subtree_cost,
		warnings
	FROM @output
END
go

grant execute on MS_PerfDashboard.usp_TransformShowplanXMLToTable to public
go




/* 
 *
 *	Helper procedures for building showplan output.  These are called, indirectly, by MS_PerfDashboard.usp_TransformShowplanXMLToTable and because
 *	they belong to the same schema we do not need to grant EXECUTE permissions to users.  They are not intended to be called directly as they require
 *	proper context within the showplan XML in order to return meaningful output.
 *
 *
 */
if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanBuildColumnReference'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanBuildColumnReference
go

create function MS_PerfDashboard.fn_ShowplanBuildColumnReference(@node_data xml, @include_alias_or_table bit)
returns nvarchar(max)
as
begin
	declare @output nvarchar(max)
	declare @table nvarchar(256), @alias nvarchar(256), @column nvarchar(256)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @alias = @node_data.value('(./sp:ColumnReference/@Alias)[1]', 'nvarchar(256)'),
		@table = @node_data.value('(./sp:ColumnReference/@Table)[1]', 'nvarchar(256)'),
		@column = @node_data.value('(./sp:ColumnReference/@Column)[1]', 'nvarchar(256)')

	select @column = case when left(@column, 1) = N'[' and right(@column, 1) = N']' then @column else quotename(@column) end

	if @include_alias_or_table = 0x1 and coalesce(@alias, @table) is not null
	begin
		select @alias = case when left(@alias, 1) = N'[' and right(@alias, 1) = N']' then @alias else quotename(@alias) end
		select @table = case when left(@table, 1) = N'[' and right(@table, 1) = N']' then @table else quotename(@table) end

		select @output = case 
					when @alias is not null then @alias
					else @table
				end + N'.' + @column
	end
	else
	begin
		select @output = @column
	end

	return @output
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList
go

create function MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList (@node_data xml, @include_alias_or_table bit)
returns nvarchar(max)

as
begin
	declare @output nvarchar(max)

	declare @count int, @ctr int

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = N'', @ctr = 1, @count = @node_data.value('count(./sp:ColumnReference)', 'int')

	-- iterate over each element in the list
	while @ctr <= @count
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + case when @ctr > 1 then N', ' else N'' end + MS_PerfDashboard.fn_ShowplanBuildColumnReference(@node_data.query('./sp:ColumnReference[position() = sql:variable("@ctr")]'), @include_alias_or_table)

		select @ctr = @ctr + 1
	end

	return @output
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanBuildDefinedValuesList'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanBuildDefinedValuesList
go

create function MS_PerfDashboard.fn_ShowplanBuildDefinedValuesList (@node_data xml)
returns nvarchar(max)
as
begin
	declare @output nvarchar(max)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = convert(nvarchar(max), @node_data.query('for $val in /sp:DefinedValue
				return concat(($val/sp:ColumnReference/@Column)[1], "=", ($val/sp:ScalarOperator/@ScalarString)[1], ",")'))

	declare @len int
	select @len = len(@output)
	if (@len > 0)
	begin
		select @output = left(@output, @len - 1)
	end

	return @output
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanBuildOrderBy'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanBuildOrderBy
go

create function MS_PerfDashboard.fn_ShowplanBuildOrderBy (@node_data xml)
returns nvarchar(max)
as
begin
	declare @output nvarchar(max)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = convert(nvarchar(max), @node_data.query('for $col in /sp:OrderByColumn
					return concat(if (($col/sp:ColumnReference/@Alias)[1] > "") then concat(($col/sp:ColumnReference/@Alias)[1], ".") else if (($col/sp:ColumnReference/@Table)[1] > "") then concat(($col/sp:ColumnReference/@Table)[1], ".") else "", string(($col/sp:ColumnReference/@Column)[1]), if ($col/@Ascending = 1) then " ASC" else " DESC", ",")'))
	declare @len int
	select @len = len(@output)
	if (@len > 0)
	begin
		select @output = left(@output, @len - 1)
	end

	return @output
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanBuildRowset'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanBuildRowset
go

create function MS_PerfDashboard.fn_ShowplanBuildRowset (@node_data xml)
returns nvarchar(max)
as
begin
	declare @output nvarchar(max)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = MS_PerfDashboard.fn_ShowplanBuildObject(@node_data.query('./sp:Object'))

	return @output
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanBuildScalarExpression'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanBuildScalarExpression
go

create function MS_PerfDashboard.fn_ShowplanBuildScalarExpression (@node_data xml)
returns nvarchar(max)
as
begin
	declare @output nvarchar(max)

	select @output = N''

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = @node_data.value('(./sp:ScalarOperator/@ScalarString)[1]', 'nvarchar(max)')

	return @output
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanBuildScalarExpressionList'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanBuildScalarExpressionList
go

create function MS_PerfDashboard.fn_ShowplanBuildScalarExpressionList (@node_data xml)
returns nvarchar(max)
as
begin
	declare @output nvarchar(max)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = convert(nvarchar(max), @node_data.query('for $op in ./sp:ScalarOperator
					return concat(string($op/@ScalarString), ",")'))

	declare @len int
	select @len = len(@output)
	if (@len > 0)
	begin
		select @output = left(@output, @len - 1)
	end

	return @output
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanBuildScanRange'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanBuildScanRange
go

create function MS_PerfDashboard.fn_ShowplanBuildScanRange (@node_data xml, @scan_type nvarchar(30))
returns nvarchar(max)
as
begin
	declare @output nvarchar(max)
	set @output = N''

	declare @count int, @ctr int

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @ctr = 1, @count = @node_data.value('count(./sp:RangeColumns/sp:ColumnReference)', 'int')

	while @ctr <= @count
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + 
				case when @ctr > 1 then N' AND ' else '' end + MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@node_data.query('./sp:RangeColumns/sp:ColumnReference[position() = sql:variable("@ctr")]'), 0x1)
				+ N' ' + 
			case UPPER(@scan_type) 
				when 'BINARY IS' then N'IS'
				when 'EQ' then N'='
				when 'GE' then N'>='
				when 'GT' then N'>'
				when 'IS' then N'IS'
				when 'IS NOT' then N'IS NOT'
				when 'IS NOT NULL' then N'IS NOT NULL'
				when 'IS NULL' then N'IS NULL'
				when 'LE' then N'<='
				when 'LT' then N'<'
				when 'NE' then N'<>'
			end
			 + N' '
			+ MS_PerfDashboard.fn_ShowplanBuildScalarExpressionList(@node_data.query('./sp:RangeExpressions/sp:ScalarOperator[position() = sql:variable("@ctr")]'))

		select @ctr = @ctr + 1
	end

	return @output
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanBuildSeekPredicates'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanBuildSeekPredicates
go

create function MS_PerfDashboard.fn_ShowplanBuildSeekPredicates (@node_data xml)
returns nvarchar(max)
as
begin
	declare @output nvarchar(max)
	declare @count int, @ctr int

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = N'', @ctr = 1, @count = @node_data.value('count(./sp:SeekPredicates/sp:SeekPredicate)', 'int')

	-- iterate over each element in the list
	while @ctr <= @count
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + case when @ctr > 1 then N' AND ' else N'' end + MS_PerfDashboard.fn_ShowplanBuildSeekPredicate(@node_data.query('./sp:SeekPredicates/sp:SeekPredicate[position() = sql:variable("@ctr")]/*'))

		select @ctr = @ctr + 1
	end

	return @output
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanBuildSeekPredicate'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanBuildSeekPredicate
go

create function MS_PerfDashboard.fn_ShowplanBuildSeekPredicate (@node_data xml)
returns nvarchar(max)
as
begin
	declare @output nvarchar(max)
	set @output = N''

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Prefix') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + MS_PerfDashboard.fn_ShowplanBuildScanRange(@node_data.query('./sp:Prefix/*'), @node_data.value('(./sp:Prefix/@ScanType)[1]', 'nvarchar(100)'))
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:StartRange') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + case when datalength(@output) > 0 then N' AND ' else '' end + MS_PerfDashboard.fn_ShowplanBuildScanRange(@node_data.query('./sp:StartRange/*'), @node_data.value('(./sp:StartRange/@ScanType)[1]', 'nvarchar(100)'))
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:EndRange') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + case when datalength(@output) > 0 then N' AND ' else '' end + MS_PerfDashboard.fn_ShowplanBuildScanRange(@node_data.query('./sp:EndRange/*'), @node_data.value('(./sp:EndRange/@ScanType)[1]', 'nvarchar(100)'))
	end

	return @output
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanBuildObject'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanBuildObject
go

create function MS_PerfDashboard.fn_ShowplanBuildObject (@node_data xml)
returns nvarchar(max)
as
begin
	declare @object nvarchar(max)
	set @object = N''

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Object/@Server') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @object = @object + @node_data.value('(./sp:Object/@Server)[1]', 'nvarchar(128)') + N'.'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Object/@Database') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @object = @object + @node_data.value('(./sp:Object/@Database)[1]', 'nvarchar(128)') + N'.'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Object/@Schema') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @object = @object + @node_data.value('(./sp:Object/@Schema)[1]', 'nvarchar(128)') + N'.'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Object/@Table') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @object = @object + @node_data.value('(./sp:Object/@Table)[1]', 'nvarchar(128)')
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Object/@Index') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @object = @object + N'.' + @node_data.value('(./sp:Object/@Index)[1]', 'nvarchar(128)')
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Object/@Alias') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @object = @object + N' AS ' + @node_data.value('(./sp:Object/@Alias)[1]', 'nvarchar(128)')
	end

	return @object
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanBuildWarnings'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanBuildWarnings
go

create function MS_PerfDashboard.fn_ShowplanBuildWarnings(@relop_node xml)
returns nvarchar(max)
as
begin
	declare @output nvarchar(max)

	if (@relop_node.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:RelOp/sp:Warnings') = 1)
	begin
		if (@relop_node.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:RelOp/sp:Warnings[@NoJoinPredicate = 1]') = 1)
		begin
			select @output = N'NO JOIN PREDICATE'
		end
		
		if (@relop_node.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:RelOp/sp:Warnings/sp:ColumnsWithNoStatistics') = 1)
		begin
			;with xmlnamespaces ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' as sp)
			select @output = case when @output is null then N'' else @output + N', ' end + N'NO STATS: ' + MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@relop_node.query('./sp:RelOp/sp:Warnings/sp:ColumnsWithNoStatistics/*'), 0x1)
		end
	end

	return @output
end
go




if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatAssert'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatAssert
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatAssert(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = N'Assert(' + @node_data.value('(./sp:Assert/sp:Predicate/sp:ScalarOperator/@ScalarString)[1]', 'nvarchar(max)') + N'))'

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatBitmap'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatBitmap
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatBitmap(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = N'Bitmap(Hash Keys:(' + MS_PerfDashboard.fn_BuildColumnReferenceList(@node_data.query('./sp:HashKeys/sp:ColumnReference'), 0x1) + N')'

	return @output;
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatCollapse'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatCollapse
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatCollapse(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = N'Bitmap(GROUP BY:(' + MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@node_data.query('./sp:GroupBy/sp:ColumnReference'), 0x1) + N')'

	return @output;
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatComputeScalar'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatComputeScalar
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatComputeScalar(@node_data xml, @physical_op nvarchar(128))
returns nvarchar(max)
as
begin
	declare @output nvarchar(max)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = @physical_op + N'(DEFINE: (' + MS_PerfDashboard.fn_ShowplanBuildDefinedValuesList(@node_data.query('./sp:DefinedValues/*')) + N'))';

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatConcat'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatConcat
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatConcat(@node_data xml)
RETURNS nvarchar(max)
as
begin
	return N'Concatenation'
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatIndexScan'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatIndexScan
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatIndexScan(@node_data xml, @physical_op nvarchar(128))
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)


	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = @physical_op + N'(OBJECT: (' + MS_PerfDashboard.fn_ShowplanBuildObject(@node_data.query('./sp:IndexScan/sp:Object')) + N')'

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:IndexScan/sp:SeekPredicates/sp:SeekPredicate') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', SEEK: (' + MS_PerfDashboard.fn_ShowplanBuildSeekPredicates(@node_data.query('./sp:IndexScan/sp:SeekPredicates')) + N')'
	end


	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:IndexScan/sp:Predicate') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', WHERE: (' + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:IndexScan/sp:Predicate/*')) + N')'
	end

	select @output = @output + N')'

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:IndexScan[@Lookup = 1]') = 1)
	begin
		select @output = @output + N' LOOKUP'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:IndexScan[@Ordered = 1]') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N' ORDERED ' + @node_data.value('(./sp:IndexScan/@ScanDirection)[1]', 'nvarchar(128)')
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:IndexScan[@ForcedIndex = 1]') = 1)
	begin
		select @output = @output + N' FORCEDINDEX'
	end

	return @output;
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatConstantScan'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatConstantScan
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatConstantScan(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = N'Constant Scan'

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:ConstantScan/sp:Values') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'(VALUES: (' + MS_PerfDashboard.fn_ShowplanBuildScalarExpressionList(@node_data.query('./sp:ConstantScan/sp:Values/sp:Row/*')) + N'))'
	end

	return @output
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatDeletedInsertedScan'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatDeletedInsertedScan
go

-- Passed the Rowset element of XML showplan and extracts the Object details
CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatDeletedInsertedScan(@node_data xml, @physical_op nvarchar(128))
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = @physical_op + N'(' + MS_PerfDashboard.fn_ShowplanBuildRowset(@node_data) + N')'

	return @output;
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatFilter'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatFilter
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatFilter(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	declare @fStartup tinyint

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @fStartup = case when (@node_data.exist('./sp:Filter[@StartupExpression = 1]') = 1) then 1 else 0 end

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = N'Filter(WHERE: (' + 
		case when @fStartup = 1 then N'STARTUP EXPRESSION(' else N'' end + 
		MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:Filter/sp:Predicate/*')) +
		case when @fStartup = 1 then N')' else N'' end + 
		N'))'

	return @output;
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatHashMatch'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatHashMatch
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatHashMatch(@node_data xml, @logical_op nvarchar(128))
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = N'Hash Match(' + @logical_op

	if (@logical_op = N'Aggregate')
	begin
		if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Hash/sp:HashKeysBuild') = 1)
		begin
			;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
			select @output = @output + N', HASH:(' + MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@node_data.query('./sp:Hash/sp:HashKeysBuild/sp:ColumnReference'), 0x1) + N')'
		end
	
		if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Hash/sp:BuildResidual') = 1)
		begin
			;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
			select @output = @output + N', RESIDUAL:(' + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:Hash/sp:BuildResidual/*')) + N')'
		end

		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', DEFINE: (' + MS_PerfDashboard.fn_ShowplanBuildDefinedValuesList(@node_data.query('./sp:Hash/sp:DefinedValues/*')) + N')';
	end
	else
	begin
		if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Hash/sp:HashKeysBuild') = 1)
		begin
			;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
			select @output = @output + N', HASH:(' + 
				MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@node_data.query('./sp:Hash/sp:HashKeysBuild/sp:ColumnReference'), 0x1) + 
				N')=(' + 
				MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@node_data.query('./sp:Hash/sp:HashKeysProbe/sp:ColumnReference'), 0x1) + N')'
		end
	
		if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Hash/sp:BuildResidual') = 1) or
			(@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Hash/sp:ProbeResidual') = 1)
		begin
			declare @build_residual bit
	
			select @build_residual = 0x0, @output = @output + N', RESIDUAL:('
	
			if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Hash/sp:BuildResidual') = 1)
			begin
				;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
				select @output = @output + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:Hash/sp:BuildResidual/*'))
				select @build_residual = 0x1
			end
	
			if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Hash/sp:ProbeResidual') = 1)
			begin
				;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
				select @output = @output + case when @build_residual = 0x1 then N' AND ' else '' end + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:Hash/sp:ProbeResidual/*'))
			end

			select @output = @output + N')'
		end
	end

	select @output = @output + N')'

	return @output;
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatMerge'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatMerge
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatMerge(@node_data xml, @logical_op nvarchar(128))
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = N'Merge Join(' + @logical_op + case when @node_data.exist('./sp:Merge[@ManyToMany = 1]') = 1 then N', MANY-TO-MANY'
			else N'' end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Merge/sp:InnerSideJoinColumns') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', MERGE: (' + MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@node_data.query('./sp:Merge/sp:InnerSideJoinColumns/sp:ColumnReference'), 0x1) + N')=(' + MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@node_data.query('./sp:Merge/sp:OuterSideJoinColumns/sp:ColumnReference'), 0x1) + N'))'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Merge/sp:Residual') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', RESIDUAL: (' + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:Merge/sp:Residual/*')) + N')'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Merge/sp:PassThru') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', PASSTHRU: (' + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:Merge/sp:PassThru/*')) + N')'
	end

	return @output;
end
go




if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatNestedLoops'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatNestedLoops
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatNestedLoops(@node_data xml, @logical_op nvarchar(128))
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = N'Nested Loops(' + @logical_op

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:NestedLoops/sp:OuterReferences') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', OUTER REFERENCES:' + MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@node_data.query('./sp:NestedLoops/sp:OuterReferences/sp:ColumnReference'), 0x1)
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:NestedLoops/sp:Predicate') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', WHERE: (' + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:NestedLoops/sp:Predicate/*')) + N')'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:NestedLoops/sp:PassThru') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', PASSTHRU:(' + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:NestedLoops/sp:PassThru/*')) + N')'
	end

	select @output = @output + N')'

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:NestedLoops[@Optimized = 1]') = 1)
	begin
		select @output = @output + N' OPTIMIZED'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:NestedLoops[@WithOrderedPrefetch = 1]') = 1)
	begin
		select @output = @output + N' WITH ORDERED PREFETCH'
	end
	else if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:NestedLoops[@WithUnorderedPrefetch = 1]') = 1)
	begin
		select @output = @output + N' WITH UNORDERED PREFETCH'
	end

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatParallelism'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatParallelism
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatParallelism(@node_data xml, @logical_op nvarchar(128))
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)

	select @output = N'Parallelism(' + @logical_op + N')'
	--TODO: Extend to show partitioning information, order by information	

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatSimpleUpdate'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatSimpleUpdate
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatSimpleUpdate(@node_data xml, @physical_op nvarchar(128))
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = @physical_op + N'(' + MS_PerfDashboard.fn_ShowplanBuildObject(@node_data.query('./sp:Object'))

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:SetPredicate') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', SET: ' + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:SetPredicate/*'))
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:SeekPredicate') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', WHERE: (' + MS_PerfDashboard.fn_ShowplanBuildSeekPredicate(@node_data.query('./sp:SeekPredicate/*')) + N')'
	end

	select @output = @output + N')'

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatRemoteQuery'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatRemoteQuery
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatRemoteQuery(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = N'Remote Scan('

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:RemoteQuery/@RemoteSource') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'SOURCE: (' + @node_data.value('(./sp:RemoteQuery/@RemoteSource)[1]', 'nvarchar(256)') + N')'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:RemoteQuery/@RemoteObject') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'OBJECT: (' + @node_data.value('(./sp:RemoteQuery/@RemoteObject)[1]', 'nvarchar(256)') + N')'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:RemoteQuery/@RemoteQuery') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', QUERY: (' + @node_data.value('(./sp:RemoteQuery/@RemoteQuery)[1]', 'nvarchar(max)') + N')'
	end

	select @output = @output + N')'

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatRemoteScan'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatRemoteScan
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatRemoteScan(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = N'Remote Scan('

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:RemoteScan/@RemoteSource') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'SOURCE: (' + @node_data.value('(./sp:RemoteScan/@RemoteSource)[1]', 'nvarchar(256)') + N')'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:RemoteScan/@RemoteObject') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'OBJECT: (' + @node_data.value('(./sp:RemoteScan/@RemoteObject)[1]', 'nvarchar(256)') + N')'
	end

	select @output = @output + N')'

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatRemoteModify'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatRemoteModify
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatRemoteModify(@node_data xml, @logical_op nvarchar(128))
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = @logical_op + N'('

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:RemoteModify/@RemoteSource') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'SOURCE: (' + @node_data.value('(./sp:RemoteModify/@RemoteSource)[1]', 'nvarchar(256)') + N')'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:RemoteModify/@RemoteObject') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'OBJECT: (' + @node_data.value('(./sp:RemoteModify/@RemoteObject)[1]', 'nvarchar(256)') + N')'
	end


	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:RemoteModify/sp:SetPredicate') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'WHERE: (' + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:RemoteModify/sp:SetPredicate/*')) + N')'
	end

	select @output = @output + N')'

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatSort'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatSort
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatSort(@node_data xml, @logical_op nvarchar(128))
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = N'Sort('

	if @logical_op = N'Sort'
	begin
		if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Sort[@Distinct = 1]') = 1)
		begin
			select @output = @output + N'DISTINCT '
		end

		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'ORDER BY: (' + MS_PerfDashboard.fn_ShowplanBuildOrderBy(@node_data.query('./sp:Sort/sp:OrderBy/sp:OrderByColumn')) + N')'
	end
	else if @logical_op = N'TopN Sort'
	begin
		select @output = @output + N'TOP ' + @node_data.value('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; (./sp:TopSort/@Rows)[1]', 'nvarchar(50)') + N', '

		if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:TopSort[@Distinct = 1]') = 1)
		begin
			select @output = @output + N'DISTINCT '
		end

		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'ORDER BY: (' + MS_PerfDashboard.fn_ShowplanBuildOrderBy(@node_data.query('./sp:TopSort/sp:OrderBy/sp:OrderByColumn')) + N')'
	end

	select @output = @output + N')'

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatSplit'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatSplit
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatSplit(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = N'Split'

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Split/sp:ActionColumn') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'(' + MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@node_data.query('./sp:Split/sp:ActionColumn/sp:ColumnReference'), 0x1) + N')'
	end

	return @output;
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatStreamAggregate'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatStreamAggregate
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatStreamAggregate(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	declare @need_comma bit

	select @output = N'Stream Aggregate('

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:StreamAggregate/sp:GroupBy') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'GROUP BY: (' + MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@node_data.query('./sp:StreamAggregate/sp:GroupBy/sp:ColumnReference'), 0x1) + N')'
		select @need_comma = 0x1
	end

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = @output + 
			case when @need_comma = 0x1 then N', ' else N'' end 
		+ N'DEFINE: (' + MS_PerfDashboard.fn_ShowplanBuildDefinedValuesList(@node_data.query('./sp:StreamAggregate/sp:DefinedValues/sp:DefinedValue')) + N')'

	select @output = @output + N')'

	return @output;
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatSegment'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatSegment
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatSegment(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = N'Segment'

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Segment/sp:GroupBy/sp:ColumnReference') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'(GROUP BY: ' + MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@node_data.query('./sp:Segment/sp:GroupBy/sp:ColumnReference'), 0x1) + N')'
	end

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatSpool'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatSpool
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatSpool(@node_data xml, @physical_op nvarchar(128))
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = @physical_op

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Spool/sp:SeekPredicate') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'(' + MS_PerfDashboard.fn_ShowplanBuildSeekPredicate(@node_data.query('./sp:Spool/sp:SeekPredicate/*')) + N')'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Spool[@Stack = 1]') = 1)
	begin
		select @output = @output + N' WITH STACK'
	end

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatTableScan'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatTableScan
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatTableScan(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = N'Table Scan('

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = @output + MS_PerfDashboard.fn_ShowplanBuildObject(@node_data.query('./sp:TableScan/sp:Object'))

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:TableScan/sp:Predicate') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', WHERE: (' + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:TableScan/sp:Predicate/*')) + N')'
	end
	
	select @output = @output + N')'

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:TableScan[@Ordered = 1]') = 1)
	begin
		select @output = @output + N' ORDERED'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:TableScan[@ForcedIndex = 1]') = 1)
	begin
		select @output = @output + N' FORCEDINDEX'
	end


	return @output;
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatTop'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatTop
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatTop(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = N'Top'

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Top/sp:TopExpression') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'(TOP EXPRESSION: ' + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:Top/sp:TopExpression/*')) + N')'
	end

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatTVF'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatTVF
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatTVF(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)
	select @output = N'Table-valued Function('

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:TableValuedFunction/sp:Object') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'OBJECT: (' + MS_PerfDashboard.fn_ShowplanBuildObject(@node_data.query('./sp:TableValuedFunction/sp:Object')) + N')'
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:TableValuedFunction/sp:Predicate') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N', WHERE: ( ' + MS_PerfDashboard.fn_ShowplanBuildPredicate(@node_data.query('./sp:TableValuedFunction/sp:Predicate')) + N')'
	end

	select @output = @output + N')'

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatUDX'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatUDX
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatUDX(@node_data xml)
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = N'UDX(' + @node_data.value('(./sp:Extension/@UDXName)[1]', 'nvarchar(128)') + N')'

	return @output;
end
go


if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatUpdate'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatUpdate
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatUpdate(@node_data xml, @physical_op nvarchar(128))
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @output = @physical_op + N'(' + MS_PerfDashboard.fn_ShowplanBuildObject(@node_data.query('./sp:Object/*'))

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:SetPredicate') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = @output + N'SET: ' + MS_PerfDashboard.fn_ShowplanBuildScalarExpression(@node_data.query('./sp:SetPredicate/*'))
	end

	select @output = @output + N')'

	return @output;
end
go



if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanFormatGenericUpdate'), 'IsScalarFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanFormatGenericUpdate
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanFormatGenericUpdate(@node_data xml, @physical_op nvarchar(128))
RETURNS nvarchar(max)
as
begin
	declare @output nvarchar(max)

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:SimpleUpdate') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = MS_PerfDashboard.fn_ShowplanFormatSimpleUpdate(@node_data.query('./sp:SimpleUpdate/*'), @physical_op)
	end

	if (@node_data.exist('declare namespace sp="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; ./sp:Update') = 1)
	begin
		;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
		select @output = MS_PerfDashboard.fn_ShowplanFormatUpdate(@node_data.query('./sp:Update/*'), @physical_op)
	end

	return @output;
end
go


--
-- Created last since it depends on all the above functions for building/formatting the showplan
--
if OBJECTPROPERTY(object_id('MS_PerfDashboard.fn_ShowplanRowDetails'), 'IsTableFunction') = 1
	drop function MS_PerfDashboard.fn_ShowplanRowDetails
go

CREATE FUNCTION MS_PerfDashboard.fn_ShowplanRowDetails(@relop_node xml)
returns @node TABLE (node_id int, stmt_text nvarchar(max), logical_op nvarchar(128), physical_op nvarchar(128), output_list nvarchar(max), avg_row_size float, est_cpu float, est_io float, est_rows float, est_rewinds float, est_rebinds float, est_subtree_cost float, warnings nvarchar(max))
AS
begin
	declare @node_id int
	declare @output_list nvarchar(max)
	declare @stmt_text nvarchar(max)
	declare @logical_op nvarchar(128), @physical_op nvarchar(128)
	declare @avg_row_size float, @est_cpu float, @est_io float, @est_rows float, @est_rewinds float, @est_rebinds float, @est_subtree_cost float
	declare @relop_children xml

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @logical_op = @relop_node.value('(./sp:RelOp/@LogicalOp)[1]', 'nvarchar(128)'),
		@physical_op = @relop_node.value('(./sp:RelOp/@PhysicalOp)[1]', 'nvarchar(128)'),
		@relop_children = @relop_node.query('./sp:RelOp/*')

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	select @stmt_text =
		case 
			when @physical_op = N'Assert' then MS_PerfDashboard.fn_ShowplanFormatAssert(@relop_children)
			when @physical_op = N'Bitmap' then MS_PerfDashboard.fn_ShowplanFormatBitmap(@relop_children)
			when @physical_op in (N'Clustered Index Delete', N'Clustered Index Insert', N'Clustered Index Update', 
						N'Index Delete', N'Index Insert', N'Index Update', 
						N'Table Delete', N'Table Insert', N'Table Update') then MS_PerfDashboard.fn_ShowplanFormatGenericUpdate(@relop_children, @physical_op)
			when @physical_op in (N'Clustered Index Scan', N'Clustered Index Seek', 
						N'Index Scan', N'Index Seek') then MS_PerfDashboard.fn_ShowplanFormatIndexScan(@relop_children, @physical_op)
--			when @physical_op = N'Clustered Update' then 
			when @physical_op = N'Compute Scalar' then MS_PerfDashboard.fn_ShowplanFormatComputeScalar(@relop_children.query('./sp:ComputeScalar/*'), @physical_op)
			when @physical_op = N'Concatenation' then MS_PerfDashboard.fn_ShowplanFormatConcat(@relop_children)
			when @physical_op = N'Constant Scan' then MS_PerfDashboard.fn_ShowplanFormatConstantScan(@relop_children)
			when @physical_op = N'Deleted Scan' then MS_PerfDashboard.fn_ShowplanFormatDeletedInsertedScan(@relop_children.query('./sp:DeletedScan/*'), @physical_op)
			when @physical_op = N'Filter' then MS_PerfDashboard.fn_ShowplanFormatFilter(@relop_children)
--			when @physical_op = N'Generic' then 
			when @physical_op = N'Hash Match' then MS_PerfDashboard.fn_ShowplanFormatHashMatch(@relop_children, @logical_op)
			when @physical_op = N'Index Spool' then MS_PerfDashboard.fn_ShowplanFormatSpool(@relop_children, @physical_op)
			when @physical_op = N'Inserted Scan' then MS_PerfDashboard.fn_ShowplanFormatDeletedInsertedScan(@relop_children.query('./sp:InsertedScan/*'), @physical_op)
			when @physical_op = N'Log Row Scan' then N'Log Row Scan'
			when @physical_op = N'Merge Interval' then N'Merge Interval'
			when @physical_op = N'Merge Join' then MS_PerfDashboard.fn_ShowplanFormatMerge(@relop_children, @logical_op)
			when @physical_op = N'Nested Loops' then MS_PerfDashboard.fn_ShowplanFormatNestedLoops(@relop_children, @logical_op)
			when @physical_op = N'Online Index Insert' then N'Online Index Insert'
			when @physical_op = N'Parallelism' then MS_PerfDashboard.fn_ShowplanFormatParallelism(@relop_children, @logical_op)
			when @physical_op = N'Parameter Table Scan' then N'Parameter Table Scan'
			when @physical_op = N'Print' then N'Print'
			when @physical_op in (N'Remote Delete', N'Remote Insert', N'Remote Update') then MS_PerfDashboard.fn_ShowplanFormatRemoteModify(@relop_children, @logical_op)
			when @physical_op = N'Remote Scan' then MS_PerfDashboard.fn_ShowplanFormatRemoteScan(@relop_children)
			when @physical_op = N'Remote Query' then MS_PerfDashboard.fn_ShowplanFormatRemoteQuery(@relop_children)
			when @physical_op = N'RID Lookup' then N'RID Lookup'
			when @physical_op = N'Row Count Spool' then MS_PerfDashboard.fn_ShowplanFormatSpool(@relop_children, @physical_op)
			when @physical_op = N'Segment' then MS_PerfDashboard.fn_ShowplanFormatSegment(@relop_children)
			when @physical_op = N'Sequence' then N'Sequence'
			when @physical_op = N'Sequence Project' then MS_PerfDashboard.fn_ShowplanFormatComputeScalar(@relop_children.query('./sp:SequenceProject/*'), @physical_op)
			when @physical_op = N'Sort' then MS_PerfDashboard.fn_ShowplanFormatSort(@relop_children, @logical_op)
			when @physical_op = N'Split' then MS_PerfDashboard.fn_ShowplanFormatSplit(@relop_children)
			when @physical_op = N'Stream Aggregate' then MS_PerfDashboard.fn_ShowplanFormatStreamAggregate(@relop_children)
			when @physical_op = N'Switch' then N'Switch'
			when @physical_op = N'Table-valued function' then MS_PerfDashboard.fn_ShowplanFormatTVF(@relop_children)
			when @physical_op = N'Table Scan' then MS_PerfDashboard.fn_ShowplanFormatTableScan(@relop_children)
			when @physical_op = N'Table Spool' then MS_PerfDashboard.fn_ShowplanFormatSpool(@relop_children, @physical_op)
			when @physical_op = N'Top' then MS_PerfDashboard.fn_ShowplanFormatTop(@relop_children)
			when @physical_op = N'UDX' then MS_PerfDashboard.fn_ShowplanFormatUDX(@relop_children)
			else @physical_op + N'(' + @logical_op + N')'
		end	

	;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
	insert @node (
		node_id,
		stmt_text, 
		logical_op, 
		physical_op, 
		output_list, 
		avg_row_size, 
		est_cpu, 
		est_io, 
		est_rows, 
		est_rewinds, 
		est_rebinds, 
		est_subtree_cost,
		warnings)
	values (
		@relop_node.value('(./sp:RelOp/@NodeId)[1]', 'int'),
		@stmt_text, 
		@logical_op, 
		@physical_op, 
		MS_PerfDashboard.fn_ShowplanBuildColumnReferenceList(@relop_node.query('./sp:RelOp/sp:OutputList/sp:ColumnReference'), 0x1),
		@relop_node.value('(./sp:RelOp/@AvgRowSize)[1]', 'float'),
		@relop_node.value('(./sp:RelOp/@EstimateCPU)[1]', 'float'),
		@relop_node.value('(./sp:RelOp/@EstimateIO)[1]', 'float'),
		@relop_node.value('(./sp:RelOp/@EstimateRows)[1]', 'float'), 
		@relop_node.value('(./sp:RelOp/@EstimateRewinds)[1]', 'float'), 
		@relop_node.value('(./sp:RelOp/@EstimateRebinds)[1]', 'float'), 
		@relop_node.value('(./sp:RelOp/@EstimatedTotalSubtreeCost)[1]', 'float'),
		MS_PerfDashboard.fn_ShowplanBuildWarnings(@relop_node)
		);

	return;
end
go