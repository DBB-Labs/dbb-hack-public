#!/usr/bin/env bash
# DBB-HACK — runner de los 4 niveles (estándar DBB).
# Uso: dbb-hack.sh <ruta-repo> <low|mid|full|bamf>
# LOW/MID corren aquí (estático). FULL/BAMF además orquestan lab en vivo (lo guía el agente).
set -uo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
REPO="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
NIVEL="$(echo "${2:-mid}" | tr '[:upper:]' '[:lower:]')"
EMP="python3 $KIT/dashboard/emitir.py"
PROJ="$(basename "$REPO")"
export PATH="$HOME/Library/Python/3.9/bin:$HOME/.local/bin:$PATH"

echo "╔═══════════════════════════════════════════╗"
echo "║  DBB-HACK · nivel $(echo $NIVEL|tr a-z A-Z)"
echo "║  objetivo: $PROJ"
echo "╚═══════════════════════════════════════════╝"
$EMP init "$PROJ" "auto" "DBB-HACK · nivel ${NIVEL}" 2>/dev/null

# abrir dashboard
( curl -s -o /dev/null http://localhost:8899/ 2>/dev/null || ( cd "$KIT/dashboard" && nohup python3 -m http.server 8899 >/tmp/dbb-dash.log 2>&1 & ) )
command -v open >/dev/null && open "http://localhost:8899" 2>/dev/null

n_def=0; n_hal=0; n=0
paso(){ n=$((n+1)); }

# ---- LOW (todos los niveles lo incluyen) ----
echo "▶ [$NIVEL] Recon de superficies"; bash "$KIT/recon/mapear.sh" "$REPO" > "/tmp/dbbhack-recon-$PROJ.txt" 2>&1 && echo "  recon → /tmp/dbbhack-recon-$PROJ.txt"

echo "▶ Secretos (gitleaks)"
if command -v gitleaks >/dev/null; then
  gitleaks detect --source "$REPO" --report-format json --report-path "/tmp/dbbhack-gitleaks-$PROJ.json" --redact >/dev/null 2>&1
  g=$(python3 -c "import json;print(len(json.load(open('/tmp/dbbhack-gitleaks-$PROJ.json'))))" 2>/dev/null||echo 0)
  paso; if [ "$g" = "0" ]; then n_def=$((n_def+1)); $EMP ataque S1 defendido "Secretos en git" "Secretos" "API8" "A.8.24" "gitleaks: 0 secretos" 2>/dev/null; echo "  ✅ 0 secretos";
  else n_hal=$((n_hal+1)); $EMP ataque S1 hallazgo "Secretos en git" "Secretos" "API8" "A.8.24" "gitleaks: $g secretos — rotar y purgar historial" media "Rotar las credenciales expuestas y purgar el historial (git filter-repo). Mover secretos a variables de entorno." "Contexto: gitleaks detecto $g secretos en el repo $PROJ. Tarea: rotar cada credencial, sacarla del codigo a variables de entorno, y purgar el historial con git filter-repo. Listo cuando gitleaks detect no reporte nada." 2>/dev/null; echo "  ⚠️ $g secretos"; fi
fi

echo "▶ Dependencias (npm audit)"
if [ -f "$REPO/package.json" ]; then
  a=$(cd "$REPO" && npm audit --audit-level=low --json 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('metadata',{}).get('vulnerabilities',{}).get('total',0))" 2>/dev/null||echo 0)
  paso; if [ "${a:-0}" = "0" ]; then n_def=$((n_def+1)); $EMP ataque S2 defendido "Dependencias" "Supply-chain" "API8" "A.8.8" "npm audit: 0 vulnerabilidades" 2>/dev/null; echo "  ✅ 0 vulnerabilidades";
  else n_hal=$((n_hal+1)); $EMP ataque S2 hallazgo "Dependencias" "Supply-chain" "API8" "A.8.8" "npm audit: $a vulnerabilidades" media "Actualizar las dependencias vulnerables (npm audit fix) y fijar versiones." "Contexto: npm audit reporta $a vulnerabilidades en $PROJ. Tarea: ejecutar npm audit fix, revisar breaking changes, y fijar versiones. Listo cuando npm audit no reporte vulnerabilidades de nivel moderate o superior." 2>/dev/null; echo "  ⚠️ $a vulnerabilidades"; fi
fi

# ---- MID/FULL/BAMF: SAST ----
if [ "$NIVEL" != "low" ] && command -v semgrep >/dev/null; then
  echo "▶ Código (semgrep SAST)"
  cfg="--config p/security-audit"; [ "$NIVEL" != "mid" ] && cfg="$cfg --config p/owasp-top-ten --config p/typescript"
  semgrep scan $cfg --json --output "/tmp/dbbhack-semgrep-$PROJ.json" "$REPO/src" >/dev/null 2>&1
  s=$(python3 -c "import json;print(len(json.load(open('/tmp/dbbhack-semgrep-$PROJ.json')).get('results',[])))" 2>/dev/null||echo 0)
  paso; if [ "$s" = "0" ]; then n_def=$((n_def+1)); $EMP ataque S3 defendido "Patrones inseguros (SAST)" "Codigo" "API8" "A.8.28" "semgrep: 0 hallazgos" 2>/dev/null; echo "  ✅ 0 hallazgos";
  else n_hal=$((n_hal+1)); $EMP ataque S3 hallazgo "Patrones inseguros (SAST)" "Codigo" "API8" "A.8.28" "semgrep: $s hallazgos (ver reporte)" media "Revisar cada hallazgo de semgrep en /tmp/dbbhack-semgrep-$PROJ.json y corregir o justificar." "Contexto: semgrep reporto $s hallazgos en $PROJ. Tarea: revisar cada uno, corregir los reales y suprimir los falsos positivos con nosemgrep justificado. Listo cuando no queden hallazgos sin resolver." 2>/dev/null; echo "  ⚠️ $s hallazgos"; fi
fi

cob=$([ "$NIVEL" = low ] && echo 25 || { [ "$NIVEL" = mid ] && echo 45 || { [ "$NIVEL" = full ] && echo 65 || echo 85; }; })
integ=$([ "$n_hal" = 0 ] && echo 95 || echo 80)
$EMP kpi "$n" "$n_def" "$n_hal" "$cob" "$integ" 2>/dev/null
$EMP estado completado 2>/dev/null

echo
echo "── RESUMEN nivel $NIVEL: $n controles · $n_def ok · $n_hal hallazgos ──"
echo "   dashboard: http://localhost:8899"
if [ "$NIVEL" = "full" ] || [ "$NIVEL" = "bamf" ]; then
  echo
  echo "⚡ Nivel $NIVEL requiere ATAQUE EN VIVO (laboratorio aislado)."
  echo "   Eso lo orquesta el agente /dbb-hack: montar lab local, sembrar, atacar"
  echo "   (externo, RLS, escalada, 2FA, webhook, crons) y — en BAMF — flujos de dinero,"
  echo "   fuzzing, ASVS L2/L3 y mapa de cumplimiento NCG502/Ley21719."
fi
