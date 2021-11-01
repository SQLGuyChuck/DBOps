CREATE function fn_hex_to_char (
  @x varbinary(100), -- binary hex value
  @l int -- number of bytes
  ) returns varchar(200)
 as 
-- Written by: Gregory A. Larsen
-- Date: May 25, 2004
-- Description:  This function will take any binary value and return 
--               the hex value as a character representation.
--               In order to use this function you need to pass the 
--               binary hex value and the number of bytes you want to
--               convert.
begin

declare @i varbinary(10)
declare @digits char(16)
set @digits = '0123456789ABCDEF'
declare @s varchar(100)
declare @h varchar(100)
declare @j int
set @j = 0 
set @h = ''
-- process all  bytes
while @j < @l
begin
  set @j= @j + 1
  -- get first character of byte
  set @i = substring(cast(@x as varbinary(100)),@j,1)
  -- get the first character
  set @s = cast(substring(@digits,@i%16+1,1) as char(1))
  -- shift over one character
  set @i = @i/16 
  -- get the second character
  set @s = cast(substring(@digits,@i%16+1,1) as char(1)) + @s
  -- build string of hex characters
  set @h = @h + @s
end
return(@h)
end


