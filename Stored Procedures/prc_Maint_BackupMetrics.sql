SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Maint_BackupMetrics
	@DBList VARCHAR(500) = NULL,
	@ShowFileDetails bit = 1,
	@BackupType CHAR(1) = NULL
AS
BEGIN
/******************************************************************************
**    Name: prc_Maint_BackupMetrics
**
**    Desc: Get backup history on all or a few databases.
**
*******************************************************************************
**    Change History
*******************************************************************************
**    Date:       Author:           Description:
**	7/31/2013	Chuck Lathrope		Change parameter default to 1 show details.
**	8/20/2013	Chuck Lathrope		Added @IncludeCopyOnly and is_copy_only and is_snapshot outputs
**  8/27/2013	Chuck Lathrope		Fixed last update so that missing backups appear.
**  12/12/2013	Chuck Lathrope		Removed @IncludeCopyOnly bit as code was hiding info.
******************************************************************************/

	SELECT  DISTINCT CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server,   
		--Getdate() as CaptureDate,  
		d.name as DBName,    
		d.state_desc as DBState,  
		d.recovery_model_desc as Recovery  
		,BackupType = CASE bs.type WHEN 'D' THEN 'Full DB'    
		WHEN 'I' THEN 'Diff DB'    
		WHEN 'L' THEN 'Log'    
		WHEN 'F' THEN 'FileorFileGroup'    
		WHEN 'G' THEN 'Diff file'    
		WHEN 'P' THEN 'Partial'    
		WHEN 'Q' THEN 'Diff partial'    
		ELSE 'UNKNOWN'   
		END  
		,is_copy_only
		,is_snapshot
		,bs.backup_finish_date,  
		DATEDIFF(MINUTE,bs.backup_start_date, bs.backup_finish_date) DurationMin,--Minutes to Complete  
		CAST(bs.backup_size/1024/1024 as INT) BackupMB,
		CASE WHEN @ShowFileDetails = 1 THEN bmf.physical_device_name
			 WHEN @ShowFileDetails = 0 and LEFT(bmf.physical_device_name,1) = '{' THEN bmf.physical_device_name
			 ELSE LEFT(bmf.physical_device_name,LEN(bmf.physical_device_name)-CHARINDEX('\',REVERSE(bmf.physical_device_name),1)) END AS [FILEDetails]
	FROM  sys.databases d
	LEFT JOIN  (Select max(bs.backup_set_id) backup_set_id, bs.database_name,bs.type  
				FROM msdb.dbo.backupset bs  
				JOIN msdb.dbo.backupmediafamily  bmf ON bmf.media_set_id = bs.media_set_id    
				Group by bs.database_name,bs.type) t on t.database_name = d.Name  
	LEFT JOIN msdb.dbo.backupset bs on t.backup_set_id = bs.backup_set_id AND bs.type = ISNULL(@BackupType,bs.type) 
	LEFT JOIN msdb.dbo.backupmediafamily  bmf ON bmf.media_set_id = bs.media_set_id    
	WHERE d.name NOT IN ( 'tempdb', 'model')
	AND (@DBList IS NULL 
		OR d.name in (SELECT RowValue FROM dbo.GetDelimListasTable(@DBList,','))
	)
	
	ORDER BY d.name  
END;
;
GO
