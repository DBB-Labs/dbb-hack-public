#!/usr/bin/env bash
# Sirve el dashboard DBB Labs en localhost y lo abre en el navegador.
PORT="${1:-8899}"
cd "$(dirname "$0")"
echo "DBB Labs dashboard → http://localhost:$PORT"
( sleep 1; open "http://localhost:$PORT" ) &
python3 -m http.server "$PORT"
