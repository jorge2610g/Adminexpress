# Adminexpress central por usuario

**Vigente desde:** 2026-10-11

## Objetivo

Mantener una sola aplicación administrativa y decidir todo por la identidad autenticada.

URL canónica:

`https://admin.expressviajes.online/`

## Entorno

La cuenta queda ligada a `preview` o `production`.

Fuente:

`account_runtime_bindings.environment`

Resolución:

`admin_current_runtime_environment()`

Validación:

`admin_environment_allowed(p_channel)`

No hay selector manual de entorno y no hay dos builds web.

## Contexto administrativo

`admin_access_context()` devuelve el contexto efectivo del usuario:

- `runtime_environment`
- `role`
- `read_only`
- `zone_id`
- `zone_name`
- `city`
- `region_department`
- `country`
- `country_code`
- `allowed_modules`
- `allow_preview`
- `allow_production`

## Configuración de acceso

`admin_set_panel_access_v2(...)` permite a un superadministrador asignar:

- usuario;
- rol;
- zona;
- estado activo;
- entorno;
- lista de módulos.

El cambio actualiza `admin_users` y `account_runtime_bindings`.

## Módulos

`admin_users.allowed_modules text[]` es opcional.

- `NULL`: usa defaults del rol.
- `['*']`: acceso a todos los módulos para superadmin.
- lista explícita: solo esos módulos.

La UI usa `_sectionModuleKeys` y `_sectionAllowed`.

El backend debe mantener su propia autorización para acciones sensibles.

## Operadores por ciudad

No se crea otro panel.

Un operador se modela con:

- usuario propio;
- rol;
- zona;
- módulos;
- entorno.

La misma arquitectura soporta futuros roles.

## Identidad

La revisión documental está integrada en la ficha del conductor.

Las entradas antiguas de “Verificación de identidad” y “Verificación manual” no forman parte de la navegación vigente.

## Deploy

`Deploy Adminexpress Central` publica un solo bundle raíz.

La ruta `/preview/` redirige a `/`.

## Migraciones

- `supabase/migrations/20261011210000_admin_runtime_environment_by_identity.sql`
- `supabase/migrations/20261011211000_single_admin_access_scope.sql`

## Respaldo

Antes de la unificación se creó:

`backup/main-before-single-admin-by-user-20261011`

La documentación previa se conserva en Git y los archivos antiguos se marcan como históricos cuando corresponde.
