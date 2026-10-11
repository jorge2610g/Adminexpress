# HISTÓRICO / SUPERADO — callback OAuth de Admin Preview

Este documento resolvía un callback específico de la antigua ruta `/preview/`.

Desde 2026-10-11 Adminexpress tiene una sola URL canónica:

`https://admin.expressviajes.online/`

El código vigente usa esa raíz como retorno OAuth administrativo.

No agregar `/preview/` como callback nuevo para mantener dos paneles.

Al modificar OAuth, conservar otros redirects necesarios para la app operativa y no cambiar Site URL global sin revisar impacto.

Fuente vigente: `lib/core/supabase_client.dart` y `docs/admin-central-access.md`.

El diagnóstico anterior permanece en el historial Git.
