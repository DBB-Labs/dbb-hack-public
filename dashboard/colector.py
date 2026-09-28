#!/usr/bin/env python3
"""Colector de telemetría REAL: muestrea `docker stats` y escribe metricas.json.
El dashboard lo lee cada segundo y grafica CPU/red reales de los contenedores del lab.
Uso: colector.py [patron]   (patron de nombres, por defecto 'supabase|kapa')
Corre en loop; Ctrl+C para parar.
"""
import json, os, re, subprocess, time, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "metricas.json")
PAT = re.compile(sys.argv[1] if len(sys.argv) > 1 else r"supabase|kapa")

def to_mib(s):  # "223.2MiB" / "7.748GiB" / "22.9MB"
    m = re.match(r"([\d.]+)\s*([KMGT]?i?B)", s.strip())
    if not m: return 0.0
    v, u = float(m.group(1)), m.group(2)
    f = {"B":1/1048576,"KB":1/1024,"KiB":1/1024,"MB":1,"MiB":1,"GB":1024,"GiB":1024,"TB":1048576,"TiB":1048576}
    return v * f.get(u, 1)

def sample():
    try:
        out = subprocess.check_output(
            ["docker","stats","--no-stream","--format",
             "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}"], text=True, timeout=15)
    except Exception:
        return []
    rows=[]
    for line in out.strip().splitlines():
        p=line.split("|")
        if len(p)<4 or not PAT.search(p[0]): continue
        cpu=float(p[1].replace("%","") or 0)
        mem=to_mib(p[2].split("/")[0])
        net=p[3].split("/")
        rx=to_mib(net[0]); tx=to_mib(net[1]) if len(net)>1 else 0
        rows.append({"name":p[0].replace("supabase_","").replace("_piaokcxprozozufvwqxq","").replace("_"," "),
                     "cpu":round(cpu,2),"mem":round(mem,1),"rx":rx,"tx":tx})
    return rows

def main():
    serie_net=[]; serie_cpu=[]; prev=None; prev_t=None
    while True:
        rows=sample(); t=time.time()
        tot_cpu=round(sum(r["cpu"] for r in rows),1)
        tot_mem=round(sum(r["mem"] for r in rows),0)
        tot_rx=sum(r["rx"] for r in rows); tot_tx=sum(r["tx"] for r in rows)
        rx_rate=tx_rate=0.0
        if prev is not None and prev_t is not None:
            dt=max(0.5,t-prev_t)
            rx_rate=max(0,(tot_rx-prev[0]))/dt*1024  # KB/s
            tx_rate=max(0,(tot_tx-prev[1]))/dt*1024
        prev=(tot_rx,tot_tx); prev_t=t
        serie_net.append(round(rx_rate+tx_rate,1)); serie_net=serie_net[-140:]
        serie_cpu.append(tot_cpu); serie_cpu=serie_cpu[-140:]
        data={"ts":int(t),"n":len(rows),
              "totales":{"cpu":tot_cpu,"mem_mib":tot_mem,"rx_rate_kbs":round(rx_rate,1),"tx_rate_kbs":round(tx_rate,1)},
              "containers":sorted(rows,key=lambda r:-r["cpu"]),
              "serie_net":serie_net,"serie_cpu":serie_cpu}
        try:
            with open(OUT,"w") as f: json.dump(data,f)
        except Exception: pass
        time.sleep(2)

if __name__=="__main__":
    main()
