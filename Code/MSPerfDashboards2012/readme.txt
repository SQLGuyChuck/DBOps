Notes for SQL 2012 Install.

Getting Started With the Performance Dashboard Reports

Note, MS changed some system level object types for cpu timing, so run setup script against appropriate version of SQL and install RDL files in proper \1X0\ folder.

1. Each SQL Server instance you plan to monitor must contain the procedures and functions used by the queries in the reports.  Using SQL Server Management Studio (SSMS), open the setup.sql script and run against each SQL 2012 instance you would like to use the reports against. Then copy the folder contents to (default of %ProgramFiles(x86)%\Microsoft SQL Server\110\Tools\Performance Dashboard). Close the query window once it completes.

2. In the Object Explorer pane in SSMS, right mouse click on the SQL Server instance node, then choose Reports-Custom Reports.  Browse to the installation directory and open the performance_dashboard_main.rdl file.  Explore the health of your server by clicking on the various charts and hyperlinks in the report.


All of the remaining reports are accessed as drill through operations from the main page or one of its children.  For a detailed explanation of all installation requirements and guidance on how to use the reports, please see the help file, PerformanceDashboardHelp.chm.

 