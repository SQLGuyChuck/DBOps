SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Maint_VLFTracking
	@DBName sysname = NULL
AS   
BEGIN
/******************************************************************************
**    Name: prc_Maint_VLFTracking
**
**    Desc: Get log file fragmentation count - ~ <200 is fine.
**
*******************************************************************************
**    Change History
*******************************************************************************
**  Date:       Author:         	Description:
**	7/31/2013	Chuck Lathrope		Refactoring DB status check
******************************************************************************/
	SET NOCOUNT ON

	Declare @DBMode VARCHAR(50),
			@name SYSNAME ,  
			@stmt VARCHAR(40)   

	CREATE TABLE #vlf_temp 
		( RecoveryUnitID int,
			FileID VARCHAR(3) ,  
			FileSize NUMERIC(20, 0) ,  
			StartOffset BIGINT ,  
			FSeqNo BIGINT ,  
			Status CHAR(1) ,  
			Parity VARCHAR(4) ,  
			CreateLSN NUMERIC(25, 0)  
		)      

	If (@@microsoftversion / 0x1000000) & 0xff < 11
	--removing the additional column created in 2012+
	BEGIN
		ALTER TABLE #vlf_temp
		DROP COLUMN RecoveryUnitID 
	END

	CREATE TABLE #VLF_db_total_temp 
		(  name SYSNAME ,  
			vlf_count INT  
		)      
    
	DECLARE db_cursor CURSOR Forward_ONLY FOR  

		SELECT  name  
		FROM    master.dbo.sysdatabases  
		WHERE Name = ISNULL(@DBName,Name)

		OPEN db_cursor      

		FETCH NEXT FROM db_cursor INTO @name      

		WHILE ( @@fetch_status <> -1 )   
		BEGIN      

			IF ( @@fetch_status <> -2 )   
			BEGIN      

			--Check Database Accessibility
			SELECT @DBMode = CAST(DATABASEPROPERTYEX(@name, 'Status') AS VARCHAR(30))
			
			IF @DBMode = 'ONLINE'
			BEGIN
				INSERT  INTO #vlf_temp 
				EXEC ( 'DBCC LOGINFO ([' + @name + ']) WITH NO_INFOMSGS' )
 
				INSERT  INTO #VLF_db_total_temp  

					SELECT  @name, COUNT(*)  
					FROM    #vlf_temp     

				TRUNCATE TABLE #vlf_temp     
			END
			ELSE
				PRINT 'Database [' + @name + '] is in ' + @DBMode + ' mode and needs to be in ONLINE mode.'
			END      
			FETCH NEXT FROM db_cursor INTO @name      
		END      

		CLOSE db_cursor      

		DEALLOCATE db_cursor 

		SELECT  GETDATE() AS ExtractDate ,  
			name AS [DBName] ,  
			vlf_count AS [VLFCount]  
		FROM    #VLF_db_total_temp  
		ORDER BY vlf_count DESC      
 
END      

;
GO
