> **PRIMERO — corte 2026-10-14:** `docs/EXPRESS_FOUR_APPS_CODE_AUDIT_20261014.md` registra código existente, funcionalidades retiradas y plan de separación de cuatro aplicaciones con un solo Supabase. Los documentos del 2026-10-11 no reflejan todavía la nueva decisión de Repartidor/Restaurante.

# ADMINEXPRESS — START HERE

> **Última actualización:** 2026-10-11  
> Este es el punto de entrada vigente.

## 1. Qué es Adminexpress

`Adminexpress` es el frontend administrativo web de Express.

URL canónica:

`https://admin.expressviajes.online/`

Aplicación operativa móvil:

`jorge2610g/Expressdelivery`

No volver a copiar el panel administrativo al APK/AAB.

## 2. Arquitectura actual

Existe una sola web y un solo Supabase principal:

`zgpijrznvaskgcmauwxx`

Preview y Producción se separan por **usuario**, no por URL.

La cuenta define:

- entorno;
- rol;
- zona/ciudad;
- módulos permitidos.

`/preview/` es solo una redirección de compatibilidad.

## 3. Seguridad de acceso

RPC principales:

- `admin_current_runtime_environment()`
- `admin_environment_allowed(p_channel)`
- `admin_access_context()`
- `admin_set_panel_access_v2(...)`

Datos de autorización:

- `admin_users`
- `account_runtime_bindings`

Nunca confiar únicamente en que un botón esté oculto. La autorización debe existir también en backend.

## 4. Roles y operadores

Roles implementados:

- `super_admin`
- `zone_monitor`
- `operator` (zona fija, Producción y módulos preparados/asignados)

Los operadores por ciudad usan el **mismo panel**. Se les asigna zona y módulos, no una nueva página.

## 5. Regla de paridad Preview / Producción

Todo cambio funcional o backend debe validarse también en Preview con el mismo código antes del merge.

Se usa una rama temporal `preview/<slug>` como rama de validación, nunca como segunda implementación permanente.

Los cambios visuales puros pueden omitirla si no alteran comportamiento.

Leer: `docs/PREVIEW_PRODUCTION_PARITY_RULE.md`.

## 5. Identidad de conductor

La revisión de documentos e identidad está dentro de la ficha del conductor.

No recrear opciones laterales separadas de identidad.

## 6. Deploy web

Workflow:

`.github/workflows/deploy-web.yml`

Construye un solo bundle raíz.

No volver a:

- `ADMIN_ENV`;
- build `/preview/`;
- selector Preview/Producción;
- `_previewScopedModules`;
- `PREVIEW_AUTHORIZED` como selector de otro bundle.

## 7. App Builder Android

Adminexpress crea `build_jobs`. Expressdelivery/GitHub Actions compila APK/AAB.

La identidad de firma debe permanecer estable.

No regenerar keystore ni publicar Play Store sin autorización explícita.

## 8. IA / agentes

Todas las IAs autorizadas —incluyendo Claude/Cloud— pueden programar en el repositorio según `docs/AI_AGENT_POLICY.md`.

No existe una regla vigente de “Claude solo revisa”.

## 9. Documentos a leer

1. `AGENTS.md`
2. `docs/AI_HANDOFF_2026-10-11.md`
3. `docs/AI_AGENT_POLICY.md`
4. `docs/admin-central-access.md`
5. `docs/CHANGELOG_ACTIVE.md`

Los documentos marcados **HISTÓRICO / SUPERADO** no deben usarse para diseñar cambios nuevos.
