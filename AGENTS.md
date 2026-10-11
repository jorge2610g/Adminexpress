> **ROLES 2026-10-10:** Claude = arquitecto, controlador y revisor (**no programa**, ver `CLAUDE.md`); Codex/ChatGPT/otra IA = programador. Flujo: `jorge2610g/Expressdelivery` → `docs/AI_ROLES_WORKFLOW.md`.
>
> **Backend endurecido 2026-10-10 (leer antes de tocar RPC):** en Supabase
> `zgpijrznvaskgcmauwxx`, toda RPC `admin_*` **sin `p_channel`** (lectura o
> escritura) exige ahora `allow_production` → un admin Preview-only recibe
> `No autorizado para el entorno production`. Funciones internas
> (`admin_set_driver_approval`, `admin_user_detail`, `admin_driver_detail`,
> `admin_trip_detail`, `admin_upsert_zone_v3`, …) ya no se llaman desde el
> cliente: usar `*_v2` con `p_channel`. En Preview, escribir solo vía
> `AdminEnvironmentStore.previewUpsert` (`admin_environment_config_upsert`, que
> valida el entorno). Edge Functions `zone-payment-admin` y
> `driver-subscription-admin` exigen permiso de Producción. Aprobar las 3 fotos
> de identidad aprueba al conductor automáticamente (respuesta
> `driver_auto_approved`). Nuevos admins nacen con `allow_production=false`.
> Detalle: `jorge2610g/Expressdelivery` → `docs/AI_HANDOFF_2026-10-10_SECURITY_AUDIT.md`.
>
## Arquitectura obligatoria — 2026-10-09: dos páginas en Supabase principal
- Producción (`/`): Supabase `zgpijrznvaskgcmauwxx`, canal `production`.
- Preview (`/preview/`): **el mismo** Supabase `zgpijrznvaskgcmauwxx`, canal `preview`.
- `ADMIN_ENV` es inmutable por compilación y determina la página/canal, nunca la base de datos.
- Queda prohibida la conexión de Adminexpress con el proyecto secundario antiguo `xbphilqezmwfjfpdbwad`; no borrarlo ni migrarlo.
- Los usuarios QA se identifican por `account_runtime_bindings.environment='preview'` y las RPC operativas toman `p_channel='preview'`, con `admin_assert_target_environment`.
- Configuración QA usa `admin_environment_config` con entorno preview; zonas, servicios, tarifas y ajustes jamás deben escribir registros reales.
- **IMPORTANTE:** tener dos páginas no aísla un RPC sin parámetro de entorno. El guard `_previewScopedModules` bloquea módulos no auditados antes de ejecutar sus llamadas. No quitarlo para recuperar funcionalidad sin RPCs con aislamiento comprobado.
- Builds, pagos, billetera, suscripciones, marketplace y otras funciones no auditadas se bloquean desde Preview.
- Mantener la UI y rutas de Producción, firmas Android y datos reales sin cambios; publicar exclusivamente la página Preview hasta que se valide.
- Validar `flutter analyze`, ambos `flutter build web`, consulta/revisión QA real y ausencia de escrituras Production en tests de aislamiento.

---

> **Regla global confirmada 2026-10-08:** las secciones `Reportes` (10),
> `Builds` (12) y `Auditoría` (14) son únicas a nivel de Express, **sin**
> selector Prueba/Producción ni obligación país/zona. Builds requiere permiso
> `allow_production` para crear/aprobar/publicar; Reportes y Auditoría
> consultan simultáneamente solo los entornos autorizados, mostrando los
> datos QA separados o con etiquetas. **NO** aplicar esta excepción a Viajes,
> Usuarios, Conductores, Configuración, Laboratorio QA ni otras funciones
> operativas: deben seguir aisladas por canal y geografía.
> Revisar `docs/CHANGELOG_ACTIVE.md` antes de cambiar navegación.
>
# AGENTS.md — Adminexpress

Este repositorio es el panel administrativo web de Express. Este archivo está dirigido a IAs/agentes de código y desarrolladores que necesiten editarlo sin romper Producción, Preview, App Builder o el backend compartido.

## Leer antes de editar

1. `docs/AI_HANDOFF_2026-10-04.md`
2. `docs/START_HERE_ADMINEXPRESS.md`
3. `docs/admin-preview-production.md`
4. `docs/CHANGELOG_ACTIVE.md`
5. `docs/FLOATING_DRIVER_OFFERS_ADMIN.md` — control Admin de ofertas sobre otras apps

El handoff de 2026-10-04 es el estado más reciente y prevalece sobre documentación histórica contradictoria.

## Responsabilidad

Adminexpress contiene:
- Dashboard
- Viajes
- Delivery
- Conductores
- Usuarios
- Seguridad/SOS
- Zonas
- Tarifas
- Pagos/Billetera
- Suscripciones
- Reportes
- Configuración
- Despacho
- Auditoría
- Laboratorio QA
- App Builder
- release/Preview/Producción

La app pasajero/conductor vive en `jorge2610g/Expressdelivery`.

Nunca copiar el panel de vuelta al APK.

## Backend

Supabase ref correcto:

`zgpijrznvaskgcmauwxx`

Comparte backend con Expressdelivery.

## Regla Preview / Producción

Existe UNA sola UI.

El selector:
- Producción
- Prueba

solo cambia la capa de datos/canal.

No crear árboles separados de navegación ni páginas duplicadas por entorno.

Preview nunca debe escribir configuración/datos operativos reales de Producción.

Workflow de validación:

`.github/workflows/validate-preview-production-split.yml`

Debe seguir en verde.

## SMS

Configuración > Seguridad contiene switches independientes:

- Verificación SMS · Pasajeros
- Verificación SMS · Conductores

Ambos OFF por defecto.

No activarlos automáticamente al desplegar.

Se activarán cuando el proveedor SMS/Twilio esté configurado.

## QA load lab

Archivo UI:

`lib/admin_load_lab.dart`

Edge Function vive en Expressdelivery:

`supabase/functions/express-load-lab/index.ts`

El panel debe ofrecer:

- entorno Prueba / Producción
- ciudad
- servicio QA:
  - Mixto · Auto + Moto
  - Solo Auto
  - Solo Moto
- conductores
- solicitudes
- radio
- demanda
- Crear escenario
- Limpiar prueba

El backend usa:
- Preview -> channel preview
- Producción -> channel production
- Iquique -> CLP
- Trinidad -> BOB

No volver a generar todo como Moto.

## App Builder

No compila localmente en navegador.

Crea `build_jobs` y Expressdelivery/GitHub Actions compila.

Regla crítica:

Producción solo desde el mismo SHA del Preview aprobado.

No saltarse `app_release_gate`.

## Branding

La marca global debe decir **Express**.

No volver a poner “Express Delivery” como nombre global del panel. “Delivery” solo para el módulo de delivery.

Usar el logo oficial.

## Secretos

Nunca guardar:
- Supabase service role
- Twilio secrets
- Mercado Pago secrets
- GitHub tokens
- keystore
- passwords de firma

## Antes de merge

- `flutter analyze`
- build web
- Validate Admin Preview Production Split
- revisar Preview/Producción
- actualizar documentación si cambia una regla operativa

## No hacer

- no mezclar Preview con Producción
- no activar SMS por defecto
- no regenerar firma Android
- no construir Producción desde SHA distinto al Preview aprobado
- no usar pasarela administrativa para cobrar viajes normales
- no simplificar el laboratorio QA borrando aislamiento
- no ocultar errores backend como `[object Object]`
