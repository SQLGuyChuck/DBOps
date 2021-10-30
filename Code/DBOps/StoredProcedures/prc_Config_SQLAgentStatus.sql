CREATE OR ALTER PROCEDURE dbo.prc_Config_SQLAgentStatus  
as  
BEGIN
  
IF EXISTS (  SELECT 1   
           FROM MASTER.dbo.sysprocesses   
           WHERE program_name = N'SQLAgent - Generic Refresher')  
  
   SELECT 1 AS 'SQLServerAgentRunning'  
ELSE   
   SELECT 0 AS 'SQLServerAgentRunning'  

END
go
