# Notas agente A — Viajes, Despacho, Delivery, Pedidos, Conductores, Usuarios, SOS

Inventarios: A_core.md (A), B1_zones_fares_payments_dispatch.md (B1), C2_market_subs_priority_partner.md (C2).
Todas las pantallas: 1280×1160, Sidebar + Topbar, sin notas dentro del artboard. Restricción Flutter aplicada:
solo Row/Column/Wrap/ListView/Card/Chip/TextField/Dropdown/PopupMenu/AlertDialog, colores planos, LinearGradient del `_Header`,
BoxShadow y bordes; sin blur, sin gráficos, sin mapas. Las "tablas" son filas Row dentro de ListView con cabecera Row.

Iconos comunes (Material):
- Héroe `_Header` (A §1.14): `Icons.bolt_rounded`. Héroe ACS (Despacho, B1:12): `Icons.dashboard_customize_rounded`.
- Buscar `Icons.search_rounded`; Fecha `Icons.date_range_outlined`; Exportar `Icons.download_rounded`;
  check del ChoiceChip seleccionado = checkmark por defecto de ChoiceChip (`Icons.check_rounded`).

## Viajes.dc.html — sección 2 (A §4 `_Records` + §5), env preview
- Héroe `Viajes` / `Historial y operación de viajes Express.`; barra de filtros: `Hoy` (seleccionado) / `Semana` / `Mes`, `Fecha`,
  búsqueda `Buscar`, `Exportar`; segunda línea `Todos (142)` + 5 chips de estado (máx. 5 según A:220).
- Filas: ruta origen → destino, estado, categoría, tarifa `Bs`, pasajero, conductor, pago, creado (`dd/mm/yyyy` + `HH:mm`),
  botón icono `Ver detalle completo` (abre §10.3).
- Iconos: `Icons.local_taxi_rounded` (fila), `Icons.open_in_new_rounded` (detalle).
- Correcciones de presentación:
  - Estados crudos traducidos: accepted→Aceptado, cancelled→Cancelado, completed→Completado, in_progress→En curso,
    searching→Buscando (A:238 subtítulo `{status}` muestra el código crudo; A:220 chips con valores crudos).
  - Categoría: economy→Económico, comfort→Confort, xl→XL, motorcycle→Moto (A:238 muestra `category` crudo, fallback `Express`).
  - Pago: paid→Pagado, pending→Pendiente; sin dato → `—`.
  - En el código pasajero/conductor/pago/creado solo se ven en modo ExpansionTile (zone_monitor) (A:239-240); para el admin
    la fila solo muestra título + subtítulo. El mockup los pone como columnas de la fila (mismos datos, sin funciones nuevas).
  - Cabecera de columnas añadida (presentación de tabla).

## Despacho.dc.html — sección 13 (B1 §13, ACS:20-445), env production
- Héroe `Despacho manual · Producción` / `Solo servicios reales de clientes en Producción.`; tarjeta `Conductores disponibles ahora: 7`;
  `Solicitudes de viaje` y `Delivery esperando` con filas `_DispatchItem` y botón `Asignar`.
- Panel derecho (diálogos simples, 480 px en el código, aquí 372 px apilados): `Asignar viaje` (texto ruta, dropdown
  `Conductor disponible` abierto con ítems `{nombre} · ★ {rating|—}`, `Tarifa final`, `Cancelar` / `Asignar`) y
  `Asignar delivery` (ruta, `Repartidor disponible`, `Cancelar` / `Asignar`). Filas seleccionadas resaltadas con borde azul.
- Iconos: `Icons.local_taxi_rounded`, `Icons.local_shipping_rounded`, `Icons.drive_eta_rounded` (tarjeta de disponibles,
  añadido decorativo; el código no tiene icono ahí, B1:39), `Icons.alt_route_rounded` (línea de ruta en los diálogos, decorativo),
  `Icons.expand_more_rounded` (dropdown).
- Observaciones del código:
  - Moneda fija `Bs` en las filas (B1:42, B1:350); se mantiene.
  - `Tarifa final` sin sufijo de moneda ni validación (B1:52); se dibuja sin sufijo para ser fiel.
  - Fallbacks `Pasajero` / `Cliente` y `Bs —` mostrados en una fila cada uno (B1:42, B1:45).
  - Error y validaciones salen como snack `Error: …` (B1:23).

## Delivery.dc.html — sección 3 (A §6), env preview
- Héroe `Delivery` / `Pedidos y entregas de Express.`; filtros de período con rango personalizado activo (`1/10/2026 – 10/10/2026`,
  formato `d/m/yyyy – d/m/yyyy` de A:225, por eso ningún chip de período está seleccionado), `Buscar`, `Todos (64)` + 5 estados, `Exportar`.
- Filas `_OperationCard` en modo ExpansionTile (A:246, siempre expandible, sin diálogo); la primera abierta mostrando
  `Cliente`, `Repartidor`, `Pago`, `Creado`.
