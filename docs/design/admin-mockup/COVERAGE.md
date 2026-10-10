# Cobertura de los 54 artboards de Admin Express

Fuente de verdad: `project/canvas.json` (54 artboards) y los 54 originales `project/*.dc.html` incorporados **sin editar** desde la rama `claude/express-admin-audit-cp07ml`.

## Estado e integridad

- El PR #63 contiene la base de rediseño Flutter y los componentes compartidos `AdminPageHero`, `AdminCard`, `AdminStatusChip` y los tokens de color/radio.
- La cabecera y los encabezados de registros usan una composición común adaptable a móvil y escritorio; la barra superior adopta la geometría del mockup (72 px, sin tarjeta flotante).
- El panel de socios adapta su navegación y sus tres conjuntos de vistas al mismo lenguaje.
- **Esto no es una certificación de paridad uno a uno de los 54 artboards.** Los archivos del mockup son referencias estáticas y pueden agrupar varias subpantallas/diálogos; cada uno requiere comparación visual en Preview con datos representativos y pruebas de sus interacciones.
- **Preview:** no debe escribir Producción; no desactivar `_previewScopedModules` ni habilitar módulos sin RPC auditadas. **Producción:** sin despliegue desde esta rama.
- Identidad + requisitos se concentran en Conductores y se evita repetir el flujo independiente, como se acordó. La aprobación genérica sigue bloqueada hasta el PR backend #155 en QA.

## Matriz para la revisión visual y funcional

