# C1 — UI inventory: Reportes, Builds, Auditoría, Verificación manual, Entornos de prueba, Carga QA, Demanda y precios

Source repo: `/home/user/adminexpress` (read-only extraction, 2026-10-10). All paths relative to `lib/`.

## 0. Environment flags (how pages are wired) — `admin_panel.dart`

- `allowPreview = adminIsPreview && access['allow_preview'] != false` (admin_panel.dart:308)
- `allowProduction = !adminIsPreview && access['allow_production'] != false` (admin_panel.dart:309)
- => In practice only ONE of includePreview/includeProduction is true at a time (follows the top panel mode selector Prueba/Producción).
- Routing (admin_panel.dart:1264-1382):
  - 10 → `AdminEnvironmentReportsPage(includePreview: allowPreview, includeProduction: allowProduction)` (:1265)
  - 12 → `AdminSingleAppReleasePage(productionAccess: allowProduction && !adminIsPreview)` (:1272)
  - 14 → `AdminEnvironmentAuditPage(includePreview, includeProduction)` (:1282)
  - 18 → `DefaultTabController(length 2)` with white `TabBar` (:1305-1333):
    - Tab 1: icon `fact_check_outlined`, text **'Revisión de documentos'** → `AdminManualIdentityPage` (:1313-1324)
    - Tab 2: icon `settings_outlined`, text **'Requisitos de identidad'** → `AdminIdentitySecurityPage` (out of scope) (:1315, :1325)
  - 20 → `AdminAuditSandboxPage(channel: adminChannel)` (:1337)
  - 21 → `AdminLoadLabPage(channel: adminChannel)` (:1339)
  - 27 → `AdminManualIdentityPage(channel, countryCode, zoneId)` (same widget as 18/tab1) (:1372)
  - 28 → `AdminDynamicPricingPage(channel, countryCode, zoneId)` (:1378)

---

## 1. Section 10 — "Reportes" — `admin_environment_reports.dart`

Colors: bg `#F1F5F9`, ink `#0F172A`, muted `#64748B`, blue `#2563EB` (:5-8).

### Header (:240-247)
- Title: **'Reportes'** (24, w900)
- Subtitle: **'Resumen general de Express. Una sola pantalla, sin cambiar el modo del panel ni seleccionar país o zona.'**

### Filters / actions row (Wrap, :249-268) — all `OutlinedButton.icon`
| Label | Icon | Behavior |
|---|---|---|
| `'Desde ' + dd/MM/yyyy` | `calendar_today_outlined` (16) | DatePicker, firstDate 2024-01-01, lastDate today; default = now − 30 days (:29, :78-92) |
| `'Hasta ' + dd/MM/yyyy` | `event_outlined` (16) | DatePicker, lastDate today+1; default now+1 day (displayed as to−1 day = today) (:30, :94-109, :260) |
| `'Actualizar'` | `refresh_rounded` (16) | reload (:262-266) |

Date format `dd/MM/yyyy` (:111-112). No country/zone selectors.

### Data
- RPC `admin_report_summary_v2(p_channel, p_from, p_to)` once per enabled channel: production first, then preview (:56-76). Never summed.

### Per-channel block (`_channelReport`, :172-213) — repeated for each channel
- Banner container (radius 12):
  - Production: bg `#E8F8EF`, accent `#14804A`, icon `verified_rounded`, title **'Actividad real de Express'**, text **'Datos reales de clientes y operaciones.'**
  - Preview: bg `#FFF7E6`, accent `#B54708`, icon `science_rounded`, title **'Actividad de pruebas internas'**, text **'Datos QA separados: no se suman a los resultados reales.'**
- Metric grid (`_metrics`, :114-170): responsive — 1 col <650px, 2 cols <1000px, else 4 cols. White Card, CircleAvatar bg `#EAF2FF` with blue icon; value (20, w900, null→0) over label (muted).

