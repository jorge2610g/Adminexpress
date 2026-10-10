# Notas agente D — Zonas (7/17), Tarifas (8), Pagos (9)

Fuente: `inventory/B1_zones_fares_payments_dispatch.md` (abajo, "B1:línea"). ACS = `lib/admin_control_sections.dart`.
Todo se implementa con Flutter Material 3 + flutter_map (TileLayer OSM, PolygonLayer, PolylineLayer, CircleLayer, MarkerLayer). Sin gráficos, sin blur, sin blend. Mapas dibujados = TileLayer + capas; barras de herramientas = Stack + Container blanco 95%.

## Componentes y equivalencias Flutter comunes
- Héroe degradado (`_Header`) = Container + LinearGradient; KPI = Card; filas = ListTile/Row en ListView; tabla de movimientos = Row dentro de ListView con cabecera Container #F8FAFC.
- Chips de estado = `_MiniStatus` (Container píldora); Hoy/Semana/Mes = ChoiceChip; Viajes/Delivery/Suscripciones/Billetera = FilterChip; Principal = ChoiceChip con avatar estrella.
- Switch = Switch/SwitchListTile; Radio/Polígono = SegmentedButton; Nivel de riesgo = Slider(divisions: 4); dropdowns = DropdownButtonFormField; menú abierto de "Jerarquía" = menú del DropdownButtonFormField desplegado.
- Unidades (BOB, km, %, ×) = `suffixText` de InputDecoration.

## Artboards

### Pagos.dc.html (1280×1160, env=production, scope=admin) — §9 (B1:291-329)
Header "Pagos y Billetera"; "Método de pago por zona" con tarjeta de zona Trinidad (Switch global, "Bolivia · BOB", métodos activos + "Activos", chips por método, "Configurar métodos", nota VeriPagos, bloque Mercado Pago "Falta conectar" + "Conectar Mercado Pago"; "Verificar" se oculta porque solo aparece con credenciales); "Recargas pendientes" (contador + filas con Rechazar/Aprobar); barra de filtros (Zona de movimientos, Hoy/Semana/Mes, Fecha); 4 KPI; "Movimientos del período".
Cambio de disposición: Recargas pendientes va a la derecha de la tarjeta de zona (no depende del período); filtros, KPI y movimientos van juntos debajo.
Iconos: Icons.account_balance_wallet_outlined, Icons.payments_outlined, Icons.tune_rounded, Icons.info_outline_rounded, Icons.manage_accounts_rounded, Icons.verified_outlined (oculto), Icons.date_range_outlined, Icons.check_rounded, Icons.schedule_rounded, Icons.receipt_long_rounded, Icons.error_outline_rounded, Icons.account_balance_wallet_rounded, Icons.credit_card_rounded, Icons.expand_more_rounded.

### Tarifas.dc.html (1280×1160, env=preview) — §8 (B1:220-243, 260-264)
Header "Tarifas por zona" + "Aeropuerto / Terminal" + "Nueva tarifa"; selector de zona "Editar tarifas de"; lista de reglas; tarjeta "Tarifa escalonada por distancia" (aviso PREVIEW, ayuda con BOB, Servicio con service_key crudo, escalones Hasta km / Precio (BOB) / eliminar, Agregar escalón, Guardar escalones); panel "Tarifas fijas · Trinidad".
Propuesta: la lista de §8.C (diálogo 860×520 en el código, se abre con "Aeropuerto / Terminal") se muestra como panel en la página; "Cerrar" no aplica allí.
Añadido de presentación: píldora de jerarquía en cada regla (Zona + servicio / Por servicio / Global), derivada del tipo; el código no muestra estado activo/inactivo de la regla.
Iconos: Icons.payments_outlined, Icons.place_outlined, Icons.add_rounded, Icons.location_city_rounded, Icons.edit_outlined, Icons.stacked_line_chart_rounded, Icons.science_rounded (aviso Preview), Icons.delete_outline_rounded, Icons.add, Icons.save_outlined, Icons.place_rounded, Icons.flight_rounded, Icons.directions_bus_rounded.

