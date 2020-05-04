SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/******************************************************************************
**	File: \DBOPS\Functions\udf_AgentDateTime2DateTime.sql
**	Desc: Get SQL Agent date and time fields into a DateTime value.
**	Usage Example:

	--select top 10 dbo.udf_AgentDateTime2DateTime(run_date,run_time) FROM msdb.dbo.sysjobhistory
	
*******************************************************************************	
**  Created 1/20/2008 Chuck Lathrope
*******************************************************************************
**	Change History
*******************************************************************************
**	Date:		Author:			Description:
**
*******************************************************************************/
CREATE OR ALTER FUNCTION dbo.udf_AgentDateTime2DateTime (@agentdate int, @agenttime int)
RETURNS DATETIME
AS
BEGIN
	DECLARE @date DATETIME,
	@year int,
	@month int,
	@day int,
	@hour int,
	@min int,
	@sec int

	IF @agentdate IS NULL OR @agentdate = 0 
		SET @agentdate = 19000101 
	IF @agenttime IS NULL 
		SET @agenttime = 100000 

	SELECT @year = (@agentdate / 10000)
	SELECT @month = (@agentdate - (@year * 10000)) / 100
	SELECT @day = (@agentdate - (@year * 10000) - (@month * 100))
	SELECT @hour = (@agenttime / 10000)
	SELECT @min = (@agenttime - (@hour * 10000)) / 100
	SELECT @sec = (@agenttime - (@hour * 10000) - (@min * 100))

	SELECT @date = CONVERT(DATETIME, CONVERT(NVARCHAR(4), @year) 
		+ N'-' + CONVERT(NVARCHAR(2), @month) 
		+ N'-' + CONVERT(NVARCHAR(4), @day) 
		+ N' ' + REPLACE(CONVERT(NVARCHAR(2), @hour) 
		+ N':' + CONVERT(NVARCHAR(2), @min) 
		+ N':' + CONVERT(NVARCHAR(2), @sec), ' ', '0'))

	RETURN @date
END;
GO
