# C2 — UI inventory: Suscripciones (22), Express Market (23), Delivery Fase 2 / Express Plus (24), Pedidos Delivery (26), Prioridad conductores (25), Partner panel

Source repo: `/home/user/adminexpress`. All refs are `lib/<file>:<line>`. Strings verbatim (Spanish). Read-only extraction.
Common: every screen receives `channel` (`'production'` default | `'preview'`), `countryCode`, `zoneId` from the shell.

---

## 22 · Suscripciones — `AdminDriverSubscriptionsPage` (lib/admin_driver_subscriptions.dart)

Behaviour notes
- Preview channel: reads/writes go to a preview store (`AdminEnvironmentStore.previewList/previewGet/previewUpsert`), drivers list filtered to QA drivers only (`:102-207`). Production: RPCs `admin_zone_list_for_country`, table `driver_subscription_plans`, `admin_zone_subscription_settings`, `admin_driver_subscriptions`, `admin_subscription_payment_list_v2` (limit 100), Edge fn `driver-subscription-admin` action `get` (`:210-316`).
- Zone is fixed to the shell's `zoneId` (zones list filtered to that single id) (`:215-217`).
- A 1-second timer re-renders to animate countdowns (`:56`).
- QA driver rule: email starts `qa-` and ends `@expressdelivery.pro`, or name `qa` / starts `qa ` (`:76-88`), or `is_qa == true` in preview.
- Load-error prefixes (shown in warning notice): `'Preview: '`, `'Zonas: '`, `'Planes: '`, `'Configuración: '`, `'Conductores: '`, `'Pagos: '`, `'VeriPagos: '` (`:203,228,242,256,271,291,315`).
- Money format: `BOB` → prefix `Bs`, else currency code; integers without decimals, otherwise 2 decimals (`:366-379`). Date format `dd/MM/yyyy · HH:mm`, null → `—` (`:381-394`).
- Remaining-time format: `DDd HHh MMm SSs`; null → `Sin plan`; past → `Vencido` (`:396-413`).

Loading: full-screen `CircularProgressIndicator` (`:999-1001`). Pull-to-refresh on the whole list (`:1036`).

