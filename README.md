> **Continuidad 2026-10-14:** [Auditoría de código y separación de las cuatro aplicaciones](docs/EXPRESS_FOUR_APPS_CODE_AUDIT_20261014.md). Adminexpress permanece como **único panel global**; Principal conserva cinco funciones y las nuevas apps Restaurante/Repartidor están por construir, sin migración terminada. No borrar módulos de comercio o liquidaciones hasta validar reemplazos.

# Adminexpress

Panel administrativo web de **Express**.

## Arquitectura vigente

Desde 2026-10-11 existe **una sola aplicación administrativa**:

`https://admin.expressviajes.online/`

El entorno ya no depende de dos páginas distintas.

La cuenta autenticada define:

- Preview o Producción;
- rol;
- ciudad/zona;
- módulos permitidos.

Backend único:

`zgpijrznvaskgcmauwxx`

La ruta histórica `/preview/` redirige a la página principal y no contiene otro bundle Flutter.

## Acceso

La fuente de verdad del acceso es `admin_access_context()`.

El entorno efectivo lo resuelve `admin_current_runtime_environment()` usando la identidad y `account_runtime_bindings.environment`.

Los permisos se guardan en `admin_users`:

- `access_role`;
- `zone_id`;
- `allowed_modules`;
- `allow_preview`;
- `allow_production`.

Los operadores de ciudad usan el mismo panel. No se crea otra web para ellos.

## Roles actuales

- `super_admin`
- `zone_monitor`

El modelo permite añadir nuevos roles sin duplicar frontend.

## Regla de paridad

Los cambios de flujo/backend deben quedar sincronizados entre Preview y Producción en la misma entrega.

Para QA se usa una rama temporal `preview/<slug>` con **el mismo código funcional**. No mantener lógica separada por entorno.

Ver `docs/PREVIEW_PRODUCTION_PARITY_RULE.md`.

## Identidad

La revisión de identidad y documentos se realiza dentro de la **ficha del conductor**.

No volver a crear menús separados de “Verificación de identidad” o “Verificación manual”.

## Deploy

Workflow vigente:

`.github/workflows/deploy-web.yml`

Nombre:

`Deploy Adminexpress Central`

Build:

`flutter build web --release --base-href /`

No usar `ADMIN_ENV` ni construir un segundo bundle `/preview/`.

## Backend compartido

Adminexpress y la app móvil `jorge2610g/Expressdelivery` comparten Supabase.

No copiar el panel administrativo dentro del APK/AAB.

## App Builder Android

Adminexpress crea trabajos; GitHub Actions de Expressdelivery compila/firma APK y AAB.

No publicar Google Play sin validar el artefacto firmado y sin autorización explícita.

## IA / agentes

Claude/Cloud, ChatGPT, Codex y otras IAs autorizadas pueden programar y editar el repositorio completo dentro de sus permisos técnicos reales.

Ver:

- `AGENTS.md`
- `CLAUDE.md`
- `docs/AI_AGENT_POLICY.md`

## Documentación vigente

Leer en este orden:

1. `AGENTS.md`
2. `docs/START_HERE_ADMINEXPRESS.md`
3. `docs/AI_HANDOFF_2026-10-11.md`
4. `docs/admin-central-access.md`
5. `docs/CHANGELOG_ACTIVE.md`

Documentos anteriores que describan dos páginas, `ADMIN_ENV`, selector manual de entorno o Preview pinneado por SHA están superados.
