USE master
GO
IF (OBJECT_ID('dbo.sp_hexadecimal') IS NULL)
BEGIN
      EXEC('Create procedure dbo.sp_hexadecimal  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
      IF (@@error = 0)
            PRINT 'Successfully created empty stored procedure dbo.sp_hexadecimal.'
      ELSE
      BEGIN
            PRINT 'FAILED to create stored procedure dbo.sp_hexadecimal.'
      END
END
GO

ALTER PROCEDURE dbo.sp_hexadecimal
    @binvalue varbinary(256),
    @hexvalue varchar (514) OUTPUT
AS
--Return char value from a hex value.
--http://support.microsoft.com/kb/918992
SET NOCOUNT ON

DECLARE @charvalue varchar (514)
	, @i int
	, @length int
	, @hexstring char(16)

SELECT @charvalue = '0x'
SELECT @i = 1
SELECT @length = DATALENGTH (@binvalue)
SELECT @hexstring = '0123456789ABCDEF'
WHILE (@i <= @length)
BEGIN
  DECLARE @tempint int
  DECLARE @firstint int
  DECLARE @secondint int
  SELECT @tempint = CONVERT(int, SUBSTRING(@binvalue,@i,1))
  SELECT @firstint = FLOOR(@tempint/16)
  SELECT @secondint = @tempint - (@firstint*16)
  SELECT @charvalue = @charvalue +
    SUBSTRING(@hexstring, @firstint+1, 1) +
    SUBSTRING(@hexstring, @secondint+1, 1)
  SELECT @i = @i + 1
END

SELECT @hexvalue = @charvalue
GO

