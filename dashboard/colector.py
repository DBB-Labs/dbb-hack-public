#!/usr/bin/env python3
"""Colector de telemetría REAL del lab: docker stats + docker logs -> metricas.json + logs.json.
El centro de comando los lee cada segundo. Uso: colector.py [patron]. Loop; Ctrl+C para parar.
"""
import json, os, re, subprocess, time, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MET = os.path.join(HERE, "metricas.json")
LOG = os.path.join(HERE, "logs.json")
PAT = re.compile(sys.argv[1] if len(sys.argv) > 1 else r"supabase|kapa")
LOG_CONTS = ["supabase_db","supabase_rest","supabase_kong","supabase_auth","supabase_realtime"]

def to_mib(s):
    m = re.match(r"([\d.]+)\s*([KMGT]?i?B)", s.strip())
    if not m: return 0.0
    v,u=float(m.group(1)),m.group(2)
    f={"B":1/1048576,"KB":1/1024,"KiB":1/1024,"MB":1,"MiB":1,"GB":1024,"GiB":1024,"TB":1048576,"TiB":1048576}
    return v*f.get(u,1)

def short(n): return n.replace("supabase_","").replace("_piaokcxprozozufvwqxq","").replace("_"," ")

def stats():
    try:
        out=subprocess.check_output(["docker","stats","--no-stream","--format",
            "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.BlockIO}}|{{.NetIO}}|{{.PIDs}}"],text=True,timeout=15)
    except Exception: return []
    rows=[]
    for line in out.strip().splitlines():
        p=line.split("|")
        if len(p)<7 or not PAT.search(p[0]): continue
        blk=p[4].split("/"); net=p[5].split("/")
        rows.append({"name":short(p[0]),
            "cpu":float(p[1].replace("%","") or 0),
            "mem":round(to_mib(p[2].split("/")[0]),1),
            "mem_pct":float(p[3].replace("%","") or 0),
            "disk_r":round(to_mib(blk[0]),1),"disk_w":round(to_mib(blk[1]) if len(blk)>1 else 0,1),
            "rx":to_mib(net[0]),"tx":to_mib(net[1]) if len(net)>1 else 0,
            "pids":int(p[6] or 0)})
    return rows

def full_name(short_c):
    try:
        out=subprocess.check_output(["docker","ps","--format","{{.Names}}"],text=True,timeout=5)
        for n in out.split():
            if n.startswith(short_c): return n
    except Exception: pass
    return None

def logs():
    lines=[]
    for c in LOG_CONTS:
        fn=full_name(c)
        if not fn: continue
        try:
            out=subprocess.check_output(["docker","logs","--tail","6","--timestamps",fn],
                text=True,stderr=subprocess.STDOUT,timeout=6)
        except Exception: continue
        for ln in out.strip().splitlines()[-6:]:
            m=re.match(r"(\S+)\s+(.*)",ln)
            ts=m.group(1)[11:19] if m else ""
            msg=(m.group(2) if m else ln)[:160]
            sev="err" if re.search(r"error|fatal|exception",msg,re.I) else ("warn" if re.search(r"warn",msg,re.I) else "info")
            lines.append({"hora":ts,"cont":short(c),"sev":sev,"msg":msg})
    return lines[-40:]

def main():
    serie_net=[]; serie_cpu=[]; prev=None; prev_t=None; seen=set(); logbuf=[]
    while True:
        rows=stats(); t=time.time()
        tot_cpu=round(sum(r["cpu"] for r in rows),1)
        tot_mem=round(sum(r["mem"] for r in rows),0)
        tot_rx=sum(r["rx"] for r in rows); tot_tx=sum(r["tx"] for r in rows)
        rx_rate=tx_rate=0.0
        if prev and prev_t:
            dt=max(0.5,t-prev_t); rx_rate=max(0,tot_rx-prev[0])/dt*1024; tx_rate=max(0,tot_tx-prev[1])/dt*1024
        prev=(tot_rx,tot_tx); prev_t=t
        serie_net=(serie_net+[round(rx_rate+tx_rate,1)])[-140:]
        serie_cpu=(serie_cpu+[tot_cpu])[-140:]
        try:
            json.dump({"ts":int(t),"n":len(rows),
                "totales":{"cpu":tot_cpu,"mem_mib":tot_mem,"rx_rate_kbs":round(rx_rate,1),"tx_rate_kbs":round(tx_rate,1),
                           "pids":sum(r["pids"] for r in rows)},
                "containers":sorted(rows,key=lambda r:-r["cpu"]),
                "serie_net":serie_net,"serie_cpu":serie_cpu}, open(MET,"w"))
        except Exception: pass
        # logs (cada 2 loops ~4s para no recargar)
        for l in logs():
            k=(l["hora"],l["cont"],l["msg"])
            if k not in seen: seen.add(k); logbuf.append(l)
        logbuf=logbuf[-60:]
        if len(seen)>2000: seen=set(list(seen)[-1000:])
        try: json.dump({"lineas":logbuf},open(LOG,"w"))
        except Exception: pass
        time.sleep(2)

if __name__=="__main__": main()
