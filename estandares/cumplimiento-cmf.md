# Mapa de cumplimiento (B16) — CMF NCG 502 E.4.1 + Ley 21.719

Mapa honesto entre lo que DBB-HACK verifica y las exigencias regulatorias chilenas para una
fintech que maneja dinero. **DBB-HACK aporta evidencia técnica; no certifica cumplimiento** —
eso lo firma un tercero y depende de controles organizacionales, no solo de código.

## NCG 502 (CMF) — Anexo E.4.1, gestión de ciberseguridad
| Exigencia | Evidencia que aporta DBB-HACK | Brecha / acción del equipo |
|---|---|---|
| Autenticación robusta (MFA) en sistemas críticos | A3 prueba que mover dinero exige 2FA | **Activar MFA de operadores en producción** (tarea del equipo) |
| Control de acceso por rol | A1, A2, B4, B5 (RLS, escalada, mass-assign) | — |
| Protección de datos de clientes | A0, A1, B5 (aislamiento, exposición) | — |
| Integridad de transacciones | B1 (idempotencia), B2, B3 (montos, saldo) | Sembrar cuentas para cerrar B3 en vivo |
| Registro y trazabilidad | (ledger de doble entrada verificado) | Revisar retención de logs (manual) |
| Gestión de vulnerabilidades | LOW/MID/FULL/BAMF de DBB-HACK, continuo | Correr en cada release |

## Ley 21.719 (protección de datos personales)
| Principio | Evidencia DBB-HACK | Brecha / acción |
|---|---|---|
| Confidencialidad (acceso solo autorizado) | A1, B5 (RLS en 38 tablas) | — |
| Seguridad de tratamiento | S1 (secretos), A10 (cabeceras), B9 (buckets) | **Cerrar bucket documentos-empresas** (B9) |
| Minimización / exposición | A0 (robo externo), A7 (introspección) | — |

## Lo honesto (por qué B16 es "manual")
- El cumplimiento regulatorio incluye **controles no técnicos** (políticas, contratos, DPO,
  respuesta a incidentes, capacitación) que ninguna herramienta prueba.
- DBB-HACK entrega la **evidencia técnica** y señala las brechas; la certificación y la firma
  ante la CMF las hace un tercero. Fingir "cumple" sería el peor falso positivo.
- Brechas abiertas hoy: (1) MFA de operadores en prod, (2) bucket `documentos-empresas` sin
  límites (B9), (3) sembrar cuentas para cerrar B3 en vivo.
