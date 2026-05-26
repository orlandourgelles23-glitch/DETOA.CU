#!/bin/bash
set -e
cd "$(dirname "$0")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "============================================================"
echo "  DETOA v2.10.0 - Instalador"
echo "  Sistema de Gestion Empresarial CADEM/PDL"
echo "============================================================"
echo ""
echo " Si se corta la red, ejecute este script de nuevo."
echo ""

# ============================================================
# STEP 1: Check Node.js
# ============================================================
echo -e "${BLUE}[1/8]${NC} Verificando Node.js..."
if ! command -v node &>/dev/null; then
    echo -e " ${YELLOW}Node.js no encontrado. Instalando...${NC}"
    if command -v curl &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v brew &>/dev/null; then
        brew install node@22
    fi
    if ! command -v node &>/dev/null; then
        echo -e " ${RED}[ERROR] No se pudo instalar Node.js.${NC}"
        echo " Descarguelo de https://nodejs.org"
        exit 1
    fi
fi
echo -e " ${GREEN}[1/8] Node.js $(node -v) - OK${NC}"

# ============================================================
# STEP 2: Check Bun
# ============================================================
echo ""
echo -e "${BLUE}[2/8]${NC} Verificando Bun (gestor de paquetes alternativo)..."
PKG_MANAGER=""
if command -v bun &>/dev/null; then
    PKG_MANAGER="bun"
    echo -e " Bun encontrado - OK"
else
    echo -e " Bun no encontrado. Se usara npm."
    PKG_MANAGER="npm"
fi

# ============================================================
# STEP 3: Install dependencies
# ============================================================
echo ""
echo -e "${BLUE}[3/8]${NC} Instalando dependencias..."
echo " (Si se corta la red, ejecute de nuevo)"
echo ""

INSTALL_OK=0
if [ "$PKG_MANAGER" = "bun" ]; then
    echo " Intentando con bun install --ignore-scripts..."
    bun install --ignore-scripts && INSTALL_OK=1 || true
fi

if [ "$INSTALL_OK" = "0" ]; then
    echo " Intentando con npm install --ignore-scripts..."
    npm install --ignore-scripts && INSTALL_OK=1 || true
fi

if [ "$INSTALL_OK" = "0" ]; then
    echo " Reintentando con npm install..."
    npm install && INSTALL_OK=1 || true
fi

if [ ! -d "node_modules/next" ]; then
    echo ""
    echo -e " ${RED}[ERROR] Dependencias no instaladas correctamente.${NC}"
    echo " Verifique su conexion a internet y ejecute de nuevo."
    exit 1
fi
echo -e " ${GREEN}Dependencias instaladas correctamente.${NC}"

# ============================================================
# STEP 4: Generate Prisma client
# ============================================================
echo ""
echo -e "${BLUE}[4/8]${NC} Generando cliente Prisma..."
echo " (Esto descarga el motor de base de datos, requiere internet)"
echo ""
PRISMA_GEN_OK=0
MAX_PRISMA_RETRIES=10

for attempt in $(seq 1 $MAX_PRISMA_RETRIES); do
    if [ "$PRISMA_GEN_OK" = "0" ]; then
        echo " Intento $attempt de $MAX_PRISMA_RETRIES..."
        if [ -f "node_modules/.bin/prisma" ]; then
            npx prisma generate && PRISMA_GEN_OK=1
        else
            npx -y prisma generate && PRISMA_GEN_OK=1
        fi
        
        if [ "$PRISMA_GEN_OK" = "0" ] && [ $attempt -lt $MAX_PRISMA_RETRIES ]; then
            DELAY=$((attempt * 5))
            if [ $DELAY -gt 30 ]; then DELAY=30; fi
            echo " Fallo. Reintentando en ${DELAY} segundos..."
            sleep $DELAY
        fi
    fi
done

if [ "$PRISMA_GEN_OK" = "1" ]; then
    echo -e " ${GREEN}Cliente Prisma generado correctamente.${NC}"
else
    echo ""
    echo " ============================================================"
    echo -e "  ${RED}[ERROR] No se pudo generar el cliente Prisma.${NC}"
    echo " ============================================================"
    echo ""
    echo " Esto puede ser por problemas de conexion a internet."
    echo " Prisma necesita descargar el motor de base de datos."
    echo ""
    echo " Soluciones:"
    echo "   1. Verifique su conexion y ejecute install.sh de nuevo"
    echo "   2. Si usa proxy, configure las variables:"
    echo "      export HTTP_PROXY=http://su-proxy:puerto"
    echo "      export HTTPS_PROXY=http://su-proxy:puerto"
    echo "   3. Intente manualmente:"
    echo "      npx prisma generate"
    echo "      ./install.sh"
    echo ""
    echo " La instalacion no puede continuar sin el cliente Prisma."
    echo ""
    exit 1
fi