### Header (`:1041-1066`)
- Title: `Suscripciones de conductores` (24, w900)
- Subtitle: `Planes, vigencias y pagos por zona.` (muted #64748B)
- IconButton `refresh_rounded`, tooltip `Actualizar`.
- If error: warning notice card (amber `warning_amber_rounded`) with error text (`:1067-1070`).

### Zone card (`:1072-1125`) — visible if zones not empty
- Icon `location_city_rounded`, label `Zona` (w900)
- Dropdown (dense) label `Administrar suscripciones de`; items `<zone name> · <currency_code|BOB>`. Disabled while saving settings. Changing resets lists and reloads.

### Payment-methods notice (`:1127-1144`) — info notice (blue `info_outline`)
- No methods: `Configurando <zoneName>. Todavía no hay métodos habilitados para pagar suscripciones.`
- With methods: `Configurando <zoneName>. Métodos de suscripción: <display_name|provider_key|Método, …>.`
- (Methods = zone payment_methods with `enabled != false && use_subscriptions == true`.)
- OutlinedButton `tune_rounded` `Editar métodos de suscripción` (`:1146-1162`) → opens shared `showAdminZonePaymentMethodsEditor` (defined `lib/admin_control_sections.dart:5147`); disabled when no zone.

### "Configuración" card — `_SettingsCard` (`:1492-1630`)
- Title `Configuración` (17, w900)
- Switch `Mostrar suscripciones al conductor` — subtitle `Permite ver planes y contador sin bloquear la operación.` (`settings.enabled`)
- Switch `Exigir suscripción para trabajar` — subtitle `Déjalo apagado durante QA. Al activarlo, solo conductores con plan vigente podrán ponerse online u ofertar.` (`enforce_access`)
- Only if zone has VeriPagos (`provider_key == 'veripagos_qr'`) subscription method (`:1587`):
  - Switch `Habilitar QR Bolivia` — subtitle `VeriPagos tiene configuración guardada.` / `Primero completa la conexión con VeriPagos.`; disabled when provider not configured (`provider_enabled`).
  - Text field (width 220) label `Vigencia QR`, helper `Ej.: 0/00:15`; default `0/00:15` (`:1009`).
- FilledButton `save_rounded` `Guardar configuración` (disabled while saving) (`:1613-1624`).
- On save (`_saveSettings :600-701`):
  - If turning enforce on (was off) → confirmation dialog: title `Exigir suscripción · <zoneName>`; body `Solo los conductores de <zoneName> sin una suscripción vigente serán puestos offline. Las demás zonas no se modificarán.`; actions `Cancelar` / `Activar exigencia` (`:622-645`).
  - Validation snacks (Bolivia zone + provider enabled): `Configura y verifica primero VeriPagos.`; `Falta conectar el endpoint de verificación de estado QR antes de habilitar cobros.` (`:647-658`). No zone: `Selecciona una zona.`
  - Success `Configuración de la zona guardada.`; error `No se pudo guardar: <e>`.
  - Production RPCs: `admin_set_driver_subscription_zone_settings` (+ `admin_set_driver_subscription_provider_settings` if Bolivia).

### "QR Bolivia · VeriPagos" card — `_ProviderCard` (`:1632-1753`) — only if zone has VeriPagos method (`:1174`)
- Avatar `qr_code_2_rounded` (green bg #E8F8EF if configured, orange #FFF3E0 otherwise)
- Title `QR Bolivia · VeriPagos`
- Status line: `Credenciales guardadas y conexión verificada.` | `Credenciales guardadas. Falta verificar la conexión.` | `Ingresa tus credenciales para conectar VeriPagos.`
- Chips: `Conexión verificada` (verified_rounded) / `Conexión sin verificar` (error_outline_rounded); `Servicio activo` (check_circle_rounded) / `Servicio inactivo` (pause_circle_outline_rounded) — active = configured && provider_enabled.
- Buttons: OutlinedButton `wifi_tethering_rounded` `Verificar conexión` (only if credentials configured; spinner while verifying); FilledButton `manage_accounts_rounded` `Editar credenciales` / `Conectar`. Both disabled while saving/verifying.
- Verify (`:954-995`): success `Conexión VeriPagos verificada correctamente.`; error `VeriPagos no responde correctamente: <e>`; fallback error `No se pudo verificar la conexión`.

#### Dialog "Conectar VeriPagos" (`:814-952`), width 520
- Intro: `Express ya tiene configuradas internamente las rutas oficiales de VeriPagos. Solo ingresa las credenciales de API.`
- Field `Usuario Basic Auth` (prefilled username)
- Field (obscured) `Contraseña · dejar vacía para conservar` if has_password, else `Contraseña Basic Auth`
- Field (obscured) `Secret Key · dejar vacía para conservar` if has_secret_key, else `Secret Key`
- Info notice: `Al verificar, Express generará un QR de prueba por Bs 0 con vigencia de 1 minuto. No genera un cobro real.`
- Actions: `Cancelar`; FilledButton.icon `verified_rounded` `Guardar y verificar conexión`
- Success `VeriPagos conectado: generación y verificación de pagos operativas.`; error `No se pudo conectar con VeriPagos: <e>`.

### "Mercado Pago · Suscripciones" card (`:1186-1216`) — only if zone has `mercado_pago` subscription method
- Avatar `account_balance_wallet_rounded`; title `Mercado Pago · Suscripciones`; text `Método habilitado para esta zona. Las credenciales se administran en Pagos / Billetera y pueden convivir con otros métodos.` (no actions)

### Plans section (`:1218-1283`)
- Heading `Planes · <zoneName>` (19, w900); FilledButton `add_rounded` `Nuevo plan` (disabled with no zone).
- Empty/error card: amber warning icon, `No se pudieron cargar los planes en esta vista. El resto del módulo seguirá funcionando mientras se reintenta.` + OutlinedButton `refresh_rounded` `Recargar planes` (`:1237-1263`).
- Plan cards (Wrap, width 280 each) — `_AdminPlanCard` (`:1755-1830`): name (17, w900); chip `Inactivo` if not active; price line `<money> · <days> días` (blue #2563EB, w900); up to 4 benefits with green check `check_rounded`; OutlinedButton `edit_rounded` `Editar plan`.

#### Dialog Nuevo/Editar plan (`:421-598`), width 520
- Title `Nuevo plan` / `Editar plan`
- `Código` (hint `Ej. daily, weekly, monthly`) — disabled when editing
- `Nombre`
- `Precio (<currency_code|BOB>)` — decimal number
- `Días de acceso` — integer
- `Beneficios` — multiline 4-8 lines, hint `Un beneficio por línea`
- Switch `Plan visible y activo` (default on)
- Actions `Cancelar` / `Guardar`
- Validation snack: `Revisa código, nombre, precio y duración.` (code/name non-empty, price ≥ 0, days ≥ 1). No zone: `Selecciona una zona.`
- Success `Plan creado.` / `Plan actualizado.`; error `No se pudo guardar: <e>`. sort_order auto = (plans+1)*10.

### Drivers section (`:1285-1391`)
- Heading `Conductores reales (<n>)` (19, w900); search field width 300, dense, hint `Buscar conductor`, prefix `search_rounded`, suffix IconButton `arrow_forward_rounded` (submit reloads).
- Caption: `Los usuarios de prueba no se mezclan con los conductores reales.` or `<n> conductores QA están separados y no cuentan como reales.`
- Empty: info notice `No hay conductores reales para mostrar.`
- Row (Card + ListTile, three-line): avatar `two_wheeler_rounded`; title full_name | email | `Conductor`; subtitle `<plan_name|Sin plan> · <countdown>` newline `<email>`; trailing FilledButton `Asignar` (no plan) / `Editar`.
- QA block (if any): Card ExpansionTile, icon `science_outlined`, title `Conductores de prueba (<n>)`, subtitle `Usuarios QA del laboratorio de carga. No cuentan como conductores reales.`; rows same format (fallback name `Conductor QA`), no action button.

#### Dialog "Asignar plan · <name|email|Conductor>" (`:703-812`), width 480 — not shown if no plans
- Dropdown `Plan`; items `<name|Plan> · <money> · <days> días`; default current plan or first.
- Number field `Días personalizados (opcional)`, initial `0`, helper `0 usa la duración normal del plan.`
- Actions `Cancelar` / `Activar plan`
- Success `Suscripción activada.`; error `No se pudo asignar: <e>`. Notes saved: `Asignado desde Adminexpress` (prod) / `Asignado desde Adminexpress Preview`.

### Payments section (`:1393-1485`)
- Heading `Pagos de suscripciones` (19, w900)
- ChoiceChips `Hoy` (default) / `Semana` / `Mes`; OutlinedButton `date_range_outlined` `Fecha` → date-range picker (from now-3y to Dec 31 next year) → period `custom`.
- Empty: info notice `Todavía no hay pagos registrados.`
- Rows (max 30): icon `receipt_long_rounded`; title money (w900); subtitle `<dd/MM/yyyy · HH:mm> · <provider|veripagos>`; trailing raw status text (`pending` default, w800).

---

## 23 · Express Market — `AdminMarketplacePage` (lib/admin_marketplace.dart)

Palette consts: blue #2563EB, ink #0F172A, muted #64748B, bg #F1F5F9 (`:5-8`). Scaffold bg = bg.
Data: RPC `admin_marketplace_state_scoped(p_country_code, p_zone_id)`; if zone/country missing → empty state (no error) (`:35-68`). Categories/banners/merchants filtered to rows visible in current channel (`preview_visible` or `production_visible`) (`:59-66`).
- Loading: centered spinner. Error: centered FilledButton `refresh_rounded` `Reintentar` (`:885-897`).

### Header (`:910-944`)
- Title `Express Market` (26, w900, ink)
- Subtitle `Administra el módulo para Preview y Producción desde un solo lugar.`
- OutlinedButton `refresh_rounded` `Actualizar`; FilledButton `tune_rounded` `Configuración`.

### Status tags row (`:946-956`) — pill tags (green #E8F8EF/#14804A when active, grey #F2F4F7/muted otherwise, 10px w800)
- `Preview` (active if settings.preview_enabled), `Producción` (production_enabled), `<n> categorías`, `<n> banners`, `<n> comercios` (always active style).

### Sections — each: title (18, w900) + subtitle (12, muted) + FilledButton `add_rounded` (`:832-876`); responsive grid 3 cols ≥1100px, 2 cols ≥700px, else 1 (`:811-830`).
Card (`_card :751-809`): white, radius 16, 42×42 icon tile (#EAF2FF, `storefront_rounded` blue), title (1 line, w900), subtitle (2 lines, 11 muted), tags row; whole card tappable; optional trailing.
1. `Categorías` — `Orden, icono y visibilidad por entorno.` — button `Nueva categoría`. Card: title name|`Categoría`; subtitle category_key; tags `Activa`, `Preview`, `Prod`. Tap → edit category (`:958-977`).
2. `Banners y promociones` — `Contenido promocional del Home.` — button `Nuevo banner`. Card: title|`Banner`, subtitle; tags `Activo`, `Preview`, `Prod`. Tap → edit banner (`:979-998`).
3. `Comercios y productos` — `Locales, tiempos, costo de envío y catálogo.` — button `Nuevo comercio`. Card: name|`Comercio`; subtitle `<category_key> · <eta_min|15>-<eta_max|40> min`; tags `Activo`, `Preview`, `Prod`; tap → products page; trailing PopupMenu: `Editar comercio`, `Productos` (`:1000-1044`).
- No empty-state text for empty sections (just empty grid).

Shared guard on edit (category/banner/merchant): if row visible in both envs → snack `Este registro está compartido entre Prueba y Producción. Debe separarse antes de editarlo.` and no dialog (`:217-225, 349-357, 516-524`).
Env switches rule: `Visible en Preview` editable only in preview channel; `Visible en Producción` editable only in production channel; new rows default visible in current channel only.

### Dialog "Configuración de Express Market" (`:87-204`), width 560
- Switch `Activo en Preview` — `Permite probar el módulo sin activarlo en producción.` (editable only in preview channel)
- Switch `Activo en Producción` — `Actívalo solo después de aprobar la Preview.` (editable only in production channel)
- `Nombre del módulo` (default `Express Market`)
- `Texto del buscador` (default `Locales, productos y promociones`)
- `Título principal` (default `Todo lo que necesitas, en Express`)
- `Subtítulo principal` (default `Comida, mercados, tiendas y más.`)
- Actions `Cancelar` / `Guardar`. Success `Configuración actualizada.`; error = raw exception. RPC `admin_marketplace_update_settings`.

### Dialog Nueva/Editar categoría (`:206-334`), width 520
- `Nombre`; `Clave` (hint `ej. pharmacies`, disabled on edit); `Icono interno` (default `storefront`); `Orden` (number, default `100`)
- Switches `Categoría activa` (default on), `Visible en Preview`, `Visible en Producción`
- `Cancelar` / `Guardar`; success `Categoría guardada.`

### Dialog Nuevo/Editar banner (`:336-472`), width 520
- `Título`; `Subtítulo`; `Botón / CTA`; `Estilo` (hint `blue, yellow, green, purple`, default `blue`); `Orden` (default `100`)
- Switches `Banner activo`, `Visible en Preview`, `Visible en Producción`
- `Cancelar` / `Guardar`; success `Banner guardado.`

### Dialog Nuevo/Editar comercio (`:484-721`), width 600
- Dropdown `Zona` (items `<name> · <city>`; only current zone; default current zone)
- Dropdown `Categoría` (category names; default first)
- `Nombre`; `Descripción`; `URL de imagen`
- Row: `Rating` (number, default `5`) | `Costo envío` (number, default `0`; no currency label)
- Row: `ETA mínimo` (default `15`) | `ETA máximo` (default `40`) | `Orden` (default `100`) — minutes, no unit label
- Switches `Comercio activo`, `Visible en Preview`, `Visible en Producción`
- `Cancelar` / `Guardar`; success `Comercio guardado.`

### Sub-page: merchant products — `_MerchantProductsPage` (`:1053-1284`), pushed route
- AppBar title = merchant name | `Productos`; action IconButton `refresh_rounded`.
- FAB extended `add_rounded` `Producto`.
- Loading spinner; error = raw error text; empty `Todavía no hay productos en este comercio.`
- Rows (Card ListTile): avatar `inventory_2_outlined` (green bg if active, grey otherwise); title name|`Producto` (w900); subtitle `<currency_code> <price> · Activo|Inactivo`; trailing `edit_outlined`; tap → edit.
- Dialog Nuevo/Editar producto (`:1091-1213`), width 520: `Nombre`; `Descripción`; row `Precio` (number, default `0`) | `Moneda` (text, default `CLP`); `URL de imagen`; `Orden` (default `100`); switch `Producto activo`. `Cancelar` / `Guardar`. No success snack; error raw.

---

## 24 · Delivery Fase 2 / Express Plus — `AdminMarketplacePhase2Page` (lib/admin_marketplace_phase2.dart)

Nav entry: `('Delivery Fase 2 / Express Plus', Icons.delivery_dining_rounded)` (lib/admin_panel.dart:292), built at `lib/admin_panel.dart:1353`.
Palette same as Market (`:5-8`). Note: widget default `channel = 'preview'` (`:19`) but shell always passes the active channel.
Data (`:60-105`): no zoneId → empty state. Else RPC `admin_marketplace_phase2_state`; zones/plus_plans/benefits/merchants filtered by zone (or country) scope; recent_orders filtered to current channel + scope. Reloads when channel/country/zone changes (`:40-47`).
- Loading: centered spinner. Error: centered FilledButton `refresh_rounded` whose label is the raw error text (`:1644-1652`).
- Money: `CLP` → `CLP 12.345` (dot thousands, no decimals); other → `<CUR> 0.00` (`:124-135`).
- None of the save actions in this file show success/error snacks (RPC errors are unhandled) except the Plus price validation.

### Header (`:1678-1706`)
- Title `Delivery · Configuración` (26, w900)
- Subtitle `Cada bloque abre su propia administración para mantener el panel compacto.`
- OutlinedButton `refresh_rounded` `Actualizar`

### Module cards grid (`:1708-1762`) — 3 cols ≥1050, 2 cols ≥680, else 1; gap 12
`_moduleCard` (`:1300-1365`): Card radius 18, CircleAvatar r24 (#EAF2FF, blue icon), title (16 w900), subtitle (12 muted), right column: count label (blue w900) + `open_in_new_rounded` icon. Tap opens a module dialog.
1. icon `delivery_dining_rounded` — `Tarifas por zona` — `Tarifa cliente, pago repartidor, métodos y activación por ciudad.` — count `<n> zonas`
2. icon `bolt_rounded` — `Express Plus` — `Planes mensuales, precio, descuentos y beneficios incluidos.` — count `<n> planes`
3. icon `storefront_rounded` — `Locales y beneficios` — `Logística, beneficios Plus y usuarios autorizados por comercio.` — count `<n> locales`

### Info card "orders moved" (`:1764-1797`)
- Avatar `receipt_long_rounded` (#EAF2FF/blue); title `Pedidos fuera de esta pantalla`; text `Los pedidos ahora tienen acceso propio debajo de Delivery en el menú lateral.`; badge `<n> recientes` (green if > 0, grey otherwise).

### Module dialog "Tarifas Delivery por zona" (`:1367-1421`), 820×560
- Empty: `Todavía no hay zonas configuradas.`
- Rows: avatar `delivery_dining_rounded`; title zone_name|`Zona` (w900); subtitle `Cliente: <money> base · Repartidor: <money> base`; trailing `chevron_right_rounded`; tap → zone editor.
- Action `Cerrar`.

#### Dialog "Delivery · <zone_name|Zona>" (`:137-400`), width 680 — RPC `admin_marketplace_update_zone_phase2`
- Group `Tarifa que paga el cliente` (w900): row `Base cliente` | `Por km cliente` | `Mínimo cliente` (numbers, default `0`; no currency suffix)
- Group `Pago independiente al repartidor`: row `Base repartidor` | `Por km repartidor` | `Mínimo repartidor`
- Group `Envío Plus · prioridad`: row `Recargo al cliente` | `Bono al repartidor`
- Switch `Habilitar Envío Plus prioritario` (priority_enabled)
- Switch `Permitir propinas` (tips_enabled)
- Divider
- Switch `Efectivo` (cash_enabled)
- Switch `Transferencia al comercio` — subtitle `Requiere comprobante y aprobación del comercio.` (transfer_enabled)
- Switch `Tarjeta / Mercado Pago` (online_enabled)
- Switch `Suscripción Express Plus clientes` (plus_enabled)
- Divider
- Switch `Delivery Fase 2 en Preview` — editable only in preview channel
- Switch `Delivery Fase 2 en Producción` — subtitle `Mantener apagado hasta aprobación final.` — editable only in production channel
- Actions `Cancelar` / `Guardar` (no feedback snack; list refresh)

### Module dialog "Express Plus · planes" (`:1423-1473`), 760×520
- Empty: `Todavía no hay planes configurados.`
- Rows: avatar `bolt_rounded`; title `<name|Express Plus> · <zone_name>`; subtitle `<money> / mes`; trailing badge `Activo` (green/grey by active); tap → plan editor. No "new plan" button (only edits existing rows).
- Action `Cerrar`.

#### Dialog "Express Plus · <zone_name>" (`:402-560`), width 560 — RPC `admin_marketplace_upsert_plus_plan`
- `Nombre` (default `Express Plus`)
- `Precio mensual` (number, default `0`)
- `Descuento general %` (number, default `0`)
- `Envíos prioritarios incluidos / mes` (integer, default `0`)
- `Descripción` (3 lines)
- Switches: `Envío gratis`, `Plan activo`, `Visible Preview` (preview channel only; default on unless false), `Visible Producción` (production channel only)
- `Cancelar` / `Guardar`
- Validation snack: `Define un precio mensual mayor a 0 antes de activar Express Plus.` (active && price ≤ 0) (`:516-532`)

### Module dialog "Locales · beneficios y logística" (`:1475-1546`), 840×560
- Empty: `Todavía no hay locales configurados.`
- Rows: avatar `storefront_rounded`; title name|`Comercio` (w900); subtitle zone_key; trailing PopupMenu (tooltip `Administrar local`): `Beneficios Express Plus`, `Ubicación / transferencia`, `Usuarios del local`.
- Action `Cerrar`.

#### Dialog "Plus · <merchant name|Comercio>" (`:562-661`), width 480 — RPC `admin_marketplace_set_plus_merchant_benefit`
- `Descuento exclusivo %` (number, default `0`)
- Switch `Envío gratis para Plus`
- Switch `Promoción exclusiva Plus`
- Dropdown `Quién financia el descuento`: `Express` (value express, default) | `Comercio` (merchant)
- Switch `Beneficio activo`
- `Cancelar` / `Guardar`

#### Dialog "Logística · <merchant name>" (`:663-778`), width 560 — loads `admin_marketplace_merchant_detail` first; saves `admin_marketplace_update_merchant_logistics`
- `Dirección del comercio`
- Row `Latitud` | `Longitud` (numbers)
- `Datos/instrucciones de transferencia` (5 lines), hint `Banco, tipo de cuenta, titular, RUT/CI, correo, etc.`
- `Cancelar` / `Guardar`

#### Dialog "Accesos · <merchant name|Comercio>" (`:780-903`), width 620
- Email field `Correo de la cuenta Express del comercio`; suffix IconButton `person_add_alt_1_rounded` tooltip `Vincular` (assigns role `manager`; empty → no-op)
- Empty: ListTile `info_outline_rounded` — `Todavía no hay cuentas vinculadas.` / `La persona debe tener una cuenta Express con ese correo.`
- Rows: SwitchListTile (active toggle) title full_name|email|`Usuario`; subtitle `<email> · <role|manager>`
- Action `Cerrar`

### Order detail dialog (shared with section 26) — `_openOrder` (`:905-1259`), 720×620, RPC `marketplace_order_detail`
- Title `Pedido · <first 8 chars of id>`
- Status line (w900): `Estado: <status> · Pago: <payment_status>` (raw enum values)
- Financial card — rows label + money (w800) (`:1011-1078`):
  `Total cliente`, `Productos comercio`, `Pago repartidor`, `Propina`, `Margen Express`, — divider —, `Comercio debe al repartidor`, `Comercio debe a Express`, `Repartidor debe al comercio`, `Repartidor debe a Express`, `Express debe al comercio`, `Express debe al repartidor`, — divider —, `Liquidación: <settlement_status|pending>` (w900). Currency default `CLP`.
- Settle buttons (OutlinedButton, each only if that balance > 0) (`:1083-1152`), RPC `marketplace_settle_balance`, note `Liquidación confirmada: <label>.`:
  - `account_balance_rounded` `Cerrar saldo Comercio → Express`
  - `storefront_rounded` `Cerrar saldo Repartidor → comercio`
  - `account_balance_wallet_rounded` `Cerrar saldo Repartidor → Express`
  - `store_mall_directory_rounded` `Cerrar saldo Express → comercio`
  - `delivery_dining_rounded` `Cerrar saldo Express → repartidor`
  - (no confirmation dialog)
- `Chat / comprobantes` (w900) + message rows: dense ListTile `chat_bubble_outline`, title body|attachment_url, subtitle `<sender_role> · <message_type>` (no empty text).
- If payment_method `transfer` && payment_status `under_review`: row OutlinedButton `close_rounded` `Rechazar comprobante` | FilledButton `check_rounded` `Aprobar transferencia` (RPC `marketplace_review_transfer`; notes `Transferencia aprobada por el comercio/administración.` / `Comprobante rechazado. Envía uno nuevo.`) (`:1174-1195`)
- status `pending` && method `cash`: full-width FilledButton `check_circle_outline_rounded` `Confirmar pedido en efectivo` → status confirmed
- status `confirmed`: FilledButton `soup_kitchen_outlined` `Pasar a preparación` → preparing
- status `preparing`: FilledButton `delivery_dining_rounded` `Listo · buscar repartidor` → ready
- merchant_owes_driver > 0 && assigned driver: OutlinedButton `payments_outlined` `Confirmar pago al repartidor` (RPC `marketplace_mark_driver_paid`, note `Comercio confirmó que entregó la tarifa y propina al repartidor.`)
- Action `Cerrar`. No confirmations, no snacks.

---

## 26 · Pedidos Delivery — same class with `ordersOnly: true` (lib/admin_panel.dart:1365; nav label `('Pedidos Delivery', Icons.receipt_long_rounded)` admin_panel.dart:294)

Differences vs section 24:
- Data: RPC `admin_marketplace_orders_v2(p_channel, p_zone_id, p_limit: 100)` only (`:71-83`); no zones/plans/merchants loaded.
- Renders `_ordersView` (`:1548-1630`) instead of module cards (`:1671-1673`).
- Header title: `Pedidos Delivery · Prueba` (preview) / `Pedidos Delivery · Producción` (production) (26, w900)
- Subtitle: `Pedidos recientes, estados, pagos, comisiones y liquidaciones.`
- OutlinedButton `refresh_rounded` `Actualizar`
- Empty card: `Todavía no hay pedidos Delivery.`
- Rows (Card ListTile): leading icon by payment_method — `transfer` → `account_balance_rounded`, `cash` → `payments_outlined`, else `credit_card_rounded`; title merchant_name|`Pedido` (w900); subtitle `<zone_key> · <status> · <payment_status>` (raw values); trailing total money (blue w900). Tap → Order detail dialog (above).
- No filters, search, metrics or pagination (limit 100).
- Loading/error states identical to 24.

---

## 25 · Prioridad conductores — `AdminDriverPriorityPage` (lib/admin_driver_priority.dart)

Nav: `('Prioridad conductores', Icons.workspace_premium_outlined)` (lib/admin_panel.dart:293), built `admin_panel.dart:1359`.
Palette (`:5-11`): blue #2563EB, green #16A34A, orange #F59E0B, red #DC2626, ink #0F172A, muted #64748B, bg #F1F5F9.
Data: RPC `admin_driver_priority_state_scoped(p_channel, p_zone_id)`; no zone → empty (`:39-57`).
- Loading spinner; error → centered FilledButton `refresh_rounded` `Reintentar` (`:457-469`).
- Level labels: `high` → `Alta` (green), `medium` → `Media` (orange), else → `Baja` (red) (`:86-106`).

### Header (`:480-514`)
- Title `Prioridad de conductores` (26, w900)
- Subtitle `Alta, Media y Baja según reputación, reseñas, experiencia y frecuencia.`
- OutlinedButton `refresh_rounded` `Actualizar`; FilledButton `tune_rounded` `Configurar`

### Status pills (`:516-549`) — pill = 10% tint bg, colored 10px w900 text
- `Preview visible` (green) / `Preview oculto` (muted)
- `Ranking Preview activo` (green) / `Ranking Preview apagado` (muted)
- `Producción visible` (orange) / `Producción apagada` (muted)
- `Ranking Producción activo` (red) / `Ranking Producción apagado` (muted)

### Info banner (`:551-575`) — bg #EAF2FF radius 16, `info_outline_rounded` blue, 12px w700:
`El ranking cambia solo el orden de solicitudes y nunca bloquea conductores. Alta prioriza cercanía, buena reputación del pasajero y mejor tarifa/km; Media prioriza cercanía y tarifa/km; Baja recibe flujo normal por antigüedad, sin castigos.`

### Driver list (`:577-687`)
- Heading `Conductores · <n>` (18, w900)
- Empty: centered `No hay conductores aprobados.`
- Row card (white, radius 16, border #E2E8F0), two columns:
  - Left (flex 2): avatar `local_taxi_rounded` tinted by level; name|`Conductor` (w900); pills: level (`Alta`/`Media`/`Baja`), `Puntaje <score 1 decimal>` (blue), `<completed_trips> viajes` (muted), `<review_count> reseñas` (muted).
  - Right (flex 3): 4 metric bars (`_metric :404-448`) — label (10 muted w700) + value 0-100 (colored: ≥75 green, ≥50 orange, else red) + LinearProgressIndicator height 6 on #E2E8F0: `Reputación`, `Reseñas`, `Experiencia`, `Frecuencia`.
- No row actions, no filters/search.

### Dialog "Configurar prioridad de conductores" (`:108-384`), width 650 — RPC `admin_update_driver_priority_settings_v2` (saves only the current channel's enabled/enforcement pair)
- Switch `Mostrar prioridad en Preview` — editable only in preview channel
- Switch `Aplicar ranking al despacho Preview` — subtitle `Ordena solicitudes, pero no bloquea conductores.` — editable only in preview channel and when Preview display on
- Divider
- Switch `Mostrar prioridad en Producción` — subtitle `Puedes administrarlo por separado; Producción está preparada para aplicar el ranking seguro.` — editable only in production channel
- Switch `Aplicar ranking al despacho Producción` — editable only in production channel and when Producción display on
- Section `Umbrales` (w900): `Alta desde` (suffix `/100`, default `80`) | `Media desde` (suffix `/100`, default `55`)
- Section `Pesos del puntaje`: `Reputación` (default `35`) | `Reseñas` (`25`) | `Experiencia` (`20`) | `Frecuencia` (`20`)
- Section `Metas para llegar a 100%`: `Reseñas` (int, default `20`) | `Viajes experiencia` (`100`) | `Viajes / 30 días` (`30`)
- All numeric keyboards; no validation (unparseable → default).
- `Cancelar` / `Guardar`; success snack `Prioridad actualizada.`; error raw exception.

---

## Partner panel — `PartnerExpressPanel` (lib/partner_panel.dart)

### How it is reached (lib/main.dart)
- `_AdminAuthGate._resolveAccess` (`main.dart:75-96`): `is_admin` RPC → if admin, checks `admin_environment_allowed(p_channel)` → admin panel or denied. If **not admin**: in Preview build → always `denied` ("Preview must not query real partner data", `:88-89`); in Production → RPC `partner_my_dashboard`; non-empty list → `PartnerExpressPanel(onExit: _logout)` (`:151-152`).
- Login (`main.dart:207-235`): non-admin non-preview users are checked with `partner_my_dashboard`; failure message `Esta cuenta no tiene acceso de administrador ni de organización.` (`:229-231`). Wrong-env admin: `Esta cuenta no tiene autorización para este entorno. Utiliza las credenciales administrativas correspondientes.`
- Denied screen (`main.dart:153-163`): title `Cuenta sin acceso a Prueba` / `Cuenta sin acceso a Producción`; message (preview) `La cuenta ingresada no está autorizada para Preview. Cierra sesión y utiliza las credenciales de prueba.` / (prod) `Esta cuenta no tiene acceso administrativo a Producción ni una organización asignada.` Error resolving: title `No se pudo validar tu acceso` + error.
- => Partner panel exists only in the Production build; no preview-mode variant inside the panel.

Palette (`partner_panel.dart:7-10`): blue #2563EB, dark #0F172A, muted #64748B, soft #F8FAFC; sidebar #0B2C5B. Date format `dd/MM/yyyy · HH:mm`, null `—` (`:25-33`).
Roles used for gating: `owner`, `manager`, `operator`, `treasurer` (from dashboard row `role`).

### Root states (`:55-183`)
- Loading: Scaffold + centered spinner.
- Error card (max 520): icon `lock_outline_rounded` 46 red #D92D20; title `No se pudo abrir el panel de la organización` (19 w900); raw error; FilledButton `Reintentar`; TextButton `Cerrar sesión` (`:67-113`).
- Empty (no organizations): icon `business_outlined` 48; title `Sin organización asignada` (20 w900); text `Pide al administrador de Express que asigne tu cuenta a una empresa, sindicato o cooperativa.` (muted); FilledButton `Cerrar sesión` (`:116-154`).
- Selected organization defaults to first; switching organization resets to section 0 (`:156-180`).

### Shell — `_PartnerShell` (`:186-382`); compact if width < 900. Pages kept alive in IndexedStack.
**Compact (<900px)** (`:217-267`):
- AppBar title = organization name | `Express Aliados`; actions IconButton `refresh_rounded` tooltip `Actualizar`, IconButton `logout_rounded` tooltip `Cerrar sesión`.
- No organization switcher in compact mode.
- Bottom NavigationBar (outlined/rounded icon pairs): `Resumen` (dashboard), `Conductores` (two_wheeler), `Solicitudes` (person_add_alt), `Pagos` (payments), `Avisos` (notifications).
**Desktop (≥900px)** (`:269-381`): left sidebar 270px, bg #0B2C5B:
- Brand: white CircleAvatar with `bolt_rounded` blue + `EXPRESS` (white 20 w900).
- Dropdown `Organización` (label white70, border white30 radius 12; items org names | `Organización`).
- Divider white12.
- Nav items (`_PartnerNav :384-419`; selected = white 12% bg, radius 12, w900; else w600, icon white70): `dashboard_rounded` `Resumen`; `two_wheeler_rounded` `Conductores`; `person_add_alt_rounded` `Solicitudes`; `payments_rounded` `Pagos y comisiones`; `notifications_active_rounded` `Avisos push`.
- Bottom: ListTile `refresh_rounded` `Actualizar`; ListTile `logout_rounded` `Cerrar sesión`.
Page frame (`_PartnerPageFrame :421-470`): padding 22; title 25 w900 dark; subtitle muted; optional right action.

### Resumen — `_PartnerOverview` (`:472-559`)
- Title = org name | `Mi organización`; subtitle `Panel restringido de empresa, sindicato o cooperativa asociada a Express.`; action IconButton `refresh_rounded` tooltip `Actualizar`.
- Metric cards (3 per row ≥680px, else full width) (`_PartnerMetric :561-616`: avatar #EAF2FF blue icon, value 22 w900, label 11 muted):
  - `two_wheeler_rounded` `Conductores activos` = drivers_active
  - `account_balance_wallet_rounded` `Comisión generada` = commission_generated (2 decimals, no currency)
  - `check_circle_outline_rounded` `Comisión pagada` = commission_paid (2 decimals)
- Info card (soft bg) rows label/value (`_PartnerInfoRow`): `Rol de acceso` = role | `—`; `Comisión` = `<commission_percent>%`; `Zona ID` = zone_id | `—`; `Permisos` = `Solo información y acciones de esta organización`.

### Conductores — `_PartnerDrivers` (`:646-763`), RPC `partner_driver_list`
- Title `Conductores`; subtitle `Solo conductores vinculados a tu organización.`
- Loading: LinearProgressIndicator; error: raw text; empty card `No hay conductores afiliados todavía.`
- Row (Card ListTile, three-line): avatar #EAF2FF `two_wheeler_rounded`; title full_name | `Conductor` (w900); subtitle line 1 `<phone|Sin teléfono> · ★ <rating|—> · <completed_trips> viajes`, line 2 `<approval_status|—> · <online_status|offline>` (raw values).
- Trailing PopupMenu only if role `owner`/`manager`: `Aprobar` (approved), `Marcar pendiente` (pending), `Suspender` (suspended) → RPC `partner_set_driver_approval`; no confirmation; error → snack raw.

### Solicitudes — `_PartnerJoinRequests` (`:765-879`), RPC `partner_join_request_list`
- Roles `owner`/`manager`/`operator` only. Otherwise: title `Solicitudes`, subtitle `Afiliaciones pendientes.`, card `Tu rol no permite revisar afiliaciones.`
- Allowed: title `Solicitudes de afiliación`; subtitle `Aprueba o rechaza conductores que quieren pertenecer a tu organización.`
- Loading linear bar; error raw; empty `No hay solicitudes pendientes.`
- Row: icon `person_add_alt_rounded` blue; title driver_name | `Conductor`; subtitle `Solicitado <date>` + newline notes (if any); trailing IconButtons `close_rounded` red tooltip `Rechazar`, `check_rounded` green #14804A tooltip `Aprobar` → RPC `partner_review_join_request` (notes `Aprobado desde panel aliado` / `Rechazado desde panel aliado`); no confirmation; error snack raw.

### Pagos y comisiones — `_PartnerPayments` (`:881-977`), RPC `partner_payment_list` (limit 200)
- Roles `owner`/`manager`/`treasurer` only. Otherwise: title `Pagos y comisiones`, subtitle `Movimientos de suscripción vinculados a la organización.`, card `Tu rol no permite ver información financiera.`
- Allowed: title `Pagos y comisiones`; subtitle `Suscripciones de conductores afiliados y comisión de la organización.`
- Loading linear; error raw; empty `Todavía no hay pagos asociados.`
- Row: icon `receipt_long_rounded` blue; title driver_name | `Conductor`; subtitle `<status|—> · <paid_at or created_at date>`; trailing column: `<currency_code> <amount 2dp>` (w900) and `Comisión <partner_commission_amount 2dp>` (10 muted). No filters/totals.

### Avisos push — `_PartnerAnnouncements` (`:979-1123`), RPC `partner_send_announcement`
- Title `Avisos y promociones`; subtitle `Envía notificaciones push únicamente a los conductores afiliados a tu organización.`
- If role not `owner`/`manager`/`operator`: card text `Tu rol no permite enviar avisos.` (muted).
- Form card:
  - `Título` — maxLength 90 (counter), hint `Ej. Alta demanda en el centro`
  - `Mensaje` — maxLength 1000, 3–6 lines, hint `Conéctate ahora. Hay alta demanda en tu zona.`
  - Info box (#EAF2FF radius 12, `notifications_active_outlined`, 11px): `El aviso se guarda en la bandeja de Express y también se despacha como push.`
  - Full-width FilledButton `send_rounded` `Enviar aviso` (spinner + disabled while sending). Empty title/body → silent no-op.
- Success snack `Aviso enviado a <recipients> conductores.` (fields cleared); error snack raw. No confirmation.
