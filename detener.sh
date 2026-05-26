#!/bin/bash
cd "$(dirname "$0")"

echo ""
echo "============================================================"
echo "  DETOA v2.10.0 - Deteniendo servidor"
echo "============================================================"
echo ""

echo " Buscando procesos en puerto 3000..."
PID=$(lsof -ti:3000 2>/dev/null || true)

if [ -n "$PID" ]; then
    echo " Deteniendo proceso PID $PID..."
    kill $PID 2>/dev/null || true
    sleep 2
    # Force kill if still running
    if kill -0 $PID 2>/dev/null; then
        echo " Forzando detencion..."
        kill -9 $PID 2>/dev/null || true
    fi
    echo " Servidor detenido."
else
    echo " No se encontro ningun proceso en el puerto 3000."
fi
echo ""
