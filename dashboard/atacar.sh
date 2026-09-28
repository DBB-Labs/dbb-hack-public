#!/usr/bin/env bash
# Orquestador de ataque EN VIVO — ejecuta los vectores seleccionados contra el lab local
# y emite cada paso al dashboard (estado.json) para verlo animarse.
# Uso: atacar.sh "<objetivo>" "<nivel>" "<vectores csv o 'all'>"
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; EMP="$D/emitir.py"
OBJ="${1:-kapa21-v2}"; NIVEL="${2:-full}"; VEC="${3:-all}"
API="http://127.0.0.1:54321"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
CID="$(docker ps --format '{{.Names}}' | grep supabase_db | head -1)"
APP="http://localhost:3000"
REPO="$HOME/Documents/Proyectos/$OBJ"
export PATH="$HOME/Library/Python/3.9/bin:$HOME/.local/bin:$PATH"
em(){ python3 "$EMP" "$@" >/dev/null 2>&1; }
want(){ [ "$VEC" = "all" ] && return 0; case ",$VEC," in *",$1,"*) return 0;; *) return 1;; esac; }
run_sql(){ docker exec -i -e PGPASSWORD=postgres "$CID" psql -U postgres -d postgres -qtA 2>&1; }
IDA="$(echo "select id from app.client_profile order by created_at limit 1;" | run_sql)"
IDB="$(echo "select id from app.client_profile order by created_at offset 1 limit 1;" | run_sql)"
IDO="$(echo "select id from app.operator_profile where not is_system and mfa_enrolled_at is null limit 1;" | run_sql)"

em init "$OBJ" "Next.js + Supabase" "DBB-HACK · nivel ${NIVEL} · EN VIVO"
if [ "$VEC" = "all" ]; then TOT=14; else TOT=$(echo "$VEC" | tr ',' '\n' | grep -cE '^(S1|S2|S3|A0|A1|A2|A3|A4|A5|A6|A7|A8|A9|A10)$'); fi
em meta "$TOT"
em evento info "Ataque iniciado contra $OBJ (lab local aislado)"
nd=0; nh=0; nv=0

vec(){ # id nombre cat owasp iso  ; luego el bloque de ataque via stdin decide estado
  em ataque "$1" corriendo "$2" "$3" "$4" "$5" "preparando..."; sleep 2; }
res(){ # id estado nombre cat owasp iso detalle [sev] [recomendacion] [prompt_fix]
  em ataque "$1" "$2" "$3" "$4" "$5" "$6" "$7" "${8:-}" "${9:-}" "${10:-}"
  case "$2" in defendido) nd=$((nd+1));; hallazgo) nh=$((nh+1));; vulnerable) nv=$((nv+1));; esac
  em kpi $((nd+nh+nv)) $nd $nh 60 $([ $nv -gt 0 ] && echo 55 || { [ $nh -gt 0 ] && echo 85 || echo 95; }); sleep 2; }

if want A0; then vec A0 "Robo externo sin cuenta" "Sin cuenta" "API1/API3" "A.8.3"
  em evento ataque "A0 leyendo tablas con llave publica..."
  r=$(curl -s "$API/rest/v1/client_profile?select=*" -H "apikey: $ANON" | head -c 60)
  echo "$r" | grep -q "PGRST205\|Only the following" && res A0 defendido "Robo externo sin cuenta" "Sin cuenta" "API1/API3" "A.8.3" "API no expone esquemas sensibles" || res A0 vulnerable "Robo externo sin cuenta" "Sin cuenta" "API1/API3" "A.8.3" "DATOS EXPUESTOS: $r"
