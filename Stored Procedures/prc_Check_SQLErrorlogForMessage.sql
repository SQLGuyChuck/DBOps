USE [DBOPS]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[prc_Check_SQLErrorlogForMessage]
 @SQLErrorLogCheck INT = 1, --Else check SQL Agent Log.
 @Message NVARCHAR (255),
 @Message2 NVARCHAR (255)=NULL,
 @LimitToLastxMinutes BIT = 1, 
 @Minutes INT = 30,
 @CheckOnly BIT = 0, --Only return error code.
 @AlertEmail BIT = 1,
 @ReturnCount BIT = 0,
 @ThresholdCount INT = 1
AS  
BEGIN
/*************************************************************************************************
**	Name: prc_Check_SQLErrorlogForMessage
**	Desc: Check efficiently for SQL Error Log messages.
**
**	Created by: Chuck Lathrope
**	Creation Date: 11/1/2011
**  Alters:
**  3/23/2012	Chuck Lathrope @LimitToLastxMinutes equality mismatched fixed.
**  6/16/2019	Chuck Lathrope Parameter type update and select from table if no email.
					Add @RowCount for return parameter for scripting use.
					Add @Message2 for second search term
					Add @CheckOnly for quick find and exit with return value of 1 if found.
**  07/02/2019	Michael Capobianco - Added bit parameter to return the count of errors found, rather than returning 1
**  07/19/2019  Michael Capobianco - Added parameter @ThresholdCount. This allows for higher numbers of errors before sending alert
*************************************************************************************************/

SET NOCOUNT ON;

DECLARE @body VARCHAR (200),
		@subject VARCHAR(150),
        @StartDate DATETIME,  
        @EndDate DATETIME,
		@RowCount INT

DECLARE @ResultsFound TABLE (LogDate DATETIME, Processinfo VARCHAR(20), Text VARCHAR(MAX))

IF @SQLErrorLogCheck <> 1
	SET @SQLErrorLogCheck = 2

SET @body = 'Take a look at the error log for server: ' + @@SERVERNAME
SET @subject = 'SQL Error Log Error Message Found: ' + @Message

IF (@LimitToLastxMinutes = 1)  
BEGIN  
   SELECT @EndDate = GETDATE()  
   SELECT @StartDate = DATEADD(mi, -@Minutes, @EndDate) --filters non-recent events  
   
   INSERT INTO @ResultsFound
   EXEC xp_readerrorlog  0, @SQLErrorLogCheck, @Message , @Message2, @StartDate, @EndDate

   SET @RowCount = @@ROWCOUNT
END   
ELSE
BEGIN 
   INSERT INTO @ResultsFound
   EXEC xp_readerrorlog  0, @SQLErrorLogCheck, @Message, @Message2

   SET @RowCount = @@ROWCOUNT
END 

IF @ROWCOUNT > @ThresholdCount AND @AlertEmail = 1
BEGIN  
   EXEC prc_InternalSendMail @Address = 'databasealerts@YourDomainNameHere.com'  
	,   @subject = @subject  
	,   @body  = @body
END

IF @CheckOnly = 0
	SELECT * FROM @ResultsFound

IF @RowCount > 0
	IF @ReturnCount = 1
		RETURN @RowCount
	ELSE 
	RETURN 1

END

GO


