@echo off
setlocal enabledelayedexpansion

:: FileTransfer 自动构建脚本 (Windows)
:: 用法: build_all.bat [apk|exe|all]

cd /d "%~dp0"

set OUTPUT_DIR=build_output
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

set TARGET=%1
if "%TARGET%"=="" set TARGET=all

if "%TARGET%"=="apk" goto build_apk
if "%TARGET%"=="exe" goto build_exe
if "%TARGET%"=="all" goto build_all

echo [错误] 未知目标: %TARGET%
echo 用法: %0 [apk^|exe^|all]
exit /b 1

:build_apk
echo [i] 开始构建 Android APK...

call flutter clean >nul 2>&1
call flutter pub get >nul 2>&1
call flutter build apk --release

if !errorlevel! equ 0 (
    if exist "build\app\outputs\flutter-apk\app-release.apk" (
        copy "build\app\outputs\flutter-apk\app-release.apk" "%OUTPUT_DIR%\file_transfer.apk" >nul
        echo [✓] APK 构建成功: %OUTPUT_DIR%\file_transfer.apk
    ) else (
        echo [✗] APK 文件未找到
        exit /b 1
    )
) else (
    echo [✗] APK 构建失败
    exit /b 1
)
goto :eof

:build_exe
echo [i] 开始构建 Windows EXE...

call flutter clean >nul 2>&1
call flutter pub get >nul 2>&1
call flutter build windows --release

if !errorlevel! equ 0 (
    if exist "build\windows\x64\runner\Release" (
        if exist "%OUTPUT_DIR%\windows" rmdir /s /q "%OUTPUT_DIR%\windows"
        xcopy "build\windows\x64\runner\Release" "%OUTPUT_DIR%\windows\" /e /i /q >nul
        echo [✓] EXE 构建成功: %OUTPUT_DIR%\windows\
        echo [i] 可执行文件: %OUTPUT_DIR%\windows\file_transfer.exe
    ) else (
        echo [✗] Windows 构建目录未找到
        exit /b 1
    )
) else (
    echo [✗] EXE 构建失败
    exit /b 1
)
goto :eof

:build_all
call :build_apk
echo.
call :build_exe
echo.
echo [i] 构建完成！输出目录: %OUTPUT_DIR%\
dir /b "%OUTPUT_DIR%"
goto :eof