| Label | Field | Icon |
|---|---|---|
| 'Viajes' | trips_total | local_taxi_rounded |
| 'Completados' | trips_completed | task_alt_rounded |
| 'Cancelados' | trips_cancelled | cancel_outlined |
| 'Delivery' | delivery_total | local_shipping_rounded |
| 'Delivery completados' | delivery_completed | inventory_2_outlined |
| 'Delivery cancelados' | delivery_cancelled | remove_shopping_cart_outlined |
| 'Cobrado' | paid_volume (raw number, no currency formatting) | payments_outlined |
| 'Usuarios nuevos' | new_users | person_add_alt_1_rounded |
| 'Emergencias' | emergencies | sos_rounded |

No charts.

### States
- Loading: centered `CircularProgressIndicator` (:223-226)
- Error: centered `FilledButton.icon` `refresh_rounded`, label **'Reintentar: ' + error** (:227-235)
- Empty (no authorized channels): Card **'No hay entornos autorizados para consultar reportes.'** (:270-274)

---

## 2. Section 12 — "Builds" — `admin_single_app_release.dart`

Gate: `canManage = productionAccess` (:25). All mutating buttons disabled unless `canManage && !busy`.

### Header (:355-360)
- Title: **'Express · Una sola aplicación'** (23, w900)
- Subtitle: **'Desarrollo y pruebas compartidas: Web primero. Android usa lib/mobile_main.dart y se compila cuando hay una función nativa que verificar o una nueva publicación.'**

### Section cards (`_section`: white Card, title bold 17) (:293-308)

**a) 'Solo lectura'** — only if `!canManage` (:362-366)
- Text: **'Tu cuenta no tiene permiso para administrar publicaciones Android. Las compilaciones son globales para Express, sin separación por país, zona ni APK Preview.'**

**b) 'Error al consultar builds'** — only if error; red error text (:367-369)

**Loading**: `LinearProgressIndicator` while loading (:370-371)

**c) 'Flujo único Android'** (:372-418)
- Text: `'Google Play: build vigente {production_store_build|—} · siguiente {next_google_play_build|—}'`
- Text: **'Preparar APK/AAB firmado → probar ese mismo APK → certificar → aprobar → promover el mismo archivo → publicar.'**
- `FilledButton.icon` `build_rounded` **'Crear candidato Android (sin APK Preview)'** — enabled: canManage && !busy → dialog "Preparar" (§2.1)
- If candidate exists (`candidate.id != null`):
  - Candidate details block (`_details`, §2.6)
  - Status line: `'QA: {certificado|pendiente}  ·  Aprobación: {aprobado|pendiente}  ·  Promovido: {sí|no}'` (:390-392)
  - If verification.qa_notes: `'Evidencia: {qa_notes}'` (:393-394)
  - Action row (:396-415):

| Button | Type / Icon | Enabled when |
|---|---|---|
| 'Registrar pruebas Android' | Outlined / `fact_check_outlined` | canManage && !busy && status=='ready' && !promoted |
| 'Aprobar' | Outlined / `verified_outlined` | canManage && !busy && certified && !approved && !promoted |
| 'Promover APK/AAB' | Filled / `publish_outlined` | canManage && !busy && approved && !promoted |

**d) 'Publicaciones de Producción'** (:419-443)
- List: up to 15 builds from `admin_build_list` filtered platform=='android' && artifact_type=='apk+aab' (:63-70)
- Empty: **'Aún no hay APK/AAB promovidos.'**
- Per row: Divider, `_details(row)`, `OutlinedButton.icon` `cloud_upload_outlined` **'Publicar versión aprobada'** — enabled canManage && !busy && row.status=='ready' → confirm §2.5
- Footer: `TextButton.icon` `refresh` **'Actualizar estado'** (disabled while busy)

### 2.1 Dialog 'Preparar APK y AAB reales de Express' (:126-191), width 480
- Text: **'Se usará el código vigente de main, el paquete oficial com.express.usuario1 y la firma Android existente. No crea Express Preview ni publica en Google Play.'**
- TextField label **'Versión (igual a pubspec.yaml)'**, hint **'1.6.1'**, default = candidate.version_name or '1.6.1'
- TextField multiline (maxLines 3) label **'Notas del candidato'**
- Text: `'Siguiente versionCode de Google Play: {next_google_play_build|—}'`
- Actions: 'Cancelar' (Text) / **'Poner en cola'** (Filled)
- Validation: empty version → silently aborts (:186)
- Success snack: **'Candidato real en cola. No afecta el APK instalado ni Google Play.'**

