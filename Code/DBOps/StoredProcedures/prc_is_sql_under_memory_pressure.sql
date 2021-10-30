SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_is_sql_under_memory_pressure]
with recompile
as

/* =========================================================================================================
 Author: Michael Capobianco
 Create Date: 06/18/2019
 Description:	Is SQL Server under Memory Pressure?
				https://cms4j.wordpress.com/2014/12/08/is-sql-server-under-high-memory-pressure/
     
				This check consists of 3 Steps:
				
				1) Check Actual Page Life Expectancy    - with the help of Jonathan Kehayias adaptive PLE
				   https://www.sqlskills.com/blogs/jonathan/finding-what-queries-in-the-plan-cache-use-a-specific-index/
				2) Check Top Wait Stat                  - with the help of Paul Randal's Wait Stats CHECK
                   http://www.sqlskills.com/blogs/paul/wait-statistics-or-please-tell-me-where-it-hurts/
				3) Check Buffer Pool Rate               - With the help of SQL Rockstars Buffer Pool Rate Calculation
                   http://thomaslarock.com/2012/05/are-you-using-the-right-sql-server-performance-metrics/ -> Buffer Pool I/O Rate

Usage:			exec dbo.csp_is_sql_under_memory_pressure

Change History: 

Change Date		Change By	Sprint#		Change Comment
06/18/2019		Michael C	--			Created from Christoph Müller-Spengler's is-sql-server-under-high-memory-pressure. Modifed for sproc use.
06/19/2019		Michael C	--			Small changes 																					
========================================================================================================= */ 

set nocount on;
set transaction isolation level read uncommitted;
 
declare @MaxServerMemory int
		,@ActualPageLifeExpectancy int
		,@RecommendedPageLifeExpectancy int
		,@RecommendedMemory int
		,@TopWaitType sysname
		,@BufferPoolRate numeric(20,2)
		,@MemoryGrantsPending int
		,@CurrentMemoryUtilizationPct float;

declare @wait_stats table
(
	[wait_type] varchar(255),
	[wait_seconds] decimal(16,2),
	[resource_seconds] decimal(16,2),
	[signal_seconds] decimal(16,2),
	[wait_count] bigint,
	[wait_percentage] decimal(5,2),
	[avg_wait_seconds] decimal(16,4),
	[avg_resource_seconds] decimal(16,4),
	[avg_signal_seconds] decimal(16,4)
);
 
select @MaxServerMemory = (1.0 * cntr_value / 1024 / 1024)
        ,@RecommendedPageLifeExpectancy = convert(int ,(1.0 * cntr_value) / 1024 / 1024 / 4.0 * 300)
  from sys.dm_os_performance_counters
 where ltrim(rtrim(counter_name)) = 'Target Server Memory (KB)';
 
select @ActualPageLifeExpectancy = 1.0 * cntr_value
  from sys.dm_os_performance_counters
 where ltrim(rtrim(object_name)) LIKE '%:Buffer Manager%'
   and ltrim(rtrim(counter_name)) = 'Page life expectancy';

select @MemoryGrantsPending = cntr_value                                                                                                       
  from sys.dm_os_performance_counters 
 where ltrim(rtrim(counter_name)) = 'Memory Grants Pending'


select @CurrentMemoryUtilizationPct = cast(round((1.0 - available_physical_memory_kb / ( total_physical_memory_kb * 1.0 )),2) * 100 as float)
  from sys.dm_os_sys_memory;

-- Should match dbo.csp_get_wait_stat_info; since this is used by dbo.csp_get_performance_info,
-- avoiding the insert exec issue by duplicating the logic in the dbo.csp_get_wait_stat_info SP.
-- Isolate top waits for server instance since last restart or wait statistics clear 
with [Waits] 
as (select wait_type, wait_time_ms/ 1000.0 as [WaitS],
          (wait_time_ms - signal_wait_time_ms) / 1000.0 as [ResourceS],
           signal_wait_time_ms / 1000.0 as [SignalS],
           waiting_tasks_count as [WaitCount],
           100.0 *  wait_time_ms / sum (wait_time_ms) over() as [Percentage],
           row_number() over(order by wait_time_ms desc) as [RowNum]
    from sys.dm_os_wait_stats
    where [wait_type] not in 
	(
        N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP',
		N'BROKER_TO_FLUSH', N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE',
        N'CHKPT', N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE',
        N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE', N'DBMIRROR_WORKER_QUEUE',
		N'DBMIRRORING_CMD', N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
        N'EXECSYNC', N'FSAGENT', N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX',
        N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_LOGCAPTURE_WAIT', 
		N'HADR_NOTIFICATION_DEQUEUE', N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE', N'HADR_DATABASE_FLOW_CONTROL',
        N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE', 
		N'MEMORY_ALLOCATION_EXT', N'ONDEMAND_TASK_QUEUE',
		N'PREEMPTIVE_OS_LIBRARYOPS', N'PREEMPTIVE_OS_COMOPS', N'PREEMPTIVE_OS_CRYPTOPS',
		N'PREEMPTIVE_OS_PIPEOPS', N'PREEMPTIVE_OS_AUTHENTICATIONOPS',
		N'PREEMPTIVE_OS_GENERICOPS', N'PREEMPTIVE_OS_VERIFYTRUST',
		N'PREEMPTIVE_OS_FILEOPS', N'PREEMPTIVE_OS_DEVICEOPS',
        N'PWAIT_ALL_COMPONENTS_INITIALIZED', N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
		N'QDS_ASYNC_QUEUE', N'QDS_SHUTDOWN_QUEUE',
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', N'REQUEST_FOR_DEADLOCK_SEARCH',
		N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH', N'SLEEP_DBSTARTUP',
		N'SLEEP_DCOMSTARTUP', N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
        N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP', N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
        N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT', N'SP_SERVER_DIAGNOSTICS_SLEEP',
		N'SQLTRACE_BUFFER_FLUSH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', N'SQLTRACE_WAIT_ENTRIES',
		N'WAIT_FOR_RESULTS', N'WAITFOR', N'WAITFOR_TASKSHUTDOWN', N'WAIT_XTP_HOST_WAIT',
		N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', N'WAIT_XTP_CKPT_CLOSE', N'XE_DISPATCHER_JOIN',
        N'XE_DISPATCHER_WAIT', N'XE_LIVE_TARGET_TVF', N'XE_TIMER_EVENT')
    and waiting_tasks_count > 0)
