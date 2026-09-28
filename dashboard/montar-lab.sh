#!/usr/bin/env bash
# Auto-montador de laboratorio para un proyecto Supabase+Next.
# Levanta el Supabase local del proyecto + su app (next dev) contra ese Supabase.
# Uso: montar-lab.sh <proyecto>
# NO siembra cuentas específicas (eso es por-proyecto): habilita los vectores externos.
set -uo pipefail
OBJ="${1:?uso: montar-lab.sh <proyecto>}"
REPO="$HOME/Documents/Proyectos/$OBJ"
export PATH="$HOME/Library/Python/3.9/bin:$HOME/.local/bin:$PATH"
D="$(cd "$(dirname "$0")" && pwd)"; em(){ python3 "$D/emitir.py" evento "$@" >/dev/null 2>&1; }

[ -d "$REPO" ] || { echo "NO_REPO"; em info "No existe el repo $OBJ"; exit 1; }
[ -f "$REPO/supabase/config.toml" ] || { echo "NO_SUPABASE"; em info "$OBJ no tiene stack Supabase — solo LOW/MID (estático)."; exit 2; }
PID="$(grep -E '^[[:space:]]*project_id' "$REPO/supabase/config.toml" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
echo "PID=$PID"

# 1) Supabase del proyecto
if docker ps --format '{{.Names}}' | grep -qx "supabase_db_${PID}"; then
  echo "SUPA_OK"; em info "Supabase de $OBJ ya está arriba"
else
  em info "Montando Supabase de $OBJ (detengo otros labs y levanto este)..."
  supabase stop >/dev/null 2>&1 || true          # libera los puertos compartidos
  ( cd "$REPO" && supabase start ) || { echo "SUPA_FAIL"; em info "supabase start falló en $OBJ"; exit 3; }
  em info "Supabase de $OBJ levantado; aplicando migraciones..."
  ( cd "$REPO" && yes | supabase db reset >/dev/null 2>&1 ) || true
fi

# 2) Claves locales del proyecto
ST="$(cd "$REPO" && supabase status -o json 2>/dev/null)"
val(){ echo "$ST" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('$1','') or '')" 2>/dev/null; }
URL="$(val API_URL)"; [ -z "$URL" ] && URL="http://127.0.0.1:54321"
ANON="$(val ANON_KEY)"; [ -z "$ANON" ] && ANON="$(val PUBLISHABLE_KEY)"
SVC="$(val SERVICE_ROLE_KEY)"; [ -z "$SVC" ] && SVC="$(val SECRET_KEY)"
DBURL="$(val DB_URL)"

# 3) App (next dev) contra el supabase local
if curl -s -o /dev/null --max-time 3 http://localhost:3000/ 2>/dev/null; then
  echo "APP_OK"; em info "App de $OBJ ya responde en :3000"
elif [ -f "$REPO/package.json" ]; then
  em info "Arrancando la app de $OBJ (next dev) contra el supabase local..."
  ( cd "$REPO" && \
    NEXT_PUBLIC_SUPABASE_URL="$URL" SUPABASE_URL="$URL" \
    NEXT_PUBLIC_SUPABASE_ANON_KEY="$ANON" NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY="$ANON" SUPABASE_PUBLISHABLE_KEY="$ANON" \
    SUPABASE_SECRET_KEY="$SVC" DATABASE_URL="$DBURL" \
    MERCADOPAGO_WEBHOOK_SECRET="lab-webhook-$PID" CRON_SECRET="lab-cron-$PID" \
    nohup npx next dev >/tmp/lab-app-$OBJ.log 2>&1 & )
  for i in $(seq 1 40); do curl -s -o /dev/null --max-time 2 http://localhost:3000/ 2>/dev/null && { echo "APP_UP"; break; }; sleep 3; done
  curl -s -o /dev/null --max-time 2 http://localhost:3000/ 2>/dev/null || { echo "APP_TIMEOUT"; em info "La app de $OBJ no respondió a tiempo (ver /tmp/lab-app-$OBJ.log)"; }
else
  echo "NO_APP"; em info "$OBJ no tiene app Next (sin package.json)"
fi
em info "Laboratorio de $OBJ listo. Studio: $(val STUDIO_URL)"
echo "LAB_READY $OBJ $URL"