### 2.2 Dialog 'Registrar pruebas Android del APK real' (:193-241), width 480
- Text: **'Instala el APK del candidato firmado y comprueba inicio, login, GPS/permisos, mapas, llamadas, notificaciones y funciones de conductor/pasajero necesarias. Registra únicamente pruebas realizadas.'**
- TextField (minLines 3, maxLines 6) label **'Evidencia de las pruebas (mínimo 30 caracteres)'**
- Actions: 'Cancelar' / **'Certificar pruebas'**
- Validation: <30 chars → silently aborts (no message) (:236)
- Success snack: **'Pruebas registradas para el SHA y los hashes de este APK/AAB.'**

### 2.3 Confirm 'Aprobar candidato Android' (:243-254)
- Body: **'Se fijarán SHA, árbol de código y SHA-256 del APK y AAB exactos que ya probaste. No se recompilará para Producción.'**
- Actions: 'Cancelar' / **'Aprobar candidato'**
- Snack: **'Candidato Android aprobado sin segunda aplicación Preview.'**

### 2.4 Confirm 'Promover APK/AAB a Producción' (:256-268)
- Body: **'Se utilizarán exactamente los mismos archivos firmados, SHA y hashes que fueron certificados. Esto reserva el versionCode de Google Play; NO publica automáticamente la actualización.'**
- Actions: 'Cancelar' / **'Promover sin recompilar'**
- Snack: **'APK/AAB promovidos sin recompilar. Queda por decidir su publicación.'**

### 2.5 Confirm 'Publicar actualización de Express' (:270-282)
- Body: **'Esta acción actualiza el canal de distribución de la aplicación. Solo puedes publicar una release de Producción que ya fue promovida.'**
- Actions: 'Cancelar' / **'Publicar versión'** (p_mandatory=false fixed; no UI for "mandatory")
- Snack: **'Actualización publicada.'**

Generic failure snack: **'No se pudo realizar la operación: {e}'** (:98). Open file failure: **'No se pudo abrir el archivo.'** (:289). Only https URLs opened.

### 2.6 Build details block (`_details`, :310-342) — used for candidate and each release
- `'Versión {version_name} · build {build_number} · {status}'` (raw status string)
- SelectableText `'Código SHA: {commit_sha}'` (12px) if present
- SelectableText `'APK SHA-256: {apk_sha256}'` (11px) if present
- SelectableText `'AAB SHA-256: {aab_sha256}'` (11px) if present
- Buttons: `OutlinedButton.icon` `android` **'Probar APK real'** (if apk_url); `file_download_outlined` **'Ver AAB'** (if aab_url). Always enabled (read-only).

---

## 3. Section 14 — "Auditoría" — `admin_environment_audit.dart`

### Header (:128-149)
- Title: **'Auditoría'** (24, w900)
- Subtitle: **'Historial general de Express, ordenado por fecha. Las acciones reales y de pruebas están identificadas en una misma pantalla.'**
- Right: `OutlinedButton.icon` `refresh_rounded` **'Actualizar'**

No filters, no search, no pagination.

### Data (:52-82)
- RPC `admin_audit_list_v2(p_channel, p_limit: 200)` per enabled channel; merged, sorted desc by created_at, capped 300 rows. Invalid response → error 'Respuesta de auditoría no válida'.

### Row (Card + ListTile, three-line, :160-204)
- Leading CircleAvatar: Preview → bg `#FFF1D6`, icon `science_rounded` color `#B54708`; Production → bg `#E8F8EF`, icon `history_rounded` color `#14804A`
- Title (w800): if entity_type=='environment_config' → **'Configuración de pruebas internas actualizada'**; else `'{action with _→space} · {entity_type with _→space}'` (fallbacks 'acción', 'registro') (:93-100)
- Subtitle line 1: `'{admin_name|Administrador} · dd/MM/yyyy · HH:mm'` (local time; '—' if invalid) ; line 2: `entity_id|—`
- Trailing pill (radius 16): **'QA'** (bg `#FFF7E6`, `#B54708`) or **'REAL'** (bg `#E8F8EF`, `#14804A`), 10px w900
- No row actions/tap.

