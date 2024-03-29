USE master
GO
IF (OBJECT_ID('dbo.sp_FindText') IS NULL)
BEGIN
      EXEC('Create procedure dbo.sp_FindText  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
      IF (@@error = 0)
            PRINT 'Successfully created empty stored procedure dbo.sp_FindText.'
      ELSE
      BEGIN
            PRINT 'FAILED to create stored procedure dbo.sp_FindText.'
      END
END
GO

-- 9/3/2013 Chuck Lathrope	Modified to use sql_modules.
Alter Procedure dbo.sp_FindText @SearchText varchar(255), @PreviewTextSize INT = 50
as  
Begin  

	Select	Distinct DB_NAME() DBName, sch.[name] + '.' + obj.[name] as ObjectName
			, obj.Type_Desc
			, Replace(Replace(SubString(mod.definition, CharIndex(@SearchText, mod.definition) - (@PreviewTextSize / 2) , @PreviewTextSize )
				, char(13) + char(10), ''), @SearchText , '***' + @SearchText + '***') AS TextFoundNear
	From 	sys.objects obj 
	Inner Join sys.sql_modules mod On obj.object_Id = mod.object_Id
	Inner Join sys.schemas sch On obj.schema_Id = sch.schema_Id
	Where mod.definition Like '%' + @SearchText + '%'
	Order By ObjectName

End  
go

EXEC master.sys.sp_MS_marksystemobject sp_FindText
go



				