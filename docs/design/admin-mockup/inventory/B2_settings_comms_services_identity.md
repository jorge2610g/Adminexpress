# B2 — UI inventory: Configuración (11), Configuración avanzada (19), Notificaciones / Avisos (15), Servicios (16), Verificación de identidad · tab 2 (18)

Repo: `/home/user/adminexpress` (Flutter Web). Read-only extraction, 2026-10-10.
Abbreviation: `ACS` = `lib/admin_control_sections.dart`; `AP` = `lib/admin_panel.dart`.

---

## 0. Shell context shared by all five screens

### 0.1 Navigation entries (AP:266-296, `sections` list)
| Index | Nav label (exact) | Nav icon |
|---|---|---|
| 11 | `Configuración` | `Icons.settings_rounded` |
| 15 | `Notificaciones / Avisos` | `Icons.notifications_active_rounded` |
| 16 | `Servicios` | `Icons.apps_rounded` |
| 18 | `Verificación de identidad` | `Icons.verified_user_rounded` |
| 19 | `Configuración avanzada` | `Icons.tune_rounded` |

The top bar title (`_TopBar(title: sections[section].$1)`, AP:1134) shows the nav label. Below it: environment switcher (Prueba / Producción) and, because none of these sections is global (`_globalSections = {10,12,14}`, AP:241), the global country/zone scope switcher (AP:1145-1146).

### 0.2 Section gating (AP:1177-1201) — designer must draw these states
1. **Preview blocked** — only sections `{0,1,2,3,4,5,6,7,8,10,11,14,16,17,18,27}` run in Prueba (AP:244-246). So **15 (Notificaciones / Avisos) and 19 (Configuración avanzada) are blocked in Prueba**, even though their code has preview branches. Centered text (AP:1184-1188):
   > `Este módulo todavía no tiene aislamiento seguro por canal. Está bloqueado en Prueba para proteger los datos reales. Puedes gestionar conductores, documentos, viajes y configuración QA desde sus secciones.`
2. **Scope required** (all five sections; AP:1194-1195, `_ScopeSelectionRequired` AP:2146-2186): icon `filter_alt_outlined` 46px, title `Selecciona país y zona`, text `No se cargarán usuarios, viajes, conductores ni métricas hasta elegir el ámbito.` (Note: also applies to Configuración/Configuración avanzada although those settings are global.)
3. **Zone monitor restricted** (role `zone_monitor`, all five sections; AP:1198-1201, 2188-2222): icon `lock_outline_rounded` 44px, title `Módulo reservado al administrador global`, text `El monitor de zona tiene acceso operativo de solo lectura.`

### 0.3 Channels
- `channel` is `'preview'` or `'production'`; `AdminEnvironmentStore` (`lib/admin_environment_store.dart:13-125`) throws `Canal administrativo inválido: operación bloqueada` on any other value (:20-24).
- Preview writes go to the QA shadow via RPCs `admin_environment_config_list / _get / _upsert` with `p_environment:'preview'`, `p_module`, `p_record_key`, `p_payload` (:35-101); soft delete = upsert with `_deleted:true, active:false` (:103-113).
- `AdminRuntimeScope` (`lib/admin_runtime_scope.dart:26-61`): env labels `Producción` / `Prueba` (:12-15); page subtree is re-keyed on `channel:country:zone` (AP:1149-1162), so every page reloads when env/country/zone change.
- `lib/admin_preview_config_sections.dart` (`AdminPreviewModulePage`) is **not referenced anywhere** (dead code) — not part of these screens.

