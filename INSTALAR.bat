@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title DETOA v2.10.0 - Instalacion
color 0A

echo.
echo ============================================================
echo   DETOA v2.10.0 - Instalador
echo   Sistema de Gestion Empresarial CADEM/PDL
echo ============================================================
echo.
echo  Si se corta la red, ejecute este bat de nuevo.
echo.

REM ============================================================
REM STEP 1: Check/Install Node.js
REM ============================================================
echo [1/8] Verificando Node.js...
where node >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo  Node.js no encontrado. Instalando Node.js v22...
    echo  Descargando... esto puede tardar varios minutos.
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri 'https://nodejs.org/dist/v22.15.0/node-v22.15.0-x64.msi' -OutFile '!TEMP!\node-setup.msi' -TimeoutSec 300 } catch {}"
    if exist "!TEMP!\node-setup.msi" (
        echo  Instalando Node.js ^(puede pedir permisos de administrador^)...
        msiexec /i "!TEMP!\node-setup.msi" /qn /norestart
        del "!TEMP!\node-setup.msi" 2>nul
        set "PATH=!PATH!;C:\Program Files\nodejs"
    ) else (
        echo  [ERROR] No se pudo descargar Node.js.
        echo  Descarguelo manualmente de https://nodejs.org
        pause
        exit /b 1
    )
    where node >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo  [ERROR] No se pudo instalar Node.js.
        echo  Descarguelo de https://nodejs.org e instalelo manualmente.
        echo  Luego ejecute este instalador de nuevo.
        pause
        exit /b 1
    )
)
for /f "tokens=*" %%i in ('node -v') do echo  [1/8] Node.js %%i - OK

REM ============================================================
REM STEP 2: Check Bun (optional, fallback to npm)
REM ============================================================
echo.
echo [2/8] Verificando Bun (gestor de paquetes alternativo)...
set "BUN_AVAILABLE=0"
where bun >nul 2>&1
if !ERRORLEVEL! EQU 0 (
    set "BUN_AVAILABLE=1"
    echo  Bun encontrado - OK
) else (
    echo  Bun no encontrado. Se usara npm.
)

REM ============================================================
REM STEP 3: Install dependencies WITHOUT postinstall scripts
REM ============================================================
echo.
echo [3/8] Instalando dependencias...
echo  (Si se corta la red, ejecute de nuevo)
echo.
set "INSTALL_OK=0"

if "!BUN_AVAILABLE!"=="1" (
    echo  Intentando con bun install --ignore-scripts...
    call bun install --ignore-scripts
    if !ERRORLEVEL! EQU 0 set "INSTALL_OK=1"
)

if "!INSTALL_OK!"=="0" (
    echo  Intentando con npm install --ignore-scripts...
    call npm install --ignore-scripts
    if !ERRORLEVEL! EQU 0 set "INSTALL_OK=1"
)

if "!INSTALL_OK!"=="0" (
    echo  Reintentando con npm install...
    call npm install
    if !ERRORLEVEL! EQU 0 set "INSTALL_OK=1"
)

if not exist "node_modules\next" (
    echo.
    echo  [ERROR] Dependencias no instaladas correctamente.
    echo  Verifique su conexion a internet y ejecute de nuevo.
    pause
    exit /b 1
)
echo  Dependencias instaladas correctamente.

REM ============================================================
REM STEP 4: Generate Prisma client (separate from install)
REM ============================================================
echo.
echo [4/8] Generando cliente Prisma...
echo  (Esto descarga el motor de base de datos, requiere internet)
echo.
set "PRISMA_GEN_OK=0"
set "MAX_PRISMA_RETRIES=10"

for /L %%i in (1,1,!MAX_PRISMA_RETRIES!) do (
    if "!PRISMA_GEN_OK!"=="0" (
        echo  Intento %%i de !MAX_PRISMA_RETRIES!...
        if exist "node_modules\.bin\prisma.cmd" (
            call node_modules\.bin\prisma.cmd generate
        ) else (
            call npx prisma generate
        )
        if !ERRORLEVEL! EQU 0 set "PRISMA_GEN_OK=1"
        
        if "!PRISMA_GEN_OK!"=="0" (
            if %%i LSS !MAX_PRISMA_RETRIES! (
                set /a "DELAY=%%i * 5"
                if !DELAY! GTR 30 set "DELAY=30"
                echo  Fallo. Reintentando en !DELAY! segundos...
                timeout /t !DELAY! /nobreak >nul 2>&1
            )
        )
    )
)

