#!/usr/bin/env bash
# primitivas.sh — las MANOS del pentester. Cada primitiva ejecuta UN ataque real contra
# el lab y devuelve en JSON lo que OBSERVÓ. No decide nada: el cerebro (Claude Code) lee
# la evidencia y elige la siguiente jugada. Así se encadena como un humano.
#
# Uso:  primitivas.sh <objetivo> <primitiva> [args...]
# Salida: una línea JSON  {"primitiva","estado","evidencia","datos":{...}}
#   estado ∈ defendido | hallazgo | vulnerable | no-probado
# REGLA DE ORO: si no se pudo ejecutar de verdad → estado "no-probado". Nunca se inventa.
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
OBJ="${1:?uso: primitivas.sh <objetivo> <primitiva> [args...]}"; PRIM="${2:?falta primitiva}"; shift 2 || true
API="http://127.0.0.1:54321"; APP="http://localhost:3000"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
SVC="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
REPO="$HOME/Documents/Proyectos/$OBJ"
export PATH="$HOME/Library/Python/3.9/bin:$HOME/.local/bin:$PATH"

PID="$(grep -E '^[[:space:]]*project_id' "$REPO/supabase/config.toml" 2>/dev/null | head -1 | sed -E 's/.*=[[:space:]]*"?([^"#]+)"?.*/\1/' | tr -d '[:space:]')"
CID="supabase_db_${PID}"
run_sql(){ docker exec -i -e PGPASSWORD=postgres "$CID" psql -U postgres -d postgres -qtA 2>&1; }
esUUID(){ echo "$1" | grep -qiE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; }

# emite el JSON de salida (evidencia y datos se pasan crudos; se escapan aquí)
out(){ # estado evidencia [datos-json]
  python3 - "$PRIM" "$1" "$2" "${3:-{\}}" <<'PY'
import json,sys
prim,estado,ev,datos=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]
try: d=json.loads(datos)
except Exception: d={"raw":datos}
print(json.dumps({"primitiva":prim,"estado":estado,"evidencia":ev,"datos":d},ensure_ascii=False))
PY
}

# ── ¿lab del objetivo vivo? ──
lab_vivo(){
  [ -n "$PID" ] && docker ps --format '{{.Names}}' | grep -qx "$CID" || return 1
  curl -s -o /dev/null --max-time 3 "$API/rest/v1/" 2>/dev/null && curl -s -o /dev/null --max-time 3 "$APP/acceso" 2>/dev/null
}

case "$PRIM" in

  # ── RECON del lab: base para todo el encadenamiento ──
  lab)
    if lab_vivo; then
      ca=$(echo "select id from app.client_profile order by created_at limit 1;" | run_sql | tail -1); esUUID "$ca" || ca=""
      cb=$(echo "select id from app.client_profile order by created_at offset 1 limit 1;" | run_sql | tail -1); esUUID "$cb" || cb=""
      op=$(echo "select id from app.operator_profile where not is_system and mfa_enrolled_at is null limit 1;" | run_sql | tail -1); esUUID "$op" || op=""
      out defendido "lab de $OBJ montado ($CID)" "{\"live\":true,\"cid\":\"$CID\",\"clienteA\":\"$ca\",\"clienteB\":\"$cb\",\"operadorSin2FA\":\"$op\"}"
    else
      out no-probado "lab de $OBJ NO montado — monta con montar-lab.sh o corre estático (S1/S2/S3)" "{\"live\":false,\"cid\":\"$CID\"}"
    fi;;

  # ── externos, sin cuenta ──
  robo-anon)
    r=$(curl -s "$API/rest/v1/client_profile?select=*" -H "apikey: $ANON" | head -c 120)
    if echo "$r" | grep -q "PGRST205\|Only the following"; then out defendido "API no expone esquemas sensibles" "{\"muestra\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$r")}"
    else out vulnerable "DATOS EXPUESTOS sin cuenta" "{\"muestra\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$r")}"; fi;;

  graphql-introspection)
    r=$(curl -s -X POST "$API/graphql/v1" -H "apikey: $ANON" -H "Content-Type: application/json" -d '{"query":"{__schema{types{name}}}"}')
    echo "$r" | grep -q '"__schema"\|"types"' && out vulnerable "GraphQL expone el esquema por introspección" "{}" || out defendido "GraphQL no expone esquema" "{}";;

  open-redirect)
    loc=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 5 "$APP/auth/volver?next=//evil.com")
    echo "$loc" | grep -qi "evil.com" && out vulnerable "redirige a dominio externo" "{\"location\":\"$loc\"}" || out defendido "ignora el destino externo" "{\"location\":\"$loc\"}";;

  headers)
    H=$(curl -s -D - -o /dev/null --max-time 5 "$APP/acceso")
    [ -z "$H" ] && { out no-probado "app no respondió — no se pudo probar" "{}"; exit 0; }
    echo "$H" | grep -qi "content-security-policy" && out defendido "CSP y cabeceras presentes" "{}" || out hallazgo "falta Content-Security-Policy" "{}";;

  # ── enumeración de usuarios (paso típico de ARRANQUE de una cadena) ──
  # args: <email-probe-que-existe>
  enum-usuarios)
    lab_vivo || { out no-probado "lab no montado" "{}"; exit 0; }
    probe="${1:-dbbhack-probe-$(date +%s)@dbb.local}"
    e1=$(curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" -d "{\"email\":\"$probe\",\"password\":\"malaX\"}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('error_code'))" 2>/dev/null)
    e2=$(curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" -d '{"email":"no-existe-jamas@dbb.local","password":"malaX"}' | python3 -c "import sys,json;print(json.load(sys.stdin).get('error_code'))" 2>/dev/null)
    if [ -z "$e1" ] || [ -z "$e2" ]; then out no-probado "no se pudo comparar respuestas — no probado" "{}"
    elif [ "$e1" = "$e2" ]; then out defendido "mismo error para existente e inexistente" "{\"enumerable\":false}"
    else out hallazgo "respuestas distintas: enumera usuarios" "{\"enumerable\":true,\"existente\":\"$e1\",\"inexistente\":\"$e2\"}"; fi;;

  # crear usuario efímero para pruebas (devuelve el email para encadenar)
  # args: <email> <password>
  crear-usuario)
    lab_vivo || { out no-probado "lab no montado" "{}"; exit 0; }
    em="${1:?email}"; pw="${2:?password}"
    r=$(curl -s -X POST "$API/auth/v1/admin/users" -H "apikey: $SVC" -H "Authorization: Bearer $SVC" -H "Content-Type: application/json" -d "{\"email\":\"$em\",\"password\":\"$pw\",\"email_confirm\":true}")
    id=$(echo "$r" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
    esUUID "$id" && out defendido "usuario de prueba creado" "{\"id\":\"$id\",\"email\":\"$em\"}" || out no-probado "no se pudo crear usuario de prueba" "{}";;

  # login real: devuelve el access_token para encadenar acciones autenticadas
  # args: <email> <password>
  login)
    em="${1:?email}"; pw="${2:?password}"
    r=$(curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" -d "{\"email\":\"$em\",\"password\":\"$pw\"}")
    tok=$(echo "$r" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
    if [ -n "$tok" ]; then out defendido "login correcto (token obtenido)" "{\"token\":\"$tok\"}"
    else ec=$(echo "$r" | python3 -c "import sys,json;print(json.load(sys.stdin).get('error_code',''))" 2>/dev/null); out defendido "login rechazado" "{\"token\":\"\",\"error\":\"$ec\"}"; fi;;

  # fuerza bruta contra un email dado (encadena tras enum-usuarios)
  # args: <email>
  fuerza-bruta)
    em="${1:?email}"; ok=0
    for i in $(seq 1 15); do c=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H "Content-Type: application/json" -d "{\"email\":\"$em\",\"password\":\"x$i\"}"); [ "$c" = "429" ] && ok=1; done
    [ "$ok" = "1" ] && out defendido "rate-limit activo (429)" "{}" || out hallazgo "sin freno local a 15 intentos; verificar borde en prod" "{}";;

  # ── autorización / RLS (encadenan con IDs del recon 'lab') ──
  # idor <idA> <idB> : ¿A puede leer la fila de B?
  idor)
    lab_vivo || { out no-probado "lab no montado" "{}"; exit 0; }
    a="${1:-}"; b="${2:-}"; { esUUID "$a" && esUUID "$b"; } || { out no-probado "faltan 2 cuentas — no probado" "{}"; exit 0; }
    n=$(printf "begin; set local role authenticated; select set_config('request.jwt.claims','{\"sub\":\"%s\",\"role\":\"authenticated\"}',true); select 'CNT='||count(*) from app.client_profile where id='%s'; rollback;" "$a" "$b" | run_sql | grep -oE 'CNT=[0-9]+' | cut -d= -f2)
    [ "${n:-0}" = "0" ] && out defendido "RLS: A no ve la fila de B" "{}" || out vulnerable "A LEYÓ a B (IDOR)" "{\"filas\":$n}";;

  # escalada <id-cliente> : ¿un cliente puede aprobar dinero?
  escalada)
    lab_vivo || { out no-probado "lab no montado" "{}"; exit 0; }
    id="${1:-}"; esUUID "$id" || { out no-probado "sin cuenta de cliente — no probado" "{}"; exit 0; }
    r=$(printf "begin; set local role authenticated; select set_config('request.jwt.claims','{\"sub\":\"%s\",\"role\":\"authenticated\",\"aal\":\"aal1\"}',true); select fin.aprobar_solicitud('00000000-0000-0000-0000-000000000000'::uuid); rollback;" "$id" | run_sql 2>&1)
    echo "$r" | grep -q "NOT_AN_OPERATOR" && out defendido "bloqueado: NOT_AN_OPERATOR" "{}" || out vulnerable "CLIENTE APROBÓ dinero" "{\"resp\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$r")}";;

  # operador-sin-2fa <id-operador>
  operador-sin-2fa)
    lab_vivo || { out no-probado "lab no montado" "{}"; exit 0; }
    id="${1:-}"; esUUID "$id" || { out no-probado "sin operador sin-factor — no probado" "{}"; exit 0; }
    r=$(printf "begin; set local role authenticated; select set_config('request.jwt.claims','{\"sub\":\"%s\",\"role\":\"authenticated\",\"aal\":\"aal1\"}',true); select fin.aprobar_solicitud('00000000-0000-0000-0000-000000000000'::uuid); rollback;" "$id" | run_sql 2>&1)
    echo "$r" | grep -q "NOT_AN_OPERATOR" && out defendido "bloqueado: is_active_operator()=false" "{}" || out vulnerable "MOVIÓ DINERO SIN 2FA" "{}";;

  webhook-falso)
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 -X POST "$APP/api/pagos/webhook?data.id=999&type=payment" -H "x-signature: ts=1,v1=fake" -H "x-request-id: r1" -H "Content-Type: application/json" -d '{"type":"payment","data":{"id":"999"}}')
    case "$code" in 000) out no-probado "app no respondió (HTTP 000)" "{}";; 401|403) out defendido "$code firma inválida" "{}";; *) out hallazgo "HTTP $code (revisar validación de firma)" "{\"code\":$code}";; esac;;

  cron-sin-secreto)
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 -X POST "$APP/api/cron/pagos" -H "Content-Type: application/json" -d '{}')
    case "$code" in 000) out no-probado "app no respondió (HTTP 000)" "{}";; 404|503|401) out defendido "HTTP $code (bloqueado)" "{}";; *) out vulnerable "CRON EJECUTADO: HTTP $code" "{\"code\":$code}";; esac;;

  # ── estáticos (reales para cualquier repo, sin lab) ──
  secretos)
    [ -d "$REPO" ] || { out no-probado "no existe el repo" "{}"; exit 0; }
    command -v gitleaks >/dev/null || { out no-probado "gitleaks no instalado" "{}"; exit 0; }
    gitleaks detect --source "$REPO" --report-format json --report-path /tmp/gl.json --redact >/dev/null 2>&1
    g=$(python3 -c "import json;print(len(json.load(open('/tmp/gl.json'))))" 2>/dev/null||echo 0)
    [ "${g:-0}" = "0" ] && out defendido "gitleaks: 0 secretos" "{\"n\":0}" || out hallazgo "gitleaks: $g secretos" "{\"n\":$g}";;
  deps)
    [ -f "$REPO/package.json" ] || { out no-probado "sin package.json" "{}"; exit 0; }
    a=$(cd "$REPO" && npm audit --audit-level=low --json 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin).get('metadata',{}).get('vulnerabilities',{}).get('total',0))" 2>/dev/null||echo 0)
    [ "${a:-0}" = "0" ] && out defendido "npm audit: 0" "{\"n\":0}" || out hallazgo "npm audit: $a" "{\"n\":$a}";;
  sast)
    [ -d "$REPO/src" ] || { out no-probado "sin carpeta src/" "{}"; exit 0; }
    command -v semgrep >/dev/null || { out no-probado "semgrep no instalado" "{}"; exit 0; }
    semgrep scan --config p/security-audit --json --output /tmp/sg.json "$REPO/src" >/dev/null 2>&1
    s=$(python3 -c "import json;print(len(json.load(open('/tmp/sg.json')).get('results',[])))" 2>/dev/null||echo 0)
    [ "${s:-0}" = "0" ] && out defendido "semgrep: 0 hallazgos" "{\"n\":0}" || out hallazgo "semgrep: $s hallazgos" "{\"n\":$s}";;

  # ── BAMF implementados (señal confiable contra Supabase+Next) ──

  # B4 mass-assignment: no basta el permiso de columna — RLS puede bloquear. Se PRUEBA la
  # escritura real: como cliente A, intentar tocar columnas sensibles en filas ajenas y
  # contar filas afectadas (todo dentro de rollback). Solo cuenta si de verdad afecta.
  # args: <id-cliente>
  b4-mass-assign)
    lab_vivo || { out no-probado "lab no montado" "{}"; exit 0; }
    ca="${1:-}"; esUUID "$ca" || { out no-probado "sin cuenta de cliente — no probado" "{}"; exit 0; }
    # candidatos: (tabla,columna) sensibles con permiso de UPDATE para authenticated
    cands=$(echo "select table_name||'|'||column_name from information_schema.role_column_grants where grantee='authenticated' and privilege_type='UPDATE' and table_schema='app' and (column_name ~* 'role|is_system|is_admin|balance|saldo|amount|monto|estado|status|verified|verificad|mfa|permis|approv|aprob');" | run_sql | grep '|')
    [ -z "$cands" ] && { out defendido "authenticated no tiene permiso sobre columnas sensibles en app.*" "{}"; exit 0; }
    escritas=""
    while IFS='|' read -r t c; do
      [ -z "$t" ] && continue
      owner=$(echo "select column_name from information_schema.columns where table_schema='app' and table_name='$t' and column_name ~* 'client_id|user_id|owner|profile_id' limit 1;" | run_sql | tail -1)
      [ -z "$owner" ] && continue
      n=$(printf "begin; set local role authenticated; select set_config('request.jwt.claims','{\"sub\":\"%s\",\"role\":\"authenticated\",\"aal\":\"aal1\"}',true); with u as (update app.%s set %s=%s where %s <> '%s' returning 1) select 'N='||count(*) from u; rollback;" "$ca" "$t" "$c" "$c" "$owner" "$ca" | run_sql 2>/dev/null | grep -oE 'N=[0-9]+' | cut -d= -f2)
      [ "${n:-0}" != "0" ] && escritas="$escritas app.$t.$c($n)"
    done <<< "$cands"
    if [ -z "$escritas" ]; then out defendido "RLS bloquea la escritura de columnas sensibles en filas ajenas" "{}"
    else out vulnerable "cliente ESCRIBIÓ columnas sensibles en filas ajenas (mass-assignment)" "{\"escrituras\":\"$escritas\"}"; fi;;

  # B5 IDOR profundo / RLS en todos los recursos: ¿alguna tabla de app.* sin RLS?
  b5-idor-profundo)
    lab_vivo || { out no-probado "lab no montado" "{}"; exit 0; }
    sinrls=$(echo "select coalesce(string_agg(relname,', '),'') from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='app' and c.relkind='r' and not c.relrowsecurity;" | run_sql | tail -1)
    ntot=$(echo "select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='app' and c.relkind='r';" | run_sql | tail -1)
    if [ -z "$sinrls" ]; then out defendido "RLS activa en las $ntot tablas de app.*" "{\"tablas\":$ntot}"
    else out vulnerable "tablas de app.* SIN RLS (lectura cruzada posible)" "{\"sin_rls\":\"$sinrls\"}"; fi;;

  # B6 inyección SQL: PostgREST parametriza; probar que una comilla no rompe la consulta
  b6-sqli)
    r=$(curl -s "$API/rest/v1/client_profile?select=*&id=eq.x%27or%271%27=%271" -H "apikey: $ANON" | head -c 200)
    if echo "$r" | grep -qE '22P02|invalid input syntax|PGRST|Only the following|\[\]'; then out defendido "entrada maliciosa rechazada/parametrizada (API de datos)" "{}"
    else out hallazgo "revisar: la API devolvió datos ante entrada con comillas" "{\"muestra\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$r")}"; fi;;

  # B12 gestión de sesión: ¿un JWT falso es rechazado por la API?
  b12-sesion)
    code=$(curl -s -o /dev/null -w "%{http_code}" "$API/rest/v1/client_profile?select=id" -H "apikey: $ANON" -H "Authorization: Bearer falso.token.invalido")
    case "$code" in 401|403) out defendido "JWT inválido rechazado (HTTP $code)" "{\"code\":$code}";; 000) out no-probado "API no respondió — no probado" "{}";; *) out hallazgo "JWT inválido no fue rechazado limpio (HTTP $code)" "{\"code\":$code}";; esac;;

  # B1 carrera de doble-pago: el ledger tiene UNIQUE(idempotency_key). Se ATACA posteando
  # dos veces la misma clave; la 2a debe rebotar. Todo en rollback (no mueve plata).
  b1-doble-pago)
    lab_vivo || { out no-probado "lab no montado" "{}"; exit 0; }
    K="dbbhack-dup-$(date +%s%N)"
    r=$(printf "begin; insert into fin.ledger_transaction(kind,idempotency_key,reason) values ('adjustment','%s','prueba idempotencia dbbhack uno'); insert into fin.ledger_transaction(kind,idempotency_key,reason) values ('adjustment','%s','prueba idempotencia dbbhack dos'); rollback;" "$K" "$K" | run_sql 2>&1)
    if echo "$r" | grep -qi 'duplicate key\|unique constraint'; then out defendido "idempotencia bloquea el doble-posteo (UNIQUE idempotency_key)" "{}"
    elif echo "$r" | grep -qi 'ERROR'; then out no-probado "no se pudo aislar la prueba (otra guarda intervino)" "{\"detalle\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1][:200]))' "$r")}"
    else out vulnerable "se posteó dos veces la misma transacción (doble-pago)" "{}"; fi;;

  # B2 penny-drop / montos negativos: cliente intenta crear un retiro con monto negativo.
  # args: <id-cliente>
  b2-monto-negativo)
    lab_vivo || { out no-probado "lab no montado" "{}"; exit 0; }
    ca="${1:-}"; esUUID "$ca" || { out no-probado "sin cuenta de cliente — no probado" "{}"; exit 0; }
    r=$(printf "begin; set local role authenticated; select set_config('request.jwt.claims','{\"sub\":\"%s\",\"role\":\"authenticated\",\"aal\":\"aal1\"}',true); select fin.crear_solicitud('withdraw_clp','persona','%s'::uuid,-100000,'banco',NULL); rollback;" "$ca" "$ca" | run_sql 2>&1)
    err=$(echo "$r" | grep -i 'ERROR' | head -1)
    if [ -n "$err" ]; then out defendido "retiro con monto negativo rechazado" "{\"evidencia\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1][:160]))' "$err")}"
    else out vulnerable "se creó un retiro con monto NEGATIVO" "{\"resp\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1][:160]))' "$r")}"; fi;;

  # B3 overdraw concurrente: la guarda es CHECK(balance>=0) + FOR UPDATE. Se ATACA forzando
  # saldo negativo en una cuenta real; si no hay cuentas con saldo sembradas → no probado.
  b3-overdraw)
    lab_vivo || { out no-probado "lab no montado" "{}"; exit 0; }
    n=$(echo "select count(*) from fin.account where owner_kind<>'sistema';" | run_sql | tail -1)
    if [ "${n:-0}" = "0" ]; then out no-probado "sin cuentas con saldo sembradas; la guarda CHECK(account_no_negativo)+FOR UPDATE existe pero no se ejecutó contra saldo real" "{}"; exit 0; fi
    r=$(printf "begin; update fin.account set balance_total_minor=-1 where owner_kind<>'sistema'; rollback;" | run_sql 2>&1)
    echo "$r" | grep -qi 'no_negativo\|violates check' && out defendido "sobregiro bloqueado por CHECK de saldo no-negativo" "{\"cuentas\":$n}" || out vulnerable "se pudo dejar una cuenta en saldo NEGATIVO" "{\"cuentas\":$n}";;

  # B10 XSS: en React el riesgo real es dangerouslySetInnerHTML con __html de input de
  # usuario. Se cuentan los sinks JSX reales; si hay, se marca para revisión (no vulnerable
  # a ciegas). El cerebro revisa si el __html es constante (seguro) o viene de input.
  b10-xss)
    [ -d "$REPO/src" ] || { out no-probado "sin carpeta src/" "{}"; exit 0; }
    n=$(grep -rn "dangerouslySetInnerHTML={{" "$REPO/src" 2>/dev/null | grep -vc "__tests__")
    if [ "${n:-0}" = "0" ]; then out defendido "sin sinks de HTML crudo (React escapa por defecto)" "{\"sinks\":0}"
    else out hallazgo "$n sinks de HTML crudo — revisar que __html no venga de input de usuario" "{\"sinks\":$n}"; fi;;

  # B11 CSRF en Server Actions: Next 14+ valida same-origin por defecto. Se debilita solo si
  # serverActions.allowedOrigins trae comodines. Se revisa versión + config.
  b11-csrf)
    [ -f "$REPO/package.json" ] || { out no-probado "sin package.json" "{}"; exit 0; }
    maj=$(grep -E '"next":' "$REPO/package.json" | sed -E 's/[^0-9]*([0-9]+).*/\1/')
    wild=$(grep -rn "allowedOrigins" "$REPO"/next.config* 2>/dev/null | grep -E '\*|0\.0\.0\.0' )
    if [ -n "$wild" ]; then out hallazgo "allowedOrigins con comodín debilita la protección CSRF" "{\"config\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1][:160]))' "$wild")}"
    elif [ -n "$maj" ] && [ "$maj" -ge 14 ]; then out defendido "Next $maj: Server Actions same-origin por defecto, sin orígenes permitidos extra" "{\"next\":$maj}"
    else out no-probado "no se pudo confirmar la versión de Next (>=14)" "{}"; fi;;

  *) out no-probado "primitiva desconocida: $PRIM" "{}"; exit 2;;
esac
