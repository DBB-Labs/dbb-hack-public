# DBB-HACK — Backlog de vectores (ordenado por prioridad)

Los 8 vectores de hoy fueron la base. Esto es **todo lo que falta para "blindado de verdad"**,
ordenado. ✅ = ya probado (defendido). 🟡 = hallazgo. ⏳ = pendiente.

## Ya cubierto (ronda 1-2)
- ✅ A0 Robo externo sin cuenta (API/schemas) · OWASP API1/API3
- ✅ A1 Aislamiento entre clientes / RLS · API1 BOLA
- ✅ A2 Escalada cliente→operador · API5 BFLA
- ✅ A3 Operador sin 2FA mueve dinero · A.8.5
- ✅ A4 Webhook con firma falsa · API2/API8
- ✅ A5 Crons sin secreto · API2
- ✅ A7 Doble-pago de retiro (FOR UPDATE + idempotencia)
- ✅ A8 Secretos en git (gitleaks) · ✅ A9 Dependencias (npm audit) · ✅ A10 SAST (semgrep)
- 🟡 A6 Fuerza bruta de login → defensa en el borde, verificar prod

## Pendiente — PRIORIDAD 1 (dinero / autorización, lo más crítico)
1. ⏳ **Flujos de dinero completos** (BAMF): compra, abono, retiro de punta a punta con saldos reales.
   - Doble-gasto / doble-abono bajo concurrencia real.
   - Penny-drop y montos negativos/overflow en `amount_minor`.
   - Saltarse la doble aprobación (`motivo_doble_aprobacion`).
   - Overdraw: dos retiros concurrentes que suman más que el saldo.
2. ⏳ **IDOR profundo sobre TODOS los recursos** (no solo perfil): órdenes, movimientos,
   documentos, comprobantes, expedientes de empresa — por id ajeno.
3. ⏳ **Mass-assignment** en cada Server Action: fijar campos que no corresponden
   (role, is_system, capacidades, montos, owner_id) vía FormData.
4. ⏳ **Barrido de las 55 Server Actions**: que cada una valide sesión/rol y no lea el titular de la petición (fallo F5).

## Pendiente — PRIORIDAD 2 (superficie web / API)
5. ⏳ **Inyección**: SQL/NoSQL en cada entrada (aunque usen consultas parametrizadas, confirmarlo).
6. ⏳ **XSS** (reflejado/almacenado/DOM) en campos que se renderizan.
7. ⏳ **SSRF** en integraciones (Mercado Pago, correo, CRM, webhooks salientes).
8. ⏳ **Path traversal / LFI** en subida y descarga de documentos.
9. ⏳ **Open redirect** en `/auth/volver`, `/salir`, retornos de OAuth.
10. ⏳ **CSRF** en Server Actions (Next protege, pero confirmar el token en cada mutación).
11. ⏳ **Subida de archivos maliciosos**: tipo/tamaño/contenido en los buckets.

## Pendiente — PRIORIDAD 3 (sesión, config, infra)
12. ⏳ **Gestión de sesión**: fijación, expiración, invalidación al cerrar, reuso de token.
13. ⏳ **Cabeceras de seguridad y TLS**: CSP, HSTS, X-Frame-Options, cookies `Secure`/`HttpOnly`/`SameSite`.
14. ⏳ **Rate-limiting de borde** (confirmar el hallazgo A6 en prod: Vercel Firewall + Supabase Auth).
15. ⏳ **Enumeración de usuarios** (login/registro/reset revelan si un correo existe).
16. ⏳ **GraphQL** (`graphql_public`): introspección y acceso a datos.

## Pendiente — PRIORIDAD 4 (cobertura formal / continuo)
17. ⏳ **OWASP ASVS L2/L3**: recorrer los 345 requisitos (tu corpus) sistemáticamente.
18. ⏳ **OWASP WSTG**: las 97 pruebas web como checklist.
19. ⏳ **DAST**: `nuclei` + OWASP `ZAP` contra la app corriendo.
20. ⏳ **SBOM / supply-chain**: `osv-scanner`/`trivy`, integridad de dependencias.
21. ⏳ **Mapa de cumplimiento**: NCG 502 E.4.1 (CMF) + Ley 21.719, evidencia + gaps.
22. ⏳ **CI continuo**: correr LOW en cada PR; FULL/BAMF programado.
23. ⏳ **Pentest externo profesional** (el sello independiente ante la CMF).

> Regla: PRIORIDAD 1 antes que nada — es donde está el dinero. Cada ítem cerrado
> entra al dashboard como vector defendido y al informe con su mapeo ISO/OWASP.
