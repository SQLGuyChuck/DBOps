IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'GetServerNameFromInstanceName' And ROUTINE_SCHEMA = 'dbo' AND ROUTINE_TYPE = 'FUNCTION')
BEGIN
	EXEC( 'CREATE FUNCTION dbo.GetServerNameFromInstanceName (@param INT = 0) RETURNS varchar(20) AS BEGIN RETURN ''Empty function'' END')
	IF (@@error = 0)
		PRINT 'Successfully created empty FUNCTION dbo.GetServerNameFromInstanceName.'
	ELSE
	BEGIN
		PRINT 'FAILED to create FUNCTION dbo.GetServerNameFromInstanceName.'
	END
END
GO
-- =============================================
-- Author:		Chuck Lathrope
-- Create date: 1/2/2011
-- Description:	Get servername from a full instance name.
-- =============================================

ALTER FUNCTION dbo.GetServerNameFromInstanceName (@InstanceName VARCHAR(100))
RETURNS VARCHAR(100)
WITH EXECUTE AS CALLER
AS
BEGIN

DECLARE @RETURNVALUE VARCHAR(100)

    IF CHARINDEX ('\', @InstanceName, 1) >0
		SET @RETURNVALUE = LEFT(@InstanceName,LEN(@InstanceName)-CHARINDEX('\',REVERSE(@InstanceName),1))
	ELSE IF CHARINDEX (',', @InstanceName, 1) >0
		SET @RETURNVALUE = LEFT(@InstanceName,LEN(@InstanceName)-CHARINDEX(',',REVERSE(@InstanceName),1))
	ELSE
		SET @RETURNVALUE = @InstanceName

RETURN @RETURNVALUE
END
GO
