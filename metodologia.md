# DBB-HACK — Metodología de revisión

Revisión de seguridad de caja blanca (leyendo código) para el stack DBB:
**Next.js (App Router) + Supabase**. La corre Claude Code dentro de VS Code, gratis,
guiada por los `playbooks/`. Corre estático y ataca en vivo en laboratorio aislado (nunca producción).

## Principio rector
La mayoría de las fallas reales de estas apps **no son inyección clásica**, son de
**autorización y lógica**: alguien ve o hace algo que su rol no debería. Ahí va el foco.

## Las 5 fases (en orden)

### Fase 1 — Recon (mapear el terreno)
Correr `recon/mapear.sh <ruta-repo>`. Produce el inventario de superficies:
- **Server Actions** (`'use server'`) y **route handlers** (`app/**/route.ts`).
- **Endpoints y RPC de Supabase** que toca el cliente.
- **Políticas RLS** en `supabase/migrations/*.sql` y funciones `SECURITY DEFINER`.
- **Roles** del sistema y de dónde salen (JWT claims, tabla de perfiles, user_metadata).
- Uso de `service_role`/`SUPABASE_SECRET_KEY` (clave: nunca debe llegar al cliente).

### Fase 2 — Modelo de autorización
Antes de buscar fallas, escribir en una tabla: **qué rol puede ver/hacer qué**.
Sale de la doc del repo, los nombres de las acciones y las políticas RLS.
Sin este mapa, no se puede juzgar si algo es una falla.

### Fase 3 — Revisión por playbook
Para cada superficie de la Fase 1, aplicar los playbooks que apliquen. Prioridad DBB:
1. `broken_function_level_authorization.md` — ¿cada Server Action/route valida el rol?
2. `supabase.md` — ¿RLS activa en cada tabla? ¿SELECT/UPDATE filtran por dueño?
   ¿funciones `SECURITY DEFINER` con `search_path` fijo? ¿el cliente usa solo anon/publishable?
3. `idor.md` — ¿se accede a recursos por id sin verificar dueño?
4. `business_logic.md` — reglas del negocio saltables (montos, estados, aprobaciones).
5. `authentication_jwt.md` — ¿se confía en claims del cliente sin verificar?
6. `mass_assignment.md` — ¿inserts/updates aceptan campos que el usuario no debería fijar (role, sueldo)?
7. `race_conditions.md` — doble submit, penny-drop, aprobaciones concurrentes.
8. Resto (`sql_injection`, `xss`, `ssrf`, `open_redirect`, `path_traversal`, `csrf`,
   `information_disclosure`, `weak_password_detection`) según lo que el recon revele.

### Fase 4 — Confirmar y descartar falsos positivos
Para cada sospecha: rastrear el código hasta confirmar que **de verdad** es explotable
(que no haya un chequeo en otra capa: middleware, RLS, un `assertAdmin()` más arriba).
Marcar severidad (Crítica/Alta/Media/Baja) y **cómo se explotaría** (el PoC en texto).
Si hay dudas, decirlo: "requiere prueba en vivo".

### Fase 5 — Informe
Usar `informes-plantilla/informe.md`. Guardar en:
`~/Documents/STRIX ANALISIS/STRIX ANALISIS <año>/STRIX ANALISIS <proyecto>/STRIX ANALISIS <NN-Mes>/<fecha_hora>_dbbhack/`

## Frenos
- Solo repos propios/autorizados de DBB.
- No inventar fallas: si no se ve en el código, se dice "no verificable sin prueba en vivo".
- No tocar producción ni credenciales reales.
- Si una falla se ve grave, ofrecer montar la prueba en vivo de esa falla puntual.
