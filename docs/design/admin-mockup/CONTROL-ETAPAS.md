# Admin Express — 8 etapas, revisión visual y criterios de aceptación

**Referencia**: `Mockups-Admin-Express.pdf` (54 páginas, revisadas visualmente página por página), diseños editables de Claude en `project/*.dc.html` y orden exacto en `project/canvas.json`. Detalle comprobable por pantalla: [ETAPAS.json](ETAPAS.json).

**Interpretación correcta del encargo**: no basta con empaquetar los 54 artboards o aplicar colores. Cada pantalla Flutter debe tener la composición de su imagen y preservar la función preexistente. Los números de la columna PDF son los del documento y no los índices del menú.

## Seguimiento y semáforo

- **REFERENCIA REVISADA**: inspeccionada en el PDF y localizada en el repositorio.
- **CÓDIGO REVISADO**: se localizó la implementación actual, sus controles y limitaciones.
- **VERIFICACIÓN PENDIENTE**: aún NO hay captura reproducible de Flutter comparada con ese artboard; no significa pantalla terminada.
- **APROBADA**: requiere captura comparable + pruebas de interacción/roles + compilación/aislamiento + aceptación. Ninguna etapa está aprobada todavía.

| Etapa | Páginas PDF | Cantidad | Revisión de referencia | Estado Flutter |
|---|---|---:|---|---|
| E1 Acceso y estructura | 10–14 | 5 | Revisada | Código inspeccionado; captura y roles pendientes |
| E2 Operación principal | 1–9 | 9 | Revisada | Componentes presentes; faltan ajustes y validación real |
| E3 Fichas, identidad, requisitos | 15–18, 34–36 | 7 | Revisada | Fichas parcialmente rediseñadas; backend revisión pendiente |
| E4 Market/Express Plus/prioridad | 19–24 | 6 | Revisada | Módulos presentes; acceso de Preview restringido |
| E5 Pagos, tarifas y suscripciones | 25–30 | 6 | Revisada | Formularios presentes; requiere pruebas sin cobros reales |
| E6 Reportes, auditoría, avisos | 31–33 | 3 | Revisada | Reportes/Auditoría rediseñados; Avisos pendiente |
| E7 Configuración y cobertura | 37–49 | 13 | Revisada | Varias pantallas parcialmente rediseñadas; mapas/diálogos pendientes |
| E8 QA y socios | 50–54 | 5 | Revisada | Portal socio + herramientas existentes; faltan visual y permisos |
| **TOTAL** | **1–54, sin repetición** | **54** | **54 inspeccionadas** | **0 aprobadas visualmente** |

## E1 — Acceso y estructura (5)

**PDF 10–14**. La imagen 10 contiene el login dividido (marca en panel degradado y formulario a la derecha); 11 muestra diferentes estados de carga, permisos y denegación, no un único mensaje. Las páginas 12–14 definen menú oscuro, barra superior de dos niveles y versión compacta con drawer.

**Revisión del código**: `lib/main.dart` contiene `_AdminLogin`, `_AdminBrandPanel`, `_AccessDenied` y `_StartupError` con autorizaciones por canal. `lib/admin_panel.dart` contiene `_Navigation`, `_TopBar` y responsividad; `PlusJakartaSans` está declarada en `pubspec.yaml`.

**Pendientes**: comparar a 1280 y 390 px, estados de permisos/carga separados y menú en móvil. No modificar ni desactivar las consultas de acceso.

## E2 — Operación principal (9)

**PDF 1–9**. Dashboard: hero, 4 KPI, tarjetas de acciones rápidas verdes/amarillas/azules, estado a la derecha y actividad/resumen abajo. Live: zonas arriba, lista pequeña de viajes/conductores a la izquierda, mapa dominante a la derecha. Viajes: tabla con estados en español. Delivery: **acordeones**, no tabla. Conductores y Usuarios: tablas y menús; SOS: alerta con riel rojo y botón Resolver.