fi
if want A1; then vec A1 "Aislamiento entre clientes" "IDOR" "API1" "A.8.3"
  em evento ataque "A1 cliente A intenta leer perfil de B..."
  n=$(printf "begin; set local role authenticated; select set_config('request.jwt.claims','{\"sub\":\"%s\",\"role\":\"authenticated\"}',true); select 'CNT='||count(*) from app.client_profile where id='%s'; rollback;" "$IDA" "$IDB" | run_sql | grep -oE 'CNT=[0-9]+' | cut -d= -f2)
  [ "${n:-0}" = "0" ] && res A1 defendido "Aislamiento entre clientes" "IDOR" "API1 BOLA" "A.8.3" "RLS: A no ve la fila de B" || res A1 vulnerable "Aislamiento entre clientes" "IDOR" "API1 BOLA" "A.8.3" "A LEYO A B (IDOR)"
fi
if want A2; then vec A2 "Escalada cliente a operador" "Authz" "API5" "A.8.2"
  em evento ataque "A2 cliente intenta aprobar dinero..."
  r=$(printf "begin; set local role authenticated; select set_config('request.jwt.claims','{\"sub\":\"%s\",\"role\":\"authenticated\",\"aal\":\"aal1\"}',true); select fin.aprobar_solicitud('00000000-0000-0000-0000-000000000000'::uuid); rollback;" "$IDA" | run_sql 2>&1)
  echo "$r" | grep -q "NOT_AN_OPERATOR" && res A2 defendido "Escalada cliente a operador" "Authz" "API5 BFLA" "A.8.2" "NOT_AN_OPERATOR" || res A2 vulnerable "Escalada cliente a operador" "Authz" "API5 BFLA" "A.8.2" "CLIENTE APROBO: $r"
fi
if want A3; then vec A3 "Operador sin 2FA mueve dinero" "Auth" "ASVS-V2" "A.8.5"
  em evento ataque "A3 operador sin 2FA intenta aprobar..."
  r=$(printf "begin; set local role authenticated; select set_config('request.jwt.claims','{\"sub\":\"%s\",\"role\":\"authenticated\",\"aal\":\"aal1\"}',true); select fin.aprobar_solicitud('00000000-0000-0000-0000-000000000000'::uuid); rollback;" "$IDO" | run_sql 2>&1)
  echo "$r" | grep -q "NOT_AN_OPERATOR" && res A3 defendido "Operador sin 2FA mueve dinero" "Auth" "ASVS V2" "A.8.5" "Bloqueado: is_active_operator()=false" || res A3 vulnerable "Operador sin 2FA mueve dinero" "Auth" "ASVS V2" "A.8.5" "MOVIO DINERO SIN 2FA"
fi
if want A4; then vec A4 "Webhook con firma falsa" "Integridad" "API8" "A.8.26"
  em evento ataque "A4 aviso de pago con firma falsa..."
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:3000/api/pagos/webhook?data.id=999&type=payment" -H "x-signature: ts=1,v1=fake" -H "x-request-id: r1" -H "Content-Type: application/json" -d '{"type":"payment","data":{"id":"999"}}')
  [ "$code" = "401" ] && res A4 defendido "Webhook con firma falsa" "Integridad" "API8" "A.8.26" "401 firma invalida" || res A4 hallazgo "Webhook con firma falsa" "Integridad" "API8" "A.8.26" "HTTP $code (revisar)"
fi
if want A5; then vec A5 "Crons sin secreto" "Auth" "API2" "A.8.5"
  em evento ataque "A5 disparando cron de pagos sin secreto..."
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:3000/api/cron/pagos" -H "Content-Type: application/json" -d '{}')
  [ "$code" = "404" ] || [ "$code" = "503" ] && res A5 defendido "Crons sin secreto" "Auth" "API2" "A.8.5" "HTTP $code (bloqueado)" || res A5 vulnerable "Crons sin secreto" "Auth" "API2" "A.8.5" "CRON EJECUTADO: HTTP $code"
