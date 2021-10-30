IF OBJECT_ID('dbo.ServerPropertyInfoHistory', 'U') IS NULL
CREATE TABLE [dbo].[ServerPropertyInfoHistory](
	CMDBServerID SMALLINT,
	[ServerName] [varchar](128) NULL,
	[PhysicalComputerName] [Nvarchar] (128) NULL,
	[DateCollected] [datetime] NOT NULL,
	[IsClustered] BIT NULL,
	[ProductVersion] [varchar](4) NULL,
	[PatchNumber] [varchar](4) NULL,
	[Edition] [varchar] (40) NULL,
	[LicenseType] [varchar] (13) NULL,
	IsIntegratedSecurityOnly BIT NOT NULL,
	[MemGB] smallint NULL,
	[REALCPUCount] tinyint NULL,
	[CPUCount] tinyint NOT NULL
) ON [PRIMARY]
GO