| # | Artboard | Referencia | Código Flutter asociado | Estado de contraste |
|---:|---|---|---|---|
| 1 | 0 · Dashboard | `project/Main.dc.html` | lib/admin_panel.dart · _dashboard | Código asociado; contraste visual pendiente |
| 2 | 1 · Operación en vivo | `project/Live.dc.html` | lib/admin_panel.dart · _liveOperations | Código asociado; contraste visual pendiente |
| 3 | 2 · Viajes | `project/Viajes.dc.html` | lib/admin_panel.dart · _tripList / _Records | Código asociado; contraste visual pendiente |
| 4 | 13 · Despacho manual | `project/Despacho.dc.html` | lib/admin_panel.dart + lib/admin_control_sections.dart | Código asociado; contraste visual pendiente |
| 5 | 3 · Delivery | `project/Delivery.dc.html` | lib/admin_panel.dart · _deliveryList | Código asociado; contraste visual pendiente |
| 6 | 26 · Pedidos Delivery | `project/Pedidos.dc.html` | lib/admin_panel.dart · sección Delivery | Código asociado; contraste visual pendiente |
| 7 | 4 · Conductores | `project/Conductores.dc.html` | lib/admin_panel.dart · _driverList | Código asociado; contraste visual pendiente |
| 8 | 5 · Usuarios | `project/Usuarios.dc.html` | lib/admin_panel.dart · _userList | Código asociado; contraste visual pendiente |
| 9 | 6 · Seguridad / SOS | `project/SOS.dc.html` | lib/admin_panel.dart · _security | Código asociado; contraste visual pendiente |
| 10 | Inicio de sesión | `project/Login.dc.html` | lib/main.dart · _AdminLogin | Código asociado; contraste visual pendiente |
| 11 | Estados de acceso y bloqueo | `project/Estados.dc.html` | lib/main.dart · _AccessDenied / _StartupError | Código asociado; contraste visual pendiente |
| 12 | Vista compacta (< 1180 px) | `project/Movil.dc.html` | lib/admin_panel.dart · LayoutBuilder compact | Código asociado; contraste visual pendiente |
| 13 | Componente · Menú lateral | `project/Sidebar.dc.html` | lib/admin_panel.dart · _Navigation | Código asociado; contraste visual pendiente |
| 14 | Componente · Barra superior | `project/Topbar.dc.html` | lib/admin_panel.dart · _TopBar | Código asociado; contraste visual pendiente |
| 15 | Ficha del conductor | `project/DlgConductor.dc.html` | lib/admin_detail_dialogs.dart · _DriverEditorDialog | Código asociado; contraste visual pendiente |
| 16 | Ficha del usuario | `project/DlgUsuario.dc.html` | lib/admin_detail_dialogs.dart · _UserEditorDialog | Código asociado; contraste visual pendiente |
| 17 | Detalle del viaje | `project/DlgViaje.dc.html` | lib/admin_detail_dialogs.dart · _TripDetailDialog | Código asociado; contraste visual pendiente |
| 18 | Pedido Delivery | `project/DlgPedido.dc.html` | lib/admin_panel.dart · Delivery details | Código asociado; contraste visual pendiente |
| 19 | 23 · Express Market | `project/Market.dc.html` | lib/admin_marketplace.dart | Código asociado; contraste visual pendiente |
| 20 | 24 · Delivery Fase 2 / Express Plus | `project/Fase2.dc.html` | lib/admin_marketplace_phase2.dart | Código asociado; contraste visual pendiente |
| 21 | 25 · Prioridad conductores | `project/Prioridad.dc.html` | lib/admin_driver_priority.dart | Código asociado; contraste visual pendiente |
| 22 | Diálogos · Express Market | `project/DlgMarket.dc.html` | lib/admin_marketplace.dart · diálogos | Código asociado; contraste visual pendiente |
| 23 | Diálogos · Delivery Fase 2 | `project/DlgFase2.dc.html` | lib/admin_marketplace_phase2.dart · diálogos | Código asociado; contraste visual pendiente |
| 24 | Diálogo · Configurar prioridad | `project/DlgPrioridad.dc.html` | lib/admin_driver_priority.dart · diálogos | Código asociado; contraste visual pendiente |
| 25 | 9 · Pagos / Billetera | `project/Pagos.dc.html` | lib/admin_control_sections.dart | Código asociado; contraste visual pendiente |
| 26 | 8 · Tarifas | `project/Tarifas.dc.html` | lib/admin_control_sections.dart + lib/admin_distance_fares.dart | Código asociado; contraste visual pendiente |
| 27 | 22 · Suscripciones | `project/Suscripciones.dc.html` | lib/admin_driver_subscriptions.dart | Código asociado; contraste visual pendiente |
| 28 | Diálogos · Pagos | `project/DlgPagos.dc.html` | lib/admin_control_sections.dart · diálogos | Código asociado; contraste visual pendiente |
| 29 | Diálogos · Tarifas | `project/DlgTarifa.dc.html` | lib/admin_control_sections.dart · diálogos | Código asociado; contraste visual pendiente |
| 30 | Diálogos · Suscripciones | `project/DlgPlan.dc.html` | lib/admin_driver_subscriptions.dart · diálogos | Código asociado; contraste visual pendiente |
| 31 | 10 · Reportes | `project/Reportes.dc.html` | lib/admin_environment_reports.dart | Código asociado; contraste visual pendiente |
| 32 | 14 · Auditoría | `project/Auditoria.dc.html` | lib/admin_environment_audit.dart | Código asociado; contraste visual pendiente |
| 33 | 15 · Notificaciones / Avisos | `project/Avisos.dc.html` | lib/admin_control_sections.dart | Código asociado; contraste visual pendiente |
| 34 | 18 · Verificación de identidad · Revisión (= 27) | `project/Identidad.dc.html` | lib/admin_bolivia_kyc.dart (integrado en Conductores) | Unificado dentro de Conductores |
| 35 | 18 · Verificación de identidad · Requisitos | `project/Requisitos.dc.html` | lib/admin_driver_document_requirements.dart (integrado en Conductores) | Unificado dentro de Conductores |
| 36 | Diálogos · Identidad y requisitos | `project/DlgIdentidad.dc.html` | lib/admin_detail_dialogs.dart + lib/admin_bolivia_kyc.dart | Unificado dentro de Conductores |
| 37 | 16 · Servicios | `project/Servicios.dc.html` | lib/admin_preview_config_sections.dart + lib/admin_control_sections.dart | Código asociado; contraste visual pendiente |
| 38 | 7 · Zonas y cobertura | `project/Zonas.dc.html` | lib/admin_country_coverage.dart + lib/admin_panel.dart | Código asociado; contraste visual pendiente |
| 39 | 7 · Seguridad (= 17 Cobertura y seguridad) | `project/GeoSeguridad.dc.html` | lib/admin_zone_coverage_editor.dart | Código asociado; contraste visual pendiente |
| 40 | 11 · Configuración | `project/Configuracion.dc.html` | lib/admin_control_sections.dart | Código asociado; contraste visual pendiente |
| 41 | 19 · Configuración avanzada | `project/ConfigAvanzada.dc.html` | lib/admin_preview_config_sections.dart | Código asociado; contraste visual pendiente |
| 42 | 12 · Builds | `project/Builds.dc.html` | lib/admin_single_app_release.dart | Código asociado; contraste visual pendiente |
| 43 | 28 · Demanda y precios | `project/Demanda.dc.html` | lib/admin_dynamic_pricing.dart | Código asociado; contraste visual pendiente |
| 44 | Diálogo · Zona y cobertura | `project/DlgZona.dc.html` | lib/admin_zone_coverage_editor.dart | Código asociado; contraste visual pendiente |
| 45 | Diálogo · Servicio | `project/DlgConfig.dc.html` | lib/admin_control_sections.dart · diálogos | Código asociado; contraste visual pendiente |
| 46 | 11 · Configuración · resto de pestañas | `project/ConfiguracionTabs.dc.html` | lib/admin_control_sections.dart | Código asociado; contraste visual pendiente |
| 47 | Diálogos · Configuración avanzada | `project/DlgAvanzada.dc.html` | lib/admin_preview_config_sections.dart · diálogos | Código asociado; contraste visual pendiente |
| 48 | Zonas · Dashboard de aliados y liquidación | `project/ZonasAliados.dc.html` | lib/admin_country_coverage.dart | Código asociado; contraste visual pendiente |
| 49 | Diálogos · Países, sindicatos y accesos | `project/DlgAliados.dc.html` | lib/admin_country_coverage.dart · diálogos | Código asociado; contraste visual pendiente |
| 50 | 20 · Entornos de prueba | `project/Sandbox.dc.html` | lib/admin_audit_sandbox.dart | Código asociado; contraste visual pendiente |
| 51 | 21 · Carga QA | `project/CargaQA.dc.html` | lib/admin_load_lab.dart | Código asociado; contraste visual pendiente |
| 52 | Socios · Resumen | `project/SociosResumen.dc.html` | lib/partner_panel.dart · _PartnerOverview | Sistema visual actualizado; revisión QA pendiente |
| 53 | Socios · Conductores y solicitudes | `project/SociosConductores.dc.html` | lib/partner_panel.dart · _PartnerDrivers / _PartnerJoinRequests | Sistema visual actualizado; revisión QA pendiente |
| 54 | Socios · Pagos y avisos | `project/SociosAvisos.dc.html` | lib/partner_panel.dart · _PartnerPayments / _PartnerAnnouncements | Sistema visual actualizado; revisión QA pendiente |

## Criterios de aceptación antes de publicar

1. Revisión visual y funcional de los 54 artboards contra sus referencias, en 1280 px y en móvil; no marcar `Terminado` por estar mapeado.
2. Validación de acceso por rol y de módulo bloqueado en Preview; sin nuevas escrituras reales.
3. `flutter analyze`, compilación web Preview y pruebas de aislamiento verdes.
4. Confirmar `/preview/version.json` con commit esperado y `/version.json` de Producción intacto; verificar que el navegador realmente carga la nueva UI.
5. No fusionar ni publicar Producción durante QA del rediseño.