- Iconos: `Icons.local_shipping_rounded`, `Icons.expand_more_rounded` / `Icons.expand_less_rounded`.
- Correcciones de presentación: accepted→Aceptado, cancelled→Cancelado, delivered→Entregado, picked_up→Recogido,
  pending→Pendiente (A:248); payment_method cash→Efectivo, transfer→Transferencia (A:249). Package type mostrado en español.
  Hora corta `10/10 · HH:mm` a la derecha de la fila (dato `Creado` ya existente, A:249).

## Pedidos.dc.html — sección 26 (C2 §26), env production
- Título plano (sin héroe) `Pedidos Delivery · Producción` / `Pedidos recientes, estados, pagos, comisiones y liquidaciones.`,
  botón `Actualizar`. Sin filtros ni búsqueda (C2:286). Filas: icono por método de pago, comercio, `zone_key · status · payment_status`,
  total en azul. Tap abre el diálogo de pedido (artboard DlgPedido, otro agente).
- Iconos: `Icons.account_balance_rounded` (transfer), `Icons.payments_outlined` (cash), `Icons.credit_card_rounded` (otros),
  `Icons.refresh_rounded`.
- Correcciones de presentación: status crudo (C2:285) → pending Pendiente, confirmed Confirmado, preparing En preparación,
  ready Listo para retiro, delivered Entregado, cancelled Cancelado; payment_status → pending Pago pendiente, under_review En revisión,
  paid Pagado, rejected Rechazado; mostrados como chips en vez de texto unido por `·`.
  - Moneda: el formateador da `BOB 85.00` para monedas distintas de CLP (C2:176); el mockup muestra `Bs 85.00`.
  - `zone_key` se muestra crudo (`trinidad`) porque es una clave; sugerencia: mostrar nombre de zona.

## Conductores.dc.html — sección 4 (A §7), env preview
- Héroe, filtros `Buscar` + `Todos (84)` (solo ese chip porque las filas no tienen `status`, A:253) + `Exportar`.
- Filas anchas: identidad (avatar, nombre, correo) | vehículo o `Sin vehículo` | ciudad o `—` | chip aprobación | chip en línea | menú.
- Menú `Acciones` abierto en la 3.ª fila: `Ver / editar ficha`, divisor, `Aprobar`, `Marcar pendiente`, `Rechazar`, `Suspender` (A:259).
- Iconos: `Icons.person_rounded` / `Icons.online_prediction_rounded` (avatar), `Icons.more_horiz_rounded`, `Icons.manage_accounts_outlined`.
- Correcciones de presentación (A:231, A:258): approved→Aprobado, pending→Pendiente, rejected→Rechazado, suspended→Suspendido;
  online→En línea, offline→Fuera de línea, busy→Ocupado. Colores: el `_Chip` del código solo tiene verde/naranja/gris; el mockup usa
  rojo para Rechazado y naranja para Ocupado. Puntos de color en las opciones del menú (decorativos). Cabecera de columnas añadida.
- Fallo: la acción sólo da snack crudo `Conductor: approved|…` (A:259); sugerido traducir.

## Usuarios.dc.html — sección 5 (A §8), env preview
- Héroe; dropdowns `Zona` (`Todas las zonas`, 190), `Ciudad` (`Todas`, 165), `Región / departamento` (`Todas`, 180); `Buscar`; `Exportar`;
  `Todos (36)` + estados; chips QA `Reales` y `QA / pruebas` (activo) + `Quitar filtro QA` (visible porque hay filtro QA activo).
- Filas: avatar, nombre, correo, modo activo, estado de cuenta, menú abierto en la 3.ª fila: `Ver / editar perfil`, divisor,
  `Activar`, `Suspender`, `Bloquear` (A:269).
- Iconos: `Icons.person_rounded` / `Icons.drive_eta_rounded` (avatar por active_mode), `Icons.people_alt_outlined` (Reales),
  `Icons.science_outlined` (QA), `Icons.more_vert_rounded`, `Icons.manage_accounts_outlined`, `Icons.expand_more_rounded`.
- Correcciones de presentación: subtítulo `{email} · {active_mode} · {account_status}` crudo (A:268) → modo Pasajero/Conductor
  y estado Activa/Suspendida/Bloqueada como columnas/chips.
- Fallo del código: los filtros Zona/Ciudad/Región no se envían al RPC (A:263, A:341); el mockup los dibuja igual.

## SOS.dc.html — sección 6 (A §9), env preview
- Héroe `Seguridad / SOS` / `Emergencias activas registradas desde Viajes y Delivery.`; `Buscar`, `Todos (4)` + estados, `Exportar`.
- Tarjetas: avatar rojo SOS, nombre (fallback `Usuario Express` en una fila), `estado · dd/mm/yyyy · HH:mm`, botón `Resolver`.
- Iconos: `Icons.sos_rounded` (avatar; dibujado como escudo con exclamación), `Icons.check_circle_outline_rounded` (Resolver).
- Correcciones de presentación: open→Abierta, acknowledged→Atendida (A:274 muestra `{status|open}` crudo). Borde izquierdo de color
  según estado (Container con Border, decorativo).
- Observación: `Resolver` no pide confirmación (A:274).