**Revisión del código**: `_dashboard`, `_liveOperations`, `_LiveSidePanelState`, `_LiveZoneStrip`, `AdminRecordsTable`, `AdminDeliveryRow`, `AdminSosRow` están presentes. Tabs Viajes/Conductores del panel vivo cambian estado local. El filtro exportar de `_RecordsState` **todavía muestra aviso en vez de generar archivo**: es una discrepancia funcional pendiente, no reportarla como resuelta. Las imágenes 4 (despacho) y 6 (pedidos) muestran operaciones con acceso Producción; no abrir sus permisos en QA.

**Pendientes**: pruebas de lista real/cero resultados, estados visibles, botones de cada tabla, todas las zonas accesibles, mapa OSM responsive, imagen a imagen.

## E3 — Fichas e identidad (7)

**PDF 15–18, 34–36**. Ficha conductor extensa con licencias/documentos, foto, revisión y motivo de rechazo; usuario, viaje y pedido en diálogos blancos; configuración y revisión de documentos por país/zona. 

**Revisión del código**: `_DialogFrame` pasó a cabecera/pie blanco; `lib/admin_detail_dialogs.dart`, `admin_driver_document_requirements.dart` y `admin_bolivia_kyc.dart` participan. **Decisión explícita del propietario**: las páginas 34–36 se integran en Conductores, sin pantalla paralela de identidad; eso prevalece sobre la ubicación mostrada en el PDF. La aprobación genérica de nuevos requisitos requiere el backend QA correspondiente antes de declarar el flujo operativo.

**Avance de código E3 (10 oct 2026)**:
- Fichas de conductor, usuario y viaje con cabecera blanca compartida (820 px en escritorio, adaptable a móvil), icono identificativo y estado donde el registro lo informa.
- Documentos e identidad del conductor en lista vertical, con botones independientes frente/reverso/selfie, motivo de rechazo y fecha de vencimiento cuando existan; se conserva la revisión por requisito dentro de Conductores.
- Nuevo detalle de Pedido, **solo lectura**, desde el acordeón Delivery; usa exclusivamente datos que ya devuelve `admin_delivery_list_v4`. La referencia de Claude incluye operaciones financieras que aquí **no se habilitan** sin RPCs y permisos auditados.
- En el editor de requisitos los errores de nombre, código y alcance se muestran sin cerrar la ficha. Los rechazos documentales no se pueden confirmar con motivos inferiores a cinco caracteres.
- Pruebas de widget agregadas para cabecera/modal de fichas en 390 y 1280 px y acceso al detalle de pedidos. Ningún cambio en Supabase, roles, operaciones productivas ni parámetros de canal.

