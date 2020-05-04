USE [DBOPS]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER procedure [dbo].[prc_get_SysconfigInfo]
	@Debug bit = 0
as

/*   
Name:			prc_get_SysconfigInfo

To invoke: exec [dbo].[prc_get_SysconfigInfo] @Debug = 1

Description:	Queries and stores all non-default configuration settings.

Last Modified:      Modified By:            Description:
-----------------------------------------------------------------------------------------------------
12/05/2019          Michael Capobianco		Created. Branched from:
											http://www.sqlfingers.com/2015/08/sql-server-query-all-non-default.html
12/06/2019			Michael Capobianco		Smarter merge with delete.
12/12/2019			Michael Capobianco		Removed transaction as merge is single tran by design
*/  
   
set nocount on;
set xact_abort on;

declare @version varchar(128),
		@charindex bigint,
		@majversion varchar(max),
		@temp sql_variant;

select @version = cast(serverproperty('productversion') as varchar(128));
select @charindex = charindex('.', @version);
set @majversion = substring(@version, 1, @charindex-1);
if @majversion in (9,10)
set @temp = 20  else set @temp = 10

declare @defaults table 
(
	id int identity(1,1),
	config varchar(128),
	value sql_variant
);

insert @defaults values
	('access check cache bucket count', 0),
	('access check cache quota', 0),
	('Ad Hoc Distributed Queries', 0),
	('affinity I/O mask', 0),
	('affinity64 I/O mask', 0),
	('affinity mask', 0),
	('affinity64 mask', 0),
	('Agent XPs',0),
	('allow updates', 0),
	('backup compression default', 0),
	('blocked process threshold', 0),
	('c2 audit mode', 0),
	('clr enabled', 0),
	('common criteria compliance enabled', 0),
	('contained database authentication', 0),
	('cost threshold for parallelism', 5),
	('cross db ownership chaining', 0),
	('cursor threshold', -1),
	('Database Mail XPs', 0),
	('default full-text language', 1033),
	('default language', 0),
	('default trace enabled', 1),
	('disallow results from triggers', 0),
	('EKM provider enabled', 0),
	('filestream_access_level', 0),
	('fill factor(%)', 0),
	('ft crawl bandwidth (max)', 100),
	('ft crawl bandwidth (min)', 0),
	('ft notify bandwidth (max)', 100),
	('ft notify bandwidth (min)', 0),
	('index create memory (KB)', 0),
	('in-doubt xact resolution', 0),
	('lightweight pooling', 0),
	('locks', 0),
	('max degree of parallelism', 0),
	('max full-text crawl range', 4),
	('max server memory (MB)', 2147483647),
	('max text repl size (B)', 65536),
	('max worker threads', 0),
	('media retention', 0),
	('min memory per query (KB)', 1024),
	('min server memory (MB)', 0),
	('nested triggers', 1),
	('network packet size (B)', 4096),
	('Ole Automation Procedures', 0),
	('open objects', 0),
	('optimize for ad hoc workloads', 0),
	('PH timeout(s)', 60),
	('precompute rank', 0),
	('priority boost', 0),
	('query governor cost limit', 0),
	('query wait(s)', -1),
	('recovery interval(min)', 0),
	('remote access', 1),
	('remote admin connections', 0),
	('remote login timeout(s)', @temp),
	('remote proc trans', 0),
	('remote query timeout(s)', 600),
	('Replication XPs', 0),
	('scan for startup procs', 0),
	('server trigger recursion', 1),
	('set working set size', 0),
	('show advanced options', 0),
	('SMO and DMO XPs', 1),
	('transform noise words', 0),
	('two digit year cutoff', 2049),
	('user connections', 0),
	('user options', 0),
	('xp_cmdshell', 0);
   
select 
	   s.name as configuration_name,
	   s.value_in_use current_value,
       d.value default_value
  into #tmp_SysconfigInfo
  from @defaults d 
	inner join sys.configurations s
		ON s.name LIKE '%' + d.config + '%'
		and d.value <> s.value_in_use
    where s.name <> 'show advanced options'
 order by s.name;

if (@Debug) = 1
begin
	select *
	from #tmp_SysconfigInfo;
end;

begin try

  merge dbo.SysconfigInfo as target
  using #tmp_SysconfigInfo as source
	 on target.configuration_name = source.configuration_name 
when matched then
update
	set target.current_value = source.current_value,
		target.default_value = source.default_value,
		target.collection_date = getdate()
when not matched by target then
insert
(
	configuration_name,
	current_value,
	default_value
)
values
(
	source.configuration_name,
	source.current_value,
	source.default_value
)
when not matched by source then
delete;

end try

begin catch
    print 'Merge failed.'
    select
        error_number() as ErrorNumber,
        error_severity() as ErrorSeverity,
        error_state() as ErrorState,
        error_procedure() as ErrorProcedure,
        error_line() as ErrorLine,
        error_message() as ErrorMessage
end catch;


GO