insert into @wait_stats
	(
		[wait_type],
		[wait_seconds],
		[resource_seconds],
		[signal_seconds],
		[wait_count],
		[wait_percentage],
		[avg_wait_seconds],
		[avg_resource_seconds],
		[avg_signal_seconds]
)
select max(w1.wait_type) as [wait_type],
		cast(max (w1.WaitS) as decimal (16,2)) as [wait_seconds],
		cast(max (w1.ResourceS) as decimal (16,2)) as [resource_seconds],
		cast(max (w1.SignalS) as decimal (16,2)) as [signal_seconds],
		max(w1.WaitCount) as [wait_count],
		cast(max(w1.[Percentage]) as decimal (5,2)) as [wait_percentage],
		cast((max (w1.WaitS) / max(w1.WaitCount)) as decimal (16,4)) as [avg_wait_seconds],
		cast((max (w1.ResourceS) / max(w1.WaitCount)) as decimal (16,4)) as [avg_resource_seconds],
		cast((max (w1.SignalS) / max(w1.WaitCount)) as decimal (16,4)) as [avg_signal_seconds]
from Waits as w1
	inner join Waits AS w2
		on w2.RowNum <= w1.RowNum
group by w1.RowNum
having sum (w2.percentage) - max (w1.percentage) < 99; -- percentage threshold

select top 1 @TopWaitType = [wait_type]
  from @wait_stats
 where [wait_type] not in (N'BACKUPBUFFER', N'BACKUPIO');

select @BufferPoolRate = (1.0 * cntr_value/128.0)/ @ActualPageLifeExpectancy
  from sys.dm_os_performance_counters
 where object_name LIKE '%Buffer Manager%'
   and counter_name = 'Database pages';
 
select @RecommendedMemory = convert(int, @RecommendedPageLifeExpectancy / @ActualPageLifeExpectancy * @MaxServerMemory);
 
select 'Is SQL Server under Memory Pressure?' = 
		case
			when lower(sm.system_memory_state_desc) <> 'available physical memory is high' then 'Yes, external Memory Pressure'
			when pm.process_physical_memory_low <> 0 or pm.process_virtual_memory_low <> 0 then 'Yes, internal Memory Pressure'
			when @TopWaitType like 'PAGEIOLATCH_%' then 'Yes, high PAGEIOLATCH_% waits'
			when @MemoryGrantsPending > 0 and @BufferPoolRate > 20.0 then 'Yes, pending memory grants combined with a high buffer pool rate'
			else 'No'
		end
		,@CurrentMemoryUtilizationPct as [Current Memory Usage %]
		,sm.total_physical_memory_kb/1024/1024 as [Physical Memory (GB)]
		,sm.available_physical_memory_kb/1024/1024 as [Available Physical Memory (GB)]
		,pm.physical_memory_in_use_kb/1024/1024 AS [SQL Server Memory Usage (GB)]
        ,@MaxServerMemory as [Max Server Memory (GB)]
		,sm.total_page_file_kb/1024/1024 as [Total Page File (GB)]
		,sm.available_page_file_kb/1024/1024 as [Available Page File (GB)]
		,sm.system_cache_kb/1024/1024 as [System Cache (GB)] 
        ,@ActualPageLifeExpectancy as [Actual PLE]
        ,@RecommendedPageLifeExpectancy as [Ideal PLE]
		,'Ideal Memory (GB)' = 
			case
				when @RecommendedMemory < @MaxServerMemory then @MaxServerMemory
				else @RecommendedMemory
			end
        ,@TopWaitType as [Top Wait Type]
		,@MemoryGrantsPending as [Memory Grants Pending]
        ,@BufferPoolRate as [Ideal Buffer Pool Rate (< 20)]
		,sm.system_memory_state_desc AS [System Memory State]
		,pm.process_physical_memory_low as [Process Physical Memory Low]
		,pm.process_virtual_memory_low as [Process Virtual Memory Low]
    from sys.dm_os_sys_memory sm
		cross join sys.dm_os_process_memory pm;


GO
