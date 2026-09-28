# Metodología humana — cómo DBB-HACK piensa como un pentester

En FULL/BAMF, DBB-HACK **no corre una lista**. El cerebro (Claude Code) sigue este loop,
igual que un humano: prueba, mira, y encadena la siguiente jugada con lo que vio.

Las **manos** son `dashboard/primitivas.sh` (cada primitiva ejecuta un ataque real y
devuelve en JSON lo que observó). La **memoria** es `dashboard/conocimiento.py`. La
**voz** al dashboard es `dashboard/emitir.py`, como siempre.

## Regla que atraviesa todo
Una hipótesis pasa a `vulnerable`/`hallazgo` **solo con evidencia observada** en la salida
de una primitiva. Si una primitiva devuelve `no-probado`, se emite `no-probado` y se sigue.
Nunca se infiere un resultado que no se ejecutó.

## El loop
1. **Modelar.** `primitivas.sh <obj> lab` → saber si el lab vive y qué cuentas hay
   (clienteA, clienteB, operadorSin2FA). Guardar en memoria:
   `conocimiento.py set clienteA <id>` etc. Leer recon estático del repo (superficies, roles).
2. **Hipótesis.** Desde el modelo de negocio, no desde un checklist. Preguntarse:
   "¿quién NO debería poder hacer esto, y qué pasa si lo intenta?". Priorizar lo que toca
   **plata, PII o privilegios**.
3. **Probar.** Llamar la primitiva que corresponde. Leer el JSON de vuelta.
4. **Emitir.** `emitir.py ataque <ID> <estado> ...` con la evidencia real.
5. **Encadenar.** Usar `datos` de la respuesta como entrada de la siguiente primitiva
   (ver cadenas abajo). Guardar lo nuevo en memoria.
6. **Pivotar.** Si una vía se cierra (`defendido`), probar otra hipótesis; no seguir un
   orden fijo. Si una vía se abre (`vulnerable`), profundizar la cadena.
7. **Juzgar y documentar.** Cerrar cada cadena con su impacto de negocio (Fase B) y un PoC
   reproducible (la secuencia exacta de primitivas).

## Cadenas de ejemplo (esto es lo que un robot NO hace)
- **Toma de cuenta:** `enum-usuarios` → si `enumerable:true`, ya sé que un email existe →
  `fuerza-bruta <email>` sobre ese email real → si cae, `login` → con el token, `idor`/
  `escalada` desde una sesión válida. Cada paso usa el resultado del anterior.
- **Cuenta de prueba controlada:** `crear-usuario` → `login` (obtengo token) → con esa
  sesión de cliente real intento `escalada` (aprobar dinero) y `idor` (leer a otro).
- **Movimiento de fondos:** `lab` da `operadorSin2FA` → `operador-sin-2fa <id>` → si mueve
  plata sin segundo factor, la cadena "operador comprometido → fondos" queda probada.

## Cómo se ve en el dashboard
Cada primitiva que ejecuto se emite como paso (`emitir.py evento ataque "..."` para el
intento, luego `emitir.py ataque <ID> <estado> ...` para el resultado). Una cadena se emite
como varios pasos con el mismo prefijo de nombre ("Cadena toma de cuenta · paso 2/4"), para
que se vea el razonamiento, no solo el veredicto.

## Frenos
- Solo el lab aislado del objetivo. Nunca producción ni credenciales reales.
- Si `lab` devuelve `live:false` → solo estático (`secretos`, `deps`, `sast`); los vectores
  en vivo quedan `no-probado`.
- El usuario de prueba de `crear-usuario` es efímero y del lab; no tocar cuentas reales.
