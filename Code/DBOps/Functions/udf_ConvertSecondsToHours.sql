SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER FUNCTION dbo.udf_ConvertSecondsToHours
(
	@SecondsToConvert bigint
) 
RETURNS VARCHAR(20) AS
BEGIN

DECLARE @ReturnVar VARCHAR(20)
 , @Time varchar(25)

-- Store the datetime information retrieved in the @Time variable
SET @Time = (SELECT RTRIM(CONVERT(char(8), @SecondsToConvert/3600) ) + ':' +
	CONVERT(char(2), (@SecondsToConvert % 3600) / 60) + ':' +
	CONVERT(char(2), @SecondsToConvert % 60));

-- Display the @Time variable in the format of HH:MM:SS
SET @ReturnVar = CONVERT(varchar(8),@Time,108) 

	RETURN (@ReturnVar)

END;
GO