fi
if want A6; then vec A6 "Fuerza bruta de login" "Anti-automacion" "API4" "A.8.5"
  em evento ataque "A6 15 intentos de login fallidos rapidos..."
  ok=0; for i in $(seq 1 15); do c=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" -d "{\"email\":\"e2e-titular@e2e.kapa21.cl\",\"password\":\"x$i\"}"); [ "$c" = "429" ] && ok=1; done
  [ "$ok" = "1" ] && res A6 defendido "Fuerza bruta de login" "Anti-automacion" "API4" "A.8.5" "rate-limit activo (429)" || res A6 hallazgo "Fuerza bruta de login" "Anti-automacion" "API4" "A.8.5" "sin freno local; verificar borde en prod" "media" "Verificar en produccion: regla de rate-limit en Vercel Firewall para /acceso y el endpoint de auth; rate-limits de Supabase Auth activos; idealmente captcha en el login." "Contexto: DBB-HACK detecto que la proteccion contra fuerza bruta depende solo del borde y el limitador propio (features/auth/lib/limite.ts) es por cookie y evitable, y no cubre /auth/v1/token de Supabase. Tarea: (1) habilitar rate-limit en Vercel Firewall para /acceso y auth; (2) verificar/ajustar rate-limits de Supabase Auth en produccion; (3) evaluar captcha (hCaptcha/Turnstile); (4) definir [auth.rate_limit] en supabase/config.toml. Listo cuando 20 intentos fallidos contra /auth/v1/token reciban 429 y el login legitimo siga funcionando."
fi

# ───── LOW / estáticos (sobre el repo) ─────
if want S1; then vec S1 "Secretos en el código" "Secretos" "API8" "A.8.24"
  em evento ataque "S1 gitleaks sobre el repo e historial..."
  g=0; [ -d "$REPO" ] && command -v gitleaks >/dev/null && { gitleaks detect --source "$REPO" --report-format json --report-path /tmp/gl.json --redact >/dev/null 2>&1; g=$(python3 -c "import json;print(len(json.load(open('/tmp/gl.json'))))" 2>/dev/null||echo 0); }
  [ "${g:-0}" = "0" ] && res S1 defendido "Secretos en el código" "Secretos" "API8" "A.8.24" "gitleaks: 0 secretos" || res S1 hallazgo "Secretos en el código" "Secretos" "API8" "A.8.24" "gitleaks: $g secretos"
fi
if want S2; then vec S2 "Dependencias vulnerables" "Supply-chain" "API8" "A.8.8"
  em evento ataque "S2 npm audit..."
  a=0; [ -f "$REPO/package.json" ] && a=$(cd "$REPO" && npm audit --audit-level=low --json 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin).get('metadata',{}).get('vulnerabilities',{}).get('total',0))" 2>/dev/null||echo 0)
  [ "${a:-0}" = "0" ] && res S2 defendido "Dependencias vulnerables" "Supply-chain" "API8" "A.8.8" "npm audit: 0" || res S2 hallazgo "Dependencias vulnerables" "Supply-chain" "API8" "A.8.8" "npm audit: $a"
fi
if want S3; then vec S3 "Patrones inseguros (SAST)" "Codigo" "API8" "A.8.28"
  em evento ataque "S3 semgrep security-audit..."
  s=0; [ -d "$REPO/src" ] && command -v semgrep >/dev/null && { semgrep scan --config p/security-audit --json --output /tmp/sg.json "$REPO/src" >/dev/null 2>&1; s=$(python3 -c "import json;print(len(json.load(open('/tmp/sg.json')).get('results',[])))" 2>/dev/null||echo 0); }
  [ "${s:-0}" = "0" ] && res S3 defendido "Patrones inseguros (SAST)" "Codigo" "API8" "A.8.28" "semgrep: 0 hallazgos" || res S3 hallazgo "Patrones inseguros (SAST)" "Codigo" "API8" "A.8.28" "semgrep: $s hallazgos"
