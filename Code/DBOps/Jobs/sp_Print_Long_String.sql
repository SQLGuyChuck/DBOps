--This just prints out long code for SSMS use.

CREATE OR ALTER PROCEDURE [dbo].[sp_Print_Long_String] (
	@input_String NVARCHAR(MAX)
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON

DECLARE
	@CurrentEnd BIGINT,		/* track the length of the next substring	*/
	@offset TINYINT			/* tracks the amount of offset needed		*/
;

set @input_String = replace(  replace(@input_String, char(13) + char(10), char(10))   , char(13), char(10))

WHILE LEN(@input_String) > 1
BEGIN
    IF CHARINDEX(CHAR(10), @input_String) between 1 AND 8000
    BEGIN
           SET @CurrentEnd =  CHARINDEX(char(10), @input_String) -1
           set @offset = 2
    END
    ELSE
    BEGIN
           SET @CurrentEnd = 8000
            set @offset = 1
    END   
    PRINT SUBSTRING(@input_String, 1, @CurrentEnd) 
    set @input_String = SUBSTRING(@input_String, @CurrentEnd+@offset, LEN(@input_String))   
END 

PRINT CHAR(13) + CHAR(10);
PRINT CHAR(13) + CHAR(10);
/*End While loop*/