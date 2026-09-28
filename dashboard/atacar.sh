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
em(){ python3 "$EMP" "$@" >/dev/null 2>&1; }
want(){ [ "$VEC" = "all" ] && return 0; case ",$VEC," in *",$1,"*) return 0;; *) return 1;; esac; }
run_sql(){ docker exec -i -e PGPASSWORD=postgres "$CID" psql -U postgres -d postgres -qtA 2>&1; }
IDA="$(echo "select id from app.client_profile order by created_at limit 1;" | run_sql)"
IDB="$(echo "select id from app.client_profile order by created_at offset 1 limit 1;" | run_sql)"
IDO="$(echo "select id from app.operator_profile where not is_system and mfa_enrolled_at is null limit 1;" | run_sql)"

em init "$OBJ" "Next.js + Supabase" "DBB-HACK · nivel ${NIVEL} · EN VIVO"
em evento info "Ataque iniciado contra $OBJ (lab local aislado)"
nd=0; nh=0; nv=0

vec(){ # id nombre cat owasp iso  ; luego el bloque de ataque via stdin decide estado
  em ataque "$1" corriendo "$2" "$3" "$4" "$5" "preparando..."; sleep 2; }
res(){ # id estado nombre cat owasp iso detalle
  em ataque "$1" "$2" "$3" "$4" "$5" "$6" "$7"
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
  [ "$ok" = "1" ] && res A6 defendido "Fuerza bruta de login" "Anti-automacion" "API4" "A.8.5" "rate-limit activo (429)" || res A6 hallazgo "Fuerza bruta de login" "Anti-automacion" "API4" "A.8.5" "sin freno local; verificar borde en prod"
fi

em veredicto "Ataque completado: $nd defendidos, $nh hallazgos, $nv vulnerables de $((nd+nh+nv)) vectores."
em estado completado
em evento info "Ataque finalizado."
echo "DONE nd=$nd nh=$nh nv=$nv"