# ============================================================
# STEP 5: Initialize database
# ============================================================
echo ""
echo -e "${BLUE}[5/8]${NC} Inicializando base de datos..."

if [ "$PRISMA_GEN_OK" = "0" ]; then
    echo -e " ${YELLOW}[AVISO] Se omitira la inicializacion de la base de datos.${NC}"
    echo " Se creara automaticamente en el primer inicio del sistema."
else
    mkdir -p db
    export DATABASE_URL="file:$(pwd)/db/custom.db"
    export NODE_ENV=production

    echo " Creando tablas (prisma db push)..."
    npx prisma db push 2>/dev/null || {
        echo -e " ${YELLOW}[AVISO] prisma db push fallo.${NC}"
        echo " Se intentara crear en el primer inicio del sistema."
    }

    echo ""
    echo " Insertando datos iniciales..."
    npx tsx prisma/seed.ts 2>/dev/null || {
        echo -e " ${YELLOW}[AVISO] No se pudieron insertar todos los datos iniciales.${NC}"
        echo " El sistema puede funcionar, pero puede faltar data basica."
    }
    echo -e " ${GREEN}Base de datos inicializada.${NC}"
fi

# ============================================================
# STEP 6: Build Next.js
# ============================================================
echo ""
echo -e "${BLUE}[6/8]${NC} Compilando DETOA (1-3 minutos)..."
echo ""

BUILD_OK=0
echo " Intentando compilacion con Webpack (recomendado)..."
NODE_OPTIONS="--max-old-space-size=4096" npx next build --webpack && BUILD_OK=1 || true

if [ "$BUILD_OK" = "0" ]; then
    echo ""
    echo -e " ${YELLOW}[AVISO] Webpack fallo. Intentando con Turbopack...${NC}"
    echo ""
    NODE_OPTIONS="--max-old-space-size=4096" npx next build && BUILD_OK=1 || true
fi

if [ "$BUILD_OK" = "0" ]; then
    echo ""
    echo -e " ${YELLOW}[AVISO] Reintentando con menos memoria...${NC}"
    echo ""
    NODE_OPTIONS="--max-old-space-size=2048" npx next build --webpack && BUILD_OK=1 || true
fi

if [ "$BUILD_OK" = "0" ]; then
    echo ""
    echo -e " ${YELLOW}[AVISO] La compilacion fallo. Configurando modo desarrollo...${NC}"
    echo ""
    echo "============================================================"
    echo "  INSTALACION COMPLETADA (modo desarrollo)"
    echo "============================================================"
    echo ""
    echo "  Para iniciar DETOA:"
    echo "    bash iniciar.sh"
    echo ""
    echo "  Credenciales por defecto:"
    echo "    Usuario:    2026"
    echo "    Contrasena: 2026"
    echo ""
    exit 0
fi

if [ ! -f ".next/standalone/server.js" ]; then
    echo ""
    echo -e " ${YELLOW}[AVISO] No se genero el build standalone.${NC}"
    echo " Use modo desarrollo: bash iniciar.sh"
    echo ""
    exit 0
fi
echo -e " ${GREEN}Compilacion completada.${NC}"

# ============================================================
# STEP 7: Build Public Web Store
# ============================================================
echo ""
echo -e "${BLUE}[7/8]${NC} Compilando Tienda Web Publica..."

STORE_COPIED=0

# Priority 1: Use pre-built dist/ from the ZIP (no compilation needed)
if [ -f "public-web/dist/index.html" ]; then
    rm -rf public/tienda
    cp -r public-web/dist public/tienda
    echo -e " ${GREEN}Tienda pre-compilada copiada a public/tienda/${NC}"
    STORE_COPIED=1
fi

# Priority 2: Try to compile from source if no pre-built dist exists
if [ "$STORE_COPIED" = "0" ] && [ -d "public-web" ] && [ -f "public-web/package.json" ]; then
    cd public-web
    STORE_BUILD_OK=0
    
    # Try npm install + vite build
    echo " Instalando dependencias de la tienda..."
    npm install --prefer-offline 2>/dev/null && npm install 2>/dev/null
    
    if [ -f "node_modules/.bin/vite" ] || npx -y vite --version >/dev/null 2>&1; then
        echo " Compilando tienda web..."
        npx vite build && STORE_BUILD_OK=1 || true
    fi
    
    if [ "$STORE_BUILD_OK" = "1" ] && [ -f "dist/index.html" ]; then
        rm -rf ../public/tienda
        cp -r dist ../public/tienda
        echo -e " ${GREEN}Tienda Web compilada y copiada a public/tienda/${NC}"
    else
        echo -e " ${YELLOW}[AVISO] No se pudo compilar la tienda web. Se continuara sin ella.${NC}"
        echo " Puede compilarla manualmente: cd public-web && npm install && npx vite build"
    fi
    cd ..
fi