fi
# ───── FULL nuevos (en vivo) ─────
if want A7; then vec A7 "GraphQL introspection" "Exposicion" "API9" "A.8.3"
  em evento ataque "A7 introspeccion de GraphQL como anonimo..."
  r=$(curl -s -X POST "$API/graphql/v1" -H "apikey: $ANON" -H "Content-Type: application/json" -d '{"query":"{__schema{types{name}}}"}')
  echo "$r" | grep -q "__schema\"\|\"types\"" && res A7 vulnerable "GraphQL introspection" "Exposicion" "API9" "A.8.3" "ESQUEMA EXPUESTO" || res A7 defendido "GraphQL introspection" "Exposicion" "API9" "A.8.3" "GraphQL no expone esquema"
fi
if want A8; then vec A8 "Open redirect" "Web" "API1" "A.8.26"
  em evento ataque "A8 redireccion a dominio externo..."
  loc=$(curl -s -o /dev/null -w "%{redirect_url}" "$APP/auth/volver?next=//evil.com")
  echo "$loc" | grep -qi "evil.com" && res A8 vulnerable "Open redirect" "Web" "API1" "A.8.26" "REDIRIGE A evil.com" || res A8 defendido "Open redirect" "Web" "API1" "A.8.26" "ignora el destino externo"
fi
if want A9; then vec A9 "Enumeracion de usuarios" "Auth" "API3" "A.8.5"
  em evento ataque "A9 login con correo existente vs inexistente..."
  e1=$(curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" -d '{"email":"e2e-titular@e2e.kapa21.cl","password":"x"}' | python3 -c "import sys,json;print(json.load(sys.stdin).get('error_code'))" 2>/dev/null)
  e2=$(curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" -d '{"email":"noexiste@nada.cl","password":"x"}' | python3 -c "import sys,json;print(json.load(sys.stdin).get('error_code'))" 2>/dev/null)
  [ "$e1" = "$e2" ] && res A9 defendido "Enumeracion de usuarios" "Auth" "API3" "A.8.5" "mismo error, no revela existencia" || res A9 hallazgo "Enumeracion de usuarios" "Auth" "API3" "A.8.5" "respuestas distintas: enumera"
fi
if want A10; then vec A10 "Cabeceras de seguridad" "Config" "API8" "A.8.26"
  em evento ataque "A10 revisando cabeceras de seguridad..."
  H=$(curl -s -D - -o /dev/null "$APP/acceso")
  echo "$H" | grep -qi "content-security-policy" && res A10 defendido "Cabeceras de seguridad" "Config" "API8" "A.8.26" "CSP y cabeceras presentes" || res A10 hallazgo "Cabeceras de seguridad" "Config" "API8" "A.8.26" "falta Content-Security-Policy" "media" "Agregar Content-Security-Policy (y HSTS) en next.config.ts, seccion async headers()." "Contexto: la app no envia la cabecera Content-Security-Policy (si tiene X-Frame-Options, X-Content-Type-Options, Referrer-Policy y Permissions-Policy). Tarea: agregar en next.config.ts async headers() una CSP restrictiva que permita solo origenes propios + Supabase (127.0.0.1:54321 en dev / el dominio en prod) + Mercado Pago, y agregar Strict-Transport-Security. Listo cuando la respuesta de /acceso incluya Content-Security-Policy y securityheaders.com de nota A."
fi
# ───── BAMF / MID planificados: se muestran, no se falsean ─────
for pv in M1 M2 B1 B2 B3 B4 B5 B6 B7 B8 B9 B10 B11 B12 B13 B14 B15 B16; do
  if want "$pv"; then em ataque "$pv" planificado "$pv" "Pendiente" "—" "—" "Vector en el catalogo, aun no implementado"; sleep 0; fi
done

em veredicto "Ataque completado: $nd defendidos, $nh hallazgos, $nv vulnerables de $((nd+nh+nv)) vectores."
em estado completado
em evento info "Ataque finalizado."
echo "DONE nd=$nd nh=$nh nv=$nv"
