# A_core — UI inventory: Adminexpress shell + sections 0–6 + detail dialogs

Source repo: `/home/user/adminexpress` (read-only). Files: `lib/main.dart` (M), `lib/admin_panel.dart` (P), `lib/admin_detail_dialogs.dart` (D), `lib/core/admin_environment_navigation.dart` (N).
Notation: `P:123` = admin_panel.dart line 123. Strings are verbatim. "Mi" = Material Icons rounded/outlined name.

---

## 0. Design tokens

### 0.1 Panel constants (P:23-29)
| Token | Hex | Use |
|---|---|---|
| adminBlue | #2563EB | seed color, primary, focused border, selected chips |
| adminDark | #0F172A | main text, AppBar fg, snackbar bg |
| adminMuted | #64748B | secondary text, labels |
| adminBg | #F1F5F9 | scaffold background |
| adminNavy | #0B1220 | sidebar background |
| adminNavySoft | #111C31 | declared, unused here |
| adminCyan | #22D3EE | selected nav icon/chevron, company avatar icon |

### 0.2 `_expressAdminTheme` (P:32-204)
- ColorScheme.fromSeed(adminBlue, light, surface white). Scaffold adminBg; canvas white; divider #EAECF0.
- Card: white, elevation 0, radius 18, border #DDE6F0, shadow #1A0F172A.
- AppBar: white bg, fg adminDark, elevation 0, toolbarHeight 60, title 14/w900 adminDark, not centered.
- Input: dense, filled white, padding 12/12, label 11 adminMuted, hint 11 #98A2B3, radius 10, border #D0D5DD, focused adminBlue, error #D92D20.
- FilledButton: minH 40, pad 14×10, radius 9, text 11/w800. OutlinedButton: same + border #D0D5DD, fg adminDark. TextButton: minH 38, pad 12×9, radius 9, 11/w800. IconButton: 38–42 square, radius 9.
- Chip: bg white, selected #EAF2FF, disabled #F2F4F7, border #E4E7EC, label 10/w700 adminDark, secondary 10/w900 adminBlue, radius 20.
- Dialog: white, radius 16, title 18/w900 adminDark. PopupMenu: white, radius 11, text 11/w600. SnackBar: floating, bg adminDark, text white 11/w600, radius 10.

### 0.3 Login app theme (M:47-54)
- Material3, colorSchemeSeed #0B57D0, scaffold #F7F9FC. App title: `Adminexpress · Prueba` / `Adminexpress · Producción`.

### 0.4 Dialog constants (D:7-11)
_detailBlue #2563EB · _detailDark #0F172A · _detailMuted #64748B · _detailBorder #E2E8F0 · _detailSoft #F8FAFC.

### 0.5 Other recurring colors
- Success/prod green: fg #14804A / #0F6848 / #156C41, bg #E8F8EF. Preview amber: fg #B54708 / #7A2E0E / #935B0B, bg #FFF7E6.
- Error red #D92D20; error box bg #FFF1F1 text #B42318.
- Driver live status: available #12B76A, signal #246BFD, trip #F79009, offline #E5484D (P:4225-4236).
- Zone strip dot palette (cycled): #0B57D0, #12B76A, #F79009, #7A2CF3, #06AED4, #EF4444 (P:3294-3301).
- `_Header` gradient #0F2854 → #174B91 → #0D6B8D, radius 22, shadow #33174B91 (P:2722).

---

## 1. App shell

