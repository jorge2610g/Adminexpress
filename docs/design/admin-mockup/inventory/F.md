# Notas F — Configuración, Avisos, Servicios, Identidad (tab 2), Config. avanzada

Fuente: `inventory/B2_settings_comms_services_identity.md` (abreviado `B2:<línea>`).
Todas las pantallas cumplen la "Restricción obligatoria" (Flutter): solo Row/Column/Wrap/GridView/ListView, Card, TabBar, Chip, Switch/SwitchListTile, TextField, DropdownButtonFormField, PopupMenu (lista desplegada), AlertDialog/Dialog, SnackBar; efectos = color plano, LinearGradient, BoxShadow, bordes y radios. Sin gráficos ni mapas. Overlays `rgba(255,255,255,.12–.16)` = `Colors.white.withOpacity(...)`.

Iconos comunes a todas: `Icons.keyboard_arrow_down_rounded` (dropdown), `Icons.save_outlined`, `Icons.add_rounded`, `Icons.arrow_forward_ios_rounded`, `Icons.dashboard_customize_rounded` (icono de `_Header`).

---

## 1. Avisos.dc.html (1280×1160) — sección 15, env=production
Cubre: TabBar `Soporte`/`Avisos` (B2:265-268) con Avisos activa; `_Header` `Enviar avisos` (B2:288); tarjeta de composición con `Destinatarios`, `Zona` (deshabilitada + helper), `Empresa / sindicato / cooperativa` (+ helper), estimación en vivo (4 píldoras), caja info push, `Título` (contador /90), `Mensaje` (contador /1000), botón `Enviar aviso` (B2:289-299); `Historial y telemetría push` con caption y filas con píldoras Destinatarios/Push activo/Aceptados/Abiertos/Leídos/Tokens inválidos (verde si ≠0, gris si 0) (B2:305-309). Segunda región: mini TabBar con `Soporte` activa, lista de hilos (avatar, nombre, último mensaje, badge no leídos, fila seleccionada #F4F8FF/#CFE0FF), cabecera con nombre, burbujas admin derecha #EAF2FF / usuario izquierda #F2F4F7 con fecha `dd/MM/yyyy · HH:mm`, composer `Responder desde soporte...` + botón enviar (B2:272-285).
Iconos Material: `support_agent_rounded`, `campaign_outlined`, `campaign_rounded`, `notifications_active_outlined`, `lock_outline_rounded` (sufijo zona bloqueada), `person_outline_rounded`, `send_rounded`.
No dibujado (estados): diálogo de confirmación `Enviar aviso · Producción` (B2:300-303), vacíos `No hay conversaciones de soporte todavía.`, `Sin mensajes.`, `Todavía no hay campañas con telemetría.`, error de telemetría.
Correcciones de presentación / fallos del código:
- La línea secundaria del historial puede mostrar `audience` crudo (`drivers`/`passengers`/`all`) → debe mostrarse `Conductores`/`Pasajeros`/`Todos` (B2:309). Corrección de presentación.
- Selector de organización muestra `<name> · <organization_type>` con tipo crudo → traducir (Empresa/Sindicato/Cooperativa) (B2:294).
- Título o mensaje vacío: `Enviar aviso` no hace nada y no avisa (B2:299). Fallo: falta validación visible.
- Selector `Zona` siempre deshabilitado (`onChanged: null`) (B2:293): el mockup lo pinta como campo bloqueado con candado.
- Sección bloqueada en Prueba por el shell aunque su código tiene ramas preview (B2:22, 263).
- Errores de carga de zonas/organizaciones ignorados en silencio (B2:270).

## 2. Requisitos.dc.html (1280×1160) — sección 18, pestaña 2, env=preview
Cubre: TabBar `Revisión de documentos` / `Requisitos de identidad` (activa) (B2:367-369); `_Header` (B2:373); `_AdminHero` `Centro de identidad` con stats `Motor`=`Manual`, `Proveedor externo`=`Deshabilitado` (B2:374); tarjeta `Documentos requeridos para conductores` + `Nuevo documento` y 7 filas con chips de alcance (`Todas las ciudades`/`Bolivia`/`Trinidad`), `Obligatorio`, `Frente`, `Reverso`, `Selfie`, `Inactivo`, fila inactiva con fondo #F8FAFC, acciones Editar/Eliminar (B2:381-383); tarjeta informativa al pie (B2:376).
Iconos Material: `fact_check_outlined`, `settings_outlined`, `verified_user_rounded`, `folder_shared_outlined`, `badge_outlined`, `face_retouching_natural_rounded`, `edit_outlined`, `delete_outline_rounded`.
Correcciones / fallos:
- No hay chip para `require_number` (B2:383): el mockup lo respeta (sin chip); se recomienda añadir chip `Número`.
- Alcance de país muestra código crudo si no es BO/CL (B2:383) → mostrar nombre del país.
- Sin mensaje de éxito al guardar (solo recarga) (B2:403).

## 3. DlgIdentidad.dc.html (1280×1000)
Cubre: diálogo `Editar documento requerido` (ancho 650) con banner info y los 13 campos: `Nombre visible`, `Código interno`, `Descripción`, `Aplicar a`, `País`, `Ciudad`, `Documento obligatorio`, `Solicitar número del documento`, `Solicitar foto del frente`, `Solicitar foto del reverso`, `Solicitar selfie para comparación facial` (+ subtítulo), `Activo`, `Orden`; acciones `Cancelar`/`Guardar` (B2:384-401). Diálogo `Eliminar requisito` con botón rojo (B2:404). Los tres mensajes de validación como SnackBar (`Completa nombre y código.`, `Selecciona el país.`, `Selecciona la ciudad.`, B2:402) y una versión compacta de `Nuevo documento requerido` con los campos en error.
Agrupaciones `Documento` / `Alcance` / `Requisitos` = títulos de sección de presentación (no existen en el código). Los hints de opciones de `Aplicar a` (`Todas las ciudades · Un país · Una ciudad`) y "Solo el país/zona del ámbito" documentan opciones/restricción reales (B2:391-393).
Iconos Material: `info_outline_rounded`, `badge_outlined`, `location_on_outlined`, `photo_camera_outlined`, `delete_outline_rounded`, `error_outline_rounded` (snackbar), `save_outlined`.
Fallos:
- La validación ocurre DESPUÉS de cerrar el diálogo (snackbar) y se pierde lo escrito (B2:402). El mockup propone validación en línea (bordes rojos + mensajes) en el diálogo de creación: es propuesta de rediseño, no comportamiento actual.
- `Código interno` editable también al editar (B2:389) → riesgo de duplicar claves en Preview (`recordKey` usa el código, B2:403).

## 4. Servicios.dc.html (1280×1160) — sección 16, env=preview
Cubre: `_Header` `Servicios por zona` + `Crear servicio` (B2:322-324); tarjeta `Zona que estás editando` con dropdown `Zona` `Trinidad · Trinidad` (B2:328); `_AdminHero` `Catálogo · Trinidad` con stats `Servicios`/`Disponibles`/`Con ofertas` (B2:331); rejilla de 3 columnas con 6 `_AdminModuleCard` (icono por vehículo, nombre, descripción o `Sin descripción`, acento azul si disponible / gris si no, chips) (B2:334-337).
Iconos Material: `location_on_outlined`, `apps_rounded`, `two_wheeler_rounded` (motorcycle), `local_taxi_rounded` (car/xl), `commute_rounded` (any), `arrow_forward_ios_rounded`.
Correcciones / fallos:
- Chip de `vehicle_type` crudo (`car`/`motorcycle`/`xl`/`any`) → mostrado como `Auto`/`Moto`/`XL`/`Cualquiera` (B2:337). Corrección de presentación.
- Zona con 0 servicios: rejilla vacía sin mensaje (B2:338) → falta estado vacío.
- No hay acción de eliminar servicio (B2:338, 411).

## 5. Configuracion.dc.html (1280×1160) — sección 11, env=preview (sobrescribe el borrador anterior)
Cubre: `_Header` `Configuración` + `Guardar configuración` (B2:65-67); tira de 8 pestañas tipo píldora `General` (activa) · `Servicios` · `Pagos` · `Operación` · `Tarifas` · `Soporte` · `Seguridad` · `Admin` (B2:69-71); pestaña General completa: tarjeta `Módulos` (`Taxi habilitado`, `Delivery habilitado`) y `Resumen operativo` (`Empresa`, `País`, `Moneda`, `Dispatch`) (B2:73-87).
Iconos Material: `save_outlined`, `apps_rounded` (Módulos), `tune_rounded` (Resumen), `dashboard_customize_rounded`.
Correcciones / fallos:
- `Dispatch` muestra el valor crudo (`broadcast`/`progressive`/`manual`) → mostrado como `Broadcast`/`Progresivo`/`Manual` (B2:87). Corrección de presentación.
- `Taxi`/`Delivery` duplicados en General y Servicios con el mismo estado (B2:79, 409).
- `Empresa` = `Express Delivery` fijo en código (B2:84).

## 6. ConfiguracionTabs.dc.html (1280×1400) — sección 11, pestañas 1-7
Paneles titulados con el nombre exacto de la pestaña (píldora) + `_SettingsCard` correspondiente:
- `Servicios` → `Servicios`: 2 switches con subtítulo (B2:89-94).
- `Pagos` → `Métodos de pago`: `Efectivo` (def. on), `Tarjeta` (off), `Billetera Express` (off) (B2:96-102).
- `Operación` → `Operación y dispatch`: dropdown `Modo de dispatch` (Broadcast/Progresivo/Manual, def. Broadcast), `Radio inicial de dispatch km` 5 km, `Aumento progresivo de radio km` 2 km, `Duración de oferta en segundos` 45 s (entero) (B2:104-111).
- `Tarifas` → `Tarifas globales y alcance`: `Mínimo Viaje` 5 Bs, `Mínimo Delivery` 5 Bs, `Comisión global %` 0 %, `Radio máximo km` 30 km, `Moneda` BOB (B2:113-121).
- `Soporte` → `Localización y soporte`: `Zona horaria` (def. America/Santiago), `País` (def. Chile), `Teléfono de soporte`, `WhatsApp de soporte` (vacíos por defecto) (B2:123-130). Ejemplo con valores de Bolivia.
- `Seguridad` → `Verificación de teléfono por SMS`: aviso `_InlineNotice` estado "no verificado" + 2 switches con subtítulo (B2:132-140).
- `Admin` → `Admin · Publicidad (Google AdMob)`: variante PRODUCCIÓN (descripción, 3 switches, `Credenciales públicas / identificadores AdMob`, 3 campos con hint y helper, aviso naranja, error de validación en rojo, `Guardar publicidad`) y variante PRUEBA (descripción, 3 switches, texto preview, `Guardar publicidad`) (B2:144-168).
Los textos "Por defecto …" bajo campos/switches son hints de presentación que documentan el valor por defecto del código; no existen en la app.
Iconos Material: `apps_rounded`, `account_balance_wallet_outlined`, `alt_route_rounded`, `payments_outlined`, `support_agent_rounded`, `tune_rounded`, `sms_outlined` (aviso no verificado; `verified_rounded` si verificado), `admin_panel_settings_outlined`, `save_outlined`.
Fallos:
- Sin validación de campos; números inválidos vuelven al valor por defecto en silencio (B2:173, 413). Ojo: los fallback al guardar difieren de los defaults (Mínimo Viaje/Delivery default 5 pero fallback 0, B2:117-118).
- Tras guardar en Producción, el estado local se reemplaza solo con el resultado del RPC de teléfono (B2:172).
- `Guardar configuración` deshabilitado en la pestaña Admin (B2:67): en Configuracion.dc.html se ve activo porque está en General.
- `Moneda` y `País` son texto libre (sin dropdown) (B2:121, 128).

## 7. ConfigAvanzada.dc.html (1280×1160) — sección 19, env=production
Cubre: `_Header` sin acción (B2:188); `_AdminHero` `Centro de control` con stats `Respaldo pagos`, `Ofertas` (`Activas`/`Off`), `Mantenimiento` (`Activo`/`Normal`) (B2:189-192); 5 tarjetas de módulo con acento y chips exactos (B2:194-202), rejilla de 3 columnas.
Iconos Material: `tune_rounded`, `account_balance_wallet_outlined`, `radar_rounded`, `health_and_safety_outlined`, `star_outline_rounded`, `construction_rounded`, `arrow_forward_ios_rounded`.
Fallos:
- Chip `<n> respaldos activos` no pluraliza (`1 respaldos activos`) (B2:198). Se mantiene literal; proponer singular.
- Stat `Ofertas` = `Off` (inglés) (B2:191) y chips `SOS off`/`Compartir off` (B2:200) → proponer `Inactivas`/`SOS inactivo`/`Compartir inactivo`. Corrección de presentación pendiente (aquí se dibuja el estado activo).
- Errores de guardado no capturados en `_save` (B2:185).
- Bloqueada en Prueba por el shell (B2:22, 178).

## 8. DlgConfig.dc.html (1280×1000) — diálogo de Servicios
Cubre: `Crear servicio · Trinidad` (valores por defecto de creación: `Moto`, orden 100, disponibilidad/visibilidad off, ofertas/precio fijo/programados on) y `Editar servicio · Trinidad` (`Clave interna` deshabilitada), ancho 580 cada uno (B2:340-357). Campos: `Nombre visible` (hint `Ej. Moto Express`), `Clave interna` (hint `motorcycle`), `Descripción` (3 líneas), `Vehículo requerido` (Auto/Moto/XL/Cualquiera), `Orden en la app` (def. 100), `Disponible en Trinidad`, `Visible para pasajeros`, `Visible para conductores` (con subtítulos), divisor, `Permitir ofertas`, `Permitir precio fijo`, `Permitir viajes programados`; acciones `Cancelar` / `Guardar servicio`.
Agrupaciones `Catálogo base` / `Disponibilidad en la zona` = títulos de presentación (el código usa un divisor).
Iconos Material: `location_city_rounded`, `apps_rounded`, `location_on_outlined`, `keyboard_arrow_down_rounded`, `save_outlined`.
Fallos del código:
- En Producción `admin_upsert_service` envía SIEMPRE `p_enabled:true`, `p_passenger_visible:true`, `p_driver_visible:true` a nivel catálogo, y `p_icon_key:'local_taxi'` fijo (no hay selector de icono) (B2:360, 411).
- Sin validación: nombre y clave vacíos se envían tal cual (B2:358).
- Si no hay zona: snackbar `Error: Primero crea o selecciona una zona.` (B2:341).

## 9. DlgAvanzada.dc.html (1280×1200) — 5 diálogos de Configuración avanzada (26 claves)
- `Búsqueda y ofertas` (ancho 620): aviso + 7 campos numéricos con unidad (s, s, km, —, Bs, Bs, min) y defaults 180/180/15/20/1/9999/30 + switches `Viajes programados`, `Permitir contraofertas` (9 claves) (B2:216-230).
- `Mantenimiento y versión mínima` (ancho ~580): `Modo mantenimiento` (+ subtítulo), `Mensaje de mantenimiento` (3 líneas, hint), dropdown `Versión mínima permitida` desplegado con opciones `Permitir todas las versiones`, `v2.4.1 · Bloquear todas las anteriores`, `v2.4.0 · build 41` (seleccionada), `v2.3.7 · build 38`, `v2.3.2 · build 33`, helper y caja `Solo podrán operar v2.4.0 o una versión superior.` (3 claves) (B2:250-258). Estado sin builds (`Todavía no hay builds Android listos registrados en el panel.`) no dibujado.
- `Compatibilidad de pagos · legado`: aviso + 5 switches (5 claves) (B2:206-214).
- `Funciones de seguridad y contacto`: 5 switches con icono (5 claves) (B2:232-239).
- `Calificaciones`: aviso + 2 switches + dropdowns `Mínimo`/`Máximo` 1–5 (4 claves) (B2:241-248).
Total 9+3+5+5+4 = 26 claves (B2:184). La fila inferior usa 3 diálogos de ~392 px (el código usa 520) para que quepan en el artboard; en la app mantener 520.
Iconos Material: `radar_rounded`, `payments_outlined`, `sos_rounded`, `share_location_outlined`, `chat_bubble_outline_rounded`, `call_outlined`, `bookmark_outline_rounded`, `star_outline_rounded`, `check_rounded` (opción elegida en el menú).
Fallos:
- `Búsqueda y ofertas` no valida `Oferta mínima ≤ Oferta máxima` (B2:230).
- `Máximo` se sube en silencio al `Mínimo` si es menor (B2:248).
- Errores de `admin_build_list` ignorados (B2:251); errores al guardar no capturados (B2:185).
- La moneda de las ofertas no está definida en el diálogo (se dibuja Bs como ejemplo de la zona).