### DlgPagos.dc.html (1280×1000) — §9.Z (B1:279-287), §9.A (B1:318-324), §9.B (B1:326-329)
"Métodos de pago · Trinidad" (720 de ancho): aviso, una tarjeta por proveedor (Checkbox + subtítulo + Switch Habilitado; si está marcado: FilterChips y ChoiceChip Principal; FilterChips no soportados deshabilitados), Cancelar / Guardar métodos. "Mercado Pago · Trinidad" (500): intro, Public Key, Access Token (contraseña), aviso, Cancelar / Guardar y verificar. "Aprobar recarga" y "Rechazar recarga" (botón rojo #D92D20).
Estado sin conectar: la etiqueta es "Access Token"; si ya hay token cambia a "Access Token · dejar vacío para conservar" (B1:321).
Iconos: Icons.account_balance_wallet_outlined, Icons.info_outline_rounded, Icons.check_box / check_box_outline_blank, Icons.star_outline_rounded / Icons.star_rounded, Icons.save_outlined, Icons.manage_accounts_rounded, Icons.visibility_outlined, Icons.verified_rounded, Icons.check_circle_outline_rounded, Icons.cancel_outlined.

### DlgTarifa.dc.html (1280×1000) — §8.D (B1:266-275), §8.B (B1:245-258)
"Nueva tarifa fija por sector" (760): aviso, Nombre, Tipo de sector (Aeropuerto | Terminal | Otro sector especial), Servicio, Tarifa fija · BOB, Prioridad (100), mapa _PolygonEditor morado #7F56D9 con 5 vértices numerados y barra "Dibuja el perímetro de aeropuerto · 5 puntos" Deshacer/Limpiar, atribución, Switch "Tarifa especial activa", Cancelar / Guardar tarifa.
"Nueva tarifa" (460): aviso, Jerarquía desplegada con sus 3 opciones (Zona + servicio · recomendado | Por servicio · respaldo | Global · respaldo general), Servicio, Zona, 6 campos (Tarifa base 5, Precio por km 1, Precio por minuto 0, Tarifa mínima 5, Multiplicador dinámico 1, Comisión % 0), Switch "Regla activa", Cancelar / Guardar.
El editor de escalones (§8.A) no es un diálogo en el código: está en la página (Tarifas.dc.html).
Iconos: Icons.flight_rounded, Icons.info_outline_rounded, Icons.touch_app_rounded, Icons.undo_rounded, Icons.delete_sweep_outlined, Icons.save_outlined, Icons.payments_outlined, Icons.check_rounded, Icons.expand_less_rounded/expand_more_rounded.

### Zonas.dc.html (1280×1160, env=preview) — §7 pestaña 1 (B1:75, 81-118, 155-176)
TabBar "Zonas y cobertura" (activa) | "Seguridad"; header "Zonas de operación" + "Países" + "Nueva zona"; fila de zona Trinidad (2 líneas, "Activa", botones Aliados / sindicatos, Métodos de pago, Editar zona); panel "Países de operación" (página completa §7.A con "Preparar países QA" solo Preview, "Nuevo país", filas con píldoras); panel "Accesos · …" (§7.F, filas con Switch); panel "Aliados y sindicatos · Trinidad" (§7.D, tarjetas con 2 líneas, estado y 3 acciones).
Propuesta: §7.A es una página aparte (AppBar "Países y cobertura · Preview") y §7.D/§7.F son diálogos; aquí se muestran como paneles para ver la cadena entera. El botón "Cerrar" de los diálogos se omite en los paneles.
Iconos: Icons.location_city_outlined, Icons.shield_outlined, Icons.hexagon_outlined, Icons.public_rounded, Icons.public_off_rounded, Icons.add_rounded, Icons.location_on_rounded (Icons.location_off_outlined si está inactiva), Icons.groups_2_outlined, Icons.account_balance_wallet_outlined, Icons.edit_outlined, Icons.copy_all_outlined, Icons.admin_panel_settings_outlined, Icons.person_add_alt_1_rounded, Icons.verified_user_outlined, Icons.person_off_outlined, Icons.groups_2_rounded, Icons.business_outlined, Icons.dashboard_customize_outlined.

### GeoSeguridad.dc.html (1280×1160, env=preview) — §7 pestaña 2 = §17 (B1:189-213)
TabBar con "Seguridad" activa; _AdminHero "Seguridad de zonas" con chips Zonas / Sectores de seguridad; header "Zonas rojas y prevención" + "Crear sector"; lista de sectores (tipo · nivel, Activa/Inactiva, editar). A la derecha, panel "Editar zona de seguridad" con Nombre, Tipo, Aplica a, Ciudad, País, Mensaje preventivo, Nivel de riesgo (Slider 1–5 + insignia), mapa _PolygonEditor rojo con barra "Dibuja el perímetro de seguridad · 5 puntos" Deshacer/Limpiar, Switch "Zona activa", Cancelar / Guardar zona.
Propuesta: el diálogo del código (AlertDialog de 780) se muestra como panel lateral (Drawer derecho / Row). La sección 17 del menú muestra lo mismo sin TabBar.
Contraste: caución y zona segura usan tinta más oscura (#B54708 / #0E8A55) en vez de #F79009 / #12B76A del código, por legibilidad del texto.
Iconos: Icons.location_city_outlined, Icons.shield_outlined, Icons.add_moderator_outlined, Icons.warning_amber_rounded, Icons.verified_user_outlined, Icons.edit_outlined, Icons.touch_app_rounded, Icons.undo_rounded, Icons.delete_sweep_outlined.

### DlgZona.dc.html (1280×1160) — §7.B + §7.C (B1:120-153)
"Editar zona" en 2 columnas (1080 de ancho; el código usa 500 con desplazamiento): aviso, Nombre, Ciudad, Clave de zona (deshabilitada al editar + ayuda), País (prefijo globo), "Administrar países", Región / departamento, Moneda; bloque "Pantalla inicial del pasajero" (Comportamiento de inicio, Servicio predeterminado, Título del panel, Subtítulo del panel, Orden de tarjetas Viajes/Envíos/Market, ayuda dinámica de "Automático"); "Tipo de cobertura" con SegmentedButton Radio|Polígono, instrucción, Latitud/Longitud/Radio (km) + ayuda, mapa con CircleLayer + marcador; Switch "Zona activa" y "Registro de conductores en esta zona"; Cancelar / Guardar zona y cobertura.
El orden de los campos cambia por las 2 columnas. El modo Polígono (no se dibuja) cambia la instrucción a "Dibuja el área exacta marcando 3 o más puntos. El radio no se utilizará.", oculta Lat/Lng/Radio y añade el pie "{n} puntos" + "Deshacer" + "Borrar" (B1:150-153). Opciones: Automático | Mostrar siempre el panel | Entrada directa; Viajes | Envíos / Delivery | Express Market.
Iconos: Icons.location_on_rounded, Icons.hub_outlined, Icons.public_rounded, Icons.settings_outlined, Icons.dashboard_customize_outlined, Icons.radar_rounded, Icons.polyline_rounded, Icons.info_outline_rounded, Icons.location_pin.

### EXTRA ZonasAliados.dc.html (1280×1000) — §7.G (B1:178-185)
"Dashboard · {aliado}" (1020×650) con Período, Crear liquidación, 7 métricas (180 px, Wrap), "Liquidaciones" (Pagada / Marcar pagada), "Pagos de conductores", Cerrar; encima, el subdiálogo "Marcar liquidación como pagada" (Referencia / comprobante, Nota opcional, Cancelar / Confirmar pago).
Iconos: Icons.dashboard_customize_outlined, Icons.date_range_outlined, Icons.receipt_long_outlined, Icons.account_balance_outlined, Icons.receipt_long_rounded, Icons.check_circle_outline_rounded.

### EXTRA DlgAliados.dc.html (1280×1000) — §7.A diálogos (B1:105-118), §7.E (B1:161-168), §7.F subdiálogo (B1:176)
"Nuevo país" (600): aviso, Código ISO (máx. 2), Nombre, Moneda (máx. 3), Prefijo + ayuda, País habilitado (apagado por defecto), Registro de conductores (deshabilitado mientras el país está apagado), fila de identidad manual, Cancelar / Guardar. "Preparar países de prueba" (Cancelar / Preparar QA). "Nuevo sindicato · Trinidad": Nombre, Código interno, Tipo de organización (Sindicato | Empresa aliada | Cooperativa), Estado (Activo | Suspendido | Inactivo), Comisión para el aliado (%) + ayuda, Responsable / presidente, Teléfono, Correo, Notas. "Asignar acceso al panel": nota, Correo de la cuenta Express (icono correo), Rol (Propietario / presidente | Administrador | Operador | Tesorería; por defecto Administrador), Cancelar / Asignar.
Iconos: Icons.public_rounded, Icons.info_outline_rounded, Icons.verified_user_rounded, Icons.copy_all_outlined, Icons.groups_2_outlined, Icons.person_add_alt_1_rounded, Icons.mail_outline_rounded.

## Correcciones de presentación (códigos crudos → español)
- Movimientos (B1:316): método wallet → "Billetera", cash → "Efectivo", veripagos_qr → "VeriPagos QR"; estado paid → "Pagado", pending → "Pendiente", failed → "Fallido". El código muestra los valores en inglés.
- Proveedores §9.Z (B1:284): provider_type gateway → "Pasarela", manual → "Manual", internal → "Interno"; credential_scope zone → "por zona", global → "globales". El código muestra "{provider_type} · credenciales {credential_scope}" en crudo.
- Servicio en reglas de tarifa (B1:230) y en el editor de escalones (B1:236): se deja el service_key crudo (motorcycle, economy, comfort, delivery) porque así lo muestra el código; los diálogos usan el nombre (Moto, Económico). Inconsistencia anotada abajo.
- Los KPI de Pagos usan separador de miles "4.860" (el código muestra el número sin formato).
- Unidades como sufijo (BOB, km, %, ×) en los campos de tarifa y comisión; el código no muestra unidades (B1:250, 271).

## Inconsistencias y fallos del código observados
1. Moneda "Bs" fija en recargas pendientes y en la confirmación de recarga (B1:315, B1:327) mientras KPI y movimientos usan currency_code (BOB). Se dibuja tal cual ("Bs 50") y BOB en lo demás. También en Despacho (B1:42, 45).
2. Aviso de Mercado Pago fijo para "Mercado Pago Chile" (B1:322) aunque el diálogo se abre para cualquier zona (Trinidad, Bolivia).
3. Pagos bloqueada en Preview desde el shell y forzada internamente a producción (B1:293); las ramas de Preview no se alcanzan.
4. Las listas de Zonas, el selector "Editar tarifas de" y las tarjetas de Pagos solo muestran la zona del ámbito (B1:83, 228, 293, 352-353): son listas de un solo elemento.
5. El Servicio del editor de escalones muestra service_key crudo; los diálogos de tarifa muestran el nombre (B1:236, 248, 354).
6. Reglas de tarifa sin indicador activo/inactivo y sin borrado; tampoco hay borrado de tarifas fijas, zonas, aliados ni sectores (B1:230, 355).
7. Los mensajes de validación se muestran con el prefijo "Error: " (B1:23, 144, 356).
8. "Guardar tarifa" (§8.D) solo reevalúa si está habilitado al reconstruir el diálogo, no al escribir (B1:274).
9. Seguridad: Ciudad y País del sector son texto libre con valores por defecto Trinidad/Bolivia, sin relación con el ámbito (B1:204).
10. `_editCoverage` (B1:216) es código muerto; no se dibuja.
11. El pie del polígono de cobertura usa "Borrar" (B1:153) y el _PolygonEditor usa "Limpiar" (B1:213): dos nombres para la misma acción.
12. El contador de "Recargas pendientes" es gris cuando es >0 en el código (B1:313; `_MiniStatus` positive solo si es 0). Se dibuja en ámbar para señalar trabajo pendiente.
13. Las recargas pendientes no se filtran por zona ni por período (B1:315).
14. El encabezado de §7 y el de §8 son ambos `_Header`; Seguridad apila `_AdminHero` y `_Header` (dos héroes seguidos, B1:195-196). Se mantienen los dos y se compacta el segundo.