### 0.4 Shared building blocks (ACS)
| Widget | Visual | Lines |
|---|---|---|
| `_Header(title, subtitle, action?)` | Gradient banner (#102A56→#174B91→#0D6B8D), radius 20, 42px white-tinted square with `dashboard_customize_rounded`; title 23 w900 white; subtitle 11 #D7E7FA; optional action button at right (stacks below when width < 680) | 8962-9081 |
| `_AdminHero(icon, title, subtitle, stats[(label,value)])` | Gradient card (#0B57D0→#5B74F5) radius 18; 48px icon tile; title 19 w900; stat pills (value 16 w900 over label 9); stats wrap below when width < 780 | 3889-4010 |
| `_AdminModuleCard(icon, title, subtitle, accent, chips, onTap)` | White tappable card radius 16; 42px accent-tinted icon tile; `arrow_forward_ios_rounded` at right if tappable; title 15 w900; subtitle 10 muted max 3 lines; pill chips 8.5 w700 | 4012-4105 |
| `_SettingsCard(title, subtitle?, children)` | White card radius 16; 40px #EAF2FF tile with icon chosen by title keyword (`_settingsIcon`, 9258-9266: "pago"→`account_balance_wallet_outlined`; "servicio"/"módulo"→`apps_rounded`; "operación"/"dispatch"→`alt_route_rounded`; "tarifa"/"alcance"→`payments_outlined`; "soporte"/"localización"→`support_agent_rounded`; else `tune_rounded`) ; divider; children | 9176-9256 |
| `_InlineNotice(icon, text)` | #F7F9FC box, blue icon 20, muted text 10 | 8931-8959 |
| `_NumberField(label)` | `TextField`, keyboard `numberWithOptions(decimal:true, signed:true)`, label only, no validators | 9154-9174 |
| `_ReadOnlyRow(label, value)` | label muted 11 left, value w800 right | 9268-9304 |
| `_MiniStatus(text, positive)` | Pill; positive = green #E8F8EF/#14804A, else grey #F2F4F7/#667085; 9 w900 | 9404-9435 |
| `_Empty(text)` | Flat card, padding 28, muted text | 9437-9451 |
| `_Loading(title)` | Title 25 w900 + `LinearProgressIndicator` | 9453-9474 |
| `_Error(error, onRetry)` | Centered card, `error_outline_rounded` 46, raw error text, button `Reintentar` (`refresh_rounded`) | 9476-9509 |
| `_snack(error)` | SnackBar `Error: <error>` | 9528-9532 |
| `_num()` parses with `,`→`.` | | 9524-9526 |
| `_formatDate` → `dd/MM/yyyy · HH:mm` local, `—` if null | | 9545-9561 |

---

## 1. Section 11 — `AdminSettingsPage` ("Configuración")
ACS:7648-8193. Constructor: `channel` only (no country/zone). Embedded at AP:1269-1270.

### 1.1 Load / save
- Loading: `_Loading(title: 'Cargando configuración')` (ACS:7900).
- Load: Preview → `previewGet('app_settings')` (record `default`); Production → RPC `admin_settings_get` (ACS:7734-7736). Load error → snackbar `Error: …` (ACS:7769-7774).
- Save (ACS:7784-7875): one global save for tabs 0-6.
  - Preview → `previewUpsert('app_settings','default', next)` (ACS:7817-7819).
  - Production → RPC `admin_settings_update` (params below) **then** RPC `admin_phone_verification_settings_update` with `p_passenger_enabled`, `p_driver_enabled` (ACS:7821-7853).
  - Success snackbar: `Configuración guardada.` (ACS:7859). Error: `Error: …`.
- Reload on channel change (ACS:7709-7726).

### 1.2 Header (ACS:8129-8142)
- Title `Configuración`; subtitle `Administra los parámetros generales de Express Delivery.`
- Action: `FilledButton.icon` label `Guardar configuración`, icon `save_outlined` 18 (spinner 16px while saving). **Disabled** when loading, saving, or on tab `Admin` (index 7) (ACS:8133).

### 1.3 Tab strip (ACS:7902-7911, 8144-8187)
Custom horizontal pill strip (white container radius 12; selected pill bg #EAF2FF, text blue w900; unselected muted w700; font 11). Tabs in order:
`General` · `Servicios` · `Pagos` · `Operación` · `Tarifas` · `Soporte` · `Seguridad` · `Admin`

### 1.4 Tab 0 — `General` (default; ACS:8090-8123)
Card **`Módulos`** — subtitle `Configuración rápida de la plataforma.`
| Label | Type | Key (default) |
|---|---|---|
| `Taxi habilitado` | switch | `ride_enabled` (true unless false) |
| `Delivery habilitado` | switch | `delivery_enabled` (true unless false) |
(Same state as tab Servicios — duplicated controls.)

Card **`Resumen operativo`** — subtitle `Parámetros principales de la empresa.` (read-only rows)
| Label | Value |
|---|---|
| `Empresa` | `Express Delivery` (hard-coded) |
| `País` | current `default_country` text |
| `Moneda` | current `currency` text |
| `Dispatch` | raw `dispatch_mode` value (`broadcast`/`progressive`/`manual`) |

### 1.5 Tab 1 — `Servicios` (ACS:7915-7937)
Card **`Servicios`** — subtitle `Activa o desactiva verticales sin eliminar sus datos.`
| Title | Subtitle | Type | Key → RPC param |
|---|---|---|---|
| `Taxi / Viajes habilitados` | `Permite solicitar viajes desde Express Rider.` | switch | `ride_enabled` → `p_ride_enabled` |
| `Delivery habilitado` | `Permite crear y operar entregas.` | switch | `delivery_enabled` → `p_delivery_enabled` |

### 1.6 Tab 2 — `Pagos` (ACS:7938-7965)
Card **`Métodos de pago`** — subtitle `Controla qué medios pueden usar los clientes.`
| Title | Type | Key (default) → param |
|---|---|---|
| `Efectivo` | switch | `allow_cash` (true unless false) → `p_allow_cash` |
| `Tarjeta` | switch | `allow_card` (false) → `p_allow_card` |
| `Billetera Express` | switch | `allow_wallet` (false) → `p_allow_wallet` |

### 1.7 Tab 3 — `Operación` (ACS:7966-8000)
Card **`Operación y dispatch`** — subtitle `Define cómo se distribuyen las solicitudes a conductores.`
| Label | Type | Options / default | Key → param |
|---|---|---|---|
| `Modo de dispatch` | dropdown | `Broadcast` (`broadcast`, default), `Progresivo` (`progressive`), `Manual` (`manual`) | `dispatch_mode` → `p_dispatch_mode` |
| `Radio inicial de dispatch km` | number | default 5 (fallback 5) | `dispatch_radius_km` → `p_dispatch_radius_km` |
| `Aumento progresivo de radio km` | number | default 2 (fallback 2) | `progressive_radius_step_km` → `p_progressive_radius_step_km` |
| `Duración de oferta en segundos` | number (int.tryParse) | default 45 (fallback 45) | `offer_timeout_seconds` → `p_offer_timeout_seconds` |

### 1.8 Tab 4 — `Tarifas` (ACS:8001-8020)
Card **`Tarifas globales y alcance`** — subtitle `Valores generales antes de aplicar reglas por servicio o zona.`
| Label | Type | Default (fallback on save) | Key → param |
|---|---|---|---|
| `Mínimo Viaje` | number | 5 (0) | `min_ride_fare` → `p_min_ride_fare` |
| `Mínimo Delivery` | number | 5 (0) | `min_delivery_fare` → `p_min_delivery_fare` |
| `Comisión global %` | number | 0 (0) | `commission_percent` → `p_commission_percent` |
| `Radio máximo km` | number | 30 (30) | `service_radius_km` → `p_service_radius_km` |
| `Moneda` | text | `BOB` | `currency` → `p_currency` |

### 1.9 Tab 5 — `Soporte` (ACS:8021-8047)
Card **`Localización y soporte`** — subtitle `Datos regionales y canales de atención.`
| Label | Type | Default | Key → param |
|---|---|---|---|
| `Zona horaria` | text | `America/Santiago` | `timezone` → `p_timezone` |
| `País` | text | `Chile` | `default_country` → `p_default_country` |
| `Teléfono de soporte` | text | empty | `support_phone` → `p_support_phone` |
| `WhatsApp de soporte` | text | empty | `support_whatsapp` → `p_support_whatsapp` |

### 1.10 Tab 6 — `Seguridad` (ACS:8048-8086)
Card **`Verificación de teléfono por SMS`** — subtitle `Control independiente para pasajeros y conductores. Preview prueba el proveedor; Producción solo aplica el bloqueo después de una OTP real confirmada.`
- `_InlineNotice` (state from `sms_provider_verified_at`):
  - verified → icon `verified_rounded`, text `Proveedor SMS verificado con OTP real. Producción puede aplicar la exigencia según los switches de abajo.`
  - not verified → icon `sms_outlined`, text `Proveedor SMS pendiente de prueba real. Preview exige OTP; Producción permanece en modo seguro y no bloqueará usuarios hasta que una OTP se confirme correctamente.`
| Title | Subtitle | Type | Key → RPC |
|---|---|---|---|
| `Verificación SMS · Pasajeros` | `Exige teléfono verificado antes de solicitar viajes.` | adaptive switch | `sms_verification_passenger_enabled` (false) → `admin_phone_verification_settings_update.p_passenger_enabled` |
| `Verificación SMS · Conductores` | `Exige teléfono verificado para conectarse y enviar ofertas.` | adaptive switch | `sms_verification_driver_enabled` (false) → `…p_driver_enabled` |

(In Preview these two keys are stored in the `app_settings` shadow payload.)

### 1.11 Tab 7 — `Admin` → embeds `AdminAdMobSettingsPage` (ACS:8087-8088)
File `lib/admin_admob_settings.dart:8-285`. Page header save button is disabled here; the panel has its own save.
- Loading: centered `CircularProgressIndicator` (:174-179).
- Load RPC `admin_admob_settings_get` `{p_channel}` (:52-55). Bad payload: `Respuesta de anuncios no válida`; error text (red, inline): `No se pudo cargar la configuración: <error>` (:59, :73).
- Card (:180-283):
  - Header row: icon `admin_panel_settings_outlined` (#2563EB), title `Admin · Publicidad (Google AdMob)` (20 w800), right `Chip` `PRUEBA` / `PRODUCCIÓN`.
  - Description: Preview `Solo anuncios de prueba de Google. Ningún cambio modifica las credenciales ni la publicidad de Producción.`; Production `Administra los anuncios de pasajeros y los ID públicos de tu cuenta AdMob. Los anuncios reales siguen apagados hasta activarlos y tener una APK configurada.`
  - Switches (disabled while saving):
    | Title | Subtitle | Key → param |
    |---|---|---|
    | `Activar anuncios de Prueba` / `Activar anuncios de Producción` | `Interruptor general: apagarlo oculta todos los anuncios de pasajeros.` | `enabled` (false) → `p_enabled` |
    | `Mostrar en Inicio` | — | `home_enabled` (true) → `p_home_enabled` |
    | `Mostrar durante un viaje` | — | `trip_enabled` (true) → `p_trip_enabled` |
  - Preview only: text `Preview usa las unidades oficiales de prueba de Google. No necesitas colocar identificadores reales aquí.`
  - Production only: subheading `Credenciales públicas / identificadores AdMob`, then three outlined text fields (helper on each: `ID público de AdMob. No introduzcas contraseñas ni tokens.`; autocorrect off):
    | Label | Hint | Key → param |
    |---|---|---|
    | `ID de editor (Publisher ID)` | `pub-1234567890123456` | `admob_publisher_id` → `p_publisher_id` |
    | `ID de aplicación Android (App ID)` | `ca-app-pub-1234567890123456~1234567890` | `admob_android_app_id` → `p_android_app_id` |
    | `ID de unidad Banner (Ad Unit ID)` | `ca-app-pub-1234567890123456/1234567890` | `admob_passenger_banner_unit_id` → `p_banner_unit_id` |
    - Warning card (#FFF7E6): `Importante: guardar el App ID aquí no cambia el AndroidManifest de una APK instalada. Para anuncios reales se necesita compilar una versión de Express con el mismo App ID y configurar el ID de Banner en el build o en la configuración remota compatible. No compartas claves secretas de Google, OAuth ni credenciales de pago.`
  - Button (right-aligned): `Guardar publicidad`, icon `save_outlined` (spinner 17 when saving).
- Save RPC `admin_admob_settings_update` `{p_channel, p_enabled, p_home_enabled, p_trip_enabled, p_android_app_id, p_banner_unit_id, p_publisher_id}`; in Preview the three IDs are sent as `null` (:96-108).
- Validation (Production + enabled + any ID empty): inline red `Antes de activar Producción, introduce los tres ID de Google AdMob.` (:84-91).
- Success snackbar: `Publicidad de Prueba guardada. Activada.` / `… Desactivada.` / `Publicidad de Producción guardada. …` (:121-128). Error inline: `No se pudieron guardar los anuncios: <error>`.

### 1.12 Production `admin_settings_update` param list (ACS:7821-7843)
`p_currency, p_min_ride_fare, p_min_delivery_fare, p_commission_percent, p_service_radius_km, p_allow_cash, p_allow_card, p_allow_wallet, p_ride_enabled, p_delivery_enabled, p_dispatch_mode, p_dispatch_radius_km, p_offer_timeout_seconds, p_progressive_radius_step_km, p_timezone, p_default_country, p_support_phone, p_support_whatsapp`.
Note: after Production save, `settings` is replaced by the phone-settings RPC result only (ACS:7853) — the redesign should not rely on that local cache.
No field-level validation messages exist on this page (bad numbers silently fall back to the defaults listed).

---

## 2. Section 19 — `AdminAdvancedSettingsPage` ("Configuración avanzada")
ACS:8196-8928. Constructor: `channel`. Embedded AP:1334-1335. **Blocked in Prueba by shell gating** (see 0.2), so in practice Production only.

### 2.1 Load / save
- Loading `_Loading(title: 'Cargando configuración avanzada')`; error `_Error` + `Reintentar` (ACS:8810-8815).
- Load: Preview `previewGet('app_settings')`; Production RPC `admin_settings_get` (ACS:8214-8220).
- Save (every dialog): Preview `previewUpsert('app_settings','default', merged)`; Production RPC `admin_advanced_settings_update` with the **full** param set (ACS:8227-8259):
  `p_allow_pagorut, p_allow_mercadopago, p_allow_santander, p_allow_mach, p_allow_tenpo, p_search_timeout_seconds(180), p_request_visible_seconds(180), p_scheduled_rides_enabled(true), p_scheduled_publish_before_minutes(30), p_max_driver_request_radius_km(15), p_max_visible_requests_driver(20), p_allow_counteroffers(true), p_min_driver_offer(1), p_max_driver_offer(9999), p_chat_enabled(true), p_calls_enabled(true), p_share_trip_enabled(true), p_sos_enabled(true), p_saved_places_enabled(true), p_ratings_enabled(true), p_rating_comment_enabled(true), p_rating_min(1), p_rating_max(5), p_maintenance_mode(false), p_maintenance_message, p_minimum_app_version`.
- Success snackbar `Configuración avanzada guardada.` (ACS:8264). Errors are not caught in `_save` (unhandled).

### 2.2 Header + hero (ACS:8828-8844)
- `_Header` title `Configuración avanzada`, subtitle `Controla funciones de la app sin modificar código ni generar un APK por cada cambio.` (no action).
- `_AdminHero` icon `tune_rounded`, title `Centro de control`, subtitle `Cambios operativos centralizados para pasajero, conductor y administración.` Stats:
  - `Respaldo pagos` = count of true among the 5 legacy payment flags
  - `Ofertas` = `Activas` / `Off`
  - `Mantenimiento` = `Activo` / `Normal`

### 2.3 Module cards grid (ACS:8846-8921)
Responsive wrap: 1 col < 720px, 2 cols < 1120px, else 3. Each card opens a dialog.
| # | Icon | Title | Subtitle | Accent | Chips |
|---|---|---|---|---|---|
| 1 | `account_balance_wallet_outlined` | `Compatibilidad de pagos` | `Respaldo global para versiones antiguas. La configuración vigente está en Zonas y Pagos / Billetera.` | #6941C6 | `<n> respaldos activos`, `No define la zona` |
| 2 | `radar_rounded` | `Búsqueda y ofertas` | `Tiempos, radio, viajes programados y contraofertas.` | blue | `<search_timeout_seconds> s`, `<max_driver_request_radius_km> km` |
| 3 | `health_and_safety_outlined` | `Seguridad del viaje` | `SOS, compartir viaje, chat, llamadas y lugares guardados.` | #0E9384 | `SOS activo`/`SOS off`, `Compartir activo`/`Compartir off` |
| 4 | `star_outline_rounded` | `Calificaciones` | `Política privada de estrellas y comentarios.` | #F79009 | `Activas`/`Inactivas`, `<min>–<max> ★` |
| 5 | `construction_rounded` | `Mantenimiento` | `Bloqueo temporal y versión mínima permitida.` | #D92D20 if active else #667085 | `Mantenimiento activo`/`Operación normal`, `Min v<x>`/`Sin versión mínima` |

All dialogs: actions `Cancelar` (TextButton) + `Guardar` (FilledButton).

### 2.4 Dialog — `Compatibilidad de pagos · legado` (ACS:8269-8347), width 520
- Notice (icon `payments_outlined`): `Estos interruptores son solo respaldo para versiones antiguas de Express. Los métodos reales se administran por zona en Zonas y Pagos / Billetera. No uses esta pantalla para decidir qué método aparece en una ciudad.`
| Switch title | Key (default false) |
|---|---|
| `QR Bolivia / PagoRUT · legado` | `allow_pagorut` |
| `Mercado Pago` | `allow_mercadopago` |
| `Santander` | `allow_santander` |
| `MACH` | `allow_mach` |
| `Tenpo` | `allow_tenpo` |

### 2.5 Dialog — `Búsqueda y ofertas` (ACS:8349-8457), width 620, scrollable
- Notice (icon `radar_rounded`): `Estos valores controlan cuánto dura la búsqueda, cuántas solicitudes ve el conductor y el rango de ofertas.`
- Fields (two-column rows):
| Label | Type | Default | Key |
|---|---|---|---|
| `Búsqueda máxima · segundos` | number (int) | 180 | `search_timeout_seconds` |
| `Solicitud visible · segundos` | number (int) | 180 | `request_visible_seconds` |
| `Radio máx. conductor · km` | number | 15 | `max_driver_request_radius_km` |
| `Máx. solicitudes visibles` | number (int) | 20 | `max_visible_requests_driver` |
| `Oferta mínima` | number | 1 | `min_driver_offer` |
| `Oferta máxima` | number | 9999 | `max_driver_offer` |
| `Publicar viaje programado antes · minutos` | number (int), full width | 30 | `scheduled_publish_before_minutes` |
| `Viajes programados` | switch | true | `scheduled_rides_enabled` |
| `Permitir contraofertas` | switch | true | `allow_counteroffers` |
No validation (min ≤ max not enforced).

### 2.6 Dialog — `Funciones de seguridad y contacto` (ACS:8459-8537), width 520
| Switch title | Leading icon | Key (default true) |
|---|---|---|
| `Botón SOS` | `sos_rounded` | `sos_enabled` |
| `Compartir viaje` | `share_location_outlined` | `share_trip_enabled` |
| `Chat pasajero ↔ conductor` | `chat_bubble_outline_rounded` | `chat_enabled` |
| `Llamadas` | `call_outlined` | `calls_enabled` |
| `Lugares guardados` | `bookmark_outline_rounded` | `saved_places_enabled` |

### 2.7 Dialog — `Calificaciones` (ACS:8539-8627), width 520
- Notice (icon `star_outline_rounded`): `Las calificaciones continúan siendo privadas. Aquí solo controlas la política general.`
| Label | Type | Options/default | Key |
|---|---|---|---|
| `Calificaciones habilitadas` | switch | true | `ratings_enabled` |
| `Permitir comentario` | switch | true | `rating_comment_enabled` |
| `Mínimo` | dropdown | 1–5, default 1 | `rating_min` |
| `Máximo` | dropdown | 1–5, default 5 | `rating_max` (silently raised to min if lower) |

### 2.8 Dialog — `Mantenimiento y versión mínima` (ACS:8629-8802), width 580, scrollable
Pre-load: RPC `admin_build_list` (errors ignored); options = distinct `version_name` of builds with `platform=='android'` and `status=='ready'`, sorted by `build_number` desc; current minimum appended if not present (ACS:8635-8676).
| Label | Type | Details | Key |
|---|---|---|---|
| `Modo mantenimiento` | switch | subtitle `Úsalo solo cuando quieras bloquear temporalmente la operación.`; default false | `maintenance_mode` |
| `Mensaje de mantenimiento` | text, 3 lines | hint `Estamos actualizando Express. Vuelve en unos minutos.` | `maintenance_message` |
| `Versión mínima permitida` | dropdown | helper `Las versiones inferiores a la elegida quedan bloqueadas.`; options: `Permitir todas las versiones` (value `''`), newest: `v<x> · Bloquear todas las anteriores`, others: `v<x> · build <n>` (or `v<x>` if no build) | `minimum_app_version` |
- Info box (#F4F8FF): `No se forzará una actualización por versión.` or `Solo podrán operar v<x> o una versión superior.`
- If no builds: orange text `Todavía no hay builds Android listos registrados en el panel.`

---

## 3. Section 15 — `AdminCommunicationsPage` ("Notificaciones / Avisos")
ACS:6620-7545. Constructor: `channel, countryCode, zoneId`. Embedded AP:1286-1291. **Blocked in Prueba by shell gating** (see 0.2); all RPCs pass `p_channel` anyway.

### 3.1 Top tabs (ACS:7513-7544)
Material `TabBar` (white bg), 2 tabs:
1. `Soporte` — icon `support_agent_rounded`
2. `Avisos` — icon `campaign_outlined`

On init loads campaign targets: RPCs `admin_zone_list_for_country {p_country_code}` (filtered to scope zone) and `admin_partner_list {p_zone_id}`; errors ignored (ACS:6660-6685).

### 3.2 Tab `Soporte` (ACS:6878-7158) — no page header
- Threads RPC `admin_support_threads_scoped {p_channel, p_zone_id}` (empty list if no zone) (ACS:6695-6706).
- Loading `_Loading(title: 'Cargando soporte')`; error `_Error` + `Reintentar`.
- Empty: `_Empty` `No hay conversaciones de soporte todavía.`
- Layout: width ≥ 850 → left thread list 330px | vertical divider | chat. Width < 850 → thread list 210px tall on top, chat below.
- **Thread row** (ListTile, dense): leading `CircleAvatar` with `person_outline_rounded`; title `full_name` (fallback `Usuario Express`) w900; subtitle `last_message` (1 line); trailing blue badge with `unread_count` when > 0. Selected row bg #F4F8FF border #CFE0FF. First thread auto-selected.
- **Chat pane**:
  - No selection: `Selecciona una conversación.`
  - Messages RPC `admin_support_messages_v2 {p_channel, p_user_id}`; loading `_Loading(title: 'Cargando conversación')`; error `_Error`.
  - Header bar: selected user name (w900).
  - Empty: `Sin mensajes.`
  - Bubbles: max width 430; admin (`sender_role=='admin'`) right-aligned #EAF2FF, user left-aligned #F2F4F7; `body` + timestamp (`_formatDate(created_at)`, 9px muted).
  - Composer: multiline TextField (1–4 lines) hint `Responder desde soporte...`, Enter submits; `IconButton.filled` with `send_rounded` (spinner when sending, disabled while sending). Empty text → no-op.
  - Send RPC `admin_support_reply_v2 {p_channel, p_user_id, p_body}`; clears field and reloads; error snackbar `Error: …`.

### 3.3 Tab `Avisos` (ACS:7160-7510)
- `_Header` title `Enviar avisos`, subtitle `Estos son los únicos mensajes que aparecen en “Avisos” dentro de la app.`
- **Compose card** (white, border #E7ECF3, radius 12):
| Label | Type | Options / helper | Sent as |
|---|---|---|---|
| `Destinatarios` | dropdown | `Conductores` (`drivers`, default), `Pasajeros` (`passengers`), `Todos` (`all`). Changing away from drivers clears organization. | `p_audience` |
| `Zona` | dropdown, **disabled** (`onChanged: null`) | helper `Bloqueada al ámbito seleccionado en la barra superior.`; item `<zone name> · <currency_code>` (only the scoped zone) | `p_zone_id` |
| `Empresa / sindicato / cooperativa` | dropdown — visible only when audience = drivers AND partners exist | helper `Opcional: limita el aviso a los conductores afiliados.`; first item `Todas las organizaciones` (null); items `<name> · <organization_type>` filtered to scoped zone | `p_partner_id` |
  - **Live audience estimate** box (#F8FAFC): RPC `admin_push_audience_estimate_v2 {p_channel, p_audience, p_zone_id, p_partner_id}`, re-queried on every selector change; four green pills: `Destinatarios <n>`, `Push activo <n>`, `Android <n>`, `Web <n>` (`…` while loading) (ACS:7268-7316).
  - Info box (#F4F8FF, icon `notifications_active_outlined`): `Este aviso se guarda en la bandeja de la app y también se despacha como notificación push.`
  - `Título` — text, maxLength 90 (counter), hint `Ej. Actualización de Express`.
  - `Mensaje` — text, maxLength 1000, 4–8 lines.
  - Button `Enviar aviso`, icon `campaign_rounded` (spinner 17 while sending; disabled while sending). If title or body empty → silently does nothing (no validation message) (ACS:6775).
- **Confirmation dialog** (ACS:6807-6840):
  - Title `Enviar aviso · Prueba` (channel preview) / `Enviar aviso · Producción`.
  - Body: `Se enviará “<título>” a <target>.\n\nDestinatarios: <n>\nCon push activo: <n>\nAndroid: <n> · Web: <n>` where `<target>` = `conductores` / `pasajeros` / `todos los usuarios`, suffixed ` de <organization name>` or ` de <zone name>` (`—` when estimate missing).
  - Actions `Cancelar` / `Enviar`.
- Send RPC `admin_send_announcement_v4 {p_channel, p_title, p_body, p_audience, p_zone_id, p_partner_id}`; success snackbar `Aviso push enviado a <recipients> destinatarios.`; clears fields; error `Error: …` (ACS:6845-6875).
- **History section** (ACS:7379-7507):
  - Heading `Historial y telemetría push` (19 w900); caption `“Aceptados” son envíos aceptados por Web Push/FCM. “Abiertos” requiere que la app reporte el toque de la notificación.`
  - RPC `admin_notification_campaign_list_scoped {p_channel, p_zone_id, p_from:null, p_to:null, p_limit:100}`.
  - Loading: `LinearProgressIndicator`. Error: notice box `No se pudo cargar la telemetría: <error>` (`_AdminPaymentNotice`, ACS:6594-6618). Empty: `Todavía no hay campañas con telemetría.`
  - Row card: title (`title`, fallback `Aviso`) + date right; secondary line = `zone_name` ?? `partner_name` ?? `audience` ?? `Todos`; pills: `Destinatarios <recipients_targeted>` (green), `Push activo <push_enabled_recipients>` (green), `Aceptados <provider_accepted_users>`, `Abiertos <opened_users>`, `Leídos <read_users>` (green if ≠0 else grey), and `Tokens inválidos <provider_invalid_attempts>` (grey, only if ≠0). No row actions.

---

## 4. Section 16 — `AdminServicesPage` ("Servicios")
ACS:2627-3169. Constructor: `channel, countryCode, zoneId`. Embedded AP:1292-1297. Allowed in Prueba.

### 4.1 Load
- If country or zone missing → empty (ACS:2655-2666).
- Zone: Preview `previewList('service_zones')`, Production RPC `admin_zone_list_for_country {p_country_code}`; filtered to the scoped zone id only.
- Services: Preview = `previewList('service_catalog')` merged with `previewList('zone_services')` for that zone, sorted by `sort_order` (default 100); Production RPC `admin_zone_service_list {p_zone_id}` (ACS:2694-2724).
- Loading `_Loading(title: 'Cargando servicios por zona')`; error `_Error` + `Reintentar`.

### 4.2 Header (ACS:3048-3059)
- Title `Servicios por zona`; subtitle `Decide qué servicios verá cada ciudad sin afectar a las demás.`
- Action (only when the scoped zone exists): `Crear servicio`, icon `add_rounded`.
- If no zone: `_Empty` `Primero crea una zona de operación.`

### 4.3 Zone selector card (ACS:3066-3106)
Row: icon `location_on_outlined`, label `Zona que estás editando`, dropdown `Zona` (dense) with item `<name> · <city>` (`Zona` / `—` fallbacks). Only the scoped zone is listed (effectively locked to the top-bar scope).

### 4.4 Hero (ACS:3108-3118)
Icon `apps_rounded`, title `Catálogo · <zoneName>` (fallback `Sin zona`), subtitle `Disponibilidad y visibilidad se controlan por separado y se sincronizan con las apps.` Stats: `Servicios` (count), `Disponibles` (enabled count), `Con ofertas` (allow_bidding count).

### 4.5 Service cards grid (ACS:3120-3162)
1 col < 680, 2 cols < 1050, else 3. Each `_AdminModuleCard` (tap → edit dialog):
- Icon by `vehicle_type` (ACS:4177-4186): `motorcycle`→`two_wheeler_rounded`; `any`→`commute_rounded`; else (`car`, `xl`)→`local_taxi_rounded`.
- Title `name` (fallback `Servicio`); subtitle `description` (fallback `Sin descripción`); accent blue if enabled, muted if not.
- Chips: `Disponible en <zoneName>` / `No disponible`; raw `vehicle_type` (fallback `car`); `Ofertas` (allow_bidding); `Precio fijo` (allow_fixed_price); `Visible pasajero`; `Visible conductor`; `Programados` (scheduled_enabled).
- No empty state when zone exists but has zero services (grid is simply empty). No delete action.

### 4.6 Dialog — `Crear servicio · <zone>` / `Editar servicio · <zone>` (ACS:2729-3009), width 580, scrollable
- If no zone: snackbar `Error: Primero crea o selecciona una zona.` (ACS:2734-2736).
- Info banner (#EAF2FF, avatar `location_city_rounded`): `Disponibilidad en <zone>. El nombre, descripción y tipo de vehículo forman parte del catálogo base; la activación y visibilidad se controlan por zona.`
| Label | Type | Hint / options / default | Key | Level |
|---|---|---|---|---|
| `Nombre visible` | text | hint `Ej. Moto Express` | `name` | catalog |
| `Clave interna` | text, **disabled when editing** | hint `motorcycle` | `service_key` | catalog + zone |
| `Descripción` | text, 3 lines | — | `description` | catalog |
| `Vehículo requerido` | dropdown | `Auto` (`car`), `Moto` (`motorcycle`, default), `XL` (`xl`), `Cualquiera` (`any`) | `vehicle_type` | catalog |
| `Orden en la app` | number | default `100` | `sort_order` | catalog + zone |
| `Disponible en <zone>` | switch | subtitle `Activa o bloquea solicitudes. La visibilidad se controla por separado.`; default = row.enabled==true (false on create) | `enabled` | zone |
| `Visible para pasajeros` | switch | subtitle `Si está visible pero no disponible, aparecerá como “No disponible”.`; default false on create | `passenger_visible` | zone |
| `Visible para conductores` | switch | subtitle `Controla si el servicio aparece en la interfaz del conductor.`; default false on create | `driver_visible` | zone |
| — divider — | | | | |
| `Permitir ofertas` | switch | default true | `allow_bidding` | catalog + zone |
| `Permitir precio fijo` | switch | default true | `allow_fixed_price` | catalog + zone |
| `Permitir viajes programados` | switch | default true | `scheduled_enabled` | catalog + zone |
- Actions: `Cancelar`; `Guardar servicio` (FilledButton.icon, `save_outlined`).
- No validation (empty key/name are sent as-is).
- Save:
  - Production: RPC `admin_upsert_service {p_id, p_service_key, p_name, p_description, p_icon_key:'local_taxi', p_vehicle_type, p_enabled:true, p_allow_bidding, p_allow_fixed_price, p_passenger_visible:true, p_driver_visible:true, p_scheduled_enabled, p_sort_order}` then RPC `admin_set_zone_service {p_zone_id, p_service_key, p_enabled, p_passenger_visible, p_driver_visible, p_allow_bidding, p_allow_fixed_price, p_scheduled_enabled, p_sort_order}` (ACS:2959-2991). Catalog-level enabled/visibility are hard-coded true; `icon_key` is hard-coded `local_taxi` (no icon picker in UI).
  - Preview: `previewUpsert('service_catalog', serviceKey, …)` (keeps existing `icon_key`, default `local_taxi`) + `previewUpsert('zone_services', '<zoneId>:<serviceKey>', …)` (ACS:2922-2957).
  - Success snackbar `Servicio guardado para <zone>.`; error `Error: …`.

---

## 5. Section 18 — "Verificación de identidad", tab 2 `Requisitos de identidad` → `AdminIdentitySecurityPage`
Shell: `DefaultTabController(length: 2)` (AP:1301-1332) with white `TabBar`:
1. `Revisión de documentos` — icon `fact_check_outlined` → `AdminManualIdentityPage` (out of scope; it embeds `AdminBoliviaKycPanel` from `lib/admin_bolivia_kyc.dart`, `lib/admin_manual_identity.dart:24`).
2. `Requisitos de identidad` — icon `settings_outlined` → `AdminIdentitySecurityPage(channel, countryCode, zoneId)`.
Allowed in Prueba.

### 5.1 `AdminIdentitySecurityPage` (ACS:3684-3751) — stateless
- `_Header` title `Verificación de identidad`; subtitle `Documentos de conductores y revisión manual de fotografías. Los servicios de identidad automáticos y la verificación por SMS están deshabilitados.`
- `_AdminHero` icon `verified_user_rounded`, title `Centro de identidad`, subtitle `Las aprobaciones se realizan manualmente desde la pestaña Revisión de documentos. Los registros históricos de servicios anteriores no son solicitudes activas.` Stats (static): `Motor` = `Manual`; `Proveedor externo` = `Deshabilitado`.
- Embedded panel `AdminDriverDocumentRequirementsPanel` (see 5.2), ACS:3720-3724.
- Footer info card (icon `fact_check_outlined`): `Para revisar, aprobar, rechazar o reactivar por separado el frente, reverso y la selfie de un conductor, usa la pestaña «Revisión de documentos». Las solicitudes de Prueba y Producción se gestionan por separado.`

### 5.2 Embedded `AdminDriverDocumentRequirementsPanel` (`lib/admin_driver_document_requirements.dart:6-610`)
- Load (:31-96): requires country + zone, else empty. Preview `previewList('driver_document_requirements')` + `previewList('service_zones')`; Production RPCs `admin_driver_document_requirement_list` + `admin_zone_list_for_country {p_country_code}`. Rows shown = global (no country, no zone) + this country (no zone) + this zone; sorted by `sort_order` (100). Zone options = active scoped zone of this country.
- Loading: card with centered `CircularProgressIndicator` (:466-473). Error: card with red `error_outline_rounded`, error text, TextButton `Reintentar` (:474-491).
- Card header (:502-532): avatar `folder_shared_outlined`; title `Documentos requeridos para conductores` (15 w900); subtitle `Crea, edita o elimina los documentos que debe cargar cada conductor según país o ciudad.`; button `Nuevo documento` (icon `add_rounded`).
- Empty: `No hay requisitos configurados.` (:534-538).
- **Row** (:540-601): bg #F8FAFC if inactive else white; leading icon `face_retouching_natural_rounded` (if require_selfie) else `badge_outlined`; title `label` (fallback `Documento`); chips: scope label (`<zone_name>`/`<zone_key>`/`Ciudad` for zone; `Bolivia`/`Chile`/raw code for country; `Todas las ciudades` for global — :440-452), `Obligatorio`, `Frente`, `Reverso`, `Selfie`, `Inactivo` (each conditional). (No chip for `require_number`.) Row actions: IconButton `edit_outlined` tooltip `Editar`; IconButton `delete_outline_rounded` tooltip `Eliminar`.
- **Dialog `Nuevo documento requerido` / `Editar documento requerido`** (:98-399), width 650, scrollable:
  - Info banner (#EAF2FF, `info_outline_rounded`): `Define qué documento debe cargar el conductor. Puedes aplicarlo a todos, a un país o solamente a una ciudad.`
  | Label | Type | Hint / options / default | Key → param |
  |---|---|---|---|
  | `Nombre visible` | text | hint `Carné de identidad, Licencia...` | `label` → `p_label` |
  | `Código interno` | text (editable also when editing) | hint `identity_card` | `code` → `p_code` |
  | `Descripción` | text, 2 lines | — | `description` → `p_description` |
  | `Aplicar a` | dropdown | `Todas las ciudades` (`global`), `Un país` (`country`), `Una ciudad` (`zone`); default zone (if scoped) | derives `country_code`/`zone_id` |
  | `País` | dropdown (when scope ≠ global) | `Bolivia` (`BO`), `Chile` (`CL`) — only the scoped country is offered | `country_code` → `p_country_code` (null if global) |
  | `Ciudad` | dropdown (when scope = zone) | zone `city` ?? `name` ?? `Ciudad` | `zone_id` → `p_zone_id` (null unless zone) |
  | `Documento obligatorio` | switch | default true | `required` → `p_required` |
  | `Solicitar número del documento` | switch | default false | `require_number` → `p_require_number` |
  | `Solicitar foto del frente` | switch | default true | `require_front` → `p_require_front` |
  | `Solicitar foto del reverso` | switch | default false | `require_back` → `p_require_back` |
  | `Solicitar selfie para comparación facial` | switch | subtitle `La selfie queda disponible para revisión manual o proveedor automático.`; default false | `require_selfie` → `p_require_selfie` |
  | `Activo` | switch | default true | `active` → `p_active` |
  | `Orden` | number | default 100 | `sort_order` → `p_sort_order` |
  - Actions: `Cancelar`; `Guardar` (FilledButton.icon `save_outlined`).
  - Validation (snackbars after closing dialog, :327-332): `Completa nombre y código.`; `Selecciona el país.`; `Selecciona la ciudad.`
  - Save: Production RPC `admin_upsert_driver_document_requirement {p_id, …}` (:369-386); Preview `previewUpsert('driver_document_requirements', recordKey, payload)`, recordKey = existing `_record_key` or `<zone|country|global>:<code>` (:336-367). Errors → snackbar with raw error. No success message (list reloads).
- **Delete dialog `Eliminar requisito`** (:401-438): body `¿Eliminar “<label>”? Los documentos ya enviados por conductores no se borrarán.`; actions `Cancelar` / `Eliminar` (red #D92D20 FilledButton). Production RPC `admin_delete_driver_document_requirement {p_id}`; Preview `previewSoftDelete`.

---

## 6. Notes for redesign (behaviour to preserve / quirks observed)
- Configuración: one save button covers 7 tabs; `Taxi`/`Delivery` toggles appear twice (General + Servicios) bound to the same state; AdMob tab has an independent save and disables the header save.
- Configuración avanzada and Notificaciones / Avisos are unavailable in Prueba (shell gate) — needs a "blocked in Prueba" state.
- Services: zone dropdown is effectively read-only (single scoped zone); catalog-level `enabled/passenger_visible/driver_visible` forced true in Production; no icon picker, no delete.
- Avisos: zone selector permanently disabled; organization selector only for `Conductores`; empty title/body gives no feedback.
- Settings fields have no inline validation; invalid numbers fall back to defaults silently.
- No permission-based button hiding inside these pages beyond the shell's zone-monitor block; AdMob Production fields are hidden in Prueba.
