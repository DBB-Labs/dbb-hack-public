# DBB-HACK

> © 2026 Felipe Córdova · DBB Labs — Licencia **GNU AGPL-3.0** (ver LICENSE) + alcances legales chilenos. Herramienta ofensiva: uso solo sobre sistemas propios o autorizados por escrito.

Pentester interno de DBB para apps **Next.js + Supabase**, con **consola de centro de
comando (DBB Labs)**. Corre sobre Claude Code / herramientas locales — sin pagar por token.
Guiado por playbooks adaptados de Strix (Apache-2.0, ver `NOTICE`) y mapeado a ISO 27002 /
OWASP. Licencia: **GNU AGPL-3.0** (ver `LICENSE`), con alcances legales chilenos anexos.

## Qué hace (hoy)
- **Análisis estático** del código: secretos (gitleaks), dependencias (npm audit), SAST (semgrep).
- **Explotación EN VIVO** en un **laboratorio local aislado**: monta el Supabase + la app del
  proyecto y lanza ataques reales (robo externo, IDOR/RLS, escalada, 2FA, webhook, crons,
  fuerza bruta, GraphQL, open redirect, enumeración, cabeceras).
- **Consola en vivo** (http://localhost:8899): panel de control, torta de progreso, feed,
  matriz de ataque, radar de postura, tabla de contenedores (docker stats real), informe
  embebido + export PDF, y un panel por vector con recomendación + prompt de remediación.

## 4 niveles
LOW (estático) · MID (estático + revisión) · FULL (+ ataque en vivo) · BAMF (+ ASVS/WSTG,
dinero, cumplimiento). Ver `niveles.md` y el catálogo `dashboard/vectores.json`.

## Uso
```bash
bash dashboard/servir.sh        # abre la consola en http://localhost:8899
```
Elige objetivo (cualquier repo en ~/Documents/Proyectos) + nivel + vectores, y LANZAR.
En FULL/BAMF el auto-montador (`montar-lab.sh`) levanta el lab del proyecto solo.
Los informes se guardan en `~/Documents/STRIX ANALISIS/<año>/<proyecto>/<mes>/`.

## Garantía de integridad (regla de oro)
**Nunca inventa resultados.** Si el lab del objetivo no está montado (el `project_id` no
calza) o la app no responde, los vectores en vivo quedan **"no probado"** — jamás un
vulnerable/hallazgo falso. Solo se ataca el lab del objetivo, nunca producción.

## Alcance genérico
Los vectores externos/estáticos (S1-S3, A0, A7, A8, A9, A10) corren en **cualquier** proyecto
Supabase+Next. Los específicos del esquema (A1/A2/A3: RLS, escalada, 2FA) requieren cuentas
sembradas con el esquema del proyecto; si no las hay → "no probado".

## Límite honesto
DBB-HACK **sí hace explotación en vivo** (en laboratorio aislado). Lo que **no** es:
un **pentest externo profesional acreditado** — su cobertura se limita a los vectores
implementados, no tiene la creatividad de un red team humano, corre en un lab local y no
reemplaza la auditoría independiente que exige un regulador (p.ej. CMF). Es una capa fuerte,
continua y gratuita; no el sello final de cumplimiento.

## Tests
`npm run test:e2e` — suite Playwright del flujo de la consola.
