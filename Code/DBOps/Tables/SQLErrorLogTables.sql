IF OBJECT_ID(N'dbo.SQLErrorLogReportLastRun', N'U') IS NULL  
BEGIN  
    CREATE TABLE dbo.SQLErrorLogReportLastRun (LastRunTime datetime)  
    Update SQLErrorLogReportLastRun
    SET LastRunTime = DATEADD(hh, -12, getdate())  
END  
go
