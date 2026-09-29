# Cobertura OWASP WSTG (B14) — honesta

El WSTG (Web Security Testing Guide) tiene ~97 pruebas en 11 categorías (WSTG-INFO … WSTG-CLNT).
DBB-HACK automatiza señal en varias, pero **no** las 97. Aquí el mapa honesto.

| Categoría WSTG | Vectores DBB-HACK | Estado |
|---|---|---|
| INFO — Recolección de información | recon + A7 (introspección) | parcial-auto |
| CONF — Configuración y despliegue | A10, A5, S1 | parcial-auto |
| IDNT — Gestión de identidad | A9 (enumeración) | parcial-auto |
| ATHN — Autenticación | A3, A6, B12 | parcial-auto |
| ATHZ — Autorización | A1, A2, B4, B5 | parcial-auto |
| SESS — Gestión de sesión | B12 | parcial-auto |
| INPV — Validación de entradas | B6 (SQLi), B10 (XSS) | parcial-auto |
| ERRH — Manejo de errores | A9 | parcial-auto |
| CRYP — Criptografía débil | A10 (HSTS), S1 | parcial-auto |
| BUSL — Lógica de negocio | B1, B2, B3 | parcial-auto |
| CLNT — Lado cliente | B10, B11, A8 (open redirect) | parcial-auto |

## Lectura honesta
- Cobertura automatizada: las 11 categorías tienen al menos una prueba real; el detalle fino
  de cada una de las 97 pruebas WSTG requiere **revisión manual**.
- Pruebas no automatizadas hoy: fuzzing exhaustivo de entradas, pruebas de lógica de negocio
  específicas por flujo, y análisis client-side profundo (DOM XSS por componente).
- B14 se reporta **manual** con esta cobertura, nunca como "pasa WSTG".
