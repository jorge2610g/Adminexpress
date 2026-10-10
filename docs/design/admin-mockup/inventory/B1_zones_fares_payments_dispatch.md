# B1 — UI inventory: Zonas y cobertura (7/17), Tarifas (8), Pagos / Billetera (9), Despacho manual (13)

Source repo: `/home/user/adminexpress`. All paths relative to `lib/`. `ACS` = `lib/admin_control_sections.dart`.
Read-only extraction. Strings are verbatim Spanish. `→` in a string is literal.

---

## 0. Shared building blocks (used by every screen below)

| Widget | File:line | Visual / content |
|---|---|---|
| `_Header(title, subtitle, action?)` | ACS:8962-9081 | Gradient banner (#102A56→#174B91→#0D6B8D, radius 20). Left: 42×42 translucent tile with icon `dashboard_customize_rounded`. Title 23/w900 white; subtitle 11/w600 #D7E7FA. Optional `action` widget at right; under 680px width the action wraps below the copy (and the icon tile is dropped). |
| `_Kpi(title, value)` | ACS:9083-9152 | White card 220px wide, radius 18; 42×42 #E1ECFF tile w/ icon `auto_graph_rounded`; value 23/w900, label 10/w700 muted. |
| `_NumberField(controller,label)` | ACS:9154-9174 | TextField, keyboard number decimal+signed, only `labelText`. |
| `_SettingsCard(title, subtitle?, children)` | ACS:9176-9256 | White card radius 16; 40×40 #EAF2FF icon tile; icon chosen by title keyword (`_settingsIcon` ACS:9258): contains "pago"→`account_balance_wallet_outlined`; "servicio"/"módulo"→`apps_rounded`; "operación"/"dispatch"→`alt_route_rounded`; "tarifa"/"alcance"→`payments_outlined`; "soporte"/"localización"→`support_agent_rounded`; else `tune_rounded`. Divider then children. |
| `_ReadOnlyRow(label,value)` | ACS:9268-9304 | label muted 11 left, value 11/w800 right. |
| `_DispatchItem(icon,title,subtitle,onAssign)` | ACS:9306-9402 | White row radius 11; 36×36 #EAF2FF icon; title 11/w900 (max 2 lines), subtitle 10 muted. Right: `FilledButton` **"Asignar"**. Under 560px: stacked, full-width `FilledButton.icon` (icon `person_add_alt_1_rounded`) **"Asignar conductor"**. |
| `_MiniStatus(text, positive)` | ACS:9404-9435 | Pill chip 9/w900; positive = green #E8F8EF/#14804A, else grey #F2F4F7/#667085. |
| `_Empty(text)` | ACS:9437-9451 | Flat card, 28 padding, muted text. |
| `_Loading(title)` | ACS:9453-9474 | Title 25/w900 + `LinearProgressIndicator`. |
| `_Error(error,onRetry)` | ACS:9476-9509 | Centered card: icon `error_outline_rounded` 46, raw error text, `FilledButton.icon` (`refresh_rounded`) **"Reintentar"**. |
| `_InlineNotice(icon,text)` | ACS:8931-8959 | #F7F9FC box, blue icon 20, muted text 10. |
| `_snack(context, e)` | ACS:9528 | SnackBar **"Error: <error>"** (note: also used for validation strings, so those display as "Error: …"). |
| `_num(text)` | ACS:9524 | Parses number, accepts comma as decimal. |

Colors: `_blue #2563EB`, `_dark #0F172A`, `_muted #64748B` (ACS:16-18).

---

## 13. Despacho manual — `AdminDispatchPage` (ACS:20-445)

Params: `channel` (default `'preview'`), `countryCode?`, `zoneId?` (ACS:20-30). Data: RPC `admin_open_service_requests_v2(p_channel)`, `admin_available_drivers_v2(p_channel)`, `admin_zone_list_for_country(p_country_code)`; rows filtered to selected zone, or to all zones of selected country; no filter if neither (ACS:86-133). No in-page country/zone selector — scope comes from the shell.

### Main screen (build ACS:338-444)
- Loading: `_Loading` **"Cargando despacho"** (ACS:351). Error: `_Error` + "Reintentar" (ACS:354).
- `_Header` (no action):
  - title: preview → **"Despacho manual · Prueba"**; production → **"Despacho manual · Producción"** (ACS:371-373)
  - subtitle: preview → **"Solo solicitudes y conductores del entorno Preview / QA."**; production → **"Solo servicios reales de clientes en Producción."** (ACS:374-376)
- Info card (#EAF2FF, blue w900 text): **"Conductores disponibles ahora: {n}"** (ACS:379-393). Only metric on the page.
- Section heading (20/w900) **"Solicitudes de viaje"** (ACS:395)
  - Empty: **"No hay viajes esperando asignación."** (ACS:401)
  - Row `_DispatchItem`, icon `local_taxi_rounded`; title `"{pickup_address|'Origen'} → {destination_address|'Destino'}"`; subtitle `"{passenger_name|'Pasajero'} · Bs {proposed_fare|'—'}"` (currency **hard-coded "Bs"**); action "Asignar" → dialog A (ACS:403-416).
- Section heading **"Delivery esperando"** (ACS:418)
  - Empty: **"No hay delivery esperando asignación."** (ACS:424)
  - Row icon `local_shipping_rounded`; title `"{pickup_address|'Origen'} → {dropoff_address|'Destino'}"`; subtitle `"{customer_name|'Cliente'} · Bs {proposed_fare|'—'}"`; action → dialog B (ACS:426-438).

### Dialog A — "Asignar viaje" (ACS:135-241)
- Pre-check: drivers filtered by same zone + vehicle compatibility (motorcycle→motorcycle; xl→xl; economy/comfort→car or xl; other→any; driver with no vehicle_types → incompatible) (ACS:48-84). If none: SnackBar **"No hay conductores compatibles con la zona y categoría del viaje."** (ACS:148).
- AlertDialog width 480, title **"Asignar viaje"**.
  - Text line: `"{pickup} → {destination}"`.
  - Dropdown **"Conductor disponible"**; items `"{name|'Conductor'} · ★ {rating|'—'}"`; default first compatible driver.
  - `_NumberField` **"Tarifa final"** (prefilled with `proposed_fare`; no currency suffix, no validation; empty → null).
  - Actions: TextButton **"Cancelar"**; FilledButton **"Asignar"** (disabled while no driver).
- Success SnackBar **"Viaje asignado."**; error → "Error: …". RPC `admin_assign_ride_v2(p_ride_request_id,p_driver_id,p_final_fare,p_channel)`.

### Dialog B — "Asignar delivery" (ACS:243-336)
- Pre-check (zone only): SnackBar **"No hay repartidores disponibles en esta zona."**
- Title **"Asignar delivery"**, width 480; text `"{pickup} → {dropoff}"`; dropdown **"Repartidor disponible"** (items same format, fallback name "Conductor"); actions **"Cancelar"** / **"Asignar"** (disabled when null).
- Success **"Delivery asignado."**. RPC `admin_assign_delivery_v2`.

No permission gating inside the page; works on both channels (channel passed to RPCs).

---

## Shell context for these sections (`lib/admin_panel.dart`)

- Nav labels: index 7 **"Zonas y cobertura"** (icon `hexagon_outlined`, admin_panel.dart:275); index 17 **"Cobertura y seguridad"** (icon `gpp_good_rounded`, :285). (8/9/13 labels are in the same list, not re-read here.)
- Above every page in these sections the shell renders (admin_panel.dart:1141-1148):
  1. Environment band `_environmentSwitcher` (:911-968): preview → icon `science_rounded`, text **"EXPRESS PREVIEW · Solo registros de prueba"** (orange #FFF7E6 bg); production → icon `verified_rounded`, **"EXPRESS PRODUCCIÓN · Datos reales"** (green #E8F8EF). Right: `AdminEnvironmentLinkButton`.
  2. Geo scope bar `_globalGeoScopeSwitcher` (:713-899): label **"Ámbito obligatorio"** (icon `public_rounded`); dropdown **"País"** (hint **"Selecciona un país"**, items = country name), dropdown **"Zona"** (hint **"Selecciona una zona"**, items `"{name} · {city}"`; disabled text field with hint **"Primero selecciona un país"** until a country is chosen); helper **"Selecciona país y zona para cargar datos."** while incomplete. For role `zone_monitor`: green locked bar **"Monitor de zona · {country} · {zone_name}"** + **"Solo lectura"**.
- Gating (`_body`, :1177-1201):
  - Preview channel and section not in `_previewScopedModules = {0,1,2,3,4,5,6,7,8,10,11,14,16,17,18,27}` (:244) → centered text **"Este módulo todavía no tiene aislamiento seguro por canal. Está bloqueado en Prueba para proteger los datos reales. Puedes gestionar conductores, documentos, viajes y configuración QA desde sus secciones."** ⇒ **Section 9 (Pagos) and 13 (Despacho) are blocked in Preview**; 7, 8, 17 work in Preview.
  - Scope not chosen → `_ScopeSelectionRequired` (:2146): icon `filter_alt_outlined`, **"Selecciona país y zona"** / **"No se cargarán usuarios, viajes, conductores ni métricas hasta elegir el ámbito."**
  - zone_monitor role and section not in {0..6,26} → `_ZoneMonitorRestricted` (:2188): icon `lock_outline_rounded`, **"Módulo reservado al administrador global"** / **"El monitor de zona tiene acceso operativo de solo lectura."** ⇒ 7, 8, 9, 13, 17 all hidden for zone monitors.
- Section 7 wrapper (:1218-1251): white `TabBar` with 2 tabs: [icon `location_city_outlined`] **"Zonas y cobertura"** → `AdminZonesPage`; [icon `shield_outlined`] **"Seguridad"** → `AdminGeoSafetyPage`. Section 17 (:1298-1303) = `AdminGeoSafetyPage` alone (identical content to tab 2).
- `AdminRuntimeScope` (`lib/admin_runtime_scope.dart`): no UI; environment labels **"Producción"** / **"Prueba"** (:12-15); its `cacheKey` keys the page subtree so pages rebuild on channel/country/zone change.
- `AdminPreviewModulePage` (`lib/admin_preview_config_sections.dart`) is **not referenced** by any of these sections (no usage anywhere in `lib/`).

---

## 7 (tab 1). Zonas y cobertura — `AdminZonesPage` (ACS:664-2624)

Data: Only the **currently selected zone** is listed (filters list to `widget.zoneId`) (ACS:686-715). Preview reads shadow store `service_zones` + `zone_payment_methods`; production `admin_zone_list_for_country`.

### Main screen (ACS:2465-2623)
- Loading **"Cargando zonas"**; error → `_Error`.
- `_Header` title **"Zonas de operación"**, subtitle **"Cada ciudad funciona como una unidad independiente de servicios, tarifas y suscripciones."**
  - Header actions: `OutlinedButton.icon` [`public_rounded`] **"Países"** → pushes full page `AdminCountryCoveragePage` (§7.A); `FilledButton.icon` [`add_rounded`] **"Nueva zona"** → zone dialog (§7.B). Always visible (no permission checks).
- Empty: **"No hay zonas configuradas."**
- Zone row (ListTile in bordered white box, isThreeLine):
  - Leading avatar icon: active → `location_on_rounded`, else `location_off_outlined`.
  - Title: `name` (fallback **"Zona"**), w900.
  - Subtitle line 1: `"{city|—} · {country|—} · {currency_code|BOB} · Cobertura: {coverage}"` where coverage = `adminZoneCoverageSummary` (`lib/core/admin_zone_coverage_label.dart:4-15`): **"Polígono"** | **"Radio {radius_km|—} km"** | **"Sin información"**.
  - Subtitle line 2: `"Clave: {zone_key|—} · Registro: {ON|OFF} · Inicio: {Automático|Panel|Directo}"` (landing mode auto/always/direct; default direct).
  - Trailing: `_MiniStatus` **"País OFF"** (if country_active false) / **"Activa"** / **"Inactiva"** (green only if active and country on); IconButtons with tooltips: **"Aliados / sindicatos"** [`groups_2_outlined`] → §7.D; **"Métodos de pago"** [`account_balance_wallet_outlined`] → `showAdminZonePaymentMethodsEditor` (§9.Z); **"Editar zona"** [`edit_outlined`] → §7.B.

### 7.A Full page — `AdminCountryCoveragePage` (`lib/admin_country_coverage.dart`)
Embedded from: Zones header "Países" (ACS:2492-2506), zone dialog link "Administrar países" (ACS:2039-2073), and auto-opened when creating a zone with no countries (ACS:1817-1829).
- Scaffold bg #F7F9FC; AppBar title **"Países y cobertura · Preview"** / **"Países y cobertura · Producción"** (:389-393).
- Loading: centered `CircularProgressIndicator`; error: centered friendly text (see messages below).
- Heading **"Países de operación"** (23/w900) + **"Activa países y registro de conductores. Identidad es manual; la cobertura depende de las ciudades activas."** (:427-441)
- Buttons: Preview only → `OutlinedButton.icon` [`copy_all_outlined`] **"Preparar países QA"**; always → `FilledButton.icon` [`add_rounded`] **"Nuevo país"**.
- Empty card: **"No hay países configurados. Crea el primero antes de crear zonas."**
- Country row: avatar `public_rounded` (active, blue) / `public_off_rounded` (grey); title name|code|**"País"**; subtitle `"{country_code} · {currency_code} · {calling_code|'sin prefijo'} · {zones_active}/{zones_total} zonas activas"`; trailing pills **"País ON"/"País OFF"**, **"Registro ON"/"Registro OFF"** (green only if country active), **"Verificación manual"** (always green), IconButton **"Editar país"** [`edit_outlined`].
- Dialog **"Preparar países de prueba"** (preview only, :53-74): body **"Se copiarán únicamente nombre, código de país, moneda y prefijo a la configuración QA de Preview. Todos los países y registros de conductores quedarán desactivados por defecto. No se modificarán los países reales de Producción."**; buttons **"Cancelar"** / **"Preparar QA"**. Success snack **"QA preparado: {n} países de prueba. Producción permanece sin cambios."**
- Dialog **"Nuevo país"/"Editar país"** (width 590, :167-282):
  - Info box: **"Un país activo no habilita todo su territorio: Express solo funciona dentro de ciudades / zonas activas creadas en el panel. Así puedes preparar Brasil o Argentina sin abrir servicio hasta que actives una ciudad."**
  - Text **"Código ISO del país"** — hint **"CL / BO / BR / AR"**, uppercase, maxLength 2, **disabled when editing**.
  - Text **"Nombre del país"** — hint **"Brasil"**.
  - Text **"Moneda"** — hint **"BRL"**, uppercase, maxLength 3.
  - Text (phone keyboard) **"Prefijo telefónico internacional"** — hint **"+55"**, helper **"Se usa para el contacto y registro. No se envían códigos SMS."**
  - Switch **"País habilitado"** — sub **"Si está apagado, ninguna ciudad de este país queda disponible para la app."** (default off for new).
  - Switch **"Registro de conductores"** — sub **"Permite registro solo dentro de ciudades activas del país."** (disabled when país off; default on).
  - Divider + static ListTile [`verified_user_rounded` green] **"Identidad: verificación manual"** / **"Carné frontal, reverso y selfie. La revisión se gestiona en Verificación de identidad. Didit y la verificación SMS están retirados."**
  - Actions **"Cancelar"** / **"Guardar"**.
  - Success snack: active → **"País guardado. Ahora puedes crear y activar sus ciudades."**; inactive → **"País guardado como inactivo. La app bloqueará sus zonas."**
  - Friendly server errors (:130-142): **"Usa el código ISO de 2 letras, por ejemplo CL, BO, BR o AR."** / **"Usa un código de moneda de 3 letras, por ejemplo CLP, BOB, BRL o ARS."** / **"Usa el prefijo internacional con +, por ejemplo +56, +591, +55 o +54."** / else raw message.
  - Hidden (not rendered, sent as null/fixed): didit=false, manual fallback=true, workflow ids.

### 7.B Dialog — "Nueva zona" / "Editar zona" (ACS:1814-2462), width 500, scrollable
Pre-steps: if no country in scope → pushes `AdminCountryCoveragePage`; still none → snack **"Error: Primero crea un país antes de crear una ciudad."** Production edit loads coverage via `admin_zone_coverage_get`; failure → **"Error: No se pudo cargar la cobertura: {error}"**.
Country list for the dropdown = only the currently scoped country.

Fields in order:
1. Info box [`hub_outlined`]: **"Cada zona puede tener servicios, tarifas, suscripciones y varios métodos de pago propios. Las credenciales sensibles se administran de forma segura por integración."**
2. Text **"Nombre"**.
3. Text **"Clave de zona"** — hint **"Ej. trinidad, iquique, santa_cruz"**, helper **"Se genera desde la ciudad si la dejas vacía. No cambia después de crearla."**; **enabled only when creating**.
4. Text **"Ciudad"**.
5. Dropdown **"País"** (prefix icon `public_rounded`), items `"{name|'País'} · {country_code}"`; changing it auto-fills Moneda with the country's currency.
6. `TextButton.icon` [`settings_outlined`] **"Administrar países"** → pushes §7.A then refreshes list.
7. Text **"Región / departamento"** — hint **"Ej. Tarapacá / Beni"**.
8. Text **"Moneda"** — hint **"BOB / CLP"**, uppercase; default = country currency.
9. **Coverage editor** `AdminZoneCoverageEditor` (`lib/admin_zone_coverage_editor.dart`, embedded ACS:2093-2104) — see §7.C.
10. Panel box [`dashboard_customize_outlined`] **"Pantalla inicial del pasajero"** — desc **"Decide si esta zona entra directo a un servicio o muestra un panel para elegir entre Viajes, Envíos y Express Market."**
    - Dropdown **"Comportamiento de inicio"**: `auto` **"Automático"** | `always` **"Mostrar siempre el panel"** | `direct` **"Entrada directa"**. Default: new → auto; existing w/o value → direct.
    - Dropdown **"Servicio predeterminado"**: `ride` **"Viajes"** | `delivery` **"Envíos / Delivery"** | `market` **"Express Market"** (default ride).
    - Text **"Título del panel"** (default **"¿Qué necesitas hoy?"**).
    - Text **"Subtítulo del panel"** (default **"Elige un servicio de Express"**).
    - Label **"Orden de tarjetas"** + 3 number fields in a row: **"Viajes"** (hint 1), **"Envíos"** (hint 2), **"Market"** (hint 3). Defaults from stored order; missing → 99. Invalid → 1/2/3.
    - Dynamic helper: auto → **"Automático: con varios módulos visibles muestra el panel; con uno solo entra directo."**; always → **"Siempre: muestra el panel aunque haya un solo módulo visible."**; direct → **"Directo: abre el servicio predeterminado sin mostrar el panel."**
11. Switch **"Zona activa"** — sub **"La app puede detectarla automáticamente por GPS."** (default on).
12. Switch **"Registro de conductores en esta zona"** — sub **"Si está apagado, un conductor ubicado aquí verá que Express todavía no está disponible para registrarse."** (default on; disabled while Zona activa is off).
- Actions **"Cancelar"** / FilledButton **"Guardar zona y cobertura"**.
- Validation after save (snack, prefixed "Error: "): polygon with <3 points → **"Dibuja tres o más puntos para el polígono."**; radius mode with bad lat/lng or radius ≤0 → **"Selecciona un centro y un radio válido."** Radius default 25.
- Success snack **"Zona y cobertura guardadas. Solo se usará el método seleccionado."**, then **automatically opens the zone payment-methods editor (§9.Z)** for the saved zone (ACS:2441).

### 7.C Embedded widget — `AdminZoneCoverageEditor` (`lib/admin_zone_coverage_editor.dart:7-201`)
- Title **"Tipo de cobertura"** (15/w900); sub **"Selecciona un solo método. El otro no tendrá efecto."**
- `SegmentedButton`: [`radar_rounded`] **"Radio"** (`radius`) | [`polyline_rounded`] **"Polígono"** (`polygon`).
- Instruction: polygon → **"Dibuja el área exacta marcando 3 o más puntos. El radio no se utilizará."**; radius → **"Toca el mapa para elegir un centro. Solo cuenta el radio seleccionado."**
- Radius mode only: number fields **"Latitud"** | **"Longitud"** (signed decimal, side by side), **"Radio (km)"** — helper **"Se mostrará como un círculo sobre el mapa."**
- Map (height 320, radius 16, OSM tiles): initial center = first polygon point or lat/lng or (-18,-66); zoom 4.2 if empty else 11. Tap: radius → sets lat/lng (6 decimals); polygon → appends vertex. Radius render: blue circle (meters) + `location_pin` marker. Polygon render: filled polygon when ≥3 points; numbered blue circular vertex markers (31px, 1..n).
- Polygon mode footer: **"{n} puntos"**, `TextButton.icon` [`undo_rounded`] **"Deshacer"**, [`delete_outline_rounded`] **"Borrar"** (both disabled when 0 points). No drag/move of vertices, no search.

### 7.D Dialog — "Aliados y sindicatos · {zone}" (ACS:1656-1812), 920×560
- Title row: icon `groups_2_outlined`, title, `FilledButton.icon` [`add_rounded`] **"Nuevo"** → §7.E.
- Loading **"Cargando aliados"**; empty **"Esta zona todavía no tiene sindicatos o empresas aliadas."**
- Row card: avatar `groups_2_rounded` (syndicate) / `business_outlined`; name (fallback **"Aliado"**); line **"Comisión: {commission_percent}% · Conductores activos: {drivers_active}"**; line (12 muted) **"Pagos de conductores: {payments_approved} · Comisión generada: {commission_generated} · Liquidada: {commission_paid}"**; `_MiniStatus` **"Activo"/"No activo"**; IconButtons **"Dashboard financiero"** [`dashboard_customize_outlined`] → §7.G, **"Usuarios del panel"** [`admin_panel_settings_outlined`] → §7.F, **"Editar aliado"** [`edit_outlined`] → §7.E.
- Action **"Cerrar"**.

### 7.E Dialog — "Nuevo sindicato · {zone}" / "Editar aliado · {zone}" (ACS:755-957), width 560
- Text **"Nombre del sindicato o aliado"**
- Text **"Código interno"** — hint **"Se genera automáticamente si queda vacío"**
- Dropdown **"Tipo de organización"**: `syndicate` **"Sindicato"** (default) | `allied_company` **"Empresa aliada"** | `cooperative` **"Cooperativa"**
- Dropdown **"Estado"**: `active` **"Activo"** (default) | `suspended` **"Suspendido"** | `inactive` **"Inactivo"**
- Number **"Comisión para el aliado (%)"** (default 0) — helper **"Se calcula solo sobre pagos de sus conductores."**
- Text **"Responsable / presidente"**; **"Teléfono"**; **"Correo"**; **"Notas"** (3 lines).
- Actions **"Cancelar"** / **"Guardar"**. No client validation.

### 7.F Dialog — "Accesos · {partner}" (ACS:974-1233), 760×430
- Title row: icon `admin_panel_settings_outlined`; `FilledButton.icon` [`person_add_alt_1_rounded`] **"Asignar acceso"**.
- Loading **"Cargando accesos"**; empty **"Esta organización todavía no tiene usuarios con acceso al panel."**
- Row: avatar `verified_user_outlined` (active) / `person_off_outlined`; title full_name or email; subtitle `"{email} · {rol}"`; trailing **Switch** (active on/off, saves immediately).
- Role labels: owner **"Propietario / presidente"**, manager **"Administrador"**, operator **"Operador"**, treasurer **"Tesorería"**.
- Action **"Cerrar"**.
- Sub-dialog **"Asignar acceso al panel"** (width 500): note **"La persona debe tener una cuenta Express registrada. Usará el mismo correo y contraseña, pero verá solo el panel de esta organización."**; email field **"Correo de la cuenta Express"** (prefix `mail_outline_rounded`); dropdown **"Rol"** (4 roles above; default manager **"Administrador"**); actions **"Cancelar"** / `FilledButton.icon` [`person_add_alt_1_rounded`] **"Asignar"**. Empty email → silently nothing. Success snack **"Acceso asignado. Ya puede iniciar sesión en Adminexpress."**

### 7.G Dialog — "Dashboard · {partner}" (ACS:1235-1654), 1020×650
- Title row: icon `dashboard_customize_outlined`; `OutlinedButton.icon` [`date_range_outlined`] **"Período"** (date-range picker; default = 1st of current month → today; range year-3 … next year end); `FilledButton.icon` [`receipt_long_outlined`] **"Crear liquidación"** (success **"Liquidación creada."**).
- Loading **"Cargando dashboard del aliado"**.
- 7 metric tiles (180px): **"Conductores"**, **"Conductores online"**, **"Pagos aprobados"**, **"Facturación {CUR}"**, **"Comisión generada {CUR}"**, **"Comisión pendiente {CUR}"**, **"Comisión liquidada {CUR}"**.
- Heading **"Liquidaciones"**; empty **"Todavía no hay liquidaciones."**; row: icon `account_balance_outlined`, title `"{CUR} {commission_amount}"`, subtitle `"Bruto: {CUR} {gross_amount} · {fecha}"`, trailing `_MiniStatus` **"Pagada"** (paid) or `FilledButton` **"Marcar pagada"**.
- Heading **"Pagos de conductores"**; empty **"No hay pagos en este período."**; up to 30 dense rows: icon `receipt_long_rounded`, driver_name (fallback **"Conductor"**), `"{provider} · {fecha}"`, trailing right-aligned `"{CUR} {amount}\nComisión {partner_commission_amount}"`.
- Action **"Cerrar"**.
- Sub-dialog **"Marcar liquidación como pagada"** (width 460): **"Referencia / comprobante"**, **"Nota opcional"** (3 lines); **"Cancelar"** / **"Confirmar pago"**; success **"Liquidación marcada como pagada."**

---

## 7 (tab 2) & 17. Seguridad / Cobertura y seguridad — `AdminGeoSafetyPage` (ACS:3172-3676)

Data: empty unless country+zone selected; zones/coverage polygons/security zones filtered to selected zone (ACS:3194-3250).

### Main screen (ACS:3606-3675)
- Loading **"Cargando cobertura y seguridad"**; error → `_Error`.
- `_AdminHero` (ACS:3889-4010; blue gradient #0B57D0→#5B74F5, 48px icon tile) icon `shield_outlined`, title **"Seguridad de zonas"**, subtitle **"La cobertura por radio o polígono se configura directamente al crear o editar la zona. Aquí solo se administran sectores de seguridad, precaución o riesgo."**; stat chips **"Zonas"** = count, **"Sectores de seguridad"** = count.
- `_Header` title **"Zonas rojas y prevención"**, subtitle **"Sectores de riesgo y zonas seguras para conductores y pasajeros."**, action `FilledButton.icon` [`add_moderator_outlined`] **"Crear sector"** → §17.A.
- Empty **"Todavía no hay sectores de seguridad."**
- Row `_GeoRow` (ACS:4107-4175): 40px tinted icon tile (safe → `verified_user_outlined`; else `warning_amber_rounded`); color by type (`_securityTone` ACS:4188: safe #12B76A, caution #F79009, red #D92D20); title name (fallback **"Zona de seguridad"**); subtitle `"{Zona segura|Precaución|Zona roja} · nivel {severity|3}"`; tinted pill **"Activa"/"Inactiva"**; edit IconButton [`edit_outlined`]; whole row tappable → edit.
- Note: security-zone list RPC (`admin_security_zone_list`) is filtered client-side by `zone_id`.

### 17.A Dialog — "Crear zona de seguridad" / "Editar zona de seguridad" (ACS:3400-3604), width 780
- Text **"Nombre"** — hint **"Ej. Zona roja nocturna"**
- Row: Dropdown **"Tipo"**: `red` **"Zona roja"** (default) | `caution` **"Precaución"** | `safe` **"Zona segura"**; Dropdown **"Aplica a"**: `both` **"Pasajero y conductor"** (default) | `driver` **"Solo conductor"** | `passenger` **"Solo pasajero"**
- Row: Text **"Ciudad"** (default **"Trinidad"**) | Text **"País"** (default **"Bolivia"**) — free text, not tied to scope.
- Text (2 lines) **"Mensaje preventivo"** — hint **"Este sector requiere mayor precaución."**
- Row: label **"Nivel de riesgo"** + **Slider** 1–5, 4 divisions, value label, default 3 + circle badge with the number tinted by type color.
- Map `_PolygonEditor` (ACS:3753-3887) — tone = type color; overlay title **"Dibuja el perímetro de seguridad · {n} puntos"**.
- Switch **"Zona activa"** (default on).
- Actions **"Cancelar"** / `FilledButton.icon` [`shield_outlined`] **"Guardar zona"** — **disabled until ≥3 points**.

### Map widget `_PolygonEditor` (ACS:3753-3887)
- 430px tall, radius 16, OSM tiles, initial center = first point or (-14.8333, -64.9) [Trinidad], zoom 13; tap adds vertex. 2 points → polyline; ≥3 → filled polygon (tone 16% fill, 3px border); numbered 24px vertex dots; OSM attribution **"OpenStreetMap contributors"**.
- Floating top toolbar (white 95%): icon `touch_app_rounded`, **"{title} · {n} puntos"**, `TextButton.icon` [`undo_rounded`] **"Deshacer"**, [`delete_sweep_outlined`] **"Limpiar"** (disabled when empty).

### Dead / unreachable UI (keep in mind, not shown today)
- `_editCoverage` dialog (ACS:3270-3398) is **never called**: title **"Dibujar cobertura"/"Editar cobertura"**, Dropdown **"Zona"**, Text **"Nombre del polígono"** (default **"Cobertura principal"**), `_PolygonEditor` title **"Toca el mapa para marcar la cobertura"**, Switch **"Polígono activo"**, buttons **"Cancelar"** / [`save_outlined`] **"Guardar polígono"** (needs ≥3 pts); pre-check snack **"Primero crea una zona de operación."** Coverage is now edited inside the zone dialog (§7.C).

---

## 8. Tarifas — `AdminFaresPage` (ACS:4216-5144)

Data: empty unless country+zone selected. Fare rules (`admin_fare_list` / preview `fare_rules`) filtered to selected zone **or** zone_id null; zones = only selected zone; services from `admin_service_list` / preview `service_catalog` (ACS:4239-4312). Works in Preview (writes shadow store) and Production.

### Main screen (ACS:4972-5143), top to bottom
1. Loading **"Cargando tarifas por zona"**; error → `_Error`.
2. `_Header` title **"Tarifas por zona"**, subtitle **"Las reglas de la zona tienen prioridad sobre las reglas globales y de servicio."** Actions (only if a zone loaded): `OutlinedButton.icon` [`place_outlined`] **"Aeropuerto / Terminal"** → §8.C; `FilledButton.icon` [`add_rounded`] **"Nueva tarifa"** → §8.B.
3. **Distance-steps card** `AdminDistanceFaresEditor` (`lib/admin_distance_fares.dart`, embedded ACS:5040-5046, only when zone loaded) — §8.A.
4. Zone selector card (only if zones not empty): icon `location_city_rounded`, label **"Zona"**, dense dropdown **"Editar tarifas de"**, items `"{name|Zona} · {currency_code|BOB}"`. (Only one item: the scoped zone — effectively read-only.)
5. Fare rules list. Visible = all `global` + `service` rules + `zone_service` rules for this zone. Empty **"No hay reglas de tarifa configuradas."**
   - Row: avatar `payments_outlined`; title `_fareTitle` (ACS:9534): global → **"Global"**; service → **"Servicio · {service_key}"**; zone_service → **"{zone_name|Zona} · {service_key}"**; subtitle **"Base {base_fare} · km {per_km} · min {per_minute} · mínimo {minimum_fare} · comisión {commission_percent}%"** (no currency, no active/inactive chip); trailing IconButton [`edit_outlined`] (no tooltip) → §8.B. No delete action anywhere.

### 8.A Embedded card — `AdminDistanceFaresEditor` (`lib/admin_distance_fares.dart:9-352`)
- Card header icon `stacked_line_chart_rounded` + **"Tarifa escalonada por distancia"** (17/w900).
- Preview only: orange notice **"PREVIEW · Simulación QA: estos escalones no modifican las tarifas de pasajeros ni los precios de Producción."** (:242-244)
- Help text: **"Configura cuánto cuesta cada tramo en {CUR}. Los límites son inclusivos: 3 km = primer tramo, más de 3 km = siguiente tramo. Para distancias superiores al último escalón se prolonga el incremento final. Sin escalones se conserva la tarifa actual."** (CUR = zone currency, default BOB)
- No services → text **"No hay servicios configurados en esta zona."**; else outlined Dropdown **"Servicio"** — items = raw `service_key` strings, sorted (no display names); changing reloads steps; disabled while saving.
- Loading: `LinearProgressIndicator`.
- Empty steps: **"No hay escalones: se conserva la tarifa existente."**
- Step row (repeating): outlined number field **"Hasta km"** | outlined number field **"Precio ({CUR})"** | IconButton red [`delete_outline_rounded`] tooltip **"Eliminar escalón"**.
- Footer: `OutlinedButton.icon` [`add`] **"Agregar escalón"** (adds row with last km+1 / last price+1; first row defaults 3 km / 5) ; `FilledButton.icon` [`save_outlined`] **"Guardar escalones"** (disabled while saving or no service).
- Validation (red inline text): **"Ordena las distancias de menor a mayor y no disminuyas el precio."** (km must strictly increase, fare >0 and non-decreasing).
- Errors inline: **"No se pudieron cargar las tarifas: {error}"**, **"No se pudo guardar: {error}"**, **"Respuesta de tarifas no válida"**.
- Success snack: preview **"Tarifas de prueba guardadas solo en Preview."**; production **"Tarifas escalonadas de Producción guardadas."**

### 8.B Dialog — "Nueva tarifa" / "Editar tarifa" (ACS:4314-4534), width 520
- Info box: **"Usa “Zona + servicio” para que una tarifa afecte solo a una ciudad. Global y Por servicio quedan como reglas de respaldo."**
- Dropdown **"Jerarquía"**: `zone_service` **"Zona + servicio · recomendado"** (default) | `service` **"Por servicio · respaldo"** | `global` **"Global · respaldo general"**.
- Dropdown **"Servicio"** (hidden when Global): items service `name` (fallback key / **"Servicio"**); default first service or `motorcycle`.
- Dropdown **"Zona"** (only for Zona + servicio): items `"{name|Zona} · {currency_code|BOB}"`; default selected zone.
- `_NumberField`s (no units/currency shown, no validation, empty → 0):
  - **"Tarifa base"** (default 5)
  - **"Precio por km"** (default 1)
  - **"Precio por minuto"** (default 0)
  - **"Tarifa mínima"** (default 5)
  - **"Multiplicador dinámico"** (default 1; empty → 1)
  - **"Comisión %"** (default 0)
- Switch **"Regla activa"** (default on).
- Actions **"Cancelar"** / **"Guardar"**. Success snack **"Tarifa guardada."**

### 8.C Dialog — "Tarifas fijas · {zone}" (ACS:4811-4970), 860×520
- Title row: icon `place_rounded`; `FilledButton.icon` [`add_rounded`] **"Nueva"** → §8.D.
- Loading **"Cargando tarifas especiales"**; empty **"No hay sectores con tarifa fija. Crea Aeropuerto, Terminal u otro sector especial."**
- Row: avatar icon airport `flight_rounded` / terminal `directions_bus_rounded` / other `place_outlined`; title name (fallback type label); subtitle **"{Aeropuerto|Terminal|Especial} · {service_key|servicio} · {CUR} {fixed_fare|—} · prioridad {priority|100}"**; `_MiniStatus` **"Activa"/"Inactiva"**; IconButton tooltip **"Editar"** [`edit_outlined`].
- Action **"Cerrar"**.

### 8.D Dialog — "Nueva tarifa fija por sector" / "Editar tarifa fija" (ACS:4561-4809), width 820
- Pre-check snack: **"Error: No hay servicios disponibles."**
- Info box: **"Si el origen O el destino entra en este polígono, esta tarifa fija tiene prioridad sobre la tarifa normal de {zone name|la zona}. Si dos polígonos coinciden, manda el de mayor prioridad."**
- Text **"Nombre"** — hint **"Ej. Aeropuerto Teniente Jorge Henrich Arauz"**.
- Row: Dropdown **"Tipo de sector"**: `airport` **"Aeropuerto"** (default) | `terminal` **"Terminal"** | `custom` **"Otro sector especial"**; Dropdown **"Servicio"** (service names).
- Row: `_NumberField` **"Tarifa fija · {CUR}"** | `_NumberField` **"Prioridad"** (default 100).
- Map `_PolygonEditor` (see §17 map widget): tone airport #7F56D9 (purple), terminal #0E9384 (teal), custom blue; overlay title **"Dibuja el perímetro de aeropuerto"** / **"… de terminal"** / **"… de la zona especial"** + " · {n} puntos"; centered on zone center if known.
- Switch **"Tarifa especial activa"** (default on).
- Actions **"Cancelar"** / `FilledButton.icon` [`save_outlined`] **"Guardar tarifa"** — enabled only if ≥3 points AND fixed fare > 0 AND name not empty (note: enablement re-evaluates only on dialog rebuild, e.g. map tap/dropdown change, not on typing).
- No success snack (list just refreshes).

---

## 9.Z Shared dialog — `showAdminZonePaymentMethodsEditor` (ACS:5147-5470)
Embedded/opened from: Zones row icon **"Métodos de pago"** (ACS:2591-2608), automatically after saving a zone (ACS:2441), Payments page zone section (ACS:6227), and `lib/admin_driver_subscriptions.dart:1153`.
- Title **"Métodos de pago · {zone name|Zona}"**, 720×590.
- `_AdminPaymentNotice` (ACS:6594) text: **"Puedes habilitar varios métodos en una misma zona y decidir si cada uno se usa en Viajes, Delivery, Suscripciones y/o Billetera. “Principal” mantiene compatibilidad con la app móvil publicada."**
- One card per catalog provider (`admin_payment_method_catalog_list`); selected card tinted #F8FAFF with #B8CDF8 border:
  - `CheckboxListTile`: title `display_name` (fallback key, w900); subtitle **"{provider_type|gateway} · credenciales {credential_scope|zone}"**; trailing **Switch** = enabled (only active when checked; default on).
  - When checked: `FilterChip`s **"Viajes"**, **"Delivery"**, **"Suscripciones"**, **"Billetera"** (each disabled if provider doesn't support it; defaults = provider support flags) + `ChoiceChip` [`star_outline_rounded`] **"Principal"** (exclusive across providers; unchecking a provider clears it).
- Actions **"Cancelar"** / `FilledButton.icon` [`save_outlined`] **"Guardar métodos"**.
- On save: if none marked primary, first selected becomes primary; unchecked previously-existing providers are deleted. Success snack **"Métodos de pago actualizados para {zone name|la zona}."**; error → "Error: …".

---

## 9. Pagos / Billetera — `AdminPaymentsPage` (ACS:5472-6591)

Availability: **Production only** — shell blocks section 9 in Preview (see Shell context). Inside the page `_environment` is hard-coded to `'production'` (ACS:5491-5492), so all Preview branches in this class are unreachable. Zone cards show only the scoped zone.
Data: `admin_payment_overview_v2(p_from,p_to,p_zone_id,p_limit=150,p_offset=0)`, `admin_topup_requests(p_status='pending')`, `admin_zone_list_for_country`; Mercado Pago state per zone via Edge Function `zone-payment-admin {action:'get'}` (ACS:5659-5712).

### Main screen (ACS:6062-6590) — pull-to-refresh (`RefreshIndicator`)
1. Loading **"Cargando pagos"**; error → `_Error`.
2. `_Header` title **"Pagos y Billetera"**, subtitle **"Cobros, recargas pendientes, saldos y movimientos."** (no action).
3. Section title (20/w900) **"Método de pago por zona"** + desc **"Cada zona puede tener uno o varios métodos. Puedes activarlos, desactivarlos y decidir si sirven para Viajes, Delivery, Suscripciones y Billetera."**
   - Empty **"No hay zonas configuradas."**
   - **Zone card** (360px wide, white, radius 14):
     - Row: zone name (17/w900, fallback **"Zona"**) + **Switch** (on = any method enabled; toggles ALL methods of the zone; disabled while saving). Toggling with no methods → snack **"Error: Esta zona todavía no tiene métodos configurados."**; success **"Método de pago habilitado para {zone}."** / **"Método de pago deshabilitado para {zone}."**
     - Line `"{country} · {currency}"` (12, #667085).
     - Row: icon `payments_outlined` + enabled methods joined by " · " (or **"Sin métodos activos"**), `_MiniStatus` **"Activos"/"Pausados"**.
     - Wrap: one `_MiniStatus` chip per method (display_name/provider_key/**"Método"**, green if enabled) + `OutlinedButton.icon` [`tune_rounded`] **"Configurar métodos"** → §9.Z dialog.
     - If zone has `veripagos_qr`: note **"VeriPagos está disponible en esta zona. Sus credenciales se administran de forma segura y el método puede convivir con otras pasarelas."**
     - If zone has `mercado_pago`: `_MiniStatus` **"Credenciales verificadas"** (green) / **"Falta conectar"**; right-aligned nickname or account_email when configured; `FilledButton.icon` [`manage_accounts_rounded`] **"Editar credenciales"** (configured) / **"Conectar Mercado Pago"** → §9.A; `OutlinedButton.icon` [`verified_outlined`] **"Verificar"** (only when credentials_configured) — success **"Conexión Mercado Pago verificada."**, failure **"Error: … No se pudo verificar Mercado Pago."**. Both disabled while busy.
4. **Filter bar** (white bordered box, Wrap):
   - Dropdown **"Zona de movimientos"** (210px): **"Todas las zonas"** (null) + zone names. Default = scoped zone.
   - `ChoiceChip`s **"Hoy"** (default) | **"Semana"** (Mon→+7d) | **"Mes"** (calendar month).
   - `OutlinedButton.icon` [`date_range_outlined`] label **"Fecha"**, or `"d/m – d/m"` when custom range active; opens date-range picker (year-3 … next year end).
5. KPI row (`_Kpi` ×4): **"Cobrado en período"** (per-currency totals `"BOB 120 · CLP 5000"`, or "0"), **"Pendiente en período"** (same format), **"Pagos en período"** (count), **"Pendientes"** (count).
6. Section **"Recargas pendientes"** + `_MiniStatus` count (green when 0).
   - Empty **"No hay recargas pendientes."**
   - Row: orange avatar (#FFF4E5, icon `account_balance_wallet_outlined` #B54708); title full_name (fallback **"Usuario Express"**); subtitle **"Bs {amount} · {dd/mm/yyyy · hh:mm}{ · phone}"** (currency **hard-coded "Bs"**); trailing `OutlinedButton` **"Rechazar"** + `FilledButton` **"Aprobar"** → §9.B. Not filtered by zone/period (all pending top-ups).
7. Section **"Movimientos del período"**. Empty **"No hay movimientos."** Row (dense): icon by method — wallet `account_balance_wallet_rounded`, cash `payments_outlined`, else `credit_card_rounded`; title `"{currency|BOB} {amount}"`; subtitle `"{method} · {status} · {fecha}"` (raw English method/status values, e.g. wallet/paid). No row actions, max 150 rows, no pagination UI.

### 9.A Dialog — "Mercado Pago · {zone}" (ACS:5804-5933), width 540
- Intro text **"Las credenciales se verifican desde el backend y el Access Token no se expone en la aplicación."**
- Text **"Public Key"** (prefilled from stored settings).
- Password field **"Access Token"**; label becomes **"Access Token · dejar vacío para conservar"** when a token already exists.
- `_AdminPaymentNotice`: **"Usa las credenciales de producción de Mercado Pago Chile. Al guardar, Express verificará la cuenta antes de marcarlas como conectadas."**
- Actions **"Cancelar"** / `FilledButton.icon` [`verified_rounded`] **"Guardar y verificar"**.
- Success **"Mercado Pago conectado y verificado para esta zona."**; failure → "Error: …" (default message **"Mercado Pago no pudo verificar las credenciales."**).

### 9.B Confirmation — "Aprobar recarga" / "Rechazar recarga" (ACS:5987-6060)
- Body: approve **"Se acreditará Bs {amount} para {full_name|este usuario}."**; reject **"Se rechazará la solicitud de Bs {amount} para {full_name|este usuario}."**
- Actions **"Cancelar"** / FilledButton **"Aprobar"** (default color) or **"Rechazar"** (red #D92D20).
- Success **"Recarga aprobada y saldo acreditado."** / **"Recarga rechazada."**

### 9.Z Zone payment methods dialog — see section above (shared with Zones).

---

## Quick cross-reference: where each embedded widget appears

| Widget / dialog | File | Opened from |
|---|---|---|
| `AdminCountryCoveragePage` (full page) | `lib/admin_country_coverage.dart` | Zonas header "Países"; zone dialog "Administrar países"; auto when no country exists |
| `AdminZoneCoverageEditor` (radio/polígono map) | `lib/admin_zone_coverage_editor.dart` | Zone dialog §7.B only |
| `adminZoneCoverageSummary` (label) | `lib/core/admin_zone_coverage_label.dart` | Zone row subtitle "Cobertura: …" |
| `_PolygonEditor` (tap-to-draw map) | ACS:3753 | Security sector dialog §17.A; special fixed-fare dialog §8.D; (dead) `_editCoverage` |
| `AdminDistanceFaresEditor` | `lib/admin_distance_fares.dart` | Tarifas page, between header and zone selector |
| `showAdminZonePaymentMethodsEditor` | ACS:5147 | Zonas row wallet icon; after saving a zone; Pagos zone card "Configurar métodos"; `admin_driver_subscriptions.dart:1153` |
| Partner dialogs (aliados/accesos/dashboard/liquidación) | ACS:755-1812 | Zonas row "Aliados / sindicatos" |
| `AdminRuntimeScope` | `lib/admin_runtime_scope.dart` | Shell only (no UI) |
| `AdminPreviewModulePage` | `lib/admin_preview_config_sections.dart` | Not used by these sections |

## Notable inconsistencies a redesign should be aware of (observed, not fixed)
- Currency hard-coded **"Bs"** in Despacho rows and Recargas rows/confirmations, while other screens use zone `currency_code`.
- Payments page blocked in Preview at shell level and internally forced to production store.
- Tarifas "Zona" dropdown ("Editar tarifas de") only ever contains the globally scoped zone.
- Zonas list shows only the single scoped zone despite list UI.
- Distance-steps service dropdown shows raw `service_key`, while fare dialogs show service `name`.
- Fare rule rows have no active/inactive indicator and there is no delete for fares, special fares, zones, partners or security sectors.
- Validation messages from zone save appear prefixed with "Error: ".