### States
- Loading: centered spinner (:110-113)
- Error: centered FilledButton.icon **'Reintentar: {error}'** (:114-122)
- Empty: Card **'No hay acciones para los entornos autorizados.'** (muted) (:151-158)

---

## 4. Section 18 tab 1 "Revisión de documentos" + Section 27 "Verificación manual" — `admin_manual_identity.dart` + `admin_bolivia_kyc.dart`

Same widget in both entries. Params: channel, countryCode, zoneId (zoneId unused by panel).

### Page header (admin_manual_identity.dart:15-25)
- Title: **'Verificación manual'** (headlineSmall)
- Subtitle: **'Un administrador verifica el carné y la selfie. Puede aprobar, rechazar o reactivar fotografías por separado.'**
- Then `AdminBoliviaKycPanel(channel, countryCode)`

### Panel card (admin_bolivia_kyc.dart:259-310)
- Data: RPC `admin_driver_kyc_bolivia_manual_list(p_channel, p_limit 150)`, client-filtered by country_code == selected country (if any) (:49-58)
- Card title: **'Verificación manual de identidad'** (18, w900)
- Card text: **'Revisa cada fotografía del carné y la selfie por separado. Puedes reactivar rechazos por error.'**
- Counter row: **'Identidades por revisar: {N}'** (N = docs with status != 'verified') (16, w800) + `IconButton` `refresh`
- Empty: **'Aún no hay documentos para revisar.'**
- List (max 40 rows), ListTile:
  - Leading icon: `hourglass_empty` if status=='pending' else `verified_user_outlined`
  - Title: full_name or **'Conductor'**
  - Subtitle: `'Carné {document_number} · {status}'` (raw status string, not translated)
  - Trailing `chevron_right`; tap → details dialog
- No filters/search/tabs.

### States
- Loading: `LinearProgressIndicator` (:271)
- Error: Card **'No se pudieron consultar los documentos.'** + TextButton **'Reintentar'** (:265-270)

### Details dialog 'Revisión individual de identidad' (:155-257), width 690, scrollable
- Images: signed URLs (300 s) from bucket `driver-onboarding` for slots front/back/selfie.
- Header lines: `'Conductor: {full_name}'`, `'Carné: {document_number}'`, `'Identidad: {statusLabel}'` (verified→Aprobada)
- Text: **'Puedes aprobar, rechazar o reactivar cada fotografía en cualquier momento. No se exige volver a cargar una foto si el rechazo fue un error administrativo.'**
- For each slot (Divider between), heading (16, w800):
  - front → **'Frente del carné'**; back → **'Reverso del carné'**; selfie → **'Fotografía facial'** (fallback label 'Foto de perfil') (:64-69)
  - `'Estado: {label}'` — labels: approved **'Aprobada'**, rejected **'Rechazada'**, pending **'Pendiente'**, other **'Sin revisar'** (:71-76); empty status shown as Pendiente
  - `'Motivo: {reason}'` if reason
  - Image 360×200 contain, radius 10; image error **'No se pudo visualizar esta fotografía.'**; missing **'Imagen no disponible.'**
  - Buttons (only if image exists; disabled while busy):
    - `FilledButton.icon` `check_circle_outline` **'Aprobar'** — hidden if current=='approved'
    - `OutlinedButton.icon` `highlight_off` **'Rechazar'** — hidden if current=='rejected'
    - `OutlinedButton.icon` `restart_alt` **'Reactivar'** — hidden if current=='pending'
- Footer text: **'La aprobación del conductor y del vehículo es independiente de estas fotografías.'**
- Action: TextButton **'Cerrar'**

