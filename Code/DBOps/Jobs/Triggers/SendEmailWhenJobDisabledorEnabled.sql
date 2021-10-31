
USE msdb
GO 

IF EXISTS(SELECT * FROM sys.objects WHERE name = 'tr_SysJobs_enabled' And type = 'TR')
BEGIN
	EXEC('Drop trigger dbo.tr_SysJobs_enabled')
	IF (@@error = 0)
		PRINT 'Successfully dropped trigger dbo.tr_SysJobs_enabled.'
	ELSE
	BEGIN
		PRINT 'FAILED to create trigger dbo.tr_SysJobs_enabled.'
	END
END
GO

PRINT 'Creating Trigger: dbo.tr_SysJobs_enabled'
GO

Create TRIGGER dbo.tr_SysJobs_enabled  
ON msdb.dbo.sysjobs 
FOR UPDATE AS  
----------------------------------------------------------------------------  
-- Object Type : Trigger  
-- Object Name : msdb..tr_SysJobs_enabled
-- Description : trigger to email DBA team when a job is enabled or disabled  
-- Author : http://www.mssqltips.com/tip.asp?tip=1803
-- Date : 09 June 2011  
----------------------------------------------------------------------------  
SET NOCOUNT ON  

DECLARE @UserName VARCHAR(50),  
@HostName VARCHAR(50),  
@JobName VARCHAR(100),  
@DeletedJobName VARCHAR(100),  
@New_Enabled INT,  
@Old_Enabled INT,  
@Bodytext VARCHAR(200),  
@SubjectText VARCHAR(200), 
@Servername VARCHAR(50) 

SELECT @UserName = SYSTEM_USER, @HostName = HOST_NAME()  
SELECT @New_Enabled = Enabled FROM Inserted  
SELECT @Old_Enabled = Enabled FROM Deleted  
SELECT @JobName = Name FROM Inserted  
SELECT @Servername = @@servername 

-- check if the enabled flag has been updated. 
IF @New_Enabled <> @Old_Enabled  
BEGIN  

  IF @New_Enabled = 1  
  BEGIN  
    SET @bodytext = 'User: '+@username+' from '+@hostname+
        ' ENABLED SQL Job ['+@jobname+'] at '+CONVERT(VARCHAR(20),GETDATE(),100)  
    SET @subjecttext = @Servername+' : ['+@jobname+
        '] has been ENABLED at '+CONVERT(VARCHAR(20),GETDATE(),100)  
  END  

  IF @New_Enabled = 0  
  BEGIN  
    SET @bodytext = 'User: '+@username+' from '+@hostname+
        ' DISABLED SQL Job ['+@jobname+'] at '+CONVERT(VARCHAR(20),GETDATE(),100)  
    SET @subjecttext = @Servername+' : ['+@jobname+
        '] has been DISABLED at '+CONVERT(VARCHAR(20),GETDATE(),100)  
  END  

  SET @subjecttext = 'SQL Job on ' + @subjecttext  

  -- send out alert email 
  EXEC dbops.dbo.prc_InternalSendMail  
  @Address = 'chuck.lathrope@limeade.com', --<<< insert your team email here 
  @body = @bodytext,  
  @subject = @subjecttext  

END 

