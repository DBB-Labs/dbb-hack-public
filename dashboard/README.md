# Dashboard DBB Labs — consola en vivo

Consola visual del pentest: KPIs, matriz de ataque, gauge de integridad, dona de
severidades y feed en tiempo real. Estética dark SOC, marca DBB Labs.

## Uso
```bash
bash dashboard/servir.sh          # abre http://localhost:8899
```
El motor DBB-HACK escribe `estado.json` con `emitir.py` y el dashboard lo lee cada segundo.

- `index.html` — la consola (autocontenida; Chart.js por CDN).
- `estado.json` — estado de la corrida actual (lo actualiza emitir.py).
- `emitir.py` — CLI para alimentar el dashboard (init / evento / ataque / kpi / estado).
- `servir.sh` — sirve la consola y abre el navegador.
