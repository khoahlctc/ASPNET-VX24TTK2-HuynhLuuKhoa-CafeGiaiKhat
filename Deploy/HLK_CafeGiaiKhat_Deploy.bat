@echo off
cls
title Automated Database Deployment System - CafeGiaiKhat

:: Define paths and variables
set "DB_NAME=CafeGiaiKhat"
set "SQL_SCRIPT_NAME=HLK-CafeGiaiKhat_Script.sql"
set "WEB_CONFIG_NAME=Web.config"
set "TARGET_DIR=..\CafeGiaiKhat"
:: Pointing to the .sln file located in the parent directory
set "SOLUTION_FILE=..\HuynhLuuKhoa.sln"

echo ====================================================
echo    AUTOMATED DATABASE DEPLOYMENT FOR LOCALDB
echo ====================================================
echo.

:: 1. Force start LocalDB instance
echo [*] Step 1: Making sure LocalDB instance is active...
sqllocaldb start MSSQLLocalDB >nul 2>&1

:: 2. Drop existing Database completely and recreate it fresh
echo [*] Step 2: Wiping old database '%DB_NAME%' if it exists...
powershell -Command ^
    "$conn = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=master;Integrated Security=True;Encrypt=False;');" ^
    "try { $conn.Open(); } catch { Write-Host '[ERROR] Cannot connect to LocalDB!'; exit 1; }" ^
    "$cmd = $conn.CreateCommand();" ^
    "$cmd.CommandText = 'IF EXISTS (SELECT name FROM sys.databases WHERE name = ''%DB_NAME%'') BEGIN ALTER DATABASE [%DB_NAME%] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [%DB_NAME%]; END';" ^
    "$cmd.ExecuteNonQuery() | Out-Null;" ^
    "$conn.Close();" ^
    "Write-Host '[OK] Old database dropped completely.'"

if %errorlevel% NEQ 0 (
    echo [ERROR] Failed to clean up the database environment.
    timeout /t 5
    exit /b
)

:: 3. Clean and optimize the SQL script safely
echo [*] Step 3: Patching physical file paths inside SQL script...
set "FIXED_SQL_SCRIPT=%temp%\fixed_script.sql"
powershell -Command ^
    "if (Test-Path '%SQL_SCRIPT_NAME%') {" ^
    "   $content = Get-Content '%SQL_SCRIPT_NAME%' -Raw;" ^
    "   $content = $content -replace '(?s)CREATE DATABASE .*?GO', ('CREATE DATABASE [%DB_NAME%];' + [Environment]::NewLine + 'GO');" ^
    "   Set-Content -Path '%FIXED_SQL_SCRIPT%' -Value $content -Encoding UTF8;" ^
    "} else {" ^
    "   exit 1;" ^
    "}"

if %errorlevel% NEQ 0 (
    echo [ERROR] Source file %SQL_SCRIPT_NAME% not found!
    timeout /t 5
    exit /b
)

:: 4. Deploy the clean database structure
echo [*] Step 4: Creating tables and importing data rows...
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -i "%FIXED_SQL_SCRIPT%" -b
if %errorlevel% NEQ 0 (
    echo.
    echo [ERROR] SQL execution failed. Please verify your LocalDB installation.
    del "%FIXED_SQL_SCRIPT%" >nul 2>&1
    timeout /t 5
    exit /b
)
del "%FIXED_SQL_SCRIPT%" >nul 2>&1
echo [OK] Database rows and constraints created successfully!
echo ----------------------------------------------------

:: 5. Update connectionStrings inside Web.config safely
echo [*] Step 5: Updating connectionStrings inside %WEB_CONFIG_NAME%...
if not exist "%WEB_CONFIG_NAME%" (
    echo [ERROR] Configuration file %WEB_CONFIG_NAME% not found!
    timeout /t 5
    exit /b
)

set "TEMP_RESULT=%temp%\web_config_res.txt"
if exist "%TEMP_RESULT%" del "%TEMP_RESULT%"

powershell -Command ^
    "$baseConn = 'Data Source=(localdb)\MSSQLLocalDB;Initial Catalog=CafeGiaiKhat;Integrated Security=True;Encrypt=False';" ^
    "$efConn = 'metadata=res://*/Models.Gear.csdl|res://*/Models.Gear.ssdl|res://*/Models.Gear.msl;provider=System.Data.SqlClient;provider connection string=\"' + $baseConn + ';MultipleActiveResultSets=True;App=EntityFramework\"';" ^
    "$doc = [xml](Get-Content '%WEB_CONFIG_NAME%');" ^
    "$modified = $false;" ^
    "foreach ($add in $doc.configuration.connectionStrings.add) {" ^
    "   if ($add.name -eq 'ProTechTiveGearConnectionString' -or $add.name -eq 'ProTechTiveGearContext') {" ^
    "       $add.connectionString = $baseConn;" ^
    "       $modified = $true;" ^
    "   } elseif ($add.name -eq 'ProTechTiveGearEntities') {" ^
    "       $add.connectionString = $efConn;" ^
    "       $modified = $true;" ^
    "   }" ^
    "}" ^
    "if ($modified) { $doc.Save('%WEB_CONFIG_NAME%'); Write-Output 'SUCCESS' } else { Write-Output 'FAILED' }" > "%TEMP_RESULT%"

set /p WORK_STATUS=<"%TEMP_RESULT%"
del "%TEMP_RESULT%"

if "%WORK_STATUS%"=="SUCCESS" (
    echo [OK] Target connection strings patched inside Web.config successfully!
) else (
    echo [ERROR] Target elements not found in Web.config.
    timeout /t 5
    exit /b
)

:: 6. Copy updated Web.config to the target directory
echo ----------------------------------------------------
echo [*] Step 6: Overwriting Web.config to target directory...

if not exist "%TARGET_DIR%" (
    echo [ERROR] Target directory '%TARGET_DIR%' does not exist!
    timeout /t 5
    exit /b
)

xcopy "%WEB_CONFIG_NAME%" "%TARGET_DIR%\" /Y /V >nul

if %errorlevel% EQU 0 (
    echo [OK] Web.config copied and overwritten successfully!
    
    :: 7. Launch Visual Studio automatically
    echo [*] Step 7: Launching Visual Studio...
    if exist "%SOLUTION_FILE%" (
        start "" "%SOLUTION_FILE%"
    ) else (
        echo [WARNING] Solution file not found at %SOLUTION_FILE%.
        timeout /t 3
    )
) else (
    echo [ERROR] Failed to copy Web.config to target directory.
    timeout /t 5
    exit /b
)

exit