SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_is_sql_under_high_cpu_pressure]
with recompile
as

/* =========================================================================================================
Author: Michael Capobianco
Create Date: 06/18/2019

Description:	Is SQL Server under high CPU Pressure?
				https://cms4j.wordpress.com/2014/09/30/is-sql-server-under-high-cpu-pressure/

Usage:			exec dbo.csp_is_sql_under_high_cpu_pressure;

Change History: 

Change Date		Change By	Sprint#		Change Comment
06/18/2019		Michael C	--			Created from Christoph Müller-Spengler's is-sql-server-under-high-cpu-pressure. Modifed for sproc use.
06/19/2019		Michael C	--			Small changes 																					
========================================================================================================= */ 


set nocount on;
set transaction isolation level read uncommitted;

declare @AvgTaskCount int
		,@AvgRunnableTaskCount int
		,@AvgPendingDiskIOCount int
		,@PercentageSignalWaits float
		,@PercentageResourceWaits float
		,@PercentageSignalWaitsWithExclusions float
		,@SubstractedValue float
		,@CurrentCpu float;

/*
High Avg Task Counts (>10) are often caused by blocking or other resource contention
High Avg Runnable Task Counts (>1) are a good sign of CPU pressure
High Avg Pending DiskIO Counts (>1) are a sign of disk pressure
*/

set @CurrentCpu = 
( 
	select top (1) [CPU]+[OtherProcessCPU]  as [cpu_usage]
      from (select record.value('(./Record/@id)[1]', 'int') as record_id,
					 100-record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int')-record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS [OtherProcessCPU]
					,record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS [CPU]
              from (select [timestamp]
                           ,convert(xml, record) as [record]
                      from  sys.dm_os_ring_buffers 
                     where ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
                       and record like N'%<SystemHealth>%') as x) as y
           order by record_id desc
);

select @AvgTaskCount = avg(current_tasks_count)
		,@AvgRunnableTaskCount = avg(runnable_tasks_count)
		,@AvgPendingDiskIOCount = avg(pending_disk_io_count)
 from sys.dm_os_schedulers
where scheduler_id < 255;
 
select @PercentageSignalWaits = (( sum(cast(signal_wait_time_ms as numeric(20, 2))) / sum(cast(wait_time_ms as numeric(20, 2))) * 100 ))
		,@PercentageResourceWaits = ((sum(cast(wait_time_ms as numeric(20,2)) - cast(signal_wait_time_ms as numeric(20,2))) / sum (cast(wait_time_ms as numeric(20,2))) * 100))
		,@PercentageSignalWaitsWithExclusions = 
              (select (sum(cast(wpr.signal_wait_time_ms as numeric(20, 2))) / sum(cast(wpr.wait_time_ms as numeric(20, 2))) * 100 )
                from sys.dm_os_wait_stats wpr
               where wpr.wait_type not like '%SLEEP%' -- remove eg. SLEEP_TASK and
                -- LAZYWRITER_SLEEP waits
                and wpr.wait_type not like 'XE%' -- remove Extended Events
                and wpr.wait_type not in 
				(-- remove system waits
                        N'BROKER_EVENTHANDLER',N'BROKER_RECEIVE_WAITFOR',N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH',N'BROKER_TRANSMITTER',N'CHECKPOINT_QUEUE',
                        N'CHKPT',N'CLR_AUTO_EVENT',N'CLR_MANUAL_EVENT',N'CLR_SEMAPHORE',N'DBMIRROR_DBM_EVENT',N'DBMIRROR_EVENTS_QUEUE',N'DBMIRROR_WORKER_QUEUE',
						N'DBMIRRORING_CMD',N'DIRTY_PAGE_POLL',N'DISPATCHER_QUEUE_SEMAPHORE',N'EXECSYNC',N'FSAGENT',N'FT_IFTS_SCHEDULER_IDLE_WAIT',N'FT_IFTSHC_MUTEX',
						N'HADR_CLUSAPI_CALL',N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',N'HADR_LOGCAPTURE_WAIT',N'HADR_NOTIFICATION_DEQUEUE',N'HADR_TIMER_TASK',N'HADR_WORK_QUEUE',
                        N'KSOURCE_WAKEUP',N'LAZYWRITER_SLEEP',N'LOGMGR_QUEUE',N'ONDEMAND_TASK_QUEUE',N'PWAIT_ALL_COMPONENTS_INITIALIZED',N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
                        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',N'REQUEST_FOR_DEADLOCK_SEARCH',N'RESOURCE_QUEUE',N'SERVER_IDLE_CHECK',N'SLEEP_BPOOL_FLUSH',
                        N'SLEEP_DBSTARTUP',N'SLEEP_DCOMSTARTUP',N'SLEEP_MASTERDBREADY',N'SLEEP_MASTERMDREADY',N'SLEEP_MASTERUPGRADED',N'SLEEP_MSDBSTARTUP',N'SLEEP_SYSTEMTASK',
						N'SLEEP_TASK',N'SLEEP_TEMPDBSTARTUP',N'SNI_HTTP_ACCEPT',N'SP_SERVER_DIAGNOSTICS_SLEEP',N'SQLTRACE_BUFFER_FLUSH',N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
                        N'SQLTRACE_WAIT_ENTRIES',N'WAIT_FOR_RESULTS',N'WAITFOR',N'WAITFOR_TASKSHUTDOWN',N'WAIT_XTP_HOST_WAIT',N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',N'WAIT_XTP_CKPT_CLOSE',
						N'XE_DISPATCHER_JOIN',N'XE_DISPATCHER_WAIT',N'XE_TIMER_EVENT')
				)
  from sys.dm_os_wait_stats;
 
select @SubstractedValue = @PercentageSignalWaits - @PercentageSignalWaitsWithExclusions;
 
select 'Is SQL Server under high CPU Pressure?' = 
		case
			when @PercentageSignalWaits < 15.0 then 'No'
			when @PercentageSignalWaits > 15.0 and @SubstractedValue > 0.0 then 'No'
			when @PercentageSignalWaits > 15.0 and @SubstractedValue < 0.0 then 'Yes'
        end
		,@CurrentCpu as [Current CPU %]
		,@PercentageSignalWaits as [Signal Waits %]
		,@PercentageSignalWaitsWithExclusions as [Signal Waits % (w/ Wait Exclusions)]
		,@PercentageResourceWaits as [Resource Waits %]
		,@AvgTaskCount as [>10 (Lock Escalation / Resource Contention)]
		,@AvgRunnableTaskCount as [>1 (CPU Pressure)]
		,@AvgPendingDiskIOCount as [>1 (I/O Pressure)];

GO
