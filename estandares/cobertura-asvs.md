# Cobertura OWASP ASVS (B13) — honesta

ASVS 4.0 tiene ~345 requisitos en 14 capítulos (V1–V14). DBB-HACK **no los prueba todos
automáticamente** — eso sería mentira. Esto mapea qué capítulos toca cada vector implementado
y cuáles quedan para revisión manual. Nivel objetivo para una fintech: **L2** (algunos L3).

| Cap. ASVS | Tema | Vectores DBB-HACK que lo tocan | Estado |
|---|---|---|---|
| V1 Arquitectura | Diseño, modelo de amenazas | (metodología humana + recon) | manual |
| V2 Autenticación | Login, MFA, fuerza bruta | A3, A6, A9, B12 | parcial-auto |
| V3 Sesión | Tokens, expiración, reuso | B12 | parcial-auto |
| V4 Control de acceso | Authz, IDOR, escalada | A1, A2, B4, B5 | parcial-auto |
| V5 Validación/encoding | Inyección, XSS | B6, B10 | parcial-auto |
| V6 Criptografía | Secretos, claves | S1 | parcial-auto |
| V7 Errores y logging | Fugas por error, enum | A9 | parcial-auto |
| V8 Protección de datos | PII, exposición | A0, A1, B5 | parcial-auto |
| V9 Comunicaciones | TLS, HSTS | A10 | parcial-auto |
| V10 Código malicioso | Supply-chain | S2, S3 | parcial-auto |
| V11 Lógica de negocio | Flujos de dinero, race | B1, B2, B3 | parcial-auto |
| V12 Archivos | Subida, path traversal | B8, B9 | parcial-auto |
| V13 API | REST/GraphQL, authz | A0, A2, A7, B4 | parcial-auto |
| V14 Config | Cabeceras, CSRF, crons | A4, A5, A10, B11 | parcial-auto |

## Lectura honesta
- DBB-HACK **automatiza señal** en los 14 capítulos, pero **no** cierra los 345 requisitos.
  "Parcial-auto" = hay al menos un ataque real que ejercita ese capítulo, no que esté completo.
- Los requisitos L2/L3 finos (rotación de claves, gestión de secretos en runtime, revisión de
  diseño) exigen **revisión manual guiada** por un analista.
- Por eso B13 se reporta como **manual**, con esta cobertura, y nunca como "cumple ASVS".
