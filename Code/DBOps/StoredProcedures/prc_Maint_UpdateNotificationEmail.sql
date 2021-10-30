SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.prc_Maint_UpdateNotificationEmail
	@EscalationTeam		varchar(50) = NULL,
	@OperatorName		nvarchar(128) = NULL,
	@NotificationEmail	nvarchar(100) = NULL,
	@SetToLastKnown		bit = 1	--1 sets to last known value; 0 sets to default value
AS
BEGIN
-- ======================================================================================
-- Author:		Melanie Labuguen
-- Create date: 8/17/2016
-- Description:	This stored procedure will update the values for SQL Server Operators in the 
-- system tables and in the DBOPS.dbo.ProcessParameter table. This procedure will be used when needing to
-- change the recipient list of alerting and job results, success, or failure emails that are sent from the server
-- for a temporary amount of time, such as during server patching.
--
--	@EscalationTeam: Team that will have its email updated. Found as ParameterName in the ProcessParameter table.
--	@OperatorName: Name of SQL Operator that will have its email updated. Found as name in the sysoperators table.
--	@NotificationEmail: Email address to change to.
--  @SetToLastKnown:1 sets value to LastKnown
--					0 sets value to NOT LastKnown (this would be default value of ParameterName)
--
-- If @NotificationEmail is null AND @SetToLastKnown = 1: Update to value where parameter name contains "LastKnown"
-- If @NotificationEmail is null AND @SetToLastKnown = 0: Break. Nothing to update
-- If @NotificationEmail is not null AND @SetToLastKnown = 1: Update to value where parameter name contains "LastKnown"; Ignore @NotificationEmail
-- If @NotificationEmail is not null AND @SetToLastKnown = 0: Update to passed @NotificationEmail
--
--
-- Change History:
-- Change By		Sprint#	Ticket#		Short change description
-- Melanie Labuguen			ITOP-460	Initial Version
-- ======================================================================================
SET NOCOUNT ON;

DECLARE @EscalationProcessParameterID int
DECLARE @LastKnownProcessParameterID int
DECLARE @EscalationParameterValue varchar(75)	--Value currently configured for Escalation
DECLARE @OperatorEmailLastKnown nvarchar(200)

/* Validate parameters */
IF @EscalationTeam IS NULL AND @OperatorName IS NULL
BEGIN
	PRINT 'Please provide @EscalationTeam or @OperatorName.'
	RETURN
END

/* If @NotificationEmail is null and @SetToLastKnown = 0, there is nothing to update so return */
IF @NotificationEmail IS NULL AND @SetToLastKnown = 0
BEGIN
	PRINT '@NotificationEmail value cannot be null if @SetToLastKnown = 0.'
	RETURN
END

/* If @NotificationEmail is not null and @SetToLastKnown = 1, @NotificationEmail is ignored */
IF @SetToLastKnown = 1
BEGIN
	PRINT 'Email will be updated to last known email on record. If @NotificationEmail is also provided, it is ignored.'
END

IF @EscalationTeam IS NOT NULL
BEGIN
	/* Check if the provided Escalation Team currently exists and retrieve current value */
	SELECT
			@EscalationProcessParameterID = ProcessParameterID,
			@EscalationParameterValue = ParameterValue
	FROM
			dbo.ProcessParameter
	WHERE
			ParameterName = @EscalationTeam

	IF @EscalationProcessParameterID IS NULL
	BEGIN
		PRINT 'There is no Escalation Team named ' + @EscalationTeam + '. No record found to update'
		RETURN
	END
END

IF @OperatorName IS NOT NULL
BEGIN
	/* Get Operator email address then check if the provided Operator Name currently exists */
	SELECT
			@OperatorEmailLastKnown = email_address
	FROM
			msdb.dbo.sysoperators
	WHERE
			name = @OperatorName

	IF @OperatorEmailLastKnown IS NULL 
	BEGIN
		PRINT 'There is no Operator named ' + @OperatorName + '. No record found to update'
		RETURN
	END
END

/* If @SetToLastKnown = 0, change to @NotificationEmail. If @SetToLastKnown = 1, revert back to LastKnown */
IF @SetToLastKnown = 0
BEGIN
	IF @EscalationTeam IS NOT NULL
	BEGIN
		/* Save the ParameterValue into <Team> LastKnown */
		UPDATE	dbo.ProcessParameter
		SET
				ParameterValue = @EscalationParameterValue
		WHERE
				ParameterName = @EscalationTeam + ' LastKnown'

		/* Update Escalation value to @NotificationEmail */
		UPDATE	dbo.ProcessParameter
		SET
				ParameterValue = @NotificationEmail
		WHERE
				ParameterName = @EscalationTeam
	END

	IF @OperatorName IS NOT NULL
	BEGIN
	/* Save the Operator email into <Operator> LastKnown */
	UPDATE	dbo.ProcessParameter
	SET
			ParameterValue = @OperatorEmailLastKnown
	WHERE
			ParameterName = @OperatorName + ' Operator LastKnown'

	/* Update @OperatorName's email address with @NotificationEmail */
	EXEC msdb.dbo.sp_update_operator
			@name = @OperatorName,
			@email_address = @NotificationEmail
	END
END
ELSE
IF @SetToLastKnown = 1
BEGIN
	IF @EscalationTeam IS NOT NULL
	BEGIN
		DECLARE @LastKnownEscalation varchar(75)
			
		SELECT
				@LastKnownEscalation = ParameterValue
		FROM
				dbo.ProcessParameter
		WHERE
				ParameterName = @EscalationTeam + ' LastKnown'

		/* Update @EscalationTeam's email address with LastKnown value */
		UPDATE	dbo.ProcessParameter
		SET
				ParameterValue = @LastKnownEscalation
		WHERE
				ProcessParameterID = @EscalationProcessParameterID
	END

	IF @OperatorName IS NOT NULL
	BEGIN
		DECLARE @LastKnownOperator	nvarchar(200)

		SELECT
				@LastKnownOperator = ParameterValue
		FROM
				dbo.ProcessParameter
		WHERE
				ParameterName = @OperatorName + ' Operator LastKnown'

		/* Update @OperatorName's email address with LastKnown value */
		IF @OperatorName IS NOT NULL
			/* Update SQL Server Operator */
			EXEC msdb.dbo.sp_update_operator
					@name = @OperatorName,
					@email_address = @LastKnownOperator
	END
END

END

GO
