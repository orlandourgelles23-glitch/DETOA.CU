#!/bin/bash
set -e
cd "$(dirname "$0")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check Node.js
if ! command -v node &>/dev/null; then
    echo ""
    echo -e " ${RED}[ERROR] Node.js no esta instalado.${NC}"
    echo " Ejecute install.sh primero para instalar las dependencias."
    echo ""
    exit 1
fi

# ============================================================
# Detect mode: standalone (production) or project root (dev)
# ============================================================

# If server.js exists here, we're in standalone mode
if [ -f "server.js" ]; then
    MODE="standalone"
# If .next/standalone/server.js exists, redirect there
elif [ -f ".next/standalone/server.js" ]; then
    echo ""
    echo " Redirigiendo al directorio de ejecucion standalone..."
    cd .next/standalone
    MODE="standalone"
# If we're in project root with no build, use dev mode
elif [ -d "node_modules/next" ]; then
    MODE="dev"
else
    echo ""
    echo -e " ${RED}[ERROR] No se encontro la instalacion de DETOA.${NC}"
    echo " Ejecute install.sh primero."
    echo ""
    exit 1
fi

# ============================================================
# STANDALONE MODE (production)
# ============================================================
if [ "$MODE" = "standalone" ]; then
    export NODE_ENV=production
    export PORT=3000
    export DETOA_AUTO_OPEN=1

    # Build ABSOLUTE DATABASE_URL
    mkdir -p db
    export DATABASE_URL="file:$(pwd)/db/custom.db"

    echo ""
    echo "============================================================"
    echo "  DETOA v2.10.0 - Iniciando sistema (produccion)"
    echo "============================================================"
    echo ""
    echo "  Servidor: http://localhost:$PORT"
    echo "  Base de datos: $DATABASE_URL"
    echo ""

    if [ -f "start.js" ]; then
        node start.js
    elif [ -f "server.js" ]; then
        node server.js
    else
        echo ""
        echo -e " ${RED}[ERROR] No se encontro server.js ni start.js.${NC}"
        echo " Ejecute install.sh para generar los archivos necesarios."
        echo ""
        exit 1
    fi

# ============================================================
# DEV MODE
# ============================================================
else
    export PORT=3000
    export NODE_ENV=development
    export DETOA_AUTO_OPEN=1

    # Build ABSOLUTE DATABASE_URL for dev mode
    mkdir -p db
    export DATABASE_URL="file:$(pwd)/db/custom.db"

    echo ""
    echo "============================================================"
    echo "  DETOA v2.10.0 - Iniciando sistema (desarrollo)"
    echo "============================================================"
    echo ""
    echo "  NOTA: Modo desarrollo (la compilacion produccion fallo o"
    echo "        no se ha ejecutado todavia)."
    echo "  Servidor: http://localhost:$PORT"
    echo "  Base de datos: $DATABASE_URL"
    echo ""

    npx next dev -p $PORT
fi