### 1.1 Login screen `_AdminLogin` (M:171-422)
Layout: Row; if width ≥ 900 → left `_AdminBrandPanel` (flex 6) + right form (flex 5). Form card max 430 wide, padding 28, elevation 0.
- Title `Adminexpress` (28/w900).
- Env line: Preview `Acceso de Prueba · sesión independiente` (#935B0B) / Prod `Acceso de Producción` (#156C41), 13/w700.
- Subtitle `Panel administrativo de Express Delivery` (#667085).
- Field 1: text (email keyboard), label `Correo administrador`, prefix Mi `mail_outline_rounded`.
- Field 2: password (obscured), label `Contraseña`, prefix `lock_outline_rounded`, suffix IconButton toggle `visibility_outlined` / `visibility_off_outlined`. Enter submits.
- Error text (if any): #D92D20, 12px. Messages:
  - `Esta cuenta no tiene autorización para este entorno. Utiliza las credenciales administrativas correspondientes.` (admin but wrong env)
  - `Esta cuenta no tiene acceso de administrador ni de organización.`
  - `No se pudo iniciar sesión con Google.`
  - otherwise raw exception text.
- Primary button (full width, h48): FilledButton.icon Mi `login_rounded`, `Ingresar al panel`; while busy icon = 18px spinner, disabled. Silently ignored if email/password empty.
- Preview only: OutlinedButton.icon (h46) Mi `account_circle_outlined` `Acceder con Google · Preview`; helper `Necesitas permisos administrativos para el canal de Prueba en Supabase principal.` (11, #667085).
- Centered `AdminEnvironmentLinkButton` (N:41): OutlinedButton Mi `swap_horiz_rounded`, label Preview→`Ir a Producción` (fg #0F6848, border #9AD8B3) / Prod→`Ir a Prueba` (fg #7A2E0E, border #F5C36A). Failure snack: `No se pudo abrir el otro panel.`
- `Cada página utiliza su canal autorizado.` (11, #667085).
- Version `Adminexpress v1.0.1 · build 2` (11, #98A2B3) (M:11).

### 1.2 Brand panel `_AdminBrandPanel` (M:424-495)
Gradient TL→BR #073B8C → #0B57D0 → #39A0FF, padding 54.
- Top row: white CircleAvatar r24 with Mi `bolt_rounded` #0B57D0 30px + `EXPRESS` (white 28/w900).
- Headline `Administra Express\ndesde un solo lugar.` (white 42/w900, h1.05).
- Body `Operación, conductores, seguridad, tarifas, builds y releases.` (#DCEAFF 17).
- Footer `Adminexpress · Solo web` (#BFD8FF).

### 1.3 Auth gate states (M:117-168)
- Resolving: plain Scaffold + centered CircularProgressIndicator.
- `_AccessDenied` card (M:498-556, max 520): Mi `admin_panel_settings_outlined` 52 #D92D20; title 21/w900; message #667085; FilledButton Mi `logout_rounded` `Cerrar sesión`.
  - Error: title `No se pudo validar tu acceso`, message = error.
  - Denied Preview: `Cuenta sin acceso a Prueba` / `La cuenta ingresada no está autorizada para Preview. Cierra sesión y utiliza las credenciales de prueba.`
  - Denied Prod: `Cuenta sin acceso a Producción` / `Esta cuenta no tiene acceso administrativo a Producción ni una organización asignada.`
- `_StartupError` (M:558-594): Mi `error_outline_rounded` 52, `Adminexpress no pudo iniciar` (22/w900), error text.
- Partner accounts go to `PartnerExpressPanel` (out of scope).

### 1.4 Panel loading / unauthorized (P:1047-1060, 4966-5011)
- `_authorized()` pending: Scaffold bg adminBg + centered spinner.
- `_Unauthorized` card (max 520): Mi `lock_outline_rounded` 52, `Acceso de administrador` (23/w900), `Esta cuenta no está autorizada para administrar Express.`, FilledButton Mi `logout_rounded` `Cerrar sesión`.

### 1.5 Layout (P:1062-1175)
- Breakpoint: `compact = width < 1180`.
- Wide: Row[ sidebar `_Navigation` width 248 | Column[ `_TopBar`, env banner, scope bar, body ] ].
- Compact: AppBar + Drawer(`_Navigation`), no `_TopBar`.
- Under top bar, always: `_environmentSwitcher()` banner (both branches render it). Then `_globalGeoScopeSwitcher()` for every section except 10, 12, 14 (Reportes, Builds, Auditoría).

### 1.6 Compact AppBar (P:1070-1100)
- title: `_Brand(compact: true)`.
- actions: IconButton tooltip `Nuevo viaje` Mi `add_circle_outline_rounded` → section 13 (hidden for zone_monitor); IconButton tooltip `Actualizar` Mi `refresh_rounded`; PopupMenu tooltip `Cuenta` icon `more_vert_rounded` → item `Cerrar sesión`.
- drawer: `_Navigation` in SafeArea; tap closes drawer then navigates.

### 1.7 `_Brand` (P:2486-2558)
- Logo square 39 (compact 34), radius 11, gradient #2563EB → #22D3EE, shadow #3322D3EE blur12 y5, Mi `bolt_rounded` white 21.
- `Express Delivery` 14/w900, ls -0.2 (white on sidebar, adminDark in compact AppBar).
- Non-compact only: `COMMAND CENTER` 8/w900 ls 1.4 #8FA3BF.

### 1.8 `_Navigation` sidebar (P:2226-2383)
Material color adminNavy #0B1220.
1. `_Brand` padding 18/20/18/14.
2. Company card (P:2269-2325) — "EMPRESA ACTUAL" (not an env indicator): padding 13, radius 15, gradient TL→BR #17243B → #101A2C, border #263650. CircleAvatar r17 bg #1E3A5F with Mi `apartment_rounded` 18 adminCyan; label `EMPRESA ACTUAL` (8/w900 ls .9 #8FA3BF); `Express Delivery` (white 12/w900); trailing Mi `unfold_more_rounded` 16 #8FA3BF (decorative, not tappable).
3. Divider #1E2B41.
4. Grouped list. Group header: 8/w900 ls 1.05 #71839D.
   - Full admin groups (P:2246-2256):
     - `GENERAL`: Dashboard
     - `OPERACIONES`: Operación en vivo, Viajes, Despacho manual, Delivery, Pedidos Delivery, Conductores, Usuarios, Seguridad / SOS
     - `MÓDULOS`: Express Market, Delivery Fase 2 / Express Plus, Prioridad conductores
     - `FINANZAS`: Pagos / Billetera, Tarifas, Suscripciones
     - `ANÁLISIS`: Reportes, Auditoría
     - `COMUNICACIÓN`: Notificaciones / Avisos
     - `SEGURIDAD`: Verificación de identidad
     - `CONFIGURACIÓN`: Servicios, Zonas y cobertura, Configuración, Configuración avanzada, Builds
     - `HERRAMIENTAS QA`: Entornos de prueba, Carga QA
   - readOnly (zone_monitor) groups (P:2242-2245): `GENERAL`: Dashboard · `OPERACIONES`: Operación en vivo, Viajes, Delivery, Pedidos Delivery, Conductores, Usuarios, Seguridad / SOS.
   - Defined but never in nav: 17 `Cobertura y seguridad`, 27 `Verificación manual`, 28 `Demanda y precios`.
5. Divider + exit ListTile (P:2355-2377): Mi `logout_rounded` 18 #94A3B8, `Cerrar sesión` (11/w700 #D9E2EF), radius 12.

Section index → label → icon (P:267-297):
0 Dashboard `dashboard_rounded` · 1 Operación en vivo `map_rounded` · 2 Viajes `local_taxi_rounded` · 3 Delivery `local_shipping_rounded` · 4 Conductores `drive_eta_rounded` · 5 Usuarios `people_rounded` · 6 Seguridad / SOS `shield_rounded` · 7 Zonas y cobertura `hexagon_outlined` · 8 Tarifas `payments_outlined` · 9 Pagos / Billetera `account_balance_wallet_rounded` · 10 Reportes `bar_chart_rounded` · 11 Configuración `settings_rounded` · 12 Builds `build_circle_outlined` · 13 Despacho manual `alt_route_rounded` · 14 Auditoría `history_rounded` · 15 Notificaciones / Avisos `notifications_active_rounded` · 16 Servicios `apps_rounded` · 17 Cobertura y seguridad `gpp_good_rounded` · 18 Verificación de identidad `verified_user_rounded` · 19 Configuración avanzada `tune_rounded` · 20 Entornos de prueba `science_rounded` · 21 Carga QA `speed_rounded` · 22 Suscripciones `workspace_premium_rounded` · 23 Express Market `storefront_rounded` · 24 Delivery Fase 2 / Express Plus `delivery_dining_rounded` · 25 Prioridad conductores `workspace_premium_outlined` · 26 Pedidos Delivery `receipt_long_rounded` · 27 Verificación manual `fact_check_outlined` · 28 Demanda y precios `trending_up_rounded`.

`_NavEntry` (P:2385-2484): pad 11×10, radius 12, anim 180ms.
- Selected: bg #173A68, border #25558E, shadow #3322D3EE blur14 y5; icon tile 31×31 r9 bg #1E4E83, icon adminCyan 17; text white 11/w900; trailing Mi `chevron_right_rounded` adminCyan.
- Idle: transparent; icon tile bg #142037, icon #91A4BF; text #C5D0DF 11/w600.
- Section 6 always shows badge `SOS` (bg #4B1D26, text #FF8A8A 8/w900, radius 9) instead of chevron.

### 1.9 `_TopBar` (wide only) (P:2560-2703)
Container h70, margin 18/14/18/0, white, radius 16, border #DDE6F0, shadow #120F172A blur22 y8.
- Leading tile 34×34 r10 bg #EAF2FF, Mi `grid_view_rounded` adminBlue 18.
- Overline `ADMINISTRACIÓN` (8/w900 ls 1.1 adminMuted); title = current section label (14/w900 adminDark).
- FilledButton.icon Mi `add_rounded` `Nuevo viaje` → section 13. NOTE: `showNewTrip` param is passed (`!_isZoneMonitor`) but NOT used — button always visible on wide layout, even for zone_monitor.
- IconButton tooltip `Actualizar` Mi `refresh_rounded` 20.
- IconButton tooltip `Notificaciones` Mi `notifications_none_rounded` with permanent red dot r4 #EF4444 (no-op onPressed).
- Account PopupMenu tooltip `Cuenta`: pill bg #F8FAFC, radius 12, border #E2E8F0; CircleAvatar r15 bg #DBEAFE Mi `person_rounded` adminBlue; `Administrador` 10/w900; Mi `keyboard_arrow_down_rounded`. Item: `Cerrar sesión`.

### 1.10 Environment banner `_environmentSwitcher()` (P:911-968)
Full width, pad 18×10.
- Preview: bg #FFF7E6, Mi `science_rounded` #B54708 19, text `EXPRESS PREVIEW · Solo registros de prueba` (#7A2E0E 12/w900).
- Production: bg #E8F8EF, Mi `verified_rounded` #14804A, text `EXPRESS PRODUCCIÓN · Datos reales` (#0F6848).
- Right: `AdminEnvironmentLinkButton` (`Ir a Producción` / `Ir a Prueba`). Width < 580: button wraps to own line, right-aligned.

### 1.11 Scope bar `_globalGeoScopeSwitcher()` (P:713-899)
- zone_monitor variant: bg #F0FDF4, bottom border #BBF7D0; Mi `lock_outline_rounded` 18 #15803D; text `Monitor de zona · {country} · {zone_name}` (#166534 11/w900); right `Solo lectura` (#166534 10/w800).
- Admin variant: bg #F8FAFC, bottom border #E2E8F0, pad 18/9. Wrap:
  - Mi `public_rounded` adminBlue + `Ámbito obligatorio` (11/w900).
  - Dropdown (w190) label `País`, hint `Selecciona un país`; items = country name (fallback code). Change resets zone.
  - Zone: if no country → disabled TextField (w220) label `Zona`, hint `Primero selecciona un país`; else Dropdown (w220) label `Zona`, hint `Selecciona una zona`, items `{name} · {city}`.
  - If scope not ready: `Selecciona país y zona para cargar datos.` (10/w700 adminMuted).

### 1.12 Body gating states (P:1177-1201)
- Preview + module not in {0,1,2,3,4,5,6,7,8,10,11,14,16,17,18,27}: centered text `Este módulo todavía no tiene aislamiento seguro por canal. Está bloqueado en Prueba para proteger los datos reales. Puedes gestionar conductores, documentos, viajes y configuración QA desde sus secciones.`
- Scope missing — `_ScopeSelectionRequired` (P:2146-2186): Mi `filter_alt_outlined` 46 adminBlue; `Selecciona país y zona` (18/w900); `No se cargarán usuarios, viajes, conductores ni métricas hasta elegir el ámbito.` (11/w600 adminMuted).
- `_ZoneMonitorRestricted` (P:2188-2224), for zone_monitor on any section not in {0,1,2,3,4,5,6,26}: Mi `lock_outline_rounded` 44 #64748B; `Módulo reservado al administrador global` (16/w900); `El monitor de zona tiene acceso operativo de solo lectura.` (11 adminMuted).

### 1.13 Shared loading / error
- `_Loading` (P:4894-4911): `_Header` title `Cargando operación`, subtitle `Sincronizando datos administrativos con Express.` + LinearProgressIndicator below (pad 22).
- `_ErrorView` (P:4913-4964): card max 560; Mi `error_outline_rounded` 48; `No se pudo cargar el módulo` (20/w900); error text (11 adminMuted); FilledButton Mi `refresh_rounded` `Reintentar`.
- Snackbars: `Conductor: {status}`, `Cuenta: {status}`, `Emergencia marcada como resuelta.`, `Error: {error}` (P:992-1038).

### 1.14 `_Header` hero card (P:2705-2823)
Gradient banner (see 0.5), pad 22/20, radius 22. Left tile 48×48 r14 white@12% border white@18%, Mi `bolt_rounded` white 25. Title white 23/w900 ls -.4. Optional badge pill bg #16A34A, dot #BBF7D0 6px, text white 9/w900. Subtitle #D7E7FA 11/w600.

---

## 2. Section 0 — Dashboard `_dashboard()` (P:1388-1574)
Data: `admin_dashboard_state_v2` → `metrics`, `activity`. Pull-to-refresh. Padding 22/20/22/30.
- Header: `_Header` title `Express Delivery`, subtitle `Bienvenido al panel de control de tu empresa.`, badge `Activa`. Right (or below if width < 680): FilledButton.icon Mi `bolt_rounded` `Ver en vivo` → section 1.
- KPI row (`_Metric`, P:2827-2982). 4 cols ≥1100, 2 cols ≥700, 1 col below; gap 14.
  | Label | Value key | Icon | Tone (soft / accent) | Footnote |
  |---|---|---|---|---|
  | `Viajes activos` | active_trips | location_on_outlined | green #DDF8EA / #0F9F68 | `En operación ahora` |
  | `Viajes hoy` | trips_today | schedule_rounded | blue #E1ECFF / #2563EB | `Solicitudes del día` |
  | `Conductores` | drivers_online | drive_eta_rounded | orange #FFEED0 / #D97706 | `de {drivers_total} conectados` |
  | `Completados` | completed_today | task_alt_rounded | purple #EDE5FF / #7C3AED | `Finalizados hoy` |
  Card: white, minH 138, radius 19, border accent@16%, decorative circle 78px soft@72% at top-right (-17,-17); icon tile 42 r13 soft bg; pill top-right Mi `trending_up_rounded` accent + `HOY` (7/w900); value 28/w900; title 11/w800; footnote 9 adminMuted. (alert variant: soft #FFE7E7 / accent #DC2626, unused here.)
- Row 2 (stack < 900; else flex 3:2):
  - `_QuickActions` (P:2984-3138) in `_Surface` (white, r19, border #DDE6F0). Title `Acciones rápidas` (15/w900). 3 tiles (h166, stacked if <620):
    | Title | Subtitle | Icon | bg | accent | Target |
    |---|---|---|---|---|---|
    | `Ver viajes en vivo` | `Monitorea la operación en tiempo real` | location_on_outlined | #CFF3E2 | #129B67 | section 1 |
    | `Gestionar conductores` | `Administra estados, aprobación y flota` | drive_eta_rounded | #FFE7A8 | #C98000 | section 4 |
    | `Despacho manual` | `Asigna un conductor directamente` | alt_route_rounded | #D8E5FF | #246BFD | section 13 |
    Tile: radius 13, icon tile 36 white@72%, title 12/w900, subtitle 9 muted, trailing Mi `arrow_forward_rounded` accent. (Shown also to zone_monitor; section 13 then shows restricted state.)
  - `_SystemStatus` (P:3140-3254): title `Estado del sistema`. Rows (icon tile #F3F6FA, value 11/w900, green dot #12B76A always):
    - `Conductores` — drivers_online — `de {drivers_total} conectados` — drive_eta_rounded
    - `Usuarios` — users_total — `Registrados` — people_alt_outlined
    - `Solicitudes` — ride_searching — `Pendientes` — radar_rounded
    - `SOS` — open_emergencies — `Sin alertas` (static even if >0) — sos_rounded
- Row 3 (h330; stack < 900; else 3:2):
  - `_Activity` (P:4251-4353): title `Actividad reciente`; max 6 rows; icon by kind (delivery→local_shipping_rounded, emergency→sos_rounded, else local_taxi_rounded); emergency tile bg #FFE8E8 icon #D92D20, else bg #EAF2FF icon adminBlue; title (fallback `Actividad`) 10/w800; subtitle 8 muted; time `HH:mm` 8 #98A2B3. Empty: `Todavía no hay actividad.`
  - `_DailySummary` (P:4355-4448): title `Resumen del día`. Rows: `Total de viajes` (trips_today, local_taxi_rounded, #E5F8F1/#129B67), `Completados` (completed_today, task_alt_rounded, #F0E8FF/#7A2CF3), `Viajes activos` (active_trips, location_on_outlined, #E8F0FF/#246BFD), `Conductores online` (drivers_online, drive_eta_rounded, #FFF3D9/#D98A00).
- Unused widget `_Totals` (P:4450): Usuarios, Conductores, Pendientes, Viajes hoy, Delivery hoy, Delivery completados.

## 3. Section 1 — Operación en vivo `_liveOperations()` (P:1576-1675)
Data: dashboard state (`drivers`, `active_trips`, `active_deliveries`, `emergencies`) + zones of country. No `_Header`. Padding 22/10/22/22.
- Zone strip `_LiveZoneStrip` (P:3281-3390): h68 white card r14 border #E4EAF2. First chip `Todas las zonas` with Mi `grid_view_rounded`; then horizontally scrolling chips per zone (`name`, fallback `Zona`) with colored 9px dot from palette. Chip: pad 13×10 r10; selected bg/border adminBlue, white text; idle bg #F8FAFD border #E4EAF2, text adminDark 10/w800. Selecting a zone also sets the global scope zone/country.
- Body: width ≥ 980 → Row[ side panel w405 | map ]; else ListView[ side h430, map h560 ].
- `_LiveSidePanel` (P:3392-3495): white, r14, border #E4EAF2.
  - 2 `_LiveMetricCard`s (P:3497-3571; minH 104, bg #FDFEFF, border #E9EDF3, r12; icon tile 34; value 22/w900 right; label 10/w800; note 8/w700 in accent):
    - `Viajes activos` = trips count, Mi `route_rounded`, soft #E5F8F1, accent #12A66A, note `En tiempo real`.
    - `Conductores` = drivers not offline, Mi `groups_2_outlined`, soft #F0E8FF, accent #7A2CF3, note `Conectados ahora`.
  - Tabs `_LiveTab` (h45, borders #EEF1F5): `Viajes ({n})` | `Conductores ({n})`. Selected: adminBlue 10/w900 + 2px underline; idle adminMuted w700. Default = Viajes.
  - `_LiveTripList` (P:3613-3740): row = blue dot #246BFD; `#{first 7 chars of id upper}` (fallback `Viaje activo`) 10/w900; env pill `Prueba` (#B54708 on #FFF7E6) or `Producción` (#14804A on #E8F8EF); status pill raw status (fallback `activo`) adminBlue on #E8F0FF; line `{pickup}  →  {destination}` (fallbacks `Origen`/`Destino`) 8 muted, 2 lines. Empty: `No hay viajes activos.`
  - `_LiveDriverList` (P:3742-3830): icon tile 30 (status color @12%) Mi `drive_eta_rounded`; name (name/full_name/driver_name, fallback `Conductor`) 10/w800; 8px status dot; status label. Empty: `No hay conductores para mostrar.`
  - Live status derivation (P:4174-4249): `trip` → `En viaje` (#F79009); `signal` → `Sin señal` (#246BFD); `offline` → `Desconectado` (#E5484D); `available` → `Disponible` (#12B76A).
- `_OperationsMap` (P:3832-4054), fullScreen=true (no header; non-fullScreen header would be Mi `map_outlined` + `Mapa operativo`). Card clip, OSM tiles, attribution `OpenStreetMap contributors`.
  - Zone circle (radius_km): fill #1F0B57D0, border adminBlue 2px. Zoom 13.5 with zone, else 13. Default center -20.2208, -70.1431.
  - Markers `_MapDot` 46×46 circle, 3px white border, white icon 20: drivers (drive_eta_rounded, status color, tooltip `{name} · {status label}`); trips (local_taxi_rounded, adminBlue, `Viaje · {pickup}`); deliveries (local_shipping_rounded, adminDark, `Delivery · {pickup}`); emergencies (sos_rounded, #D92D20, `SOS · {user_name|Usuario}`).
  - Top-left zone label pill (white@94%, r9) = zone name 9/w900 (only when a zone selected).
  - Bottom-left `_MapStatusLegend` (P:4056-4143) w190 white@95% r11 border #E4EAF2: title `Conductores`; rows `Disponibles` #12B76A, `En línea, sin señal` #246BFD, `En viaje` #F79009, `Desconectados` #E5484D, each with count.

## 4. Shared `_Records` list (P:4505-4665)
ListView pad 22:
1. `_Header(title, subtitle)` (no badge).
2. Filter bar: white r12 border #E7ECF3 pad 10, Wrap:
   - `serverFilters` (if any, see per section).
   - Search TextField w240, Mi `search_rounded`, hint `Buscar` (client-side, matches any field).
   - ChoiceChip `Todos ({total})` + up to 5 ChoiceChips of distinct raw `status` values (sorted).
   - If showQaFilter: ChoiceChip avatar `people_alt_outlined` `Reales`; ChoiceChip avatar `science_outlined` `QA / pruebas`; TextButton `Quitar filtro QA` (only when a QA filter active).
   - OutlinedButton.icon Mi `download_rounded` `Exportar` → snack `Exportación CSV/Excel se conectará en el módulo de reportes.`
3. Rows, or empty box (pad 28, white r12): `No hay resultados para los filtros seleccionados.` when search/status set, else section-specific empty text.

Period filter `_periodFilter` (P:498-579) for Viajes & Delivery: ChoiceChips `Hoy` / `Semana` / `Mes` + OutlinedButton.icon Mi `date_range_outlined` label `Fecha` or `d/m/yyyy – d/m/yyyy` (opens date range picker, range now-3y … end of next year). Default `Hoy`.

`_OperationCard` (P:4667-4778): white r10 border #E7ECF3, leading tile 32 r8 #EAF2FF icon adminBlue 17; title 11/w800; subtitle 10 muted.
- With onTap → ListTile, trailing Mi `open_in_new_rounded` adminBlue, tooltip `Ver detalle completo`.
- Without onTap → ExpansionTile; expanded shows `details` strings (10 muted, wrap spacing 18).

`_Chip` (P:4780-4816): approved/online/active → bg #E8F8EF fg #14804A; pending → #FFF3E7 / #C76B16; else #F2F4F7 / #475467. 9/w800, radius 20. Shows raw English value.

## 5. Section 2 — Viajes `_tripList()` (P:1677-1726)
- Header: `Viajes` / `Historial y operación de viajes Express.` Empty: `Todavía no hay viajes.`
- Filters: period filter + search + status chips. No QA chips.
- Row `_OperationCard` icon `local_taxi_rounded`:
  - title `{pickup_address|Origen} → {destination_address|Destino}`
  - subtitle `{status|—} · {category|Express} · Bs {final_fare|—}`
  - details (only visible in ExpansionTile mode): `Pasajero: …`, `Conductor: …`, `Pago: {payment_status}`, `Creado: dd/mm/yyyy · HH:mm`.
  - Admin: tap → Trip detail dialog (§10.3). zone_monitor: no tap, expandable details instead.
- Data: `admin_trip_list_v4`, limit 200.

## 6. Section 3 — Delivery `_deliveryList()` (P:1728-1770)
- Header: `Delivery` / `Pedidos y entregas de Express.` Empty: `Todavía no hay delivery.`
- Filters: period filter + search + status chips.
- Row `_OperationCard` icon `local_shipping_rounded` (always ExpansionTile, no dialog):
  - title `{pickup_address|Origen} → {dropoff_address|Destino}`
  - subtitle `{status|—} · {package_type|Paquete} · Bs {proposed_fare|—}`
  - details `Cliente: …`, `Repartidor: …`, `Pago: {payment_method}`, `Creado: …`.

## 7. Section 4 — Conductores `_driverList()` (P:1772-1982)
- Header: `Conductores` / `Aprobación, estado, licencia, vehículo y control de conductores.` Empty: `Todavía no hay conductores registrados.`
- Filters: search + status chips (rows have no `status` key → only `Todos (n)` shows). No QA, no server filters.
- Row container white r11 border #E7ECF3.
  - Identity: CircleAvatar r18 bg #EAF2FF icon adminBlue (`online_prediction_rounded` if online else `person_rounded`); name (fallback `Conductor`) 12/w900; email 9 muted.
  - Wide (≥760): identity (w240) | `vehicle_summary` or `Sin vehículo` (10 muted) | city or `—` (w120) | `_Chip(approval_status)` | `_Chip(online_status)` | actions.
  - Narrow: identity; chips; `_Line` Mi `directions_car_outlined` vehicle/`Sin vehículo`; `_Line` Mi `phone_outlined` phone/`Sin teléfono`; actions right.
  - Approval chip values: `approved` / `pending` / `rejected` / `suspended`; online: `online` / `offline` / `busy`.
  - Actions (hidden for zone_monitor): PopupMenu tooltip `Acciones` icon `more_horiz_rounded`: `Ver / editar ficha` (Mi `manage_accounts_outlined`, opens Driver editor §10.1) · divider · `Aprobar` · `Marcar pendiente` · `Rechazar` · `Suspender` (→ snack `Conductor: approved|pending|rejected|suspended`).

## 8. Section 5 — Usuarios `_userList()` (P:1984-2089)
- Header: `Usuarios` / `Pasajeros, conductores y control del estado de las cuentas.` Empty: `Todavía no hay usuarios registrados.`
- Server filters `_userGeoFilters` (P:581-711) — NOTE: changing them only bumps revision; values are not sent to the RPC (UI only):
  - Dropdown w190 `Zona`: `Todas las zonas` + `{name} · {city}`.
  - Dropdown w165 `Ciudad`: `Todas` + cities.
  - Dropdown w180 `Región / departamento`: `Todas` + regions.
- Search + status chips + QA chips (`Reales`, `QA / pruebas`, `Quitar filtro QA`) + Exportar.
- Row ListTile in white r11 card: avatar r18 #EAF2FF (Mi `drive_eta_rounded` if active_mode=driver else `person_rounded`); title full_name (fallback email, then `Usuario`); subtitle `{email} · {active_mode|passenger} · {account_status|active}`.
- Trailing PopupMenu (hidden for zone_monitor): `Ver / editar perfil` (Mi `manage_accounts_outlined`, opens User editor §10.2) · divider · `Activar` · `Suspender` · `Bloquear` (→ snack `Cuenta: active|suspended|blocked`).

## 9. Section 6 — Seguridad / SOS `_security()` (P:2091-2142)
- Header: `Seguridad / SOS` / `Emergencias activas registradas desde Viajes y Delivery.` Empty: `No hay emergencias abiertas.`
- Filters: search + status chips (+ Exportar). No QA.
- Row Card (margin-bottom 10) ListTile: CircleAvatar bg #FFE4E8 Mi `sos_rounded` #D92D20; title user_name (fallback `Usuario Express`); subtitle `{status|open} · dd/mm/yyyy · HH:mm`; trailing FilledButton.icon Mi `check_circle_outline_rounded` `Resolver` (hidden for zone_monitor) → snack `Emergencia marcada como resuelta.`

---

## 10. Dialogs (lib/admin_detail_dialogs.dart)

Shared frame `_DialogFrame` (D:136-192): AlertDialog, inset 14, width 820 (or screen-28 if <900), content maxH 72% screen. Title 20/w900 _detailDark; subtitle 11/w500 muted.
`_Section` (D:194-239): bg #F8FAFC, r14, border #E2E8F0, pad 14; header icon 18 _detailBlue + title 13/w900.
`_InfoGrid` (D:241-288): 2 cols (1 col <560); label 9/w700 muted; value SelectableText 11/w700 dark.
Format helpers: date `dd/mm/yyyy · HH:mm` or `—`; money `{CUR} 0.00` or `—`.

### 10.1 Ficha del conductor — `showAdminDriverEditor` (D:90-104, 290-1149)
Opened from: Section 4 Conductores → row menu `Ver / editar ficha` (P:1858). Not dismissible by barrier. Returns true on save → list refresh.
- Title `Ficha del conductor`; subtitle `Cargando información completa...` while loading, then user email (fallback user id).
- Actions: TextButton `Cerrar` (disabled while saving); FilledButton.icon Mi `save_rounded` `Guardar cambios` (disabled loading/saving; spinner while saving).
- Loading: centered spinner. Load error w/o data: red centered error text. Inline error box: bg #FFF1F1 r10, text #B42318 11.
- Section `Fotos para aprobación` (Mi `photo_library_outlined`): OutlinedButton Mi `account_circle_outlined` `Ver foto de perfil` (if exists); per vehicle photo OutlinedButton Mi `directions_car_outlined` `Foto vehículo {n}`. Empty: `El conductor todavía no cargó fotografías.`; if only profile: `No hay fotos del vehículo cargadas.` Open fail snack: `No se pudo abrir el archivo.` / `No se pudo abrir el archivo: {e}`.
- Section `Datos personales y operación` (Mi `person_rounded`):
  - Text `Nombre completo`; Text `Teléfono`; read-only text `Correo (solo lectura)`.
  - 2-col: Dropdown `Estado de cuenta`: `Activa`(active) / `Suspendida`(suspended) / `Bloqueada`(blocked). Dropdown `Aprobación conductor`: `Aprobado` / `Pendiente` / `Rechazado` / `Suspendido`. Dropdown `Estado operativo`: `Fuera de línea`(offline) / `En línea`(online) / `Ocupado`(busy). Dropdown `País`: items `{country} · {CODE}`.
  - Dropdown full width `Zona / ciudad`, hint `Selecciona una zona del país`; items `{city}[ · {name}] · {region_department|currency_code}`; disabled until country chosen.
  - Text `Número de licencia`.
- Section `Vehículo` (Mi `two_wheeler_rounded`): Dropdown `Tipo`: `Moto`(motorcycle) / `Auto`(car) / `XL`(xl). 2-col text: `Marca`, `Modelo`, `Color`, `Placa`, `Año` (number keyboard).
- Validation messages on save: `Selecciona un país para el conductor.` · `Selecciona una zona para el conductor.` · `La zona seleccionada ya no está disponible.` · `La zona no corresponde al país seleccionado.` · `El año del vehículo no es válido.`
- Section `Documentos e identidad` (Mi `badge_rounded`):
  - Intro `Revisa las imágenes y aprueba o rechaza cada documento. No necesitas editar datos técnicos.` (12 muted).
  - Empty: `El conductor todavía no cargó documentos.`
  - Per document card (#F8FAFC r12 border #E2E8F0): type label (`Licencia de conducir` / `Cédula de identidad` / `Documento del vehículo` / `Seguro del vehículo` / fallback `Documento del conductor`) 14/w800 + Chip status (`Aprobado` / `Rechazado` / `Vencido` / `Pendiente`); `Número: {n}`; `Vencimiento: {date}`; rejection note in #B42318 when rejected.
  - Asset buttons (Outlined, icon 16): `Ver frente` (credit_card_rounded), `Ver reverso` (flip_to_back_rounded), `Ver foto facial` (face_rounded).
  - Review buttons: FilledButton `Aprobar` (check_circle_outline; hidden if verified); OutlinedButton `Rechazar` (cancel_outlined; hidden if rejected); TextButton `Reabrir revisión` (restart_alt; hidden if pending).
  - Confirm sub-dialog: title `Aprobar {label}` / `Rechazar {label}` / `Volver a revisar {label}`; body reject: `Indica por qué se rechaza. El conductor podrá corregirlo.` else `Solo cambiará el estado de este documento. La aprobación general del conductor se hace por separado.`; reject field (3 lines) label `Motivo del rechazo`, hint `Ej.: foto ilegible o documento incorrecto`; actions `Cancelar` + FilledButton `Confirmar rechazo` / `Aprobar documento` / `Reabrir revisión`. Validation: `Indica un motivo de rechazo de al menos cinco caracteres.` Success snack `{label}: {Aprobado|Rechazado|Pendiente}.`; error `No se pudo actualizar el documento. {e}`.
  - Divider, subheading `Revisión de identidad` (w900); empty `Aún no se realizó la revisión.`; up to 3 rows: Mi `fact_check_outlined` + `Verificación manual` + status Chip.
- Section `Resumen operativo` (Mi `insights_rounded`) InfoGrid: `Calificación` = `{avg} / 5 · {count} evaluaciones`; `Suscripción` = `{plan} · {status}` or `Sin suscripción`; `Vence suscripción`; `QA / pruebas` = `{group} · {role}` or `Cuenta real`; `Empresa / sindicato` = name or `Sin organización`; `Alta` = created date.

### 10.2 Ficha del usuario — `showAdminUserEditor` (D:106-120, 1151-1426)
Opened from: Section 5 Usuarios → row menu `Ver / editar perfil` (P:2046). Not barrier-dismissible.
- Title `Ficha del usuario`; subtitle `Cargando perfil...` → email.
- Actions: `Cerrar`; FilledButton.icon Mi `save_rounded` `Guardar cambios`.
- Error box bg #FFF1F1 text #B42318 (no radius here).
- Section `Perfil y cuenta` (Mi `person_rounded`): Text `Nombre completo`; Text `Teléfono`; read-only `Correo (solo lectura)`; 2-col: Dropdown `Modo activo`: `Pasajero`(passenger) / `Conductor`(driver); Dropdown `Estado`: `Activa` / `Suspendida` / `Bloqueada`; Dropdown `Zona`: `Sin zona asignada` + zone names. No client validation.
- Section `Resumen` (Mi `analytics_outlined`): `Billetera` = `{CUR} {balance}` or `Sin billetera`; `Calificación`; `QA / pruebas` (`Cuenta real`); `Alta`.
- Section `Viajes recientes` (Mi `local_taxi_outlined`): up to 10 ListTiles, Mi `route_rounded` blue; title `{pickup|Origen} → {destination|Destino}` (2 lines); subtitle `{status} · {fare 0.00} · {date}`. Empty `No hay viajes recientes.`

### 10.3 Detalle del viaje — `showAdminTripDetail` (D:122-134, 1428-1669)
Opened from: Section 2 Viajes → tap row (admin only, P:1717). Read-only. Barrier-dismissible.
- Title `Detalle del viaje`; subtitle `Información operativa, cobro, historial y participantes.`; action TextButton `Cerrar`.
- Loading spinner; error red text.
- `Ruta` (Mi `route_rounded`): pickup (13/w900), Mi `south_rounded` arrow, destination; InfoGrid `Zona` (fallback `Sin zona`), `Servicio`, `Distancia` (`{n} km`), `Duración estimada` (`{n} min`).
- `Participantes` (Mi `people_alt_rounded`): `Pasajero`, `Teléfono pasajero`, `Conductor`, `Teléfono conductor`.
- `Tarifa y pago` (Mi `payments_rounded`; currency default `BOB`): `Tarifa propuesta`, `Tarifa final`, `Método solicitado`, `Estado de pago`, `Modo de precio`, `Demanda` (`{level} · x{multiplier}`). Payments list: Mi `receipt_long_outlined`; title `{CUR amount} · {method}`; subtitle `{status} · comisión {CUR amt} · {date}`. Wallet: `Movimientos de billetera: {n}` then rows `{reference}` … `{amount} · {status}`.
- `Fechas y estado` (Mi `schedule_rounded`): `Estado actual`, `Creado`, `Programado`, `Completado`, `Cancelación`, `ID viaje`.
- `Historial del viaje` (Mi `timeline_rounded`): ListTiles dot Mi `circle` 10 blue; title status; subtitle `{date} · {changed_by_name|Sistema}`. Empty `Sin historial.`
- `Calificaciones` (Mi `star_rounded`): Mi `star_rounded` #F59E0B; `{score} / 5`; subtitle `{comment|Sin comentario} · {date}`. Empty `Este viaje todavía no tiene calificaciones.`

### 10.4 Which section opens which dialog
| Dialog | Section | Trigger | zone_monitor |
|---|---|---|---|
| Ficha del conductor | 4 Conductores | menu `Ver / editar ficha` | hidden |
| Ficha del usuario | 5 Usuarios | menu `Ver / editar perfil` | hidden |
| Detalle del viaje | 2 Viajes | tap row | disabled (row expands instead) |
| (none) | 3 Delivery, 6 SOS, 1 Live | — | — |

---

## 11. Role / environment visibility summary
- zone_monitor (`adminAccess.role == 'zone_monitor'`): reduced nav; green locked scope bar `Solo lectura`; no Nuevo viaje in compact AppBar (still shown in wide `_TopBar` — bug); no row menus in Conductores/Usuarios; no `Resolver` in SOS; Viajes not clickable; sections outside {0–6, 26} → restricted screen.
- Preview vs Production: banner colors/text, login sub-line, Google login (Preview only), env link label, live trip env pill `Prueba`/`Producción`, Preview module blocking text. `allowPreview`/`allowProduction` only gate access (returns unauthorized) and are passed to sections 10/12/14 (out of scope).
- Observations for designer: notifications bell red dot is static; `SOS · Sin alertas` footnote static; Users geo filters don't affect the server query; status chips show raw English codes (`approved`, `online`, `active`, …).
