#!/usr/bin/env python3
"""Actualiza estado.json del dashboard DBB Labs en vivo.

Uso:
  emitir.py init  <objetivo> <stack> <modo>
  emitir.py evento <tipo> "<texto>"                 # tipo: info|ataque|defendido|hallazgo|vulnerable
  emitir.py ataque <id> <estado> "<nombre>" "<categoria>" "<owasp>" "<iso>" "<detalle>"
  emitir.py kpi   <vectores> <defendidos> <hallazgos> <cobertura> <integridad>
  emitir.py estado <en_curso|completado>
"""
import json, sys, os, datetime
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), "estado.json")

def load():
    try:
        with open(P) as f: return json.load(f)
    except Exception:
        return {"marca":"DBB Labs","objetivo":"—","stack":"","modo":"","estado":"en_curso",
                "kpis":{"vectores":0,"defendidos":0,"hallazgos":0,"cobertura":0},
                "severidades":{"critica":0,"alta":0,"media":0,"baja":0},
                "integridad":100,"ataques":[],"eventos":[]}

def save(d):
    with open(P,"w") as f: json.dump(d,f,ensure_ascii=False,indent=2)

def hora(): return datetime.datetime.now().strftime("%H:%M:%S")

def main():
    a=sys.argv[1:]
    if not a: print(__doc__); return
    d=load(); cmd=a[0]
    if cmd=="init":
        d.update({"objetivo":a[1],"stack":a[2],"modo":a[3],"estado":"en_curso",
                  "inicio":datetime.datetime.now().isoformat(),
                  "kpis":{"vectores":0,"defendidos":0,"hallazgos":0,"cobertura":0},
                  "severidades":{"critica":0,"alta":0,"media":0,"baja":0},
                  "integridad":100,"ataques":[],"eventos":[]})
    elif cmd=="evento":
        d["eventos"].append({"hora":hora(),"tipo":a[1],"texto":a[2]})
    elif cmd=="ataque":
        aid,est,nombre,cat,owasp,iso,det=a[1],a[2],a[3],a[4],a[5],a[6],a[7]
        found=False
        for x in d["ataques"]:
            if x["id"]==aid:
                x.update({"estado":est,"nombre":nombre,"categoria":cat,"owasp":owasp,"iso":iso,"detalle":det}); found=True
        if not found:
            d["ataques"].append({"id":aid,"nombre":nombre,"categoria":cat,"owasp":owasp,"iso":iso,"estado":est,"detalle":det})
        d["eventos"].append({"hora":hora(),"tipo":est if est in("defendido","hallazgo","vulnerable") else "ataque","texto":f"{aid} {nombre}: {det}"})
    elif cmd=="kpi":
        d["kpis"]={"vectores":int(a[1]),"defendidos":int(a[2]),"hallazgos":int(a[3]),"cobertura":int(a[4])}
        d["integridad"]=int(a[5])
    elif cmd=="estado":
        d["estado"]=a[1]
    save(d)

if __name__=="__main__": main()
