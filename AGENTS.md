# AGENTS.md — Adminexpress

## REGLA ABSOLUTA DEL PROPIETARIO (2026-10-12): UNA WEB + UNA APP

- **Una sola web administrativa:** https://admin.expressviajes.online/ (repositorio Adminexpress). No crear Admin Preview, sitio espejo, Vercel Preview, GitHub Pages externo ni una segunda URL para pruebas.
- **Una sola aplicación Android oficial:** Expressdelivery, package `com.express.usuario1`. No crear, compilar, desplegar ni actualizar un APK con package `com.express.usuario.preview` o `com.express.usuario.qa`.
- **Prueba y Producción son contextos internos de datos, NO aplicaciones ni despliegues independientes.** La cuenta autenticada determina el contexto en Supabase; nunca por URL, selector manual ni una APK diferente.
- Cuando se pida «probar en Preview», «subir a prueba», «ver en prueba» o similar, usar el **mismo panel/la misma app** con una cuenta de prueba y datos de prueba aislados. No interpretar esas palabras como autorización para crear otra web/aplicación.
- Cualquier cambio de esta arquitectura exige una revocación expresa de esta regla por parte del propietario, no una inferencia a partir de la palabra «Preview».
- El código publicado es compartido: proteger funciones todavía no aprobadas con controles de acceso/feature flags y reglas backend; no exponerlas a producción solo porque se despliegue el mismo bundle.
- Las ramas temporales y los PR de revisión son permitidos; no representan otra web ni otra app. Mantener CI y QA en el mismo código y probar el APK oficial firmado antes de publicarlo.
- No borrar ni relajar el aislamiento por cuenta, zona, permisos, RLS, RPC, tarifas, viajes, pedidos o liquidaciones. Mantener en servicio taxi y producción.


> **Arquitectura vigente desde 2026-10-11.**
> Este archivo es la regla principal para IAs/agentes de código y desarrolladores.
> Cualquier documento anterior que contradiga este archivo queda superado.

## Leer antes de editar

1. `docs/START_HERE_ADMINEXPRESS.md`
2. `docs/AI_HANDOFF_2026-10-11.md`
3. `docs/AI_AGENT_POLICY.md`
4. `docs/admin-central-access.md`
5. `docs/CHANGELOG_ACTIVE.md`

Los archivos marcados **HISTÓRICO / SUPERADO** sirven solo para trazabilidad.

## Política de IA

Claude/Cloud, ChatGPT, Codex y cualquier otra IA autorizada por el propietario **pueden programar y editar todo el repositorio** dentro de sus permisos técnicos reales.

No existe una regla vigente que limite a Claude/Cloud a arquitectura o revisión.

Pueden trabajar sobre:

- `lib/`, `test/`, `web/`;
- `supabase/` y migraciones;
- `.github/` y workflows;
- `docs/`;
- ramas, commits, PR y merges;
- despliegues cuando el propietario haya autorizado ese alcance.

La documentación no crea credenciales ni permisos externos. Si un agente no tiene acceso técnico, debe decirlo y no simular cambios.

## Arquitectura obligatoria

Adminexpress tiene **una sola web administrativa**:

`https://admin.expressviajes.online/`

Reglas:

- `/preview/` ya no es otro panel; solo redirige a la raíz.
- Un solo proyecto Supabase: `zgpijrznvaskgcmauwxx`.
- Preview/Producción se determina por la **cuenta autenticada**.
- No existe selector manual Preview/Producción dentro de la misma cuenta.
- No existe un build distinto con `ADMIN_ENV`.
- No volver a crear dos árboles de navegación ni dos bundles web.
- No reintroducir `_previewScopedModules`.
- No reintroducir `PREVIEW_AUTHORIZED` como mecanismo de publicación de otro bundle.

## Regla obligatoria de paridad Preview / Producción

Todo cambio **no visual** de flujo, backend, permisos, RPC, SQL, configuración o comportamiento debe quedar funcionando también en Preview antes de considerarse terminado.

- el código es único y compartido;
- para cada cambio funcional/backend se crea una rama temporal `preview/<slug>` para validar el mismo commit con datos Preview;
- esa rama NO puede convertirse en otra implementación permanente;
- si QA exige correcciones, se corrige la rama principal del cambio y Preview se vuelve a sincronizar al mismo código;
- no se acepta “Producción ahora y Preview después” salvo excepción explícita del propietario;
- cambios visuales puros quedan fuera si no alteran flujo, consultas, permisos ni acciones.

Contrato completo: `docs/PREVIEW_PRODUCTION_PARITY_RULE.md`.

## Acceso por usuario

La sesión administrativa se resuelve con:

- `admin_current_runtime_environment()`
- `admin_environment_allowed(p_channel)`
- `admin_access_context()`
- `admin_set_panel_access_v2(...)`

Tablas/campos relevantes:

- `admin_users.access_role`
- `admin_users.zone_id`
- `admin_users.allowed_modules`
- `admin_users.allow_preview`
- `admin_users.allow_production`
- `account_runtime_bindings.environment`

El usuario puede quedar ligado a:

- entorno `preview` o `production`;
- rol;
- zona/ciudad;
- módulos concretos.

No crear otra web para operadores de ciudad. Todos usan el mismo panel.

## Roles actuales

- `super_admin`: administración general.
- `zone_monitor`: acceso de zona, solo lectura y módulos operativos definidos.

Se pueden añadir nuevos roles en el mismo modelo de permisos.

## Identidad de conductor

La validación de identidad/documentos está integrada en la **ficha del conductor**.

No volver a mostrar entradas laterales separadas:

- Verificación de identidad;
- Verificación manual.

El código de componentes antiguos puede permanecer temporalmente para compatibilidad/rollback, pero no debe crear navegación duplicada.

## Backend

Supabase principal:

`zgpijrznvaskgcmauwxx`

Adminexpress comparte backend con `jorge2610g/Expressdelivery`.

La seguridad debe existir en backend/RPC; ocultar un botón no sustituye autorización.

## Módulos globales

Builds, Reportes y Auditoría siguen siendo módulos globales de Express.

Los módulos operativos pueden requerir zona/ciudad según el rol.

## App Builder

Adminexpress no compila Android dentro del navegador.

Flujo:

`Adminexpress -> build_jobs -> GitHub Actions Expressdelivery -> APK/AAB -> release`

No regenerar firma Android ni publicar Google Play sin autorización explícita.

## Secretos

Nunca guardar en Git:

- Supabase service role;
- Twilio secrets;
- Mercado Pago secrets;
- GitHub tokens;
- keystore;
- passwords de firma.

## Antes de merge

Para cambios sustanciales:

- ejecutar las validaciones disponibles;
- mantener compilación web en verde;
- validar permisos backend;
- actualizar migraciones si cambia Supabase;
- actualizar documentación vigente en la misma entrega.

## No hacer

- no volver a dos paneles;
- no decidir entorno por URL/build;
- no mezclar datos Preview/Producción fuera de las reglas del usuario;
- no dar más módulos a un operador que los autorizados;
- no activar SMS/AdMob/funciones sensibles por defecto;
- no publicar Producción o Google Play sin autorización explícita;
- no usar documentos históricos como instrucciones vigentes.
