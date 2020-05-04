SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
** Name: prc_Error  
** Desc: Universal error handling for capturing all system provided errors.      
**    Default is to just raiserror. Includes ability to print, email, and/or log to table.      
** Compatibility: SQL 2005+  
**      
** @Options variables you can pass in (delimiter not necessary if more than one provided):      
** print - Print error message.      
** alert/email - Email alert to someone.       
** norecord - don't log to logs table, default is to log to logs table now.     
** log   - Write Raiserror to Event Log on server.      
** suppress - Don't raise RAISERROR event (overrides LOG option).      
**  
** Example (do include the @ProcNameSource when linked servers are involved):     
** EXEC prc_Error @AlertEmail='alerts@YourDomainNameHere.com',   
**  @options = 'alert', @custmsg = 'My proc threw an error!', @procnamesource = 'tempdb.dbo.prc_test'      
**  
*******************************************************************************      
**  Change History      
*******************************************************************************      
** Date:		Author:			Description:      
** 6/16/2011	Chuck Lathrope	Simplified proc for DBOPS db use.
** 5/15/2015	Chuck Lathrope	Bug fix on alternate error msg and @ErrorProcedure population improvement
*******************************************************************************/      
/*
--Testing:
USE master
go
EXEC dbops.dbo.prc_Error @custmsg = 'from master',@AlertSubject='Test prc_Error',@Options='',@ProcNameSource=
*/
CREATE OR ALTER PROCEDURE dbo.prc_Error
    @CustMsg VARCHAR(MAX) = ''
    ,@AlertEmail VARCHAR(1000) = 'Alerts@YourDomainNameHere.com'--'chuck.lathrope@YourDomainNameHere.com'--
    ,@AlertSubject VARCHAR(255) = ''
    ,@Options VARCHAR(40) = '' --norecord,print,alert/email,suppress (suppress RAISERROR event)      
    ,@ProcNameSource VARCHAR(80) = NULL --Provide using Object_Name(@@ProcID) when nested proc could raise error.      
  
