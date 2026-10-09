## Arquitectura vigente — 2026-10-09: dos bases y dos paneles web
- **Producción:** sitio raíz, proyecto Supabase `zgpijrznvaskgcmauwxx`.
- **Preview:** sitio `/preview/`, proyecto Supabase `xbphilqezmwfjfpdbwad`.
- Mismo código y navegación, pero compilaciones Flutter independientes; se suprimió el selector Prueba/Producción dentro de cada sitio.
- El canal RPC `production` **es local a la base conectada**. En el proyecto físico Preview significa filas normales de Preview, no clientes reales ni las antiguas cuentas QA mezcladas en Producción.
- Login, sesión, permisos RLS, documentos, Storage y revisiones son independientes por proyecto. El panel Preview exige una cuenta de administrador autorizada **en Preview**, sin heredar permisos de Producción.
- Preview no habilita la promoción/publicación de Android; `productionAccess` se desactiva para Builds allí.
- Los registros antiguos de QA en Producción NO se migran ni borran automáticamente. No se han cambiado registros reales.
- Las instrucciones históricas sobre `admin_environment_config` describen el **modelo antiguo**, que no se utiliza en los dos despliegues nuevos.
- **Antes de publicar:** validar `flutter analyze`, ambos `flutter build web`, acceso Admin en cada proyecto y rechazo/corrección de selfie exclusivamente en Preview.

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
