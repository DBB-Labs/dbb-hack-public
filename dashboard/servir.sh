#!/usr/bin/env bash
# Sirve el centro de comando DBB Labs + arranca el colector de métricas reales de Docker.
PORT="${1:-8899}"; cd "$(dirname "$0")"
pgrep -f "colector.py" >/dev/null || ( nohup python3 colector.py >/tmp/dbb-colector.log 2>&1 & echo "colector de Docker iniciado" )
echo "DBB Labs → http://localhost:$PORT"
( sleep 1; open "http://localhost:$PORT" ) &
python3 -m http.server "$PORT"
