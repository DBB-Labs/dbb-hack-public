#!/usr/bin/env bash
PORT="${1:-8899}"; cd "$(dirname "$0")"
pgrep -f "colector.py" >/dev/null || ( nohup python3 colector.py >/tmp/dbb-colector.log 2>&1 & echo "colector iniciado" )
echo "DBB Labs → http://localhost:$PORT"
( sleep 1; open "http://localhost:$PORT" ) &
python3 servidor.py "$PORT"