if [ "$STORE_COPIED" = "0" ] && [ ! -d "public/tienda" ]; then
    echo -e " ${YELLOW}[AVISO] No se encontro la tienda web. Se continuara sin ella.${NC}"
fi

# ============================================================
# STEP 8: Copy files to standalone
# ============================================================
echo ""
echo -e "${BLUE}[8/8]${NC} Copiando archivos al directorio de ejecucion..."

STANDALONE=".next/standalone"

# Copy start.js
[ -f "start.js" ] && cp -f "start.js" "$STANDALONE/start.js" && echo " start.js copiado."

# Copy launcher scripts
[ -f "INICIAR.bat" ] && cp -f "INICIAR.bat" "$STANDALONE/INICIAR.bat"
[ -f "DETENER.bat" ] && cp -f "DETENER.bat" "$STANDALONE/DETENER.bat"
[ -f "iniciar.sh" ] && cp -f "iniciar.sh" "$STANDALONE/iniciar.sh" && chmod +x "$STANDALONE/iniciar.sh"
[ -f "detener.sh" ] && cp -f "detener.sh" "$STANDALONE/detener.sh" && chmod +x "$STANDALONE/detener.sh"

# Copy static files
if [ -d ".next/static" ]; then
    mkdir -p "$STANDALONE/.next"
    cp -r ".next/static" "$STANDALONE/.next/"
    echo " Archivos estaticos copiados."
fi

# Copy public
[ -d "public" ] && cp -r "public" "$STANDALONE/public" && echo " Archivos publicos copiados."

# Ensure uploads directory exists in standalone (for runtime image uploads)
mkdir -p "$STANDALONE/public/uploads/products"
echo " Directorio uploads/products asegurado."

# Copy native modules that standalone doesn't include
for mod in docx jszip jose bcryptjs xlsx jspdf jspdf-autotable qrcode file-saver; do
    if [ -d "node_modules/$mod" ]; then
        mkdir -p "$STANDALONE/node_modules/$mod"
        cp -r "node_modules/$mod" "$STANDALONE/node_modules/" 2>/dev/null && echo " $mod copiado."
    fi
done

# Copy @prisma/engines (Prisma's bundled SQLite engine — NOT better-sqlite3)
if [ -d "node_modules/@prisma/engines" ]; then
    mkdir -p "$STANDALONE/node_modules/@prisma/engines"
    cp -r "node_modules/@prisma/engines" "$STANDALONE/node_modules/@prisma/" 2>/dev/null && echo " @prisma/engines copiado."
fi

# Copy Prisma
[ -d "node_modules/.prisma" ] && mkdir -p "$STANDALONE/node_modules/.prisma" && cp -r "node_modules/.prisma" "$STANDALONE/node_modules/"
[ -d "node_modules/@prisma" ] && mkdir -p "$STANDALONE/node_modules/@prisma" && cp -r "node_modules/@prisma" "$STANDALONE/node_modules/" && echo " @prisma copiado."
[ -d "node_modules/prisma" ] && mkdir -p "$STANDALONE/node_modules/prisma" && cp -r "node_modules/prisma" "$STANDALONE/node_modules/" && echo " prisma CLI copiado."
[ -d "node_modules/tsx" ] && mkdir -p "$STANDALONE/node_modules/tsx" && cp -r "node_modules/tsx" "$STANDALONE/node_modules/" && echo " tsx copiado."

# Write .env
echo "DATABASE_URL=file:$(cd "$STANDALONE" && pwd)/db/custom.db" > "$STANDALONE/.env"
echo " .env creado."

# Copy/create database
mkdir -p "$STANDALONE/db"
if [ -f "db/custom.db" ]; then
    cp -f "db/custom.db" "$STANDALONE/db/custom.db"
    echo " Base de datos copiada."
elif [ -f "prisma/data/custom.db" ]; then
    cp -f "prisma/data/custom.db" "$STANDALONE/db/custom.db"
    echo " Base de datos copiada (desde prisma/data)."
else
    echo " [AVISO] No se encontro db/custom.db. Se creara en el primer inicio."
fi

# Copy prisma schema and seed
mkdir -p "$STANDALONE/prisma"
[ -f "prisma/schema.prisma" ] && cp -f "prisma/schema.prisma" "$STANDALONE/prisma/" && echo " schema.prisma copiado."
[ -f "prisma/seed.ts" ] && cp -f "prisma/seed.ts" "$STANDALONE/prisma/" && echo " seed.ts copiado."

echo ""
echo "============================================================"
echo "  INSTALACION COMPLETADA (modo produccion standalone)"
echo "============================================================"
echo ""
echo "  Para iniciar DETOA:"
echo "    cd .next/standalone"
echo "    bash iniciar.sh"
echo ""
echo "  O simplemente ejecute:"
echo "    bash iniciar.sh"
echo ""
echo "  Credenciales por defecto:"
echo "    Usuario:    2026"
echo "    Contrasena: 2026"
echo ""
