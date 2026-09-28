#!/usr/bin/env python3
"""conocimiento.py — la MEMORIA de la corrida. Lo que el pentester va aprendiendo se guarda
aquí para que la siguiente jugada use lo de la anterior (encadenamiento). No decide nada:
solo recuerda hechos observados.

Uso:
  conocimiento.py reset                      # empieza una corrida limpia
  conocimiento.py set <clave> <valor>        # recuerda un hecho (token, id, email...)
  conocimiento.py get <clave>                # imprime el valor (vacío si no está)
  conocimiento.py add <clave-lista> <valor>  # agrega a una lista (cadenas, hallazgos)
  conocimiento.py dump                        # imprime todo en JSON
"""
import json, sys, os
F = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conocimiento.json")

def load():
    try:
        with open(F) as fh: return json.load(fh)
    except Exception:
        return {}

def save(d):
    with open(F, "w") as fh: json.dump(d, fh, ensure_ascii=False, indent=2)

def main(a):
    if not a: print("uso: reset|set|get|add|dump", file=sys.stderr); return 2
    cmd = a[0]
    if cmd == "reset":
        save({}); return 0
    if cmd == "dump":
        print(json.dumps(load(), ensure_ascii=False, indent=2)); return 0
    if cmd == "get":
        print(load().get(a[1], "") if len(a) > 1 else ""); return 0
    if cmd == "set" and len(a) >= 3:
        d = load(); d[a[1]] = a[2]; save(d); return 0
    if cmd == "add" and len(a) >= 3:
        d = load(); d.setdefault(a[1], []); d[a[1]].append(a[2]); save(d); return 0
    print("comando inválido", file=sys.stderr); return 2

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
