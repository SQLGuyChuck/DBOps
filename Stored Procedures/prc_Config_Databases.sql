SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.prc_Config_Databases
as
SELECT
CAST(serverproperty(N'Servername') AS sysname) AS [Server_Name],
dtb.database_id AS [DBID],
dtb.name AS [DBName],
dtb.user_access_desc as UserAccess,
dtb.recovery_model_desc AS [RecoveryModel],
dtb.state_desc AS CurrentState,
dtb.compatibility_level AS [CompatibilityLevel],
dtb.collation_name AS [Collation],
suser_sname(dtb.owner_sid) AS [Owner],
dtb.create_date AS [CreateDate],
CAST(case when dtb.name in ('master','model','msdb','tempdb') then 1 else dtb.is_distributor end AS bit) AS [IsSystemObject],
dtb.is_ansi_null_default_on AS [AnsiNullDefault],
CAST(case when dmi.mirroring_partner_name is null then 0 else 1 end AS bit) AS [IsMirroringEnabled],
ISNULL(dmi.mirroring_state + 1, 0) AS [MirroringStatus],
dtb.is_db_chaining_on AS [DatabaseOwnershipChaining],
dtb.is_read_only AS [ReadOnly],
dtb.is_in_standby AS InStandby,
dtb.snapshot_isolation_state_desc AS SnapshotIsolationState,
dtb.is_read_committed_snapshot_on AS ReadCommittedSnapshotOn,
dtb.is_ansi_nulls_on AS [AnsiNullsEnabled],
dtb.is_ansi_padding_on AS [AnsiPaddingEnabled],
dtb.is_ansi_warnings_on AS [AnsiWarningsEnabled],
dtb.is_arithabort_on AS [ArithmeticAbortEnabled],
dtb.is_auto_close_on AS [AutoClose],
dtb.is_auto_create_stats_on AS [AutoCreateStatisticsEnabled],
dtb.is_auto_shrink_on AS [AutoShrink],
dtb.is_auto_update_stats_on AS [AutoUpdateStatisticsEnabled],
dtb.is_broker_enabled AS [BrokerEnabled],
dtb.is_fulltext_enabled AS [IsFullTextEnabled],
dtb.is_quoted_identifier_on AS [QuotedIdentifiersEnabled],
dtb.is_trustworthy_on AS [Trustworthy],
dtb.page_verify_option_desc  AS PageVerifyOption,
dtb.is_parameterization_forced AS ForcedParameterizationOn,
dtb.is_published as IsPublished,
dtb.is_merge_published AS IsMergePublished,
dtb.is_subscribed AS ReplSubscriber,
 dtb.is_cdc_enabled AS CDCEnabled,
	dtb.is_encrypted AS Encrypted
	FROM master.sys.databases AS dtb
LEFT OUTER JOIN sys.database_mirroring AS dmi ON dmi.database_id = dtb.database_id
GO