**Pendientes para aprobar E3**: capturas reales comparadas contra PDF páginas 15–18 y 34–36; pruebas end-to-end con permisos por país/zona, fotos (frente/reverso/selfie), aprobaciones y suspensiones con QA real; validar backend complementario de revisión genérica (#155). **E3 no está certificada visualmente**.

## E4 — Market, Delivery avanzado y prioridad (6)

**PDF 19–24**. Market agrupa categorías, banners, comercios/productos; Delivery Fase 2 usa tres tarjetas grandes; Prioridad muestra ranking con barras; sus modales contienen varios formularios independientes. 

**Revisión del código**: `admin_marketplace.dart`, `admin_marketplace_phase2.dart` y `admin_driver_priority.dart` tienen fuentes reales y cabeceras planas (como el PDF). Son **módulos productivos restringidos en Preview**; no fingir paridad visual mostrando los datos de ejemplo de Claude ni desbloquear permisos solo para compararlos.

**Avance de código E4 (10 oct 2026)**:
- **Express Market:** rejilla de tres columnas a partir de 900 px de espacio útil, tarjetas con borde, iconografía diferenciada y acciones adaptadas a móvil.
- **Delivery Fase 2 / Express Plus:** tres tarjetas compactas de módulos en escritorio, tarjeta de acceso a Pedidos preservada y cabeceras de formularios alineadas al diseño.
- **Prioridad:** cuatro indicadores reales (reputación, reseñas, experiencia y frecuencia) en paralelo cuando hay ancho, con adaptación a móvil y valores de progreso limitados a 0–100; **no se cambió el algoritmo de ranking**.
- Los principales cuadros de configuración de Market, Plus y Prioridad ahora comparten cabeceras claras con icono y etiqueta de entorno; sus switches, RPC, validaciones existentes y permisos permanecen intactos.
- Pruebas de widget para indicadores de prioridad, anchos 320/390/900 px y cabeceras de formularios a 390/960 px añadidas a CI.
- Respaldo previo: `backup/admin-e4-before-market-priority-20261010`.

**Pendientes para aprobar E4**: capturas de Flutter comparadas con PDF 19–24; verificación de todos los diálogos, acciones y ausencia de overflow; no desbloquear Market/Plus/Prioridad en Preview. Verificar visualmente mediante build QA aislado con datos sintéticos, sin ejecutar operaciones de Producción. **E4 no está certificada.**

## E5 — Finanzas (6)

**PDF 25–30**. Formulario de métodos de pago por zona, recargas y liquidaciones; tarifas fijas/escalonadas y mapa polígono; tres vistas de suscripciones; diálogos de Mercado Pago, tarifas, planes y VeriPagos.

**Revisión del código**: `admin_control_sections.dart`, `admin_distance_fares.dart`, `admin_driver_subscriptions.dart`. Se corrigió una regresión previa que había truncado el módulo de suscripciones; la lógica original fue restaurada. 

**Avance de código E5 (10 oct 2026)**:
- Pagos/Billetera vuelve a tomar el canal recibido por la pantalla en vez de asumir Producción; las recargas, métodos y credenciales de Preview permanecen en su almacenamiento QA aislado.
- Los formularios de Mercado Pago, planes, asignación de planes y VeriPagos adoptan cabeceras claras con icono, zona y contexto, como los diálogos de referencia.
- La tarjeta de tarifa escalonada adopta el contenedor visual compartido del panel; su lectura/escritura Preview sigue limitada a `admin_environment_config`.
- Se añadieron pruebas de widget de las cabeceras financieras a 390 y 1280 px. No se cambiaron RPCs, cobros, algoritmos de tarifa, permisos ni credenciales.

**Pendientes**: capturas reales comparadas con PDF 25–30; validación del estado/moneda por zona (Bs/CLP), permisos y cancelaciones; no realizar compras/cobros de prueba en Producción. E5 no está certificada visualmente.

## E6 — Informes y avisos (3)

**PDF 31–33**. Reportes usa 9 indicadores y barra blanca de fechas (sin héroe); Auditoría es una lista cronológica con marcas QA/REAL; Avisos divide editor a la izquierda e historial a la derecha.

**Revisión del código**: `admin_environment_reports.dart` y `admin_environment_audit.dart` conservan la separación de consultas por canal y ya tienen títulos planos. `admin_control_sections.dart` concentra avisos.

**Avance de código E6 (10 oct 2026)**:
- Reportes conserva sus nueve indicadores y la separación de resultados QA/REAL, usando la cabecera plana y tarjetas compartidas del sistema visual.
- Auditoría agrupa el historial cronológico en una sola superficie con leyenda visible y etiquetas QA/REAL por registro; no se mezclan ni se ocultan sus canales de origen.
- Avisos adopta la composición de dos columnas del mockup en escritorio (editor a la izquierda, historial/telemetría a la derecha) y vuelve a una lista única en móvil.
- Se añadió una prueba responsive de la composición de Avisos a 390 y 1280 px. No se alteraron RPC, destinatarios, permisos, soporte ni envío push.

**Pendientes**: capturas reales comparadas con PDF 31–33; validar conteos, fechas y origen de eventos con datos autorizados; probar el envío de Avisos únicamente en un entorno QA aislado. E6 no está certificada visualmente.

## E7 — Configuración y cobertura (13)

**PDF 37–49**. Catálogo de 3 tarjetas, centro de zonas/aliados, seguridad sectorial con polígono rojo, 8 pestañas de configuración, 5 tarjetas avanzadas, Builds, Demanda, radio/polígono y los diálogos correspondientes; incluye panel de liquidación de sindicato y creación de países.

**Revisión del código**: `admin_control_sections.dart`, `admin_preview_config_sections.dart`, `admin_zone_coverage_editor.dart`, `admin_single_app_release.dart`, `admin_dynamic_pricing.dart`, `admin_country_coverage.dart`. El selector de cobertura debe conservar **radio O polígono, jamás ambos**. No cambiar la aprobación de builds ni seguridad en QA.

**Avance de código E7 (10 oct 2026)**:
- Respaldo `backup/admin-e7-before-config-coverage-20261010` en el estado E6, antes de editar.
- **Zona y cobertura:** selector responsive con dos tarjetas excluyentes (Radio / Polígono) enlazado al mismo `onModeChanged` y modo persistido; el mapa continúa dibujando únicamente el modo activo. No se modificaron la RPC, los datos ni la validación del backend.
- **Zonas de operación:** tarjetas responsive con nombre, país, ciudad, moneda, modo de cobertura, estado e información de registro; los accesos existentes a Aliados, Métodos de pago y Editar permanecen conectados con sus funciones originales.
- **Demanda y precios:** siete indicadores presentados en siete columnas cuando hay ancho, cuatro o dos en tablet/móvil; formulario de demanda reorganizado en filas adaptativas, sin cambiar parámetros ni algoritmo.
- **Diálogos:** cabeceras de edición de zona, país, servicio, seguridad y demanda visualmente unificadas con el diseño de Claude. Se conservaron permisos por entorno y acciones originales.
- **Builds:** encabezado plano y tarjetas con borde alineados al artboard, manteniendo intacta la cadena de crear candidato → certificar → aprobar → promover → publicar y `productionAccess`.
- Pruebas widget añadidas: selección exclusiva de cobertura, resumen y acciones de zona, siete indicadores de demanda, y cuatro campos de formulario a tamaños móviles y de escritorio; integradas en el workflow de Flutter.

**Pendientes para aprobar E7**: faltan detalles visuales e interacciones de los demás artboards 37–49 (incluidos los subestados de Builds, Configuración y Avanzada, aliados y seguridad), capturas comparativas de Flutter, validación en QA de radio/polígono y pruebas autorizadas por roles/canales. Estas mejoras **no certifican la Etapa 7**, ni se publicaron todavía en Preview. No habilitar publicaciones de builds ni usar cambios reales de zona para pruebas de diseño.

## E8 — QA y socios (5)

**PDF 50–54**. Entornos internos, Carga QA con mapa y estadísticas, dashboard de socios, aprobaciones de conductores afiliados y pagos/avisos de sindicatos.

**Revisión del código**: `admin_audit_sandbox.dart`, `admin_load_lab.dart`, `partner_panel.dart`; el portal de socios comparte tokens y tarjetas renovadas.

**Pendientes**: validar carga sin contaminar Producción, aislamiento por sindicato, nombres correctos y permiso de avisos. No simular cargas reales masivas para probar el diseño.

## Puertas entre etapas

1. **Preparar**: mantener tag/rama de respaldo y Preview aislado.
2. **Implementar**: 1 artboard → 1 o varios widgets Flutter reales, preservando cada dato, campo y RPC.
3. **Revisar**: captura real del Flutter compilado a 1280×1160 y a 390 px si aplica; comparación por regiones, sin inventar datos.
4. **Probar**: widget tests, `flutter analyze`, dos web builds, pruebas de rol/aislamiento y tareas sensibles en modo seguro.
5. **Publicar**: despliegue *solo Preview*, verificar `/preview/version.json` y que `/version.json` de Producción no cambió.
6. **Aprobar etapa**: registrar captura de pantalla y checklist; no cambiar `parity` a `comparada_con_captura_real` sin evidencia.

**Estado a la fecha**: clasificación e inspección de las 54 imágenes realizada; implementación total **no certificada**. El PR #63 es el área de trabajo, no se debe fusionar con Producción mientras falten aprobaciones.