### Slot confirm dialog (:78-153)
- Title: **'Aprobar {slot}'** / **'Rechazar {slot}'** / **'Reactivar {slot}'**
- Body: `'Cambiar de {old} a {new}. Las otras fotografías no cambiarán. Una aprobación del documento NO aprueba al conductor.'`
- Only for reject: TextField (OutlineInputBorder, maxLines 2) label **'Motivo del rechazo'**
- Actions: 'Cancelar' / **'Confirmar'**
- Validation: reject with reason <5 chars → snack **'Escribe al menos cinco caracteres como motivo.'**
- Success: closes details dialog, reloads, snack `'{slot}: {status}.'`
- Error snack: **'No se pudo actualizar la fotografía: {e}. Actualiza la lista.'**
- Uses optimistic version (p_expected_version).

---

## 5. Section 20 — "Entornos de prueba" — `admin_audit_sandbox.dart`

### Production gate (channel != 'preview', :282-320)
Centered Card (max 560): icon `science_outlined` 42 muted;
- Title: **'Entornos de prueba no muestran datos en Producción'**
- Text: **'Cambia el selector superior a Prueba para administrar cuentas QA y sandboxes. Producción no carga ni muestra esos registros.'**

### Data: RPC `admin_audit_sandbox_state` → {groups[], candidates[]} (:33-37)

### States
- Loading: centered spinner
- Error card (max 520): icon `error_outline_rounded` red `#B42318`; title **'No se pudo cargar Entornos de prueba'**; error text; FilledButton.icon `refresh_rounded` **'Reintentar'** (:331-372)

### Hero (`_AuditHero`, :416-531) — gradient `#102A56→#174B91→#0D6B8D`, radius 20
- Icon tile `science_rounded` (white, 46×46)
- Title: **'Entornos de prueba'** (white, 23, w900)
- Subtitle: **'Prueba la aplicación real sin enviar solicitudes, ofertas ni notificaciones a usuarios de producción.'**
- Stat pills: **'ENTORNOS'** = groups count; **'CUENTAS QA'** = total members
- Button: `FilledButton.icon` `add_rounded` **'Nuevo entorno'** (white bg, blue text); disabled while saving
- Layout: stacked <760px, row otherwise.

### Isolation notice (`_IsolationNotice`, :592-624) — green bg `#ECFDF3`, border `#ABEFC6`, icon `verified_user_rounded`
- **'Aislamiento activo en backend: viajes, ofertas, Realtime, push, conductores cercanos y delivery solo cruzan entre cuentas del mismo entorno. Las cuentas sin entorno continúan operando normalmente en producción.'**

### Empty state (`_EmptyAuditState`, :999-1040)
- icon `science_outlined`; **'No hay entornos de prueba'**; **'Crea uno y asigna al menos un pasajero y un conductor.'**; FilledButton.icon `add_rounded` **'Crear entorno'**

### Group card (`_AuditGroupCard`, :626-818) — one per group
- Header: icon tile `science_rounded` (active: bg `#DBEAFE`/blue; paused: `#F1F5F9`/muted); name (fallback **'Entorno QA'**), slug (small muted)
- Status pill: **'AISLADO / ACTIVO'** (green) or **'PAUSADO / AISLADO'** (grey) + `Switch.adaptive` (active toggle)
- Two role columns (side by side ≥760px):

| Column title | Icon | Tone | Empty text | Add button |
|---|---|---|---|---|
| 'Pasajeros de prueba' | person_outline_rounded | #2563EB | 'Sin pasajero asignado' | 'Añadir pasajero' |
| 'Conductores de prueba' | drive_eta_rounded | #0F9F68 | 'Sin conductor asignado' | 'Añadir conductor' |

  - Column header shows member count pill.
  - Add button: `OutlinedButton.icon` `person_add_alt_1_rounded`.
- Member tile (`_MemberTile`, :917-997): avatar `person_rounded` in tone; name (or email if no name) + email line if name; status dot green `#12B76A` (enabled) / grey `#98A2B3`; `IconButton` `close_rounded` tooltip **'Quitar del entorno'**.

