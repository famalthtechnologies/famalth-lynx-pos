@echo off
setlocal enabledelayedexpansion

echo =======================================================
echo   Building Famalth Enterprise Control Plane Standalone
echo =======================================================

cd /d "%~dp0"

echo [1/4] Building standalone Flutter Windows release...
call flutter build windows -t lib\main_control_plane.dart --release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Flutter Windows build failed with code %ERRORLEVEL%.
    exit /b %ERRORLEVEL%
)

echo [2/4] Preparing enterprise console staging directory...
if not exist "build\enterprise_console\Release" (
    mkdir "build\enterprise_console\Release"
)

xcopy /E /Y /I "build\windows\x64\runner\Release\*" "build\enterprise_console\Release\"
if exist "server_config.json" (
    copy /Y "server_config.json" "build\enterprise_console\Release\server_config.json"
)
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to copy build files to staging.
    exit /b %ERRORLEVEL%
)

echo [3/4] Renaming binary to FamalthEnterpriseConsole.exe...
if exist "build\enterprise_console\Release\FamalthLynx.exe" (
    if exist "build\enterprise_console\Release\FamalthEnterpriseConsole.exe" (
        del /f /q "build\enterprise_console\Release\FamalthEnterpriseConsole.exe"
    )
    ren "build\enterprise_console\Release\FamalthLynx.exe" "FamalthEnterpriseConsole.exe"
)
if exist "build\enterprise_console\Release\Retailpos.exe" (
    if exist "build\enterprise_console\Release\FamalthEnterpriseConsole.exe" (
        del /f /q "build\enterprise_console\Release\FamalthEnterpriseConsole.exe"
    )
    ren "build\enterprise_console\Release\Retailpos.exe" "FamalthEnterpriseConsole.exe"
)

echo [4/4] Compiling Inno Setup installer...
set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist "%ISCC_PATH%" (
    set "ISCC_PATH=C:\Program Files\Inno Setup 6\ISCC.exe"
)

if exist "%ISCC_PATH%" (
    "%ISCC_PATH%" "installer\enterprise_control_plane.iss"
    if %ERRORLEVEL% equ 0 (
        echo =======================================================
        echo [SUCCESS] Installer successfully created at:
        echo   installer\Output\Famalth_Enterprise_Console_Installer.exe
        echo =======================================================
    ) else (
        echo [ERROR] Inno Setup compiler exited with error code %ERRORLEVEL%.
        exit /b %ERRORLEVEL%
    )
) else (
    echo [WARNING] Inno Setup compiler ISCC.exe was not found.
    echo Please install Inno Setup 6 or run installer\enterprise_control_plane.iss manually.
)

exit /b 0
