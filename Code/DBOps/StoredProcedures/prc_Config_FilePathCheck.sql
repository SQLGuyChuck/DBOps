CREATE OR ALTER PROCEDURE dbo.prc_Config_FilePathCheck 
	@RootDirectory VARCHAR(300),--Directory to check if path exists or you can reach it.
	@SubDirectory VARCHAR(50) = NULL, --You want to create a sub directory if it doesn't exist in the @RootDirectory you provided. Pass just the name, no \.
	@CreateSubDir TINYINT = 0,  --If directory doesn't exist, create it?
	@Debug BIT = 0,--Print out debug statements
	@Success SMALLINT OUTPUT,
	@StatusMsg VARCHAR(1000) OUTPUT
AS
BEGIN
/*************************************************************************
-- Revision History:
-- 4/24/2012 - Chuck Lathrope	Created Proc
--
--Testing:
--Declare @StatusMsg VARCHAR(1000)
-- , @Success SMALLINT
--exec prc_Config_FilePathCheck @RootDirectory = 'c:\Temp\', @SubDirectory = 'test', @CreateSubDir = 1, @Debug = 1, @Success=@Success output, @StatusMsg=@StatusMsg output
--Select @Success Success, @StatusMsg StatusMsg
*************************************************************************/

DECLARE @cmd VARCHAR(8000),
		@BackupDir VARCHAR(300)
		
--Initialize variables
IF RIGHT(RTRIM(@RootDirectory), 1) = '\' 
    SET @RootDirectory = LEFT(RTRIM(@RootDirectory),
                                LEN(RTRIM(@RootDirectory)) - 1)
                                    
CREATE TABLE #CheckPathExistance (
      FileExists INT ,
      FileIsDir INT ,
      ParentDirExists INT
    )
    
--Check for @RootDirectory backup path existence and is a directory.
SET  @Cmd = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = master.dbo.xp_fileexist ''' + @RootDirectory + ''' IF @ReturnCode <> 0 RAISERROR(''Error reading directory.'', 16, 1)'

IF @Debug > 0 
	PRINT @Cmd

INSERT #CheckPathExistance
EXEC ( @Cmd )
IF @@ERROR <> 0 
	BEGIN
		SELECT  @StatusMsg = 'Error - Unable to check root directory: (' + @RootDirectory + ')',
				@Success = -1
		RETURN -1
	END
--You must check to see if "file" is a folder.
IF NOT EXISTS ( SELECT * FROM #CheckPathExistance WHERE FileIsDir = 1 ) 
	BEGIN
		SELECT  @StatusMsg = 'Error - RootDirectory does not exist: (' + @RootDirectory + ')',
				@Success = -2
		RETURN -2
	END

--Check subdir existence
IF @SubDirectory IS NOT NULL
BEGIN
	SELECT  @BackupDir = @RootDirectory + '\' + @SubDirectory
	TRUNCATE TABLE #CheckPathExistance
	
	SET  @Cmd = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = master.dbo.xp_fileexist ''' + @BackupDir + ''' IF @ReturnCode <> 0 RAISERROR(''Error reading directory.'', 16, 1)'

	IF @Debug > 0 
		PRINT @Cmd
		
	INSERT #CheckPathExistance
	EXEC ( @Cmd )
	IF @@ERROR <> 0 
		BEGIN
			SELECT  @StatusMsg = 'Error - Unable to check @SubDirectory directory: (' + @BackupDir + ')',
					@Success = -3
			RETURN -3
		END

	--You must check to see if "file" is a folder.
	IF NOT EXISTS ( SELECT * FROM #CheckPathExistance WHERE FileIsDir = 1 ) 
		BEGIN
			IF @CreateSubDir = 0
			BEGIN
				SELECT  @StatusMsg = 'Error - @SubDirectory does not exist: (' + @RootDirectory + ')',
						@Success = -4
				RETURN -4
			END
			ELSE 
			BEGIN
				SET @Cmd = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = master.dbo.xp_create_subdir N''' + @BackupDir + ''' IF @ReturnCode <> 0 RAISERROR(''Error creating directory.'', 16, 1)'

				IF @Debug > 0 
					PRINT @Cmd
			
				EXEC ( @Cmd )
				IF @@ERROR <> 0 
					BEGIN
						SELECT  @StatusMsg = 'Error - Unable to create backup directory (' + @BackupDir + ')',
								@Success = -5
						RETURN -5
					END
			END
		END

END--Create Dir

SET @Success = 1

END --Proc
go
