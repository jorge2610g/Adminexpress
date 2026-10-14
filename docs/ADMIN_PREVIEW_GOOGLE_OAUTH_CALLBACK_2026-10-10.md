> **Estado 2026-10-14:** las reglas de Preview y Producción de este documento quedan superadas en lo que contradigan `docs/ARQUITECTURA_UNICA_2026-10-14.md` (una app, una web, entorno decidido por la cuenta). Se conserva como histórico.

# HISTÓRICO / SUPERADO — callback OAuth de Admin Preview

Este documento resolvía un callback específico de la antigua ruta `/preview/`.

Desde 2026-10-11 Adminexpress tiene una sola URL canónica:

`https://admin.expressviajes.online/`

El código vigente usa esa raíz como retorno OAuth administrativo.

No agregar `/preview/` como callback nuevo para mantener dos paneles.

Al modificar OAuth, conservar otros redirects necesarios para la app operativa y no cambiar Site URL global sin revisar impacto.

Fuente vigente: `lib/core/supabase_client.dart` y `docs/admin-central-access.md`.

El diagnóstico anterior permanece en el historial Git.