### Toggle snacks (:135-151)
- On: **'Entorno activado. El aislamiento está operativo.'**
- Off: **'Entorno pausado. Sus miembros siguen aislados y no reciben tráfico de producción.'**
- Error: **'No se pudo actualizar el entorno: {e}'**
- (No confirmation dialog on toggle.)

### Dialog 'Nuevo entorno de prueba' (:51-133), width 460
- TextField **'Nombre'**, hint **'Auditoría Cuba'**, autofocus; auto-fills slug (lowercase, non [a-z0-9]→'-', trimmed dashes) only while slug empty
- TextField **'Identificador'**, hint **'auditoria-cuba'**, helper **'Solo letras minúsculas, números, guion y guion bajo.'**
- Actions: 'Cancelar' / FilledButton.icon `add_rounded` **'Crear'**
- No client validation; created active=true.
- Snacks: **'Entorno de prueba creado.'** / **'No se pudo crear el entorno: {e}'**

### Dialog 'Añadir {conductor|pasajero}' (:153-239), width 520
- Pre-check: no eligible candidates (not in another group) → error snack **'No hay usuarios disponibles para asignar.'**
- Dropdown (isExpanded) label **'Cuenta de {conductor|pasajero}'**, helper **'Esta cuenta quedará aislada junto con los demás miembros del grupo.'**; items `'{full_name} · {email}'` or email
- Actions: 'Cancelar' / **'Asignar'** (disabled until selection)
- Snacks: **'Cuenta añadida al entorno de prueba.'** / **'No se pudo asignar la cuenta: {e}'**

### Dialog 'Quitar del entorno' (:241-278)
- Body: **'¿Quitar a {name|email|esta cuenta}? Al salir del sandbox volverá al alcance normal de producción.'**
- Actions: 'Cancelar' / **'Quitar'**
- Snacks: **'Cuenta retirada del entorno.'** / **'No se pudo retirar la cuenta: {e}'**

Snack colors: error `#B42318`, normal `#0F172A`.

---

## 6. Section 21 — "Carga QA" — `admin_load_lab.dart`

targetScope derived from panel channel: production → 'production', else 'sandbox' (:45-46). Not user-selectable.

### Header (:295-307)
- Title: **'Laboratorio de carga QA'** (26, w900)
- Subtitle: **'Genera conductores y solicitudes sintéticas en la ciudad QA que elijas y permite simular demanda para Express Preview. La operación real sigue centrada en Trinidad; LOADTEST y la demanda QA no alteran la tarifa real de producción.'**

### Scope banner (`_scopeBanner`, :702-744)
- Production: bg `#FFF4E5`, border `#F79009`, icon `warning_amber_rounded`: **'Producción real: los usuarios sintéticos compartirán alcance con usuarios reales y podrán aparecer en la app hasta limpiar o expirar.'**
- Sandbox: bg `#EFF6FF`, border `#93C5FD`, icon `science_rounded`: **'Prueba aislada: los usuarios sintéticos solo interactúan dentro de qa-core y no aparecen a usuarios reales.'**

### Controls card (Wrap, :311-506) — all disabled while busy
| Control | Type | Label | Options / default |
|---|---|---|---|
| Entorno | read-only InputDecorator (w220) | 'Entorno' | 'Producción (real)' (icon verified_outlined) / 'Prueba (aislado)' (icon science_outlined) |
| Ciudad | Dropdown (w200) | 'Ciudad QA' | 'Trinidad' (trinidad, default), 'Iquique' (iquique). Change resets snapshot/result and reloads |
| Servicio | Dropdown (w220) | 'Servicio QA' | 'Mixto · Auto + Moto' (mixed, default), 'Solo Auto' (car), 'Solo Moto' (motorcycle) |
| Demanda | Dropdown (w220) | 'Demanda Preview' | 'Automática (real)' (automatic, default), 'Normal · 1.00x', 'Media · 1.10x', 'Alta · 1.20x', 'Muy alta · 1.35x', 'Crítica · 1.50x' |
| — | OutlinedButton.icon `trending_up_rounded` | 'Aplicar demanda' | RPC admin_set_dynamic_pricing_qa_override(city, level, 60 min) |
| Conductores | Dropdown<int> (w180) | 'Conductores' | 10, 50, 100 (default), 250 |
| Solicitudes | Dropdown<int> (w180) | 'Solicitudes' | 10, 50, 100 (default), 250 |
| Radio | Dropdown<double> (w180) | 'Radio de prueba' | '1.5 km', '3.0 km' (default), '5.0 km' |
| — | FilledButton.icon `science_rounded` (spinner 16 while busy) | 'Crear escenario' / 'Recrear escenario' (if run active) | invokes edge fn `express-load-lab` action seed; then applies demand silently |
| — | OutlinedButton.icon `cleaning_services_rounded` | 'Limpiar prueba' | action cleanup; resets demand to automatic silently |
| — | IconButton `refresh_rounded` | tooltip 'Actualizar' | reload |

