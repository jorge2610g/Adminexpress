# Notas agente B

Inventarios: `A_core.md` (A) y `C2_market_subs_priority_partner.md` (C2). Las referencias `A:n` / `C2:n` son líneas del inventario.
Todas las pantallas cumplen la "Restricción obligatoria": solo Row/Column/Wrap/GridView/ListView/Stack, Card, Chip, TextField, DropdownButtonFormField, PopupMenuButton, AlertDialog, Drawer, LinearProgressIndicator / CircularProgressIndicator; colores planos, LinearGradient, BoxShadow, bordes y radios. Sin blur ni blend, sin gráficos, sin mapas.

## 1. Login.dc.html (1280×800): A §1.1–1.2 (A:47-70)
- Panel de marca a la izquierda (flex 6) y tarjeta de formulario a la derecha (flex 5, ancho 430, padding 28), en variante Preview.
- Textos literales: `Adminexpress`, `Acceso de Prueba · sesión independiente`, `Panel administrativo de Express Delivery`, `Correo administrador`, `Contraseña`, `Ingresar al panel`, `Acceder con Google · Preview` con su texto de ayuda, `Ir a Producción`, `Cada página utiliza su canal autorizado.` y `Adminexpress v1.0.1 · build 2`. En el panel de marca: `EXPRESS`, el titular, el cuerpo y `Adminexpress · Solo web`.
- Rediseño de presentación:
  - El degradado del panel de marca pasa de #073B8C→#0B57D0→#39A0FF (M:424, A:66) a los colores del panel (#0B1220→#0F2854→#174B91→#0D6B8D).
  - El logo pasa de CircleAvatar blanco a una baldosa con degradado #2563EB→#22D3EE, como `_Brand`.
  - Se añaden tres píldoras decorativas (Operación / Conductores / Seguridad) y anillos concéntricos hechos con Container circulares dentro de un Stack.
  - Se añaden una píldora `PREVIEW` junto al título y un separador "o". Son solo visuales.
  - El tema del login usa la semilla #0B57D0 (A:31). La propuesta es unificarlo con la del panel, #2563EB.
- Iconos: Icons.bolt_rounded, Icons.mail_outline_rounded, Icons.lock_outline_rounded, Icons.visibility_outlined, Icons.login_rounded, Icons.account_circle_outlined, Icons.swap_horiz_rounded, Icons.map_rounded, Icons.drive_eta_rounded, Icons.shield_rounded.
- Estado de error (A:54-58): no se dibuja porque el texto sería #D92D20 12px bajo los campos.

## 2. Estados.dc.html (1280×1160): A §1.3, §1.4, §1.12, §1.13 (A:72-83, 152-159)
- Celdas:
  - Resolviendo acceso (spinner).
  - `_Loading` con su héroe `Cargando operación` y la barra de progreso.
  - `_AccessDenied` en sus variantes Prueba, Producción y error (`No se pudo validar tu acceso`).
  - `_Unauthorized`, `_StartupError` y `_ErrorView` (`Reintentar`).
  - `_ScopeSelectionRequired`, el aviso de módulo bloqueado en Preview y `_ZoneMonitorRestricted`.
