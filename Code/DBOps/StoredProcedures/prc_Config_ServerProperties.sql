SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE dbo.prc_Config_ServerProperties
AS    
BEGIN    
/*************************************************************************************************  
** File: prc_Config_ServerProperties  
** Desc: Get server information.  
** Created by: Chuck Lathrope    
** Creation Date: 8-11-2010    
** Altered: 9-19-2010 Chuck Lathrope Added IsIntegratedSecurityOnly Column    
** 09-07-2012 Matias Sincovich Added lot of columns: portnumbber, SO data, memory and cpu ghz    
** 07/08/2013 Matias Sincovich new queue method adapted 
*************************************************************************************************/    
 SET NOCOUNT ON    
     
 DECLARE @pathKey VARCHAR(200)  
 , @tcp_port VARCHAR(6)  
 , @WindowsVersion VARCHAR(10)  
 , @ServerArchitecture VARCHAR(10)  
 , @WindowsVersion1 VARCHAR(5) 
 , @WindowsVersion2 VARCHAR(5)
 
 SET @pathKey = 
    CASE WHEN LEFT(Cast(SERVERPROPERTY('ProductVersion') As Varchar), 1) <>1 THEN @@SERVICENAME + '\MSSQLServer\SuperSocketNetLib\Tcp'    
     ELSE 'MSSQL'+(CASE RIGHT(LEFT(Cast(SERVERPROPERTY('ProductVersion') As Varchar), 4), 1 )     
      WHEN '5' THEN REPLACE(LEFT(Cast(SERVERPROPERTY('ProductVersion') As Varchar), 4), '.', '_') + '0'    
      ELSE LEFT(Cast(SERVERPROPERTY('ProductVersion') As Varchar), 2) END) +'.'+ @@SERVICENAME +'\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'    
     END    
 SET @pathKey = 'SOFTWARE\Microsoft\Microsoft SQL Server\' + @pathKey    
    
 EXEC xp_regread    
  @rootkey = 'HKEY_LOCAL_MACHINE',    
  @key = @pathKey,    
  @value_name = 'TcpPort',    
  @value = @tcp_port OUTPUT    
   --select @tcp_port, @pathKey , LEFT(Cast(SERVERPROPERTY('ProductVersion'') As Varchar), 4), @@SERVICENAME    


	EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
											 N'SOFTWARE\Microsoft\Windows NT\CurrentVersion',
											 N'CurrentVersion',
											 @WindowsVersion1 OUTPUT,
											 N'no_output'

	EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
											 N'SOFTWARE\Microsoft\Windows NT\CurrentVersion',
											 N'CurrentBuildNumber',
											 @WindowsVersion2 OUTPUT,
											 N'no_output'

	SET @WindowsVersion = @WindowsVersion1 + ' (' + @WindowsVersion1 +')'
    
	EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
											 N'System\CurrentControlSet\Control\Session Manager\Environment',
											 N'PROCESSOR_ARCHITECTURE',
											 @ServerArchitecture OUTPUT,
											 N'no_output'

 DECLARE @Script NVARCHAR(MAX)    
     
 SET @Script =''    
 SET @Script = @Script + 'SELECT '    
 --SET @Script = @Script + 'GETDATE() as CaptureDate ,'    
 SET @Script = @Script + ' @@ServerName [ServerName] '     
 SET @Script = @Script + ', CAST(SERVERPROPERTY (''ComputerNamePhysicalNetBIOS'') AS NVARCHAR(128)) PhysicalComputerName '    
 SET @Script = @Script + ', CAST(SERVERPROPERTY(''IsClustered'') AS BIT) IsClustered '    
 SET @Script = @Script + ', CAST(FULLTEXTSERVICEPROPERTY(''IsFullTextInstalled'') AS bit) AS IsFullTextInstalled '    
 SET @Script = @Script + ', CAST(SERVERPROPERTY(N''ProductVersion'') As nvarchar(128)) AS VersionString '    
 SET @Script = @Script + ', CAST(SERVERPROPERTY(N''Edition'') AS nvarchar(128)) AS Edition '    
 SET @Script = @Script + ', CAST(SERVERPROPERTY(N''ProductLevel'') AS nvarchar(128)) AS ProductLevel '    
 SET @Script = @Script + ', LEFT(Cast(SERVERPROPERTY(''ProductVersion'') As nvarchar(128)), 4) ProductVersion '    
 SET @Script = @Script + ', CAST(SERVERPROPERTY(''EngineEdition'') AS int) AS EngineEdition '    
 SET @Script = @Script + ', CAST(SERVERPROPERTY(N''ResourceVersion'') As nvarchar(128)) AS ResourceVersionString '    
 SET @Script = @Script + ', convert(nvarchar(128), serverproperty(N''collation'')) AS Collation '    
 SET @Script = @Script + ', CAST(SERVERPROPERTY(N''ComputerNamePhysicalNetBIOS'') As nvarchar(128)) AS ComputerNamePhysicalNetBIOS '    
 SET @Script = @Script + ', CAST(SERVERPROPERTY(N''ResourceLastUpdateDateTime'') As nvarchar(128)) AS ResourceLastUpdateDateTime '    
 SET @Script = @Script + ', CAST(SERVERPROPERTY(N''LicenseType'') As nvarchar(128)) AS LicenseType '    
 SET @Script = @Script + ', CAST(SERVERPROPERTY(N''NumLicenses'') As nvarchar(128)) AS NumLicenses '    
 SET @Script = @Script + ', RIGHT(Cast(SERVERPROPERTY(''ResourceVersion'') As Varchar), 4) PatchNumber '    
 SET @Script = @Script + ', CAST(SERVERPROPERTY(''IsIntegratedSecurityOnly'') AS BIT) IsIntegratedSecurityOnly '    
  
 IF (CONVERT(decimal(5,2),LEFT(Cast(SERVERPROPERTY('ProductVersion') As Varchar), 4)) > 10.5 )  
 BEGIN    
  SET @Script = @Script + ', (physical_memory_kb/1024/1024) as PhysicalRAMGB '    
  SET @Script = @Script + ', (virtual_memory_kb/1024/1024) as VASGB '    
 END    
 ELSE    
 BEGIN    
  SET @Script = @Script + ', (physical_memory_in_bytes/1024/1024/1024) as PhysicalRAMGB '    
  SET @Script = @Script + ', (virtual_memory_in_bytes/1024/1024/1024) as VASGB '    
 END    
     
 SET @Script = @Script + ', (ms_ticks/1000/1000 ) CPUGHz '    
 SET @Script = @Script + ', cpu_count/hyperthread_ratio REALCPUCount '    
 SET @Script = @Script + ', cpu_count CPUCount '    
 SET @Script = @Script + ', '''+ ISNULL(@tcp_port,'NULL') +''' PortNumber '    
 SET @Script = @Script + ', '''+ ISNULL(@WindowsVersion,'NULL') +''' WindowsVersion '    
 SET @Script = @Script + ', '''+ ISNULL(@ServerArchitecture,'NULL') +''' ServerArchitecture '    
    
 SET @Script = @Script + ' from sys.dm_os_sys_info '  
   
 EXEC (@Script)    
END --Proc creation.;
GO
