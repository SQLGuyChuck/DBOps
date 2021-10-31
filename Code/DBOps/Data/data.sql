--Update database to the database you use for DB Operations code, USE CTRL-SHIFT-M in SSMS to fill in template.
USE <DBOps Database Name,String, DBOps>
GO

--Update this distribution list to alert DB folks you want alerted.
DECLARE @DatabaseTeamDLToAlert varchar(100) = '<Email without domain for DB Team Alerts,String,DatabaseAlerts>@<Email Domain Name,String, YourDomainName.com>'

--What is DB team name for above alert email
DECLARE @DBTeamName nvarchar(50) = '<DBOps Team Name,String, DBOps>'

--Update this distribution list to alert DB and Dev folks you want alerted.
DECLARE @DBandDevTeamDLToAlert varchar(100) = '<Email without domain for DB & Dev Team Alerts,String,Alerts>@<Email Domain Name,String, YourDomainName.com>'

--What is Dev and DB team name you want above alert email
DECLARE @DBandDevTeamName nvarchar(60) = @DBTeamName + ' & Dev'

--Update this distribution list to alert Dev folks you want alerted.
DECLARE @DevTeamDLToAlert varchar(100) = '<Email without domain for Dev Team Alerts,String,Alerts>@<Email Domain Name,String, YourDomainName.com>'

--What is Dev and DB team name you want above alert email
DECLARE @DevTeamName nvarchar(50) = '<Dev Team Name,String, Dev>'


IF NOT EXISTS (Select * from Processes where ProcessName = 'Admin')
	Insert into Processes (ProcessID,ProcessName,ProcessStatus) Values (1,'Admin',1)

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'Environment')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	Select Processid, 'Environment', CASE WHEN @@SERVERNAME like '%<ServerName String used in staging servers,String, STG>%' Then 'QA'
											WHEN @@SERVERNAME like '%<ServerName String1 used in dev servers,String, dev>%' or @@SERVERNAME like '%<ServerName String2 used in dev servers,String, HQ>%' THEN 'Dev'
											Else 'Production' 
									 END
	From Processes
	Where ProcessName = 'Admin'
END

--Update the mail server info:
IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'SMTPServerName')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'SMTPServerName','mail.yourdomainname.com'
	From Processes
	Where ProcessName = 'Admin'
END

--Update the mail server info:
IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'SMTPServerPort')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'SMTPServerPort','25'
	From Processes
	Where ProcessName = 'Admin'
END


IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'Blocking Threshold (ms)')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	Select ProcessID, 'Blocking Threshold (ms)','5000'
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'Job Run Default Threshold (min)')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	Select ProcessID, 'Job Run Default Threshold (min)','60'
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'Query Run Default Threshold (min)')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	Select ProcessID, 'Query Run Default Threshold (min)','15'
	From Processes
	Where ProcessName = 'Admin'
END

--For procs that need to email, store the operators in the processparameter table
IF NOT EXISTS (Select * from ProcessParameter where ParameterName = @DBTeamName+' Team Escalation')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,@DBTeamName+' Team Escalation',@DatabaseTeamDLToAlert
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = @DBandDevTeamName+' Team Escalation')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,@DBandDevTeamName+' Team Escalation',@DBandDevTeamDLToAlert
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = @DevTeamName+' Team Escalation')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,@DevTeamName+' Team Escalation',@DevTeamDLToAlert
	From Processes
	Where ProcessName = 'Admin'
END


--See Admin values:
Select p.ProcessName, pp.* from Processes p
join ProcessParameter pp on pp.ProcessID = p.ProcessID
where ProcessName = 'Admin'


--MSDB Job Operator Setup
--Create operators if they don't exist
IF NOT EXISTS (select * from msdb.dbo.sysoperators Where name = @DBTeamName)
BEGIN
	EXEC msdb.dbo.sp_add_operator @name=@DBTeamName, 
				@enabled=1, 
				@pager_days=0, 
			@email_address=@DBTeamName
END

IF NOT EXISTS (select * from msdb.dbo.sysoperators Where name = @DevTeamName)
BEGIN
		EXEC msdb.dbo.sp_add_operator @name=@DevTeamName, 
			@enabled=1, 
			@pager_days=0, 
			@email_address=@DevTeamDLToAlert
END

IF NOT EXISTS (select * from msdb.dbo.sysoperators Where name = @DBandDevTeamName)
BEGIN
		EXEC msdb.dbo.sp_add_operator @name=@DBandDevTeamName, 
			@enabled=1, 
			@pager_days=0, 
			@email_address=@DBandDevTeamDLToAlert
END

select * from msdb.dbo.sysoperators



