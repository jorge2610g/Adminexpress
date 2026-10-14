> **Estado 2026-10-14:** las reglas de Preview y Producción de este documento quedan superadas en lo que contradigan `docs/ARQUITECTURA_UNICA_2026-10-14.md` (una app, una web, entorno decidido por la cuenta). Se conserva como histórico.

# Admin > Publicidad (Google AdMob)

Dentro de Configuración existe el control de publicidad.

## Un panel, dos contextos de datos

Adminexpress ya no usa dos páginas.

La cuenta autenticada determina:

- Preview -> configuración de prueba/shadow y unidades oficiales de prueba;
- Producción -> configuración real.

Las RPC `admin_admob_settings_get` y `admin_admob_settings_update` deben validar administrador y entorno efectivo. La separación no depende de una URL `/preview/`.

Producción permanece OFF por defecto salvo decisión explícita.

## Tres identificadores públicos

En AdMob se usan:

1. Publisher ID.
2. Android App ID.
3. Banner Ad Unit ID.

No guardar claves JSON de service account, tokens OAuth ni secretos en el panel o repo.

## Limitación técnica

El Android App ID debe estar compilado en `AndroidManifest.xml`.

Activar un switch web no modifica una APK instalada.

Para anuncios reales hace falta:

- configuración correcta;
- build Android firmado;
- revisión de Data Safety/declaración de anuncios;
- autorización de publicación.

**Sin App ID válido compilado, mantener Producción OFF.**
