# AGENTS.md — Adminexpress

Este repositorio es el panel administrativo web de Express. Este archivo está dirigido a IAs/agentes de código y desarrolladores que necesiten editarlo sin romper Producción, Preview, App Builder o el backend compartido.

## Leer antes de editar

1. `docs/AI_HANDOFF_2026-10-04.md`
2. `docs/START_HERE_ADMINEXPRESS.md`
3. `docs/admin-preview-production.md`
4. `docs/CHANGELOG_ACTIVE.md`

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
