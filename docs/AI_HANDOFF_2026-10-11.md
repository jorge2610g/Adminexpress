# Adminexpress — handoff vigente 2026-10-11

Este es el handoff operativo vigente para cualquier IA o desarrollador.

## Estado actual

Adminexpress dejó de mantener dos aplicaciones web separadas para Preview y Producción.

La arquitectura vigente es:

- **URL canónica única:** `https://admin.expressviajes.online/`
- **Backend único:** Supabase `zgpijrznvaskgcmauwxx`
- **Entorno por identidad:** Preview/Producción se resuelve desde la cuenta autenticada
- **Rol y alcance:** `admin_users` + `account_runtime_bindings`
- **Contexto único:** `admin_access_context()`
- **Ruta heredada:** `/preview/` redirige a la raíz; no es otro panel

El PR #70 introdujo el panel central por usuario. El deploy verificado fue el workflow **Deploy Adminexpress Central** y confirmó el modo `account_scoped`.

## Control de acceso

El frontend ya no decide el entorno por build.

`admin_access_context()` devuelve, entre otros:

- `runtime_environment`
- `role`
- `zone_id`
- `country_code`
- `allowed_modules`
- `allow_preview`
- `allow_production`

`admin_current_runtime_environment()` toma el entorno efectivo de la identidad.

`admin_environment_allowed(p_channel)` exige que el canal solicitado coincida con el entorno de esa cuenta.

`admin_set_panel_access_v2(...)` permite al superadministrador asignar entorno, rol, zona y módulos.

## Roles

Actualmente el esquema admite:

- `super_admin`: acceso administrativo total salvo restricciones explícitas de release;
- `zone_monitor`: alcance de zona, solo lectura y módulos operativos predefinidos.

Se pueden añadir nuevos roles de operador en el mismo panel. **No crear otra web** para una ciudad, operador o rol.

## Permisos de módulos

La columna `admin_users.allowed_modules text[]` permite limitar el menú y el acceso visible por usuario.

`NULL` usa los defaults del rol.  
`['*']` representa todos los módulos para superadmin.

La UI usa `_sectionAllowed` y `_sectionModuleKeys`.

La seguridad real debe seguir reforzada por RPC/backend; ocultar un botón por sí solo no reemplaza autorización.

## Identidad del conductor

La revisión documental/identidad ya está integrada en la ficha del conductor.

Las rutas antiguas de:

- Verificación de identidad
- Verificación manual

no deben volver a aparecer como entradas laterales independientes.

## Despliegue

Workflow:

`.github/workflows/deploy-web.yml`

Nombre vigente:

`Deploy Adminexpress Central`

Construye un solo bundle:

`flutter build web --release --base-href /`

`/preview/` solo contiene redirección al panel central.

No reintroducir un segundo build con `--base-href /preview/`.

## Supabase versionado

Migraciones relevantes de esta arquitectura:

- `20261011210000_admin_runtime_environment_by_identity.sql`
- `20261011211000_single_admin_access_scope.sql`

## IA / agentes

Claude/Cloud, ChatGPT, Codex u otra IA autorizada puede programar y modificar cualquier parte del repositorio dentro de sus permisos técnicos reales. Ver `docs/AI_AGENT_POLICY.md`.

## Documentos superados

No usar como contrato vigente documentos que describan:

- dos páginas `/` y `/preview/`;
- `ADMIN_ENV`;
- Preview autorizado por SHA independiente;
- selector de entorno dentro del panel;
- Claude como agente “solo de arquitectura”.

Esos archivos quedan marcados como históricos y apuntan a este handoff.