City centers: Trinidad (-14.8333, -64.9000), Iquique (-20.2307, -70.1357) (:22-25).

### Confirm dialog (only seed in production) 'Lanzar carga QA en producción' (:147-173)
- Body: **'Ciudad QA: {city}. Este escenario será visible dentro del alcance operativo real. Los {N} conductores sintéticos aparecerán online y las {M} solicitudes podrán verse en la app de producción. Los push LOADTEST seguirán desactivados. Las solicitudes expiran automáticamente y puedes usar “Limpiar prueba” en cualquier momento.'**
- Actions: 'Cancelar' / **'Lanzar en producción'**

### Notices (:507-514, `_notice` :810-826)
- Error card (red `#B42318`, 11px): friendly error text (fallback 'Operación fallida')
- Result card (green `#067647`): raw `result.toString()` (Map dump — designer should replace with formatted summary)

### Metric cards (:516-564) — 6 per row ≥760px (7 cards so wraps), else full width; icon blue, label 11 muted, value 18 w900
| Label | Value | Icon |
|---|---|---|
| 'Estado' | 'ACTIVO' / 'LIMPIO' | bolt_rounded |
| 'Entorno' | 'PRODUCCIÓN' / 'PRUEBA' (metrics.scope_mode) | layers_rounded |
| 'Ciudad' | metrics.city / run.city / selected | location_city_rounded |
| 'Demanda QA' | '{multiplier}x' if override active else 'AUTO' | trending_up_rounded |
| 'Conductores' | drivers count | drive_eta_rounded |
| 'Solicitudes' | requests count | local_taxi_rounded |
| 'Creación' | '{seed_duration_ms} ms' or '—' | speed_rounded |

### Map card (height 620, :566-669)
- OSM tiles, zoom 13.5, centered on run center or selected city
- Driver markers: blue `#2563EB` 18px circle with `two_wheeler_rounded` white icon
- Request markers: orange `#F97316` `location_on_rounded` 24px at pickup
- Attribution 'OpenStreetMap contributors'
- Overlay top-left (white 94%): `'{city} · Azul: {N} conductores · Naranja: {M} solicitudes'`

### Run summary card (:671-697)
- No run: **'No hay un escenario activo.'**
- Else: `'Run {id} · {PRODUCCIÓN|PRUEBA} · {city} · {N} conductores · {M} solicitudes. El escenario mide renderizado, Realtime, filtrado por radio y lectura masiva usando el entorno seleccionado.'`

No loading spinner for initial load (blank metrics until data).

---

## 7. Section 28 — "Demanda y precios" — `admin_dynamic_pricing.dart`

Data: if no zoneId → empty settings/cities (no message shown); else RPC `admin_dynamic_pricing_qa_state_scoped(p_zone_id, p_channel)` (:41-59).

### Header (:310-345)
- Title: **'Demanda y precios'** (26, w900)
- Subtitle: `'Precio recomendado autoritativo · {Preview|Producción}'`
- Right: `OutlinedButton.icon` `refresh_rounded` **'Actualizar'**; `FilledButton.icon` `tune_rounded` **'Configurar'** (always enabled, both channels)