if "!PRISMA_GEN_OK!"=="1" (
    echo  Cliente Prisma generado correctamente.
) else (
    echo.
    echo  ============================================================
    echo   [ERROR] No se pudo generar el cliente Prisma.
    echo  ============================================================
    echo.
    echo  Esto puede ser por problemas de conexion a internet.
    echo  Prisma necesita descargar el motor de base de datos.
    echo.
    echo  Soluciones:
    echo    1. Verifique su conexion y ejecute INSTALAR.bat de nuevo
    echo    2. Si usa proxy, configure las variables:
    echo       set HTTP_PROXY=http://su-proxy:puerto
    echo       set HTTPS_PROXY=http://su-proxy:puerto
    echo    3. Intente manualmente:
    echo       npx prisma generate
    echo       INSTALAR.bat
    echo.
    echo  La instalacion no puede continuar sin el cliente Prisma.
    echo.
    pause
    exit /b 1
)

REM ============================================================
REM STEP 5: Initialize database
REM ============================================================
echo.
echo [5/8] Inicializando base de datos...

if "!PRISMA_GEN_OK!"=="0" (
    echo  [AVISO] Se omitira la inicializacion de la base de datos.
    echo  Se creara automaticamente en el primer inicio del sistema.
    goto :skip_db_init
)

if not exist "db" mkdir db

for /f "tokens=*" %%d in ('cd') do set "DATABASE_URL=file:%%d/db/custom.db"
set "DATABASE_URL=!DATABASE_URL:\=/!"
set "NODE_ENV=production"

echo  Creando tablas ^(prisma db push^)...
if exist "node_modules\.bin\prisma.cmd" (
    call node_modules\.bin\prisma.cmd db push
) else (
    call npx prisma db push
)
if !ERRORLEVEL! NEQ 0 (
    echo  [AVISO] prisma db push fallo. Intentando alternativa...
    call node node_modules\prisma\entrypoint.js db push
    if !ERRORLEVEL! NEQ 0 (
        echo  [AVISO] No se pudieron crear las tablas.
        echo  Se intentara crear en el primer inicio del sistema.
    )
)

echo.
echo  Insertando datos iniciales...
call npx tsx prisma\seed.ts
if !ERRORLEVEL! NEQ 0 (
    echo  [AVISO] Seed con tsx fallo. Intentando alternativa...
    call node -e "require('tsx/cjs'); require('./prisma/seed.ts')"
    if !ERRORLEVEL! NEQ 0 (
        echo  [AVISO] No se pudieron insertar todos los datos iniciales.
        echo  El sistema puede funcionar, pero puede faltar data basica.
    )
)
echo  Base de datos inicializada.

:skip_db_init

REM ============================================================
REM STEP 6: Build the Next.js standalone app
REM ============================================================
echo.
echo [6/8] Compilando DETOA ^(1-3 minutos^)...
echo.

set "BUILD_OK=0"

REM -- Attempt 1: Webpack with 4GB memory (recommended, Turbopack has CSS import bugs) --
echo  Intentando compilacion con Webpack ^(4GB RAM^)...
set "NODE_OPTIONS=--max-old-space-size=4096"
call npx next build --webpack
if !ERRORLEVEL! EQU 0 set "BUILD_OK=1"

REM -- Attempt 2: Turbopack with 4GB memory --
if "!BUILD_OK!"=="0" (
    echo.
    echo  [AVISO] Webpack fallo. Intentando con Turbopack...
    echo.
    set "NODE_OPTIONS=--max-old-space-size=4096"
    call npx next build
    if !ERRORLEVEL! EQU 0 set "BUILD_OK=1"
)

REM -- Attempt 3: Webpack with 2GB memory --
if "!BUILD_OK!"=="0" (
    echo.
    echo  [AVISO] Reintentando con menos memoria...
    echo.
    set "NODE_OPTIONS=--max-old-space-size=2048"
    call npx next build --webpack
    if !ERRORLEVEL! EQU 0 set "BUILD_OK=1"
)

if "!BUILD_OK!"=="0" (
    echo.
    echo  [AVISO] La compilacion fallo ^(posiblemente por falta de memoria^).
    echo  Configurando modo desarrollo ^(usa menos memoria^)...
    echo.
    goto :dev_mode_setup
)

if not exist ".next\standalone\server.js" (
    echo.
    echo  [AVISO] No se genero el build standalone.
    echo  Configurando modo desarrollo...
    echo.
    goto :dev_mode_setup
)
echo  Compilacion completada.

REM ============================================================
REM STEP 7: Build Public Web Store
REM ============================================================
echo.
echo [7/8] Preparando Tienda Web Publica...

set "STORE_COPIED=0"

