IF OBJECT_ID('dbo.CodeAuditingIncludeList', 'U') IS NULL
BEGIN
CREATE TABLE dbo.CodeAuditingIncludeList
(
      Keyword     sysname,
      DateAdded datetime default getdate()
)

Create unique clustered index ci_CodeAuditingIncludeList_Keyword on CodeAuditingIncludeList(Keyword)
END
go
