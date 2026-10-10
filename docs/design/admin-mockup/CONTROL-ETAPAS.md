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

**Pendientes**: permisos por país/zona, foto de cada lado, aprobar/rechazar/suspender con validación, conservación de cambios y errores.

## E4 — Market, Delivery avanzado y prioridad (6)

**PDF 19–24**. Market agrupa categorías, banners, comercios/productos; Delivery Fase 2 usa tres tarjetas grandes; Prioridad muestra ranking con barras; sus modales contienen varios formularios independientes. 

**Revisión del código**: `admin_marketplace.dart`, `admin_marketplace_phase2.dart` y `admin_driver_priority.dart` tienen fuentes reales y cabeceras planas (como el PDF). Son **módulos productivos restringidos en Preview**; no fingir paridad visual mostrando los datos de ejemplo de Claude ni desbloquear permisos solo para compararlos.

**Pendientes**: contrastar grids, menús y cada campo de los diálogos con fixtures QA aisladas; verificar botones sin datos reales.

## E5 — Finanzas (6)

**PDF 25–30**. Formulario de métodos de pago por zona, recargas y liquidaciones; tarifas fijas/escalonadas y mapa polígono; tres vistas de suscripciones; diálogos de Mercado Pago, tarifas, planes y VeriPagos.

**Revisión del código**: `admin_control_sections.dart`, `admin_distance_fares.dart`, `admin_driver_subscriptions.dart`. Se corrigió una regresión previa que había truncado el módulo de suscripciones; la lógica original fue restaurada. 

**Pendientes**: validación del estado/moneda por zona (Bs/CLP), permisos y cancelaciones; no realizar compras/cobros de prueba en Producción.

## E6 — Informes y avisos (3)

**PDF 31–33**. Reportes usa 9 indicadores y barra blanca de fechas (sin héroe); Auditoría es una lista cronológica con marcas QA/REAL; Avisos divide editor a la izquierda e historial a la derecha.

**Revisión del código**: `admin_environment_reports.dart` y `admin_environment_audit.dart` conservan la separación de consultas por canal y ya tienen títulos planos. `admin_control_sections.dart` concentra avisos.

**Pendientes**: validar que conteos, fecha y origen de eventos no se mezclen; ajustar la composición de Avisos.

## E7 — Configuración y cobertura (13)

**PDF 37–49**. Catálogo de 3 tarjetas, centro de zonas/aliados, seguridad sectorial con polígono rojo, 8 pestañas de configuración, 5 tarjetas avanzadas, Builds, Demanda, radio/polígono y los diálogos correspondientes; incluye panel de liquidación de sindicato y creación de países.

**Revisión del código**: `admin_control_sections.dart`, `admin_preview_config_sections.dart`, `admin_zone_coverage_editor.dart`, `admin_single_app_release.dart`, `admin_dynamic_pricing.dart`, `admin_country_coverage.dart`. El selector de cobertura debe conservar **radio O polígono, jamás ambos**. No cambiar la aprobación de builds ni seguridad en QA.

**Pendientes**: comparación por formulario/campo y límites del mapa, zonas/sindicatos, roles y separaciones de canal. Las 13 pantallas suman varios modales y subestados.

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
