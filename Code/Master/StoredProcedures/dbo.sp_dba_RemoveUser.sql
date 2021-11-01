SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_dba_RemoveUser] @SpecificName VARCHAR(75)
AS

PRINT ''
PRINT '--                         *** Remove User/Login Tool ***'
PRINT '--									Verion 1.2'
PRINT '--'
PRINT '-- This code will generate the t-sql code needed to remove a specific user from databases and '
PRINT '-- from SQL Server logins if needed.' 
PRINT ''
PRINT '-- ***********************************************************************************'
PRINT '-- *** Execute the following code to remove user from ALL DATABASES, if needed *** '
PRINT ''
-- Section 1: Check for the existance of the temp table used
if (select object_id('tempdb..##dbnames')) is not null
  drop table ##dbnames

-- Section 2: Creation of temp table and populate
create table ##dbnames (DBName varchar(75), DBUser varchar(75))

exec dbo.sp_MSforeachdb 'insert into ##dbnames select ''?'',name from [?].dbo.sysusers'

-- Section 3: Populate temp table with user information 
DECLARE @DatabaseName VARCHAR (50),
		@DatabaseUser VARCHAR (50)
        
DECLARE LoopThru CURSOR FOR SELECT dbname,dbuser FROM ##dbnames

OPEN LoopThru
	FETCH NEXT FROM LoopThru INTO @DatabaseName, @DatabaseUser
	
-- Section 4: Create customized deletion code while populating temp table
	WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @DatabaseUser = @SpecificName	
			BEGIN
				PRINT ''
				PRINT 'USE '+ @DatabaseName +''
				PRINT 'GO'
				PRINT 'EXEC sp_dropuser ['+ @DatabaseUser +']' 
				PRINT 'GO'
			END
	FETCH NEXT FROM LoopThru INTO @DatabaseName, @DatabaseUser
		END

CLOSE LoopThru
DEALLOCATE LoopThru

-- Section 5: Search and drop user from SQL Server logins - If needed
PRINT ''
PRINT '-- ***********************************************************************************'
PRINT '-- *** Execute the following code to remove user from SQL Server login, if needed *** '
PRINT ''
PRINT 'IF  EXISTS (SELECT loginname FROM master.dbo.syslogins WHERE name = '''+ @SpecificName +''')'
PRINT 'EXEC sp_droplogin '+ @SpecificName +'' 
PRINT ''
PRINT '-- End of code'
-- Section 6: Removal of temp table
if (select object_id('tempdb..##dbnames')) is not null
  drop table ##dbnames
GO
