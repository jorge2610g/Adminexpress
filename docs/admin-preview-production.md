# Preview / Producción — modelo vigente

> **Actualizado 2026-10-11.**
> El nombre de este archivo se conserva por compatibilidad con referencias antiguas.

## Ya no existen dos paneles

Antes se publicaban dos superficies web:

- `/`
- `/preview/`

Ese modelo quedó retirado.

Ahora solo existe:

`https://admin.expressviajes.online/`

`/preview/` redirige a la raíz.

## Cómo se separan los datos

El entorno se determina por la cuenta autenticada.

- cuenta Preview -> `runtime_environment = preview`;
- cuenta Producción -> `runtime_environment = production`.

La misma cuenta no cambia de entorno con un selector.

## Backend

Supabase:

`zgpijrznvaskgcmauwxx`

Funciones:

- `admin_current_runtime_environment()`
- `admin_environment_allowed(p_channel)`
- `admin_access_context()`

El frontend usa el entorno retornado por el servidor.

## Roles, zona y módulos

El mismo contexto devuelve rol, zona y módulos autorizados.

Esto permite operadores por ciudad sin duplicar sitio.

## OAuth

El retorno administrativo vigente es:

`https://admin.expressviajes.online/`

No usar `/preview/` como callback canónico nuevo.

## Reglas retiradas

No volver a implementar:

- `ADMIN_ENV` para decidir entorno;
- claves de sesión distintas por ruta;
- builds web separados;
- `_previewScopedModules`;
- `preview_authorized_sha`;
- snapshots para preservar una raíz mientras se reemplaza `/preview/`;
- selector manual Prueba/Producción.

## Release Android

El release móvil sigue teniendo sus propios gates y no debe confundirse con el entorno web administrativo.

## Fuente de verdad

Ver `docs/admin-central-access.md` y `docs/AI_HANDOFF_2026-10-11.md`.
