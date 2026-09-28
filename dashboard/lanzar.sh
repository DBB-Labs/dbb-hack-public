#!/usr/bin/env bash
# Orquesta: monta el lab (si el nivel es en vivo) y luego ataca. Lo llama el servidor.
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
OBJ="${1:-kapa21-v2}"; NIVEL="${2:-full}"; VEC="${3:-all}"
if [ "$NIVEL" = "full" ] || [ "$NIVEL" = "bamf" ]; then
  python3 "$D/emitir.py" init "$OBJ" "Next.js + Supabase" "DBB-HACK · montando laboratorio..." >/dev/null 2>&1
  python3 "$D/emitir.py" evento info "Preparando laboratorio de $OBJ (la primera vez baja imágenes; puede tardar)..." >/dev/null 2>&1
  bash "$D/montar-lab.sh" "$OBJ" >>/tmp/dbb-montar.log 2>&1 || true
fi
bash "$D/atacar.sh" "$OBJ" "$NIVEL" "$VEC"
