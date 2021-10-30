USE DBOPS
GO

IF NOT EXISTS (Select * from Processes where ProcessName = 'Admin')
	Insert into Processes (ProcessID,ProcessName,ProcessStatus) Values (1,'Admin',1)

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'Environment')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	Select Processid, 'Environment', CASE WHEN @@SERVERNAME like '%stag%' Then 'QA'
											WHEN @@SERVERNAME like '%dev%' or @@SERVERNAME like '%HQ%' THEN 'Dev'
											Else 'Production' 
									 END
	from Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'Blocking Threshold (ms)')
BEGIN
	insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	Select ProcessID, 'Blocking Threshold (ms)','5000'
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'Job Run Default Threshold (min)')
BEGIN
	insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	Select ProcessID, 'Job Run Default Threshold (min)','60'
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'Query Run Default Threshold (min)')
BEGIN
	insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	Select ProcessID, 'Query Run Default Threshold (min)','15'
	From Processes
	Where ProcessName = 'Admin'
END

--For procs that need to email, store the operators in the processparameter table
IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'IT Ops Team Escalation')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'IT Ops Team Escalation','databasealerts@YourDomainName.com'
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'IT Ops & Dev Team Escalation')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'IT Ops & Dev Team Escalation','alerts@YourDomainName.com'
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'Dev Team Escalation')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'Dev Team Escalation','alerts@YourDomainName.com'
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'SMTPServerName')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'SMTPServerName','mail'
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'SMTPServerPort')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'SMTPServerPort','25'
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'IT Ops Team Escalation LastKnown')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'IT Ops Team Escalation LastKnown','databasealerts@YourDomainName.com'
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'IT Ops and Dev Team Escalation LastKnown')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'IT Ops and Dev Team Escalation LastKnown','databasealerts@YourDomainName.com'
	From Processes
	Where ProcessName = 'Admin'
END


IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'Dev Team Escalation LastKnown')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'Dev Team Escalation LastKnown','databasealerts@YourDomainName.com'
	From Processes
	Where ProcessName = 'Admin'
END



IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'IT Ops Team Operator LastKnown')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'IT Ops Team Operator LastKnown','databasealerts@YourDomainName.com'
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'IT Ops and Dev Team Operator LastKnown')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'IT Ops and Dev Team Operator LastKnown','databasealerts@YourDomainName.com'
	From Processes
	Where ProcessName = 'Admin'
END

IF NOT EXISTS (Select * from ProcessParameter where ParameterName = 'Dev Team Operator LastKnown')
BEGIN
	Insert into ProcessParameter (ProcessID,ParameterName,ParameterValue)
	SELECT ProcessID,'Dev Team Operator LastKnown','databasealerts@YourDomainName.com'
	From Processes
	Where ProcessName = 'Admin'
END

--Add username and password as needed for SMTP info for prc_internalsendmail if default profile doesn't exist

--See Admin values:
Select p.ProcessName, pp.* from Processes p
join ProcessParameter pp on pp.ProcessID = p.ProcessID
where ProcessName = 'Admin'


USE [msdb]
GO
DECLARE @ITOps varchar(200),
		@DevTeam varchar(200),
		@ITOpsandDevTeam varchar(400)

--Create operators if they don't exist
IF NOT EXISTS (select * from msdb.dbo.sysoperators Where name = 'IT Ops')
BEGIN
	SELECT @ITOps = ParameterValue
	From ProcessParameter
	Where ParameterName = 'IT Ops Team Escalation'

	IF @ITOps IS NOT NULL
		EXEC msdb.dbo.sp_add_operator @name=N'IT Ops', 
				@enabled=1, 
				@pager_days=0, 
				@email_address=@ITOps
	ELSE
		Print 'DBOPS ProcessParameter table does not have value for [IT Ops Team Escalation]. Please fix and run again.'
END

IF NOT EXISTS (select * from msdb.dbo.sysoperators Where name = 'Dev Team')
BEGIN
	SELECT @DevTeam = ParameterValue
	From ProcessParameter
	Where ParameterName = 'Dev Team Escalation'

	IF @DevTeam IS NOT NULL
		EXEC msdb.dbo.sp_add_operator @name=N'Dev Team', 
			@enabled=1, 
			@pager_days=0, 
			@email_address=@DevTeam
	ELSE
		Print 'DBOPS ProcessParameter table does not have value for [Dev Team Escalation]. Please fix and run again.'
END

IF NOT EXISTS (select * from msdb.dbo.sysoperators Where name = 'IT Ops and Dev Team')
BEGIN
	--Note, assuming if both above didn't exist, this one didn't either and variables are populated.
	SELECT @ITOpsandDevTeam = ParameterValue
	From ProcessParameter
	Where ParameterName = 'IT Ops & Dev Team Escalation'

	IF @ITOpsandDevTeam IS NOT NULL
		EXEC msdb.dbo.sp_add_operator @name=N'IT Ops and Dev Team', 
			@enabled=1, 
			@pager_days=0, 
			@email_address=@ITOpsandDevTeam
	ELSE
		Print 'DBOPS ProcessParameter table does not have value for [IT Ops & Dev Team Escalation]. Please fix and run again.'
END

select * from msdb.dbo.sysoperators



