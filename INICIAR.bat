@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title DETOA v2.10.0
color 0A

REM -- Verify Node.js is available --
where node >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo.
    echo  [ERROR] Node.js no esta instalado.
    echo  Ejecute INSTALAR.bat primero para instalar las dependencias.
    echo.
    pause
    exit /b 1
)

REM ============================================================
REM Detect mode: standalone (production) or project root (dev)
REM ============================================================

REM -- If server.js exists here, we're in standalone mode --
if exist "server.js" goto :standalone_mode

REM -- If .next\standalone\server.js exists, redirect there --
if exist ".next\standalone\server.js" (
    echo.
    echo  Redirigiendo al directorio de ejecucion standalone...
    cd .next\standalone
    goto :standalone_mode
)

REM -- If we're in the project root with no build, use dev mode --
if exist "node_modules\next" goto :dev_mode

REM -- Nothing found, tell user to install --
echo.
echo  [ERROR] No se encontro la instalacion de DETOA.
echo  Ejecute INSTALAR.bat primero.
echo.
pause
exit /b 1

REM ============================================================
REM STANDALONE MODE (production)
REM ============================================================
:standalone_mode

set "NODE_ENV=production"
set "PORT=3000"
set "DETOA_AUTO_OPEN=1"

REM -- Build ABSOLUTE DATABASE_URL --
if not exist "db" mkdir db
for /f "tokens=*" %%d in ('cd') do set "DATABASE_URL=file:%%d/db/custom.db"
set "DATABASE_URL=!DATABASE_URL:\=/!"

echo.
echo ============================================================
echo   DETOA v2.10.0 - Iniciando sistema ^(produccion^)
echo ============================================================
echo.
echo  Servidor: http://localhost:!PORT!
echo  Base de datos: !DATABASE_URL!
echo.

if exist "start.js" (
    node start.js
) else if exist "server.js" (
    node server.js
) else (
    echo.
    echo  [ERROR] No se encontro server.js ni start.js.
    echo  Ejecute INSTALAR.bat para generar los archivos necesarios.
    echo.
    pause
    exit /b 1
)

if !ERRORLEVEL! NEQ 0 (
    echo.
    echo  [ERROR] El servidor se detuvo con errores ^(codigo: !ERRORLEVEL!^).
    echo  Revise los mensajes arriba para mas informacion.
) else (
    echo.
    echo  [AVISO] El servidor se detuvo normalmente.
)
pause
exit /b 0

REM ============================================================
REM DEV MODE (when standalone build is not available)
REM ============================================================
:dev_mode

set "PORT=3000"
set "NODE_ENV=development"
set "DETOA_AUTO_OPEN=1"

REM -- Build ABSOLUTE DATABASE_URL for dev mode too --
if not exist "db" mkdir db
for /f "tokens=*" %%d in ('cd') do set "DATABASE_URL=file:%%d/db/custom.db"
set "DATABASE_URL=!DATABASE_URL:\=/!"

echo.
echo ============================================================
echo   DETOA v2.10.0 - Iniciando sistema ^(desarrollo^)
echo ============================================================
echo.
echo  NOTA: Modo desarrollo ^(la compilacion produccion fallo o
echo        no se ha ejecutado todavia^).
echo  Servidor: http://localhost:!PORT!
echo  Base de datos: !DATABASE_URL!
echo.

call npx next dev -p !PORT!

if !ERRORLEVEL! NEQ 0 (
    echo.
    echo  [ERROR] El servidor se detuvo con errores ^(codigo: !ERRORLEVEL!^).
    echo  Revise los mensajes arriba para mas informacion.
) else (
    echo.
    echo  [AVISO] El servidor se detuvo normalmente.
)
pause
