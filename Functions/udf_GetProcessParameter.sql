SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
**	File: \DBOPS\Functions\udf_GetProcessParameter.sql
**	Desc: returns the param value for a given process and param name
**	Usage Example:

	--DECLARE @Dir VARCHAR(1000)
	--SELECT @Dir = dbo.udf_GetProcessParameter('Admin','Environment')
	--SELECT @Dir
	
*******************************************************************************	
**  Created 1/20/2008 Chuck Lathrope
*******************************************************************************
**	Change History
*******************************************************************************
**	Date:		Author:			Description:
**
*******************************************************************************/
CREATE OR ALTER FUNCTION dbo.udf_GetProcessParameter 
(
	@ProcessName VARCHAR(50)
	,@ParameterName VARCHAR(50)
) 
RETURNS VARCHAR(MAX) AS
BEGIN

    DECLARE @ReturnVar VARCHAR(MAX)

	SELECT @ReturnVar = ParameterValue
	FROM dbo.ProcessParameter r 
	JOIN dbo.Processes p ON p.ProcessID = r.ProcessID
	WHERE p.ProcessName = @ProcessName
	AND r.ParameterName = @ParameterName

    RETURN (@ReturnVar)

END;
GO
