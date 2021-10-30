
SET ANSI_NULLS ON
GO
	
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SysconfigInfo]') AND type in (N'U'))
BEGIN
CREATE TABLE SysconfigInfo (
configuration_name varchar(255),
current_value sql_variant,
default_value sql_variant,
collection_date datetime2
) ON [PRIMARY]
END
GO

