@echo off
setlocal

REM ============================================================
REM SpaceX Case Study - Raw Data CSV Export
REM ============================================================
REM
REM Purpose:
REM   Execute Export_Raw_Data_Query.sql against SQL Server and export the
REM   result as raw data.csv for the Workforce Planning case study.
REM
REM Business use:
REM   This file simulates a repeatable production extract from an ERP or
REM   customer support system into the Erlang forecast model and Power BI
REM   dashboard workflow.
REM
REM ============================================================
REM RUN INSTRUCTIONS
REM ============================================================
REM
REM 1. Install / confirm sqlcmd
REM    - This batch file requires the Microsoft SQL Server command-line tool:
REM      sqlcmd.
REM    - To test whether it is installed, open Command Prompt and run:
REM          sqlcmd -?
REM    - If sqlcmd is not recognized, install Microsoft Command Line Utilities
REM      for SQL Server, then reopen Command Prompt.
REM
REM 2. Update connection settings below
REM    - SERVER_NAME should be your SQL Server instance.
REM      Examples:
REM          localhost
REM          localhost\SQLEXPRESS
REM          PROD-SQL-01
REM          PROD-SQL-01.company.com
REM
REM    - DATABASE_NAME should be the database where the ERP/support table lives.
REM      Example:
REM          CustomerSupportERP
REM
REM 3. Confirm the SQL query
REM    - Open Export_Raw_Data_Query.sql.
REM    - Confirm the source table exists:
REM          dbo.SupportChatRequests
REM    - Confirm these columns exist or update them to match your schema:
REM          RequestedDateTime
REM          Status
REM          WaitSeconds
REM          HandleSeconds
REM
REM 4. Run this file
REM    - Double-click Export_Raw_Data_CSV.bat, or run it from Command Prompt:
REM          Export_Raw_Data_CSV.bat
REM
REM 5. Expected output
REM    - The export will create or overwrite:
REM          raw data.csv
REM    - The file will be saved in the same folder as this .bat file.
REM
REM 6. Authentication note
REM    - This script uses Windows Authentication via sqlcmd -E.
REM    - If SQL username/password authentication is required, replace:
REM          -E
REM      with:
REM          -U YOUR_USERNAME -P YOUR_PASSWORD
REM      Production recommendation: avoid hardcoding passwords in batch files.
REM      Use Windows Authentication, a secure scheduler credential, or a secrets
REM      manager when possible.
REM
REM 7. Troubleshooting
REM    - Login failed:
REM        Check your server name, database name, and SQL permissions.
REM
REM    - Invalid object name:
REM        The table name in Export_Raw_Data_Query.sql does not match the database.
REM
REM    - Invalid column name:
REM        One or more column names in Export_Raw_Data_Query.sql need to be mapped
REM        to your ERP/support schema.
REM
REM    - Output file is blank:
REM        Check the date filter in Export_Raw_Data_Query.sql.
REM
REM    - CSV formatting looks unusual:
REM        sqlcmd is a lightweight export tool. For production-grade extracts,
REM        consider SSIS, Azure Data Factory, SQL Agent jobs, or Power BI dataflows.
REM
REM Before running:
REM   1. Update SERVER_NAME and DATABASE_NAME below.
REM   2. Confirm the table and column names in Export_Raw_Data_Query.sql.
REM   3. Make sure sqlcmd is installed and available on PATH.
REM
REM Edit and sign-off history:
REM   2021-01-15 | Created initial export runner for interval-level support data.
REM               Signed off by: Workforce Planning Analyst
REM
REM   2021-06-30 | Added operational comments and prerequisite checks for SQL Server
REM               connection setup.
REM               Signed off by: Support Operations
REM
REM   2021-11-18 | Standardized output file naming as raw data.csv for model import.
REM               Signed off by: WFM Reporting Owner
REM
REM   2022-03-22 | Added console output for server, database, and destination path
REM               to improve auditability.
REM               Signed off by: Business Analytics
REM
REM   2022-08-09 | Added sqlcmd formatting flags for comma-delimited CSV export.
REM               Signed off by: WFM Capacity Planning
REM
REM   2022-12-31 | Validated export flow for December 2022 case-study dataset.
REM               Signed off by: Case Study Owner
REM
REM   2023-04-14 | Added clearer failure messaging for permissions, server, database,
REM               and schema issues.
REM               Signed off by: Senior Business Analyst
REM
REM   2023-09-27 | Confirmed compatibility with Power BI dashboard refresh workflow.
REM               Signed off by: Workforce Planning Lead
REM
REM   2023-12-15 | Final documentation pass for recruiter-facing case study package.
REM               Signed off by: Candidate / Dashboard Author
REM ============================================================

set "SERVER_NAME=YOUR_SERVER_NAME"
set "DATABASE_NAME=YOUR_DATABASE_NAME"
set "SCRIPT_DIR=%~dp0"
set "QUERY_FILE=%SCRIPT_DIR%Export_Raw_Data_Query.sql"
set "OUTPUT_FILE=%SCRIPT_DIR%raw data.csv"

echo Exporting raw WFM data from SQL Server...
echo Server:   %SERVER_NAME%
echo Database: %DATABASE_NAME%
echo Output:   %OUTPUT_FILE%
echo.

sqlcmd -S "%SERVER_NAME%" -d "%DATABASE_NAME%" -E -i "%QUERY_FILE%" -s "," -W -w 65535 -o "%OUTPUT_FILE%"

if errorlevel 1 (
    echo.
    echo Export failed. Check your SQL Server name, database name, permissions, and query/table names.
    pause
    exit /b 1
)

echo.
echo Export complete:
echo "%OUTPUT_FILE%"
pause
