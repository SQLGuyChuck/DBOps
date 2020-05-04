SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*******************************************************************************
** Name: prc_OutputBuffer  
** Desc: Produce cleaned-up DBCC OUTPUTBUFFER report for a given SPID.
** Author: From the Internet: Andrew Zanevsky, 2001-06-29
**          
**  
*******************************************************************************      
**  Change History      
*******************************************************************************      
** Date:		Author:			Description:      
** 5/12/2017	Internet
*******************************************************************************/      

CREATE OR ALTER PROCEDURE dbo.prc_OutputBuffer
	(@spid smallint)
AS
SET NOCOUNT ON
SET ANSI_PADDING ON

DECLARE @outputbuffer varchar(80),
  @clean varchar(16),
  @pos smallint

CREATE TABLE #out  (  
-- Primary key on IDENTITY column prevents rows
-- from changing order when you update them later.
  line int IDENTITY PRIMARY KEY CLUSTERED,
  dirty varchar(255) NULL,
  clean varchar(16) NULL
)

INSERT #out ( dirty )
EXEC( 'DBCC OUTPUTBUFFER(' + @spid + ')' )

SET @pos = 0
WHILE @pos < 16 BEGIN
  SET @pos = @pos + 1
  -- 1. Eliminate 0x00 symbols.
  -- 2. Keep line breaks.
  -- 3. Eliminate dots substituted by DBCC OUTPUTBUFFER
  --  for nonprintable symbols, but keep real dots.
  -- 4. Keep all printable characters.
  -- 5. Convert anything else to blank,
  --  but compress multiple blanks to one.
  UPDATE #out
  SET clean = ISNULL( clean, '' ) +
    CASE WHEN SUBSTRING( dirty, 9 + @pos * 3, 2 ) =
        '0a' THEN char(10)
      WHEN SUBSTRING( dirty, 9 + @pos * 3, 2 )
        BETWEEN '20' AND '7e'
        THEN SUBSTRING( dirty, 61 + @pos, 1 )
      ELSE ' '
    END
  WHERE CASE WHEN SUBSTRING( dirty, 9 + @pos * 3, 2 ) =
        '0a' THEN 1
    WHEN SUBSTRING( dirty, 61 + @pos, 1 ) = '.'
      AND SUBSTRING( dirty, 9 + @pos * 3, 2 ) <>
        '2e' THEN 0
    WHEN SUBSTRING( dirty, 9 + @pos * 3, 2 )
        BETWEEN '20' AND '7e' THEN 1
    WHEN SUBSTRING( dirty, 9 + @pos * 3, 2 ) =
        '00' THEN 0
    WHEN RIGHT( 'x' + clean, 1 )
        IN ( ' ', char(10) ) THEN 0
    ELSE 1
  END = 1
END

DECLARE c_output CURSOR FOR SELECT clean FROM #out
OPEN c_output
FETCH c_output INTO @clean

SET @outputbuffer = ''

WHILE @@FETCH_STATUS = 0 BEGIN
  SET @outputbuffer = @outputbuffer +
    CASE WHEN RIGHT( @outputbuffer, 1 ) = ' '
      OR @outputbuffer = ''
    THEN LTRIM( ISNULL( @clean, '' ) )
  ELSE ISNULL( @clean, '' )
END

IF DATALENGTH( @outputbuffer ) > 64 BEGIN
  PRINT @outputbuffer
  SET @outputbuffer = ''
END

  FETCH c_output INTO @clean
END
PRINT @outputbuffer

CLOSE c_output
DEALLOCATE c_output

DROP TABLE #out 


GO