### Stat tiles (w150, white, border `#E2E8F0`, :347-365, `_stat` :439-460)
| Label | Value |
|---|---|
| 'Estado' | 'Activo' / 'Apagado' |
| 'Demanda baja' | % from low_multiplier (e.g. '-10%') |
| 'Elevada' | % from elevated_multiplier |
| 'Alta' | % from high_multiplier |
| 'Crítica' | % from **max_multiplier** (note: not critical_multiplier) |
| 'Radio' | '{radius_km} km' ('-' if null) |
| 'Ventana' | '{window_minutes} min' |

% format: `round((n−1)*100)`, '+' prefix if >0, default n=1 → '0%' (:268-272).

### Safety rule card (:367-377)
- **'Regla de seguridad: el pasajero puede aumentar su oferta, pero nunca bajarla por debajo del precio recomendado vigente. El servidor vuelve a calcular el piso al crear la solicitud.'**

### Preview-only: 'Simulación QA por ciudad' (:378-431) — only if channel=='preview'
- Title **'Simulación QA por ciudad'** (18, w900)
- Text **'Solo Preview. Las simulaciones expiran automáticamente y no modifican Producción.'**
- Per city Card: title `'{city_name} · {level}'` (raw level key, e.g. 'automatic')
- OutlinedButtons (no selected state): **'Automático'**(automatic), **'Baja'**(low), **'Normal'**, **'Media'**(medium), **'Alta'**(high), **'Muy alta'**(very_high), **'Crítica'**(critical) → RPC override 60 min
- Snacks: **'Demanda automática restaurada.'** / `'Simulación {level} activa por 60 minutos.'` / error raw
- Note: Carga QA offers no 'low' level; this page does.

### Dialog 'Demanda dinámica · {Preview|Producción}' (:80-239), width 720, scrollable
- `SwitchListTile` **'Activar precio por demanda'**, subtitle **'El servidor recalcula el precio recomendado y aplica el piso mínimo.'** (default from settings.enabled)
- Divider, then numeric TextFields (keyboard numberWithOptions(decimal:true), no units/hints/validation; invalid → null sent):

| Row | Label | Key | Default |
|---|---|---|---|
| 1 | 'Ratio demanda baja' | low_ratio | 0.5 |
| 1 | 'Multiplicador baja' | low_multiplier | 0.9 |
| 1 | 'Conductores mín. baja' | low_min_drivers (int) | 2 |
| 2 | 'Radio km' | radius_km | 0.75 |
| 2 | 'Ventana minutos' | window_minutes (int) | 5 |
| 2 | 'Solicitudes mín.' | min_requests (int) | 3 |
| 3 | 'Ratio elevada' | elevated_ratio | 1.2 |
| 3 | 'Ratio alta' | high_ratio | 2.0 |
| 3 | 'Ratio crítica' | critical_ratio | 3.0 |
| 4 | 'Mult. elevada' | elevated_multiplier | 1.1 |
| 4 | 'Mult. alta' | high_multiplier | 1.2 |
| 4 | 'Mult. crítica' | critical_multiplier | 1.35 |
| 4 | 'Máximo' | max_multiplier | 1.5 |

- Actions: 'Cancelar' / **'Guardar'** → RPC `admin_update_dynamic_pricing_settings` (p_channel + all 13 fields + enabled)
- Snacks: **'Demanda dinámica actualizada.'** / raw error. No confirmation for Production save.

### States
- Loading: centered spinner; Error: FilledButton.icon `refresh_rounded` **'Reintentar'** (no error text)
- No zone selected: page renders with default/'-' stats and no cities (no explicit empty text).

---

## Designer notes (gaps observed, not changes)
- Reportes 'Cobrado' has no currency formatting; no charts on any of these screens.
- Builds certify dialog silently ignores <30 chars; queue dialog silently ignores empty version.
- Carga QA result notice prints a raw Map.
- Demanda y precios: 'Crítica' tile shows max_multiplier; no empty state when zone missing; Production config save has no confirm.
- Verificación manual list subtitle shows raw status (e.g. 'pending'), not translated.