REM -- Priority 1: Use pre-built dist/ from the ZIP (no compilation needed) --
if exist "public-web\dist\index.html" (
    if exist "public\tienda" rd /s /q "public\tienda"
    xcopy /E /I /Y "public-web\dist" "public\tienda"
    echo  Tienda pre-compilada copiada a public\tienda\
    set "STORE_COPIED=1"
)

REM -- Priority 2: Try to compile from source if no pre-built dist --
if "!STORE_COPIED!"=="0" (
    if exist "public-web\package.json" (
        cd public-web
        echo  Instalando dependencias de la tienda...
        call npm install --prefer-offline 2>nul
        call npm install 2>nul
        echo  Compilando tienda web...
        call npx vite build
        if exist "dist\index.html" (
            if exist "..\public\tienda" rd /s /q "..\public\tienda"
            xcopy /E /I /Y "dist" "..\public\tienda"
            echo  Tienda Web compilada y copiada a public\tienda\
            set "STORE_COPIED=1"
        ) else (
            echo  [AVISO] No se pudo compilar la tienda web. Se continuara sin ella.
            echo  Puede compilarla manualmente: cd public-web ^&^& npm install ^&^& npx vite build
        )
        cd ..
    )
)

if "!STORE_COPIED!"=="0" (
    if not exist "public\tienda\index.html" (
        echo  [AVISO] No se encontro la tienda web. Se continuara sin ella.
    )
)

REM ============================================================
REM STEP 8: Copy files to standalone directory
REM ============================================================
echo.
echo [8/8] Copiando archivos al directorio de ejecucion...

REM -- Copy start.js (DB auto-init wrapper) --
if exist "start.js" (
    copy /Y "start.js" ".next\standalone\start.js" >nul 2>&1
    echo  start.js copiado.
) else (
    echo  [AVISO] No se encontro start.js. Se usara server.js directamente.
)

REM -- Copy INICIAR.bat to standalone --
if exist "INICIAR.bat" (
    copy /Y "INICIAR.bat" ".next\standalone\INICIAR.bat" >nul 2>&1
    echo  INICIAR.bat copiado.
) else (
    (
        echo @echo off
        echo setlocal enabledelayedexpansion
        echo cd /d "%%~dp0"
        echo set "NODE_ENV=production"
        echo set "PORT=3000"
        echo set "DETOA_AUTO_OPEN=1"
        echo if not exist "db" mkdir db
        echo for /f "tokens=*" %%%%d in ^('cd'^) do set "DATABASE_URL=file:%%%%d/db/custom.db"
        echo set "DATABASE_URL=!DATABASE_URL:\=/!"
        echo if exist "start.js" ^(
        echo     node start.js
        echo ^) else ^(
        echo     node server.js
        echo ^)
        echo if !ERRORLEVEL! NEQ 0 ^(
        echo     echo.
        echo     echo  [ERROR] El servidor fallo.
        echo ^)
        echo pause
    ) > ".next\standalone\INICIAR.bat"
)

REM -- Copy install.sh to standalone --
if exist "install.sh" (
    copy /Y "install.sh" ".next\standalone\install.sh" >nul 2>&1
)

REM -- Copy iniciar.sh to standalone --
if exist "iniciar.sh" (
    copy /Y "iniciar.sh" ".next\standalone\iniciar.sh" >nul 2>&1
)

REM -- Copy .next/static to standalone --
if exist ".next\static" (
    if not exist ".next\standalone\.next" mkdir ".next\standalone\.next"
    xcopy /E /I /Y ".next\static" ".next\standalone\.next\static" >nul 2>&1
    echo  Archivos estaticos copiados.
)

REM -- Copy public to standalone --
if exist "public" (
    xcopy /E /I /Y "public" ".next\standalone\public" >nul 2>&1
    echo  Archivos publicos copiados.
)

REM -- Copy native modules that standalone doesn't include --
for %%m in (docx jszip jose bcryptjs xlsx jspdf jspdf-autotable qrcode file-saver) do (
    if exist "node_modules\%%m" (
        if not exist ".next\standalone\node_modules\%%m" mkdir ".next\standalone\node_modules\%%m"
        xcopy /E /I /Y "node_modules\%%m" ".next\standalone\node_modules\%%m" >nul 2>&1
        echo  %%m copiado.
    )
)

