-- ======================================================================================
-- Fill in the parameters in dialog box opened with Ctrl-Shift-M
-- ======================================================================================
SET QUOTED_IDENTIFIER ON --Quoted elements must use ' and not "
GO

/*
--IF Version < SQL2012 will need to use this code instead
IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = '<Procedure_Name, , Procedure_Name>' And ROUTINE_SCHEMA = 'dbo')
BEGIN
	EXEC('CREATE Procedure dbo.<Procedure_Name, , Procedure_Name> as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
	IF (@@error = 0)
		PRINT 'Successfully created empty stored procedure dbo.<Procedure_Name, , Procedure_Name>.'
	ELSE
	BEGIN
		PRINT 'FAILED to create stored procedure dbo.<Procedure_Name, , Procedure_Name>.'
	END
END
GO
*/

CREATE OR ALTER PROCEDURE dbo.<Procedure_Name,, ProcedureName>
	<@Param1, , @p1> <Datatype_For_Param1, , int> = <Default_Value_For_Param1, , 0>,
	<@Param2, , @p2> <Datatype_For_Param2, , int> = <Default_Value_For_Param2, , 0>
AS
BEGIN
-- ======================================================================================
-- Author:		<Author,,FirstLastInitial>
-- Create date: <Create Date,,D/M/2021>
-- Description:	<Description,,Short desc/special notes>
--
-- Change History:
-- Change Date	Change By	Sprint#	Ticket#	Short change description
-- <ChangeDate,,MM/DD/2021>		<ChangeAuthor,,FirstLastInitial>	<Sprint,,EnterNumber>	<Ticket#,,EnterNumber>	<Change Comment,,Add short description>
-- ======================================================================================
	SET NOCOUNT ON;
	--If all operations don't need read consistency add:
	--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	--Notes you can delete after your read:
	--Deprecated code use and what to use instead: http://msdn.microsoft.com/en-us/library/ms143729.aspx
	--Common deprecated code in use today to watch out for:
	--Data types: text ntext or image. Use varchar(max), nvarchar(max), and varbinary(max) data types.
	--Don't use SET ROWCOUNT. Use TOP keyword instead.
	--Use of Datetime: Change to Getdate2(4) and to get current time, use SYSDATETIME() Only use when table has this datatype.
	--Table hint without WITH. WITH (NOLOCK) is proper syntax, otherwise sql has to figure out if it is a TVF.
	--More than two-part column name. e.g. select sys.objects.name, o.object_id from sys.objects o
		--The first column is on the deprecated format, the second is not.
	--'@' and names that start with '@@' as Transact-SQL identifiers
	--String literals as column aliases, e.g.'string_alias' = expression. Use expression [AS] [["']Column_alias[[]"']
	--NOLOCK or READUNCOMMITTED in UPDATE or DELETE. Remove it from these tables.
	--sysobjects, sysprocesses, syscolumns: Conversion table here: http://msdn.microsoft.com/en-us/library/ms187376.aspx
	--USER_ID. Use DATABASE_PRINCIPAL_ID
	--Don't use cursors. Try to create "SQL Set Based Query", or if row by row is needed, use a while loop.
	--No need to delete temp tables, will just slow your proc execution time.

	--Add your code here and remember to COMMENT YOUR CODE!

END
GO