# Notas C: Suscripciones (22), Express Market (23), Delivery Fase 2 (24), Prioridad (25)

Inventario: `inventory/C2_market_subs_priority_partner.md` (abajo "inv:línea"). Todas las secciones se dibujan con `env="production"` y `scope="admin"` (el shell las bloquea en Preview). En los diálogos, el canal es Producción, así que los interruptores "Preview" aparecen deshabilitados (opacidad 50 % + candado) y los de "Producción" son editables (inv:131, 134-135, 210-211, 225, 322-326).

Restricción Flutter: solo se usan Row/Column/Wrap/GridView/Card/Chip/Switch(ListTile)/TextField/DropdownButtonFormField/PopupMenuButton/Dialog/ExpansionTile. Las barras de métrica son LinearProgressIndicator. No hay gráficos, mapas, blur ni blend. Las sombras son BoxShadow.

## Market.dc.html (23 · Express Market)
- Cubre: encabezado (inv:115-118), fila de etiquetas de estado (inv:120-121) y las tres secciones Categorías / Banners y promociones / Comercios y productos con botones Nueva categoría / Nuevo banner / Nuevo comercio (inv:123-127). La tarjeta de comercio muestra el PopupMenu abierto con "Editar comercio" y "Productos" (inv:127).
- Iconos: Icons.refresh_rounded, Icons.tune_rounded, Icons.add_rounded, Icons.storefront_rounded (todas las tarjetas, como en el código), Icons.more_vert_rounded (PopupMenuButton), Icons.edit_outlined y Icons.inventory_2_outlined (ítems del menú).
- Correcciones de presentación:
  - La etiqueta "Activa"/"Activo" en gris (inactivo) se muestra como "Inactiva"/"Inactivo" (inv:125-127). El código usa el mismo texto para los dos estados y solo cambia el color.
  - La cuadrícula es de 3 columnas. Con el ancho real del contenido (~984 px < 1100) el código daría 2 columnas (inv:123).
  - El subtítulo del comercio muestra la `category_key` cruda (`restaurants · 20-35 min`), tal como hace el código (inv:127). Se recomienda mostrar el nombre de la categoría.

## Fase2.dc.html (24 · Delivery Fase 2 / Express Plus)
- Cubre: encabezado "Delivery · Configuración" + Actualizar (inv:179-182), las 3 tarjetas de módulo con contador (inv:184-188) y la tarjeta "Pedidos fuera de esta pantalla" con la insignia "12 recientes" (inv:190-191).
- Iconos: Icons.refresh_rounded, Icons.delivery_dining_rounded, Icons.bolt_rounded, Icons.storefront_rounded, Icons.open_in_new_rounded, Icons.receipt_long_rounded.
- Corrección de presentación: el contador usa singular/plural ("1 zona", "1 plan"). El código siempre pone plural (`<n> zonas`, `<n> planes`) (inv:186-187).
- Sin dibujar (no estaban asignados): los diálogos de lista "Tarifas Delivery por zona", "Express Plus · planes" y "Locales · beneficios y logística" (con el menú "Beneficios Express Plus / Ubicación / transferencia / Usuarios del local") (inv:193-196, 214-217, 229-232).

## Prioridad.dc.html (25 · Prioridad conductores)
- Cubre: encabezado + Actualizar/Configurar (inv:299-302), las 4 píldoras de estado (inv:304-308), el banner informativo (inv:310-311), "Conductores · 7" y las filas con nivel, Puntaje, viajes, reseñas y las 4 barras Reputación/Reseñas/Experiencia/Frecuencia, coloreadas ≥75 verde, ≥50 naranja y el resto rojo (inv:313-318).
- Iconos: Icons.refresh_rounded, Icons.tune_rounded, Icons.info_outline_rounded, Icons.local_taxi_rounded. Barras = LinearProgressIndicator(minHeight: 6).
- Notas: los puntajes de ejemplo son coherentes con los pesos 35/25/20/20 y con las metas 20/100/30. Los colores de las píldoras siguen el código: "Producción visible" en naranja y "Ranking Producción activo" en rojo (inv:307-308). Revisar si el rojo para "activo" es lo deseado.

## DlgMarket.dc.html (diálogos de Express Market)
- Cubre:
  - Configuración de Express Market: 2 interruptores + 4 campos con sus valores por defecto (inv:133-140).
  - Nueva categoría (inv:142-145).
  - Nuevo banner, con la ayuda "blue, yellow, green, purple" (inv:147-150).
  - Nuevo producto (inv:166).
  - Nuevo comercio: Zona/Categoría desplegables, Rating 5, Costo envío 0, ETA 15/40, Orden 100 (inv:152-159).
- Iconos: Icons.tune_rounded, Icons.category_rounded (categoría), Icons.campaign_rounded (banner), Icons.inventory_2_outlined (producto), Icons.storefront_rounded (comercio), Icons.lock_outline_rounded (interruptor bloqueado por canal), Icons.expand_more_rounded (desplegable).
- Correcciones y fallos del código:
  - Moneda del producto: el valor por defecto `CLP` (inv:166) es incorrecto en una zona de Bolivia. Se dibuja `CLP` tal cual para no ocultar el fallo. Debería tomar la moneda de la zona.
  - "Costo envío" y los campos de ETA no tienen unidad en el código (inv:156-157). Se mantienen sin sufijo; se recomienda añadir "Bs" y "min".
  - Los subtítulos de contexto bajo cada título ("Express Market · Producción", etc.) son un añadido de presentación.
  - La regla "registro compartido entre Prueba y Producción" (inv:130) es solo un snack y no se dibuja.

## DlgFase2.dc.html (diálogos de Delivery Fase 2)
- Cubre:
  - Delivery · Trinidad: 3 grupos de tarifas y los 8 interruptores en 3 bloques separados por divisor (inv:198-212).
  - Express Plus · Trinidad (inv:219-227).
  - Plus · Pollos Copacabana, con el desplegable "Quién financia el descuento" = Express (inv:234-240).
  - Logística · Pollos Copacabana, con la ayuda de transferencia (inv:242-246).
  - Accesos · Pollos Copacabana: correo + botón Vincular y filas con interruptor (inv:248-252).
- Iconos: Icons.delivery_dining_rounded, Icons.person_rounded, Icons.bolt_rounded, Icons.group_rounded, Icons.person_add_alt_1_rounded, Icons.workspace_premium_rounded, Icons.place_rounded, Icons.lock_outline_rounded, Icons.expand_more_rounded.
- Correcciones de presentación:
  - Se añade el sufijo "Bs" a las tarifas, que en el código no tienen moneda (inv:199-201). Los títulos de grupo llevan icono.
  - El rol crudo `manager` se muestra como "Encargado" (inv:251).
  - Fallo del código: ninguna acción de guardar muestra confirmación ni error (inv:177). Se recomienda añadir snacks.

## DlgPrioridad.dc.html (Configurar prioridad de conductores)
- Cubre: los 4 interruptores (Preview bloqueados en Producción), las secciones Umbrales (80/55 con sufijo /100), Pesos del puntaje (35/25/20/20) y Metas para llegar a 100% (20/100/30), y Cancelar/Guardar (inv:321-331).
- Iconos: Icons.workspace_premium_outlined, Icons.lock_outline_rounded, Icons.bar_chart_rounded (Umbrales), Icons.balance_rounded (Pesos), Icons.track_changes_rounded (Metas).
- Nota: el código no valida los pesos (no comprueba que sumen 100) (inv:330).

## Suscripciones.dc.html (22 · Suscripciones de conductores)
- Cubre, en dos columnas:
  - Encabezado + Actualizar (inv:21-24).
  - Tarjeta Zona con "Administrar suscripciones de" = "Trinidad · BOB" (inv:27-29).
  - Aviso de métodos + "Editar métodos de suscripción" (inv:31-35).
  - Configuración con 3 interruptores, Vigencia QR 0/00:15 y "Guardar configuración" (inv:37-44).
  - Tarjeta "QR Bolivia · VeriPagos" en estado verificado (inv:51-56).
  - Planes · Trinidad + Nuevo plan y 3 tarjetas con "Editar plan" (inv:71-74).
  - Conductores reales (4) con buscador, leyenda QA y Asignar/Editar (inv:88-92).
  - Desplegable QA abierto (inv:93).
  - Pagos de suscripciones con Hoy/Semana/Mes y Fecha (inv:101-105).
- Iconos: Icons.refresh_rounded, Icons.location_city_rounded, Icons.info_outline, Icons.tune_rounded, Icons.save_rounded, Icons.qr_code_2_rounded, Icons.verified_rounded, Icons.check_circle_rounded, Icons.wifi_tethering_rounded, Icons.manage_accounts_rounded, Icons.add_rounded, Icons.check_rounded, Icons.edit_rounded, Icons.search_rounded, Icons.arrow_forward_rounded, Icons.two_wheeler_rounded, Icons.science_outlined, Icons.expand_less_rounded, Icons.date_range_outlined, Icons.receipt_long_rounded.
- Correcciones de presentación:
  - Los estados crudos de pago (`paid`/`pending`/`expired`/`failed`) se muestran como Pagado/Pendiente/Vencido/Fallido, en chip de color (inv:105).
  - El proveedor crudo `veripagos` se muestra como "VeriPagos" (inv:105).
  - Conductor sin plan: el código mostraría "Sin plan · Sin plan" (`<plan_name|Sin plan> · <countdown>` con countdown nulo = "Sin plan") (inv:17, 92). Se muestra solo "Sin plan".
  - "1 días" se corrige a "1 día" en la tarjeta de plan (inv:74).
  - La cuenta atrás se colorea: verde si está vigente, rojo si está vencida.
- Sin dibujar: la tarjeta "Mercado Pago · Suscripciones" (solo aparece si la zona tiene `mercado_pago`; Trinidad usa VeriPagos) (inv:68-69), el editor compartido de métodos de pago y los estados de carga/error.

## DlgPlan.dc.html (diálogos de Suscripciones)
- Cubre:
  - Nuevo plan: Código con la ayuda "Ej. daily, weekly, monthly", Nombre, Precio (BOB), Días de acceso, Beneficios con la ayuda "Un beneficio por línea", interruptor "Plan visible y activo" encendido (inv:76-84).
  - Asignar plan · <conductor>: Plan con el formato "Semanal · Bs 70 · 7 días", Días personalizados 0 con su ayuda (inv:95-98).
  - Conectar VeriPagos con las etiquetas de "dejar vacía para conservar" y el aviso de QR Bs 0 (inv:59-65).
  - Confirmación "Exigir suscripción · Trinidad" (inv:46).
- Iconos: Icons.workspace_premium_rounded, Icons.two_wheeler_rounded, Icons.qr_code_2_rounded, Icons.verified_rounded, Icons.info_outline, Icons.warning_amber_rounded, Icons.expand_more_rounded.
- Corrección de presentación: "Activar exigencia" usa el estilo de peligro, porque deja offline a conductores. En el código es la acción por defecto del AlertDialog.
