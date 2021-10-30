SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Config_SQLAgentProperties
AS
BEGIN
	SET NOCOUNT ON
	
	/*IF(OBJECT_ID('temp..#temp_SQLAgentProperties') IS NOT NULL)
		DROP TABLE #temp_SQLAgentProperties
	
	CREATE TABLE #temp_SQLAgentProperties(
		[auto_start] [int] NOT NULL,
		[msx_server_name] [nvarchar](128) NULL,
		[sqlagent_type] [int] NULL,
		[startup_account] [nvarchar](100) NULL,
		[sqlserver_restart] [int] NOT NULL,
		[jobhistory_max_rows] [int] NULL,
		[jobhistory_max_rows_per_job] [int] NULL,
		[errorlog_file] [nvarchar](255) NULL,
		[errorlogging_level] [int] NOT NULL,
		[error_recipient] [nvarchar](30) NULL,
		[monitor_autostart] [int] NOT NULL,
		[local_host_server] [nvarchar](128) NULL,
		[job_shutdown_timeout] [int] NOT NULL,
		[cmdexec_account] [varbinary](64) NULL,
		[regular_connections] [int] NOT NULL,
		[host_login_name] [nvarchar](128) NULL,
		[host_login_password] [varbinary](512) NULL,
		[login_timeout] [int] NOT NULL,
		[idle_cpu_percent] [int] NOT NULL,
		[idle_cpu_duration] [int] NOT NULL,
		[oem_errorlog] [int] NOT NULL,
		[sysadmin_only] [int] NULL,
		[email_profile] [nvarchar](64) NULL,
		[email_save_in_sent_folder] [int] NOT NULL,
		[cpu_poller_enabled] [int] NOT NULL,
		[alert_replace_runtime_tokens] [int] NOT NULL
	)

	INSERT INTO #temp_SQLAgentProperties
		EXEC msdb.dbo.sp_get_sqlagent_properties

	SELECT auto_Start
		, startup_Account
		, SQLServer_restart
		, jobhistory_max_rows
		, jobHistory_max_rows_per_Job
		, errorLog_file
		, errorLogging_level
		, login_timeout
		, email_save_in_sent_folder
	FROM #temp_SQLAgentProperties
	
	DROP TABLE #temp_SQLAgentProperties*/

	DECLARE @auto_start                  INT
	, @startup_account             NVARCHAR(100)
	, @msx_server_name             sysname
	, @sqlserver_restart           INT
	, @jobhistory_max_rows         INT
	, @jobhistory_max_rows_per_job INT
	, @errorlog_file               NVARCHAR(255)
	, @errorlogging_level          INT
	, @error_recipient             NVARCHAR(30)
	, @monitor_autostart           INT
	, @local_host_server           sysname
	, @job_shutdown_timeout        INT
	, @cmdexec_account             VARBINARY(64)
	, @regular_connections         INT
	, @host_login_name             sysname
	, @host_login_password         VARBINARY(512)
	, @login_timeout               INT
	, @idle_cpu_percent            INT
	, @idle_cpu_duration           INT
	, @oem_errorlog                INT
	, @email_profile               NVARCHAR(64)
	, @email_save_in_sent_folder   INT
	, @cpu_poller_enabled          INT
	, @alert_replace_runtime_tokens INT

  -- NOTE: We return all SQLServerAgent properties at one go for performance reasons

  -- Read the values from the registry
  IF ((PLATFORM() & 0x1) = 0x1) -- NT
  BEGIN
    DECLARE @key NVARCHAR(200)

    SELECT @key = N'SYSTEM\CurrentControlSet\Services\'
    IF (SERVERPROPERTY('INSTANCENAME') IS NOT NULL)
      SELECT @key = @key + N'SQLAgent$' + CONVERT (sysname, SERVERPROPERTY('INSTANCENAME'))
    ELSE
      SELECT @key = @key + N'SQLServerAgent'

    EXECUTE master.dbo.xp_regread N'HKEY_LOCAL_MACHINE',
                                  @key,
                                  N'Start',
                                  @auto_start OUTPUT,
                                  N'no_output'
    EXECUTE master.dbo.xp_regread N'HKEY_LOCAL_MACHINE',
                                  @key,
                                  N'ObjectName',
                                  @startup_account OUTPUT,
                                  N'no_output'
  END
  ELSE
  BEGIN
    SELECT @auto_start = 3 -- Manual start
    SELECT @startup_account = NULL
  END
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'MSXServerName',
                                         @msx_server_name OUTPUT,
                                         N'no_output'

  -- Non-SQLDMO exposed properties
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'RestartSQLServer',
                                         @sqlserver_restart OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'JobHistoryMaxRows',
                                         @jobhistory_max_rows OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'JobHistoryMaxRowsPerJob',
                                         @jobhistory_max_rows_per_job OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'ErrorLogFile',
                                         @errorlog_file OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'ErrorLoggingLevel',
                                         @errorlogging_level OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'ErrorMonitor',
                                         @error_recipient OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'MonitorAutoStart',
                                         @monitor_autostart OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'ServerHost',
                                         @local_host_server OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'JobShutdownTimeout',
                                         @job_shutdown_timeout OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'CmdExecAccount',
                                         @cmdexec_account OUTPUT,
                                         N'no_output'
  SET @regular_connections = 0
  SET @host_login_name = NULL
  SET @host_login_password = NULL

  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'LoginTimeout',
                                         @login_timeout OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'IdleCPUPercent',
                                         @idle_cpu_percent OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'IdleCPUDuration',
                                         @idle_cpu_duration OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'OemErrorLog',
                                         @oem_errorlog OUTPUT,
                                         N'no_output'

  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'EmailProfile',
                                         @email_profile OUTPUT,
                                         N'no_output'
  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'EmailSaveSent',
                                         @email_save_in_sent_folder OUTPUT,
                                         N'no_output'

  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'AlertReplaceRuntimeTokens',
                                         @alert_replace_runtime_tokens OUTPUT,
                                         N'no_output'

  EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
                                         N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
                                         N'CoreEngineMask',
                                         @cpu_poller_enabled OUTPUT,
                                         N'no_output'
  IF (@cpu_poller_enabled IS NOT NULL)
    SELECT @cpu_poller_enabled = CASE WHEN (@cpu_poller_enabled & 32) = 32 THEN 0 ELSE 1 END

  -- Return the values to the client
  SELECT auto_start = CASE @auto_start
                        WHEN 2 THEN 1 -- 2 means auto-start
                        WHEN 3 THEN 0 -- 3 means don't auto-start
                        ELSE 0        -- Safety net
                      END,
         msx_server_name = @msx_server_name,
         sqlagent_type = (SELECT CASE
                                    WHEN (COUNT(*) = 0) AND (ISNULL(DATALENGTH(@msx_server_name), 0) = 0) THEN 1 -- Standalone
                                    WHEN (COUNT(*) = 0) AND (ISNULL(DATALENGTH(@msx_server_name), 0) > 0) THEN 2 -- TSX
                                    WHEN (COUNT(*) > 0) AND (ISNULL(DATALENGTH(@msx_server_name), 0) = 0) THEN 3 -- MSX
                                    WHEN (COUNT(*) > 0) AND (ISNULL(DATALENGTH(@msx_server_name), 0) > 0) THEN 0 -- Multi-Level MSX (currently invalid)
                                    ELSE 0 -- Invalid
                                  END
                           FROM msdb.dbo.systargetservers),
		 startup_account = @startup_account,
		 sqlserver_restart = ISNULL(@sqlserver_restart, 1),
         jobhistory_max_rows = @jobhistory_max_rows,
         jobhistory_max_rows_per_job = @jobhistory_max_rows_per_job,
         errorlog_file = @errorlog_file,
         errorlogging_level = ISNULL(@errorlogging_level, 7),
         error_recipient = @error_recipient,
         monitor_autostart = ISNULL(@monitor_autostart, 0),
         local_host_server = @local_host_server,
         job_shutdown_timeout = ISNULL(@job_shutdown_timeout, 15),
         cmdexec_account = CONVERT(NVARCHAR(MAX), @cmdexec_account),
         regular_connections = ISNULL(@regular_connections, 0),
         host_login_name = @host_login_name,
         --host_login_password = @host_login_password,
         login_timeout = ISNULL(@login_timeout, 30),
         idle_cpu_percent = ISNULL(@idle_cpu_percent, 10),
         idle_cpu_duration = ISNULL(@idle_cpu_duration, 600),
         oem_errorlog = ISNULL(@oem_errorlog, 0),
         sysadmin_only = NULL,
         email_profile = @email_profile,
         email_save_in_sent_folder = ISNULL(@email_save_in_sent_folder, 0),
         cpu_poller_enabled = ISNULL(@cpu_poller_enabled, 0),
         alert_replace_runtime_tokens = ISNULL(@alert_replace_runtime_tokens, 0)

END;
;
GO
