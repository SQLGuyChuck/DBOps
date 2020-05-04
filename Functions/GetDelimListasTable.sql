SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/***************************************************************************************
* Function dbo.GetDelimListasTable
* Purpose: Given a delimited string list, return as a table.
* Test Cases: 
*  -> If multiple Delimiters adjacent to eachother, don't return null value.
*  -> If Delimiter not provided, guess based on common Delimiters with space being last choice.
*  -> If just one value, return quickly.
*  -> If values are quoted, return quotes, but if Delimiter included in quoted value, preserve whole text string.
*  -> If no quotes and not space delimited, trim spaces on values.
*
*  Created 1/20/2008 Chuck Lathrope
*  Altered 12/5/2008 Chuck Lathrope Increased List Item size to 1000 characters.
*  Examples:
*  Select * from dbo.GetDelimListasTable('"John","Fred","first,last",',DEFAULT)
*  Select * from dbo.GetDelimListasTable('4',',')
*
*  Notes: All values must be quoted, otherwise this example will not return what you expect.
*  Select * from dbo.GetDelimListasTable('"John",Fred,"first,last",',DEFAULT)
*  ToDo: Fix above case. If in Quotes section of code, check for " at first part of string.
*			If not there, assume no quotes for this next value.
****************************************************************************************/
CREATE OR ALTER FUNCTION [dbo].[GetDelimListasTable](
	@DelimitedList varchar(8000), 
	@Delimiter varchar(15) = NULL)

   RETURNS @DelimitedTable TABLE (RowValue varchar(8000))
AS
Begin

Set @DelimitedList = rtrim(ltrim(@DelimitedList))

If @Delimiter IS NULL --try to figure it out.
Begin
	If charindex( ',', @DelimitedList, 1) > 0
		Set @Delimiter = ','
	Else If charindex('.', @DelimitedList, 1) > 0
		Set @Delimiter = '.'
	Else If charindex(';', @DelimitedList, 1) > 0
		Set @Delimiter = ';'
	Else If charindex(':', @DelimitedList, 1) > 0
		Set @Delimiter = ':'
	Else If charindex('|', @DelimitedList, 1) > 0
		Set @Delimiter = '|'
	Else If charindex(' ', @DelimitedList, 1) > 0
		Set @Delimiter = ' '
	Else If charindex('"', @DelimitedList, 1) > 0
		Set @Delimiter = '"'
	Else 
	Begin --Assuming no Delimiter present.
		Insert Into @DelimitedTable(RowValue) Values (@DelimitedList)

		Return 
	End
End

If (@Delimiter IS NOT NULL AND charindex(@Delimiter, @DelimitedList, 0) = 0)
Begin --Assuming Delimiter presented is not on the string.
	Insert Into @DelimitedTable(RowValue) Values (@DelimitedList)

	Return 
End

Declare @DelimiterPosition as Int
Declare @WorkingList as varchar(1000) --Max size of each item in the list.

If Charindex('"', @DelimitedList, 1) = 0 AND @Delimiter <> '"'
Begin
	--'No quotes'
	Set @DelimiterPosition = Charindex(@Delimiter, @DelimitedList, 1)
	While @DelimiterPosition > 0
	Begin
		Set @WorkingList = left(@DelimitedList, @DelimiterPosition - 1)
		IF @WorkingList <> ''
		Begin
			Insert Into @DelimitedTable(RowValue) Values (rtrim(ltrim(@WorkingList)))
		End

		Set @DelimitedList = Right(@DelimitedList, (len(@DelimitedList) - @DelimiterPosition))
		Set @DelimiterPosition = Charindex(@Delimiter, @DelimitedList, 1)
	End
END
Else --Delimited List has quotes, preserve quoted values.
Begin
	Set @DelimiterPosition = Charindex(@Delimiter, @DelimitedList, 1)
	While @DelimiterPosition > 0
	Begin
		Set @WorkingList = left(@DelimitedList, @DelimiterPosition - 1)
		-- Could have a value like "FirstName  and should have "FirstName, Lastname"

		IF @WorkingList <> ''--If duplicated Delimiter, this will skip entering null values.
		Begin
			IF NOT Charindex('"', @WorkingList, @DelimiterPosition-2) > 0
			-- Starting at position before Delimiter if it is a quote, then all is good, else need to adjust end point. 
			Begin
				IF Charindex(@Delimiter, @DelimitedList, @DelimiterPosition+1) > 0
				-- Not at end of delimited list.
				Begin
					--Reset @DelimiterPosition to next Delimiter.
					Set @DelimiterPosition = Charindex(@Delimiter, @DelimitedList, @DelimiterPosition+1)
					--Reset @WorkingList 
					Set @WorkingList = left(@DelimitedList, @DelimiterPosition - 1)

				End
				Else --At end of list.
				Begin
					Set @WorkingList = @DelimitedList
					Insert Into @DelimitedTable(RowValue) Values (rtrim(ltrim(@WorkingList)))

					Return
				End
			END

		Insert Into @DelimitedTable(RowValue) Values (@WorkingList)

		Set @DelimitedList = Right(@DelimitedList, (len(@DelimitedList) - @DelimiterPosition))
		Set @DelimiterPosition = Charindex(@Delimiter, @DelimitedList, 1)

		End -- IF @WorkingList <> ''
	End

END

--If at end of list, need to add last value.
If LEN(@DelimitedList) >= LEN(@Delimiter)
	Insert Into @DelimitedTable(RowValue) Values (rtrim(ltrim(@DelimitedList)))

-- IF IS ONLY ONE VALUE
--If charindex( @Delimiter, @DelimitedList, 1) = 0
--	Insert Into @DelimitedTable(RowValue) Values (@DelimitedList)
	
Return

END--Function;;
GO