--Add execute as owner only when non-admin accounts call it. Database has to be trustworthy.  
WITH EXECUTE AS OWNER
AS 
    BEGIN  
  
        SET NOCOUNT ON  
  
        DECLARE @Msg VARCHAR(MAX) ,
            @Ret VARCHAR(2) ,
            @ErrorNumber AS INT ,
            @ErrorSeverity AS TINYINT ,
            @ErrorState AS INT ,
            @ErrorProcedure AS VARCHAR(100) ,
            @ErrorLine AS SMALLINT ,
            @ErrorMessage AS VARCHAR(MAX) ,
            @ServerName SYSNAME ,
            @DBName SYSNAME ,
            @Success BIT ,
            @SQLString NVARCHAR(1000) ,
            @ParmDefinition NVARCHAR(1000) ,
            @AlternateErrorMsg VARCHAR(MAX)  
  
		--Initialize variables      
        SELECT  @ErrorNumber = ISNULL(ERROR_NUMBER(), '') ,
                @ErrorSeverity = ISNULL(ERROR_SEVERITY(), '') ,
                @ErrorState = ISNULL(ERROR_STATE(), '') ,
                @ErrorProcedure = COALESCE(@ProcNameSource, ERROR_PROCEDURE(), '') ,
                @ErrorLine = ISNULL(ERROR_LINE(), '') ,
                @ErrorMessage = ISNULL(ERROR_MESSAGE(), '') ,
                @ServerName = @@ServerName ,
                @DBName = DB_NAME() ,
                @CustMsg = COALESCE(@CustMsg, '') ,
                @AlternateErrorMsg = '' ,
                @Ret = CHAR(13) + CHAR(13)  
  
  
        IF ERROR_MESSAGE() IS NULL 
        BEGIN --then this is a custom error, we can use simple Msg  

            SET @Msg = 'Error Msg: ' + @CustMsg + @Ret + 'Time: '
                + CAST(GETDATE() AS VARCHAR(20)) + @Ret      
            SET @ErrorSeverity = 16      
            SET @ErrorState = 1      

        END      
        ELSE --if there is a real sql error, then grab everything      
        BEGIN      
            SET @Msg = 'ProcName = ' + @ErrorProcedure
                + ', Error Line# = ' + CAST(@ErrorLine AS VARCHAR(10))
                + @Ret + COALESCE('Passed in ProcName = ' + @ProcNameSource + @Ret, '')
                + 'Error Num = ' + CAST(@ErrorNumber AS VARCHAR(10))
                + '; Severity = ' + CAST(@ErrorSeverity AS VARCHAR(10))
                + '; State = ' + CAST(@ErrorState AS VARCHAR(10)) + @Ret
                + 'Error Message = ' + @ErrorMessage      
            IF @CustMsg <> '' 
                SET @Msg = @Msg + @Ret + 'Custom Error Msg = ' + @CustMsg    
        END  
  
        IF @Options LIKE '%print%' 
            PRINT @Msg  
  
		--Send Email Alert      
        IF @Options LIKE '%alert%'
            OR @Options LIKE '%email%' 
        BEGIN      
            IF ISNULL(@AlertSubject, '') = '' 
                SET @AlertSubject = 'SQL Error: ' + LEFT(@CustMsg, 50)      

            EXEC prc_InternalSendMail @Address = @AlertEmail,
                @Subject = @AlertSubject, @Body = @Msg,
                @Success = @Success OUTPUT   

            IF @Success = 0 
                BEGIN  
                    PRINT 'prc_InternalSendMail failed to send.'  
                    SET @CustMsg = 'Failed to send email using prc_internalsendmail. '
                        + @CustMsg  
                    SET @Msg = @CustMsg + @Ret + @Ret + 'Message: ' + @Msg  
                END  
        END  
  
		--Log error to LOGS db.      
        IF @Options NOT LIKE '%norecord%' 
        BEGIN  
            BEGIN TRY  
                INSERT  INTO ErrorLogs
                        ( ServerName ,
                          DatabaseName ,
                          ErrorNumber ,
                          ErrorSeverity ,
                          ErrorState ,
                          ErrorProcedure ,
                          ErrorLine ,
                          ErrorMessage ,
                          ProvidedProcName ,
                          Comments
                        )
                VALUES  ( @ServerName ,
                          DB_name() ,
                          @ErrorNumber ,
                          @ErrorSeverity ,
                          @ErrorState ,
                          @ErrorProcedure ,
                          @ErrorLine ,
                          @ErrorMessage ,
                          @ProcNameSource ,
                          @CustMsg
                        )
            END TRY  
            BEGIN CATCH  
                SELECT  @ErrorNumber = ISNULL(ERROR_NUMBER(), '') ,
                        @ErrorSeverity = ISNULL(ERROR_SEVERITY(), '') ,
                        @ErrorState = ISNULL(ERROR_STATE(), '') ,
                        @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '') ,
                        @ErrorLine = ISNULL(ERROR_LINE(), '') ,
                        @ErrorMessage = ISNULL(ERROR_MESSAGE(), '')  

                SET @AlternateErrorMsg = 'Failed to log to logs table. Command attempted: '
                    + 'Exec ' + @ProcNameSource + ' @ServerName='''
                    + @ServerName + ''', @DatabaseName=''' + @DBName
                    + ''', @ErrorNumber=' + ISNULL(CAST(@ErrorNumber AS VARCHAR(10)), 'NULL')
                    + ', @ErrorSeverity=' + ISNULL(CAST(@ErrorSeverity AS VARCHAR(5)), 'NULL')
                    + ', @ErrorState=' + ISNULL(CAST(@ErrorState AS VARCHAR(10)), 'NULL')
                    + ', @ErrorProcedure=''' + ISNULL(@ErrorProcedure, 'NULL')
                    + ''', @ErrorLine=' + ISNULL(CAST(@ErrorLine AS VARCHAR(10)), 'NULL')
                    + ', @ErrorMessage=''' + ISNULL(@ErrorMessage, 'NULL')
                    + ''', @ProvidedProcName=''' + ISNULL(@ProcNameSource,'NULL')
                    + ', Attempted to log=''' + ISNULL(@Msg, 'NULL')
                    + ''''    

                EXEC prc_InternalSendMail @Address = @AlertEmail,
                    @Subject = 'Failure to log error message from prc_Error to Logs db.',
                    @Body = @AlternateErrorMsg, @Success = @Success OUTPUT   
            END CATCH  

        END  
 
		--suppress RAISERROR alerts or LOG to event log and RAISERROR or just RAISERROR.      
        IF @Options NOT LIKE '%suppress%' 
        BEGIN      
            IF @Options LIKE '%log%'
                OR ISNULL(@ErrorSeverity, 0) > 18 
                RAISERROR(@Msg, @ErrorSeverity, @ErrorState) WITH Log      
            ELSE 
                RAISERROR(@Msg, @ErrorSeverity, @ErrorState)      
        END      
  
    END --Proc 
;
GO