- Los textos de error de ejemplo (AuthRetryableFetchException, PostgrestException 42501, Supabase) son datos verosímiles porque el código muestra la excepción tal cual.
- Presentación:
  - El texto de bloqueo en Preview (A:153) en el código es un texto suelto centrado. Se propone una tarjeta ámbar (#FFF7E6) con icono.
  - En `_ZoneMonitorRestricted` se añade la píldora `Solo lectura` (reutiliza el texto de la barra de ámbito, A:145).
  - En el resto de estados, el icono va en una baldosa suave de 52px.
- Iconos: Icons.admin_panel_settings_outlined, Icons.lock_outline_rounded, Icons.error_outline_rounded, Icons.logout_rounded, Icons.refresh_rounded, Icons.filter_alt_outlined, Icons.science_rounded, Icons.bolt_rounded. Indicadores: CircularProgressIndicator y LinearProgressIndicator.
- Fallo del código: `_StartupError` no tiene ninguna acción (no hay ni reintentar ni cerrar sesión) (A:78).

## 3. Movil.dc.html (390×844): A §1.6, §1.8, §1.10
- AppBar con `_Brand(compact)` y los botones `Nuevo viaje` (Icons.add_circle_outline_rounded), `Actualizar` (Icons.refresh_rounded) y `Cuenta` (Icons.more_vert_rounded).
- Banner de entorno Preview, con el botón `Ir a Producción` en su propia línea alineado a la derecha (comportamiento <580 px, A:142).
- Drawer con la tarjeta "EMPRESA ACTUAL" y los 9 grupos con los mismos elementos y el mismo orden que Sidebar.dc.html. El activo es Dashboard y la insignia SOS se mantiene.
- Desviación de presentación: en Flutter el Drawer del Scaffold tapa el AppBar. En el mockup el Drawer se abre debajo del AppBar y del banner para que la marca y las acciones sigan visibles. Para implementarlo, poner un Stack en el body con un scrim y un panel; si no, usar el Drawer estándar.
- Densidad: los ítems van compactos (alto 18) para que quepan los 27 sin desplazamiento. En la app real será un ListView con scroll.
- Iconos del menú: los mismos de A:122 (dashboard_rounded, map_rounded, local_taxi_rounded, alt_route_rounded, local_shipping_rounded, receipt_long_rounded, drive_eta_rounded, people_rounded, shield_rounded, storefront_rounded, delivery_dining_rounded, workspace_premium_outlined, account_balance_wallet_rounded, payments_outlined, workspace_premium_rounded, bar_chart_rounded, history_rounded, notifications_active_rounded, verified_user_rounded, apps_rounded, hexagon_outlined, settings_rounded, tune_rounded, build_circle_outlined, science_rounded, speed_rounded). Además: Icons.apartment_rounded y Icons.logout_rounded.

## 4. DlgConductor.dc.html (900×1500): A §10.1 (A:285-306)
- Secciones:
  - Fotos para aprobación: `Ver foto de perfil`, `Foto vehículo 1/2`.
  - Datos personales y operación, con los 9 campos.
  - Vehículo, con 6 campos.
  - Documentos e identidad: 3 tarjetas que muestran todas las combinaciones de botones (Pendiente → Aprobar/Rechazar; Aprobado → Rechazar/Reabrir revisión; Rechazado → Aprobar/Reabrir revisión con nota de rechazo) y la Revisión de identidad con 2 filas.
  - Resumen operativo, con 6 datos.
- Pie: `Cerrar` / `Guardar cambios`.
- Subdiálogo abajo a la derecha: `Rechazar Licencia de conducir`, `Motivo del rechazo` y `Confirmar rechazo`.
- Correcciones de presentación:
  - Los Chip de Revisión de identidad (A:305) y la Suscripción `{plan} · {status}` (A:306) muestran el estado crudo. El mockup los traduce: active→Activa, approved→Aprobado, pending→Pendiente.
  - `QA / pruebas` `{group} · {role}`: el rol `driver` se traduce a Conductor.
  - El estado general del conductor también se muestra como chip en la cabecera.
- Propuesta: el botón Aprobar en verde #14804A y Confirmar rechazo en rojo #D92D20. En el código ambos son FilledButton azules.
- Iconos: Icons.drive_eta_rounded, photo_library_outlined, account_circle_outlined, directions_car_outlined, person_rounded, two_wheeler_rounded, badge_rounded, credit_card_rounded, flip_to_back_rounded, face_rounded, check_circle_outline_rounded, cancel_outlined, restart_alt_rounded, fact_check_outlined, insights_rounded, save_rounded, keyboard_arrow_down_rounded.

## 5. DlgUsuario.dc.html (900×1000): A §10.2 (A:308-315)
- Contenido: Perfil y cuenta (6 campos), Resumen (4 datos), Viajes recientes (7 filas), `Cerrar` / `Guardar cambios`.
- Corrección de presentación: el estado del viaje viene crudo en el subtítulo `{status} · {fare} · {date}`. Se traduce: completed→Completado, cancelled→Cancelado.
- Fallo del código: la tarifa del subtítulo no lleva moneda (A:315).
- Se añade un avatar con iniciales y un chip de estado en la cabecera.
- Iconos: Icons.person_rounded, analytics_outlined, local_taxi_outlined, route_rounded, save_rounded.

## 6. DlgViaje.dc.html (900×1400): A §10.3 (A:317-326)
- Secciones: Ruta, Participantes, Tarifa y pago (con la lista de pagos y `Movimientos de billetera: 2`), Fechas y estado, Historial del viaje (6 eventos) y Calificaciones (2). Solo hay botón `Cerrar`.
- Correcciones de presentación (estados crudos en Estado actual, Historial, Estado de pago y Método):
  - completed→Completado, searching→Buscando conductor, accepted→Aceptado, arriving→Conductor llegando, arrived→Conductor en el punto, in_progress→En curso.
  - paid→Pagado, cash→Efectivo, service moto→Moto, demanda high→Alta.
  - Para `Modo de precio` el inventario no da los valores. Se supuso fixed→"Tarifa fija" y debe verificarse en el código.
- Iconos: Icons.local_taxi_rounded, route_rounded, south_rounded, people_alt_rounded, payments_rounded, receipt_long_outlined, schedule_rounded, timeline_rounded, circle, star_rounded.

## 7. DlgPedido.dc.html (800×1160): C2 "Order detail dialog" (C2:254-272)
- Escenario dibujado: estado confirmed, pago transfer + under_review.
- Con ese escenario se ven:
  - Filas financieras completas, con dos divisores y la Liquidación.
  - Botones de saldo, solo para los saldos mayores que 0: `Cerrar saldo Comercio → Express` y `Cerrar saldo Express → repartidor`.
  - Chat / comprobantes (4 mensajes).
  - `Rechazar comprobante` / `Aprobar transferencia`.
  - `Pasar a preparación` (por el estado confirmed) y `Confirmar pago al repartidor` (merchant_owes_driver > 0).
- No se ven, por depender del estado: `Confirmar pedido en efectivo` (pending + cash) y `Listo · buscar repartidor` (preparing).
- Correcciones de presentación:
  - La línea `Estado: <status> · Pago: <payment_status>` usa valores crudos (C2:256). Se muestran como chips: confirmed→Confirmado, under_review→En revisión.
  - La liquidación también viene cruda: pending→Pendiente.
  - En el chat, sender_role y message_type: customer→Cliente, merchant→Comercio, system→Sistema, text→Texto, receipt→Comprobante, status→Estado.
  - Moneda CLP con separador de miles y sin decimales ("CLP 18.450"). Los saldos en 0 van en gris.
- Fallos del código:
  - Los botones de liquidar no piden confirmación y no muestran snack (C2:265, 272).
  - El chat no tiene texto para el estado vacío (C2:266).
- Iconos: Icons.receipt_long_rounded, account_balance_rounded, delivery_dining_rounded, chat_bubble_outline, close_rounded, check_rounded, soup_kitchen_outlined, payments_outlined.

## 8–10. Panel de socios (C2:335-399): shell propio
- Shell: barra lateral de 270 px en #0B2C5B, con marca `EXPRESS` y avatar blanco con el rayo, el desplegable `Organización` (borde blanco al 30 %), 5 ítems de navegación y, abajo, `Actualizar` / `Cerrar sesión`.
- Solo existe en el build de Producción (C2:341), así que no lleva banner de entorno.
- Iconos de la barra: Icons.bolt_rounded, dashboard_rounded, two_wheeler_rounded, person_add_alt_rounded, payments_rounded, notifications_active_rounded, refresh_rounded, logout_rounded, arrow_drop_down.

### SociosResumen.dc.html (1280×900): `_PartnerOverview` (C2:365-371)
- Contenido: título con el nombre de la organización, subtítulo literal y botón Actualizar; 3 métricas; tarjeta de información con 4 filas.
- Corrección de presentación: el rol `owner` se muestra como "Propietario" (A traducir: manager→Gestor, operator→Operador, treasurer→Tesorero).
- Fallo del código: Comisión generada y Comisión pagada no tienen moneda (C2:369-370). Se muestran con formato local "1.240,50".
- `Zona ID` enseña un UUID crudo. Se propone mostrar el nombre de la zona.
- Iconos: two_wheeler_rounded, account_balance_wallet_rounded, check_circle_outline_rounded, refresh_rounded.

### SociosConductores.dc.html (1280×900): `_PartnerDrivers` + `_PartnerJoinRequests` (C2:373-383)
- En el código son dos páginas distintas. Aquí se dibujan lado a lado y el ítem activo es "Conductores".
- Conductores: 6 filas; la segunda tiene abierto el PopupMenu con `Aprobar` / `Marcar pendiente` / `Suspender`.
- Solicitudes de afiliación: 4 filas con los botones de icono `Rechazar` y `Aprobar`. Una fila usa el respaldo `Conductor` y no tiene notas.
- Correcciones de presentación: la línea 2 del subtítulo viene cruda, `<approval_status> · <online_status>` (C2:376). Se muestran chips: approved→Aprobado, pending→Pendiente, suspended→Suspendido, online→En línea, offline→Fuera de línea, busy→Ocupado. El "★" del código se dibuja como icono (Icons.star_rounded).
- Fallo del código: las acciones de aprobar, suspender o rechazar no piden confirmación (C2:377, 383).
- Iconos: two_wheeler_rounded, more_vert_rounded, check_circle_outline_rounded, schedule_rounded, block_rounded, person_add_alt_rounded, close_rounded, check_rounded, star_rounded.

### SociosAvisos.dc.html (1280×900): `_PartnerPayments` + `_PartnerAnnouncements` (C2:385-399)
- Ambas páginas van lado a lado y el ítem activo es "Avisos push".
- Pagos y comisiones: 8 filas con importe y comisión.
- Avisos y promociones: Título con contador /90, Mensaje con contador /1000, recuadro informativo y `Enviar aviso`.
- Correcciones de presentación: el estado del pago viene crudo (C2:389) y se muestra como chip: paid→Pagado, pending→Pendiente, failed→Fallido. Importe con formato local "BOB 120,00".
- Fallos del código:
  - La comisión de la fila no lleva moneda (C2:389).
  - Si el título o el cuerpo están vacíos, `Enviar aviso` no hace nada y no avisa (C2:398).
  - No pide confirmación antes de enviar un push masivo.
- Iconos: receipt_long_rounded, notifications_active_outlined, send_rounded.
