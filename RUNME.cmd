@echo off
REM Honeybadger Windows Audit Launcher
REM Starts AUDIT.ps1 with correct PowerShell settings

echo ===================================================
echo   Honeybadger - Windows ISO27001 Compliance Audit
echo ===================================================
echo.

REM Check if running as Administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Running with Administrator privileges
    echo.
) else (
    echo [WARNING] Not running as Administrator!
    echo.
    echo Some checks will be unavailable:
    echo   - BitLocker status
    echo   - Windows Defender status
    echo.
    echo For complete audit, right-click RUNME.cmd and select "Run as administrator"
    echo.
    pause
)

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"

REM Check if AUDIT.ps1 exists
if not exist "%SCRIPT_DIR%AUDIT.ps1" (
    echo [ERROR] AUDIT.ps1 not found in %SCRIPT_DIR%
    echo.
    echo Please ensure you have extracted the complete Honeybadger package.
    pause
    exit /b 1
)

echo Starting audit...
echo.

REM Run PowerShell with ExecutionPolicy Bypass
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%AUDIT.ps1"

REM Capture exit code
set EXIT_CODE=%errorLevel%

echo.
echo ===================================================
if %EXIT_CODE% == 0 (
    echo   Audit completed successfully!
) else (
    echo   Audit completed with errors (exit code: %EXIT_CODE%)
)
echo ===================================================
echo.
echo Press any key to close this window...
pause >nul

exit /b %EXIT_CODE%
