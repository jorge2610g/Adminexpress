> **Estado 2026-10-14:** las reglas de Preview y Producción de este documento quedan superadas en lo que contradigan `docs/ARQUITECTURA_UNICA_2026-10-14.md` (una app, una web, entorno decidido por la cuenta). Se conserva como histórico.

# HISTÓRICO / SUPERADO — separación de sesiones por ruta

Este documento describía la época en que Adminexpress publicaba `/` y `/preview/` como dos superficies independientes.

Desde 2026-10-11 esa arquitectura fue retirada.

Ahora:

- hay una sola web `https://admin.expressviajes.online/`;
- la cuenta autenticada define Preview/Producción;
- no se usan claves de sesión distintas por ruta;
- `/preview/` redirige a la raíz.

No reimplementar esta separación de LocalStorage ni sesiones por URL.

Fuente vigente: `docs/admin-central-access.md`.

El contenido anterior permanece en Git para trazabilidad.