REM -- Copy @prisma/engines (Prisma's bundled SQLite engine -- NOT better-sqlite3) --
if exist "node_modules\@prisma\engines" (
    if not exist ".next\standalone\node_modules\@prisma\engines" mkdir ".next\standalone\node_modules\@prisma\engines"
    xcopy /E /I /Y "node_modules\@prisma\engines" ".next\standalone\node_modules\@prisma\engines" >nul 2>&1
    echo  @prisma/engines copiado.
)

REM -- Copy .prisma (generated client internals) --
if exist "node_modules\.prisma" (
    if not exist ".next\standalone\node_modules\.prisma" mkdir ".next\standalone\node_modules\.prisma"
    xcopy /E /I /Y "node_modules\.prisma" ".next\standalone\node_modules\.prisma" >nul 2>&1
    echo  .prisma copiado.
)

REM -- Copy @prisma/client --
if exist "node_modules\@prisma\client" (
    if not exist ".next\standalone\node_modules\@prisma\client" mkdir ".next\standalone\node_modules\@prisma\client"
    xcopy /E /I /Y "node_modules\@prisma\client" ".next\standalone\node_modules\@prisma\client" >nul 2>&1
    echo  @prisma/client copiado.
)

REM -- Copy prisma CLI --
if exist "node_modules\@prisma\cli" (
    if not exist ".next\standalone\node_modules\@prisma\cli" mkdir ".next\standalone\node_modules\@prisma\cli"
    xcopy /E /I /Y "node_modules\@prisma\cli" ".next\standalone\node_modules\@prisma\cli" >nul 2>&1
    echo  @prisma/cli copiado.
) else if exist "node_modules\prisma" (
    if not exist ".next\standalone\node_modules\prisma" mkdir ".next\standalone\node_modules\prisma"
    xcopy /E /I /Y "node_modules\prisma" ".next\standalone\node_modules\prisma" >nul 2>&1
    echo  prisma CLI copiado.
)

REM -- Copy tsx (for seed execution) --
if exist "node_modules\tsx" (
    if not exist ".next\standalone\node_modules\tsx" mkdir ".next\standalone\node_modules\tsx"
    xcopy /E /I /Y "node_modules\tsx" ".next\standalone\node_modules\tsx" >nul 2>&1
    echo  tsx copiado.
)

REM -- Write .env file --
set "ENVFILE=.next\standalone\.env"
for /f "tokens=*" %%d in ('cd') do set "STANDALONE_DIR=%%d\.next\standalone"
set "STANDALONE_DIR=!STANDALONE_DIR:\=/!"
echo DATABASE_URL=file:!STANDALONE_DIR!/db/custom.db> "!ENVFILE!"
echo  .env creado.

REM -- Copy database to standalone --
if not exist ".next\standalone\db" mkdir ".next\standalone\db"
if exist "db\custom.db" (
    copy /Y "db\custom.db" ".next\standalone\db\custom.db" >nul 2>&1
    echo  Base de datos copiada al directorio de ejecucion.
) else if exist "prisma\data\custom.db" (
    copy /Y "prisma\data\custom.db" ".next\standalone\db\custom.db" >nul 2>&1
    echo  Base de datos copiada ^(desde prisma\data^).
) else (
    echo  [AVISO] No se encontro db\custom.db.
    echo  Se creara en el primer inicio.
)

REM -- Copy prisma schema and seed for DB recovery --
if not exist ".next\standalone\prisma" mkdir ".next\standalone\prisma"
if exist "prisma\schema.prisma" (
    copy /Y "prisma\schema.prisma" ".next\standalone\prisma\schema.prisma" >nul 2>&1
    echo  schema.prisma copiado.
)
if exist "prisma\seed.ts" (
    copy /Y "prisma\seed.ts" ".next\standalone\prisma\seed.ts" >nul 2>&1
    echo  seed.ts copiado.
)

echo.
echo ============================================================
echo   INSTALACION COMPLETADA ^(modo produccion standalone^)
echo ============================================================
echo.
echo  Para iniciar DETOA:
echo    cd .next\standalone
echo    INICIAR.bat
echo.
echo  O simplemente haga doble clic en:
echo    .next\standalone\INICIAR.bat
echo.
echo  Credenciales por defecto:
echo    Usuario:    2026
echo    Contrasena: 2026
echo.
pause
exit /b 0

REM ============================================================
REM DEV MODE FALLBACK
REM ============================================================
:dev_mode_setup

echo.
echo ============================================================
echo   INSTALACION COMPLETADA ^(modo desarrollo^)
echo ============================================================
echo.
echo  La compilacion produccion fallo por falta de memoria RAM.
echo  El sistema funcionara en modo desarrollo.
echo.
echo  Para iniciar DETOA haga doble clic en:
echo    INICIAR.bat
echo.
echo  NOTA: INICIAR.bat detectara automaticamente que no hay
echo  build standalone y usara modo desarrollo.
echo  Para modo produccion, compile en una maquina con mas RAM.
echo.
echo  Credenciales por defecto:
echo    Usuario:    2026
echo    Contrasena: 2026
echo.
pause
