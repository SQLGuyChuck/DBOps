
/*============================================================================
  File:     sp_AllocationMetadata.sql
 
  Summary:  This script cracks the system tables to provide top-level
            metadata about a table or index
 
  SQL Server Versions: 2005 onwards
------------------------------------------------------------------------------
  Written by Paul S. Randal, SQLskills.com
 
  (c) 2014, SQLskills.com. All rights reserved.
 
  For more scripts and sample code, check out
 
http://www.SQLskills.com
 
  You may alter this code for your own *non-commercial* purposes. You may
  republish altered code as long as you include this copyright and give due
  credit, but you must obtain prior permission before blogging this code.
 
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/
 
USE [master];
GO
 
IF OBJECT_ID (N'sp_AllocationMetadata') IS NOT NULL
    DROP PROCEDURE [sp_AllocationMetadata];
GO
 
CREATE PROCEDURE [sp_AllocationMetadata]
(
    @object SYSNAME = NULL
)
AS
SELECT
    OBJECT_NAME ([sp].[object_id]) AS [Object_Name],
    [sp].[index_id] AS [Index ID],
	ix.name AS Index_Name,
	ix.type_desc AS Index_Type,
    [sa].[allocation_unit_id] AS [Alloc Unit ID],
    [sa].[type_desc] AS [Alloc Unit Type],
    '(' + CONVERT (VARCHAR (6),
        CONVERT (INT,
            SUBSTRING ([sa].[first_page], 6, 1) +
            SUBSTRING ([sa].[first_page], 5, 1))) +
    ':' + CONVERT (VARCHAR (20),
        CONVERT (INT,
            SUBSTRING ([sa].[first_page], 4, 1) +
            SUBSTRING ([sa].[first_page], 3, 1) +
            SUBSTRING ([sa].[first_page], 2, 1) +
            SUBSTRING ([sa].[first_page], 1, 1))) +
    ')' AS [First Page],
    '(' + CONVERT (VARCHAR (6),
        CONVERT (INT,
            SUBSTRING ([sa].[root_page], 6, 1) +
            SUBSTRING ([sa].[root_page], 5, 1))) +
    ':' + CONVERT (VARCHAR (20),
        CONVERT (INT,
            SUBSTRING ([sa].[root_page], 4, 1) +
            SUBSTRING ([sa].[root_page], 3, 1) +
            SUBSTRING ([sa].[root_page], 2, 1) +
            SUBSTRING ([sa].[root_page], 1, 1))) +
    ')' AS [Root Page],
    '(' + CONVERT (VARCHAR (6),
        CONVERT (INT,
            SUBSTRING ([sa].[first_iam_page], 6, 1) +
            SUBSTRING ([sa].[first_iam_page], 5, 1))) +
    ':' + CONVERT (VARCHAR (20),
        CONVERT (INT,
            SUBSTRING ([sa].[first_iam_page], 4, 1) +
            SUBSTRING ([sa].[first_iam_page], 3, 1) +
            SUBSTRING ([sa].[first_iam_page], 2, 1) +
            SUBSTRING ([sa].[first_iam_page], 1, 1))) +
    ')' AS [First IAM Page]
	,sa.Total_Pages
	,sp.rows AS Total_Rows
FROM
    sys.system_internals_allocation_units AS [sa],
    sys.partitions AS [sp],
	sys.indexes AS [ix]
WHERE
    [sa].[container_id] = [sp].[partition_id]
AND [sp].[object_id] =
    (CASE WHEN (@object IS NULL)
        THEN [sp].[object_id]
        ELSE OBJECT_ID (@object)
    END)
AND sp.object_id = ix.object_id AND sp.index_id = ix.index_id
	;
GO
 
EXEC sys.sp_MS_marksystemobject [sp_AllocationMetadata];
GO
 