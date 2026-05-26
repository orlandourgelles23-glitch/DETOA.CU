@echo off
setlocal enabledelayedexpansion
title DETOA v2.10.0 - Detener servidor
color 0C

echo.
echo ============================================================
echo   DETOA v2.10.0 - Deteniendo servidor
echo ============================================================
echo.

REM -- Kill Next.js server on port 3000 --
echo  Buscando procesos en puerto 3000...

REM Find and kill node processes using port 3000
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":3000 " ^| findstr "LISTENING"') do (
    echo  Deteniendo proceso PID %%a...
    taskkill /PID %%a /F >nul 2>&1
)

REM Also try killing any node processes that might be the dev server
tasklist /FI "WINDOWTITLE eq DETOA v2.10.0*" 2>nul | findstr /I "node" >nul
if !ERRORLEVEL! EQU 0 (
    echo  Deteniendo proceso de DETOA...
    taskkill /FI "WINDOWTITLE eq DETOA v2.10.0*" /F >nul 2>&1
)

echo.
echo  Servidor detenido.
echo.
pause
