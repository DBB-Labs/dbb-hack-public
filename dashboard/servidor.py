#!/usr/bin/env python3
"""Servidor de control DBB Labs: sirve el dashboard y lanza ataques desde el navegador.
GET  → archivos estáticos.  POST /api/lanzar {objetivo,nivel,vectores} → corre atacar.sh.
Uso: servidor.py [puerto]  (por defecto 8899)."""
import json, os, subprocess, sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8899

class H(SimpleHTTPRequestHandler):
    def __init__(self,*a,**k): super().__init__(*a, directory=HERE, **k)
    def end_headers(self):
        self.send_header("Cache-Control","no-store"); super().end_headers()
    def log_message(self,*a): pass
    def do_POST(self):
        if self.path.split("?")[0] != "/api/lanzar":
            self.send_error(404); return
        try:
            n=int(self.headers.get("Content-Length",0)); body=json.loads(self.rfile.read(n) or b"{}")
        except Exception: body={}
        obj=str(body.get("objetivo","kapa21-v2"))[:80]
        niv=str(body.get("nivel","full"))[:10]
        vec=body.get("vectores","all")
        vec=",".join(vec) if isinstance(vec,list) and vec else "all"
        # lanzar el orquestador en segundo plano
        subprocess.Popen(["bash", os.path.join(HERE,"atacar.sh"), obj, niv, vec],
                         stdout=open("/tmp/dbb-atacar.log","a"), stderr=subprocess.STDOUT)
        self.send_response(200); self.send_header("Content-Type","application/json"); self.end_headers()
        self.wfile.write(json.dumps({"ok":True,"objetivo":obj,"nivel":niv,"vectores":vec}).encode())

if __name__=="__main__":
    print(f"DBB Labs control → http://localhost:{PORT}")
    ThreadingHTTPServer(("127.0.0.1",PORT),H).serve_forever()
