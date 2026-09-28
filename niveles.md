# DBB-HACK — Los 4 niveles (estándar DBB)

Cada análisis de seguridad de DBB se corre en uno de estos 4 niveles. Más nivel =
más profundidad, más tiempo, más cobertura. El nivel se elige por el riesgo del
objetivo: una landing estática va en LOW; Kapa21 (dinero real, regulado) va en BAMF.

| Nivel | Para qué | Tiempo | Toca la app corriendo |
|---|---|---|---|
| **LOW HACK** | CI en cada PR, chequeo rápido | minutos | No (estático) |
| **MID HACK** | Revisión estándar de un repo | ~30–60 min | No (estático + manual) |
| **FULL HACK** | Pentest en vivo real | horas | Sí (laboratorio aislado) |
| **BAMF HACK** | Máximo blindaje, dinero real / regulado | días / continuo | Sí + exhaustivo |

---

## 🟢 LOW HACK — rápido, automático, sin tocar la app
Objetivo: atrapar lo evidente en minutos, apto para correr en cada commit/PR.
- `gitleaks` — secretos en el código y en el historial de git.
- `npm audit` / `osv-scanner` — vulnerabilidades conocidas en dependencias.
- `semgrep` reglas rápidas (`p/security-audit`) — patrones inseguros.
- Recon de superficies (`recon/mapear.sh`).
- **Salida:** KPIs en el dashboard + lista de hallazgos automáticos. Sin lab, sin ataque.

## 🔵 MID HACK — LOW + revisión humana por playbooks
Objetivo: la revisión de código de caja blanca completa.
- Todo lo de LOW, con `semgrep` a fondo (`p/owasp-top-ten` + reglas del stack).
- Revisión manual guiada por los `playbooks/` (authz funcional, RLS/Supabase, IDOR,
  lógica de negocio, JWT, mass-assignment, race) leyendo el código real.
- Modelo de autorización documentado (quién puede qué).
- **Salida:** informe de caja blanca mapeado a ISO/OWASP. Sigue sin tocar la app.

## 🟠 FULL HACK — pentest en vivo
Objetivo: probar las defensas atacando de verdad, en laboratorio aislado.
- Todo lo de MID, más:
- Laboratorio local aislado (Supabase + app en Docker/local, nunca producción).
- Ataques dinámicos reales: externo sin cuenta (robo de datos/archivos), aislamiento
  entre clientes (RLS/IDOR), escalada de rol, 2FA, webhook con firma falsa, crons,
  fuerza bruta.
- DAST: `nuclei` / OWASP `ZAP` contra la app corriendo.
- **Salida:** informe de pentest en vivo + dashboard en tiempo real.

## 🔴 BAMF HACK — bad ass motherfucker (el máximo)
Objetivo: blindaje real para dinero de verdad. Adversarial, exhaustivo, continuo.
- Todo lo de FULL, más:
- Cobertura sistemática **OWASP ASVS L2/L3** (los 345 requisitos) + **WSTG** (97 pruebas).
- **Fuzzing** y búsqueda de exploits encadenados.
- **Flujos de dinero completos**: condiciones de carrera, doble-gasto, penny-drop,
  idempotencia bajo concurrencia, manipulación de montos.
- **Supply-chain / SBOM**, análisis de sesión, cabeceras/TLS, rate-limiting de borde.
- **Mapa de cumplimiento**: NCG 502 E.4.1 (CMF) + Ley 21.719 (datos) + ISO 27002.
- **CI continuo** (cada PR) + recomendación de **pentest externo profesional**.
- **Salida:** informe de blindaje + mapa de cumplimiento + plan de remediación con prompts.

---

## Honestidad de alcance (aplica a todos los niveles)
- DBB-HACK encuentra y prueba controles técnicos; **no reemplaza** un pentest externo
  acreditado, la auditoría de la CMF, ni el trabajo legal/organizacional.
- El BAMF acerca al máximo la parte técnica y **hace visible** todo lo que falta fuera de
  lo técnico — esa es la tranquilidad realista para dinero real.
- Nunca se ataca producción. Siempre laboratorio aislado o análisis estático.
