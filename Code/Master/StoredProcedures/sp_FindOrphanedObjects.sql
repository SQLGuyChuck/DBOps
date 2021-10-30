USE master
GO
IF (OBJECT_ID('dbo.sp_FindOrphanedObjects') IS NULL)
BEGIN
      EXEC('Create procedure dbo.sp_FindOrphanedObjects  as raiserror(''Empty Stored Procedure!!'', 10, 1) with seterror')
      IF (@@error = 0)
            PRINT 'Successfully created empty stored procedure dbo.sp_FindOrphanedObjects.'
      ELSE
      BEGIN
            PRINT 'FAILED to create stored procedure dbo.sp_FindOrphanedObjects.'
      END
END
GO

ALTER PROCEDURE dbo.sp_FindOrphanedObjects
/* 
http://www.simple-talk.com/community/blogs/philfactor/articles/18689.aspx
This is a stored procedure to list out the user tables, views, functions
and procedures that are not dependent on any other user object and have
no dependencies.
Obviously, each needs to be investigated to see if it is being called or usedby a process outside the database
*/
AS
SELECT [name]=COALESCE(s3.name+'.','')+sysobjects.name,[type]=
CASE sysobjects.xtype  WHEN 'C' THEN 'CHECK constraint'
                       WHEN 'D' THEN 'Default or DEFAULT constraint'
                       WHEN 'F' THEN 'FOREIGN KEY constraint'
                       WHEN 'L' THEN 'Log'
                       WHEN 'FN' THEN 'Scalar function'
                       WHEN 'IF' THEN 'Inlined table-function'
                       WHEN 'P' THEN 'Stored procedure'
                       WHEN 'PK' THEN 'PRIMARY KEY constraint'
                       WHEN 'RF' THEN 'Replication filter stored procedure' 
                       WHEN 'S' THEN 'System table'
                       WHEN 'TF' THEN 'Table function'
                       WHEN 'TR' THEN 'Trigger'
                       WHEN 'U' THEN 'User table'
                       WHEN 'UQ' THEN 'UNIQUE constraint'
                       WHEN 'V' THEN 'View'
                       WHEN 'X' THEN 'Extended stored procedure'
                       ELSE 'What was "'+sysobjects.xtype+'" then?'
END
, [created]=CONVERT(CHAR(11),sysobjects.crdate,113) FROM sysobjects
LEFT OUTER JOIN sysdepends s1 ON sysobjects.id=s1.id
LEFT OUTER JOIN sysdepends s2 ON sysobjects.id=s2.depid
LEFT OUTER JOIN sysobjects s3 ON sysobjects.parent_obj=s3.id
WHERE s1.id IS NULL AND s2.id IS NULL
AND sysobjects.xtype NOT IN ('s','d','pk','f','rf','uq','x','c','l')
ORDER BY sysobjects.crdate
go
