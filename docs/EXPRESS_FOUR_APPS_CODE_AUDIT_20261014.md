# Adminexpress — inventario y responsabilidades después de separar Restaurante/Repartidor (2026-10-14)

**Estado:** mapa documental de código real, sin modificación funcional. Inspeccionado árbol de Adminexpress `main` (102 entradas), archivos principales de Delivery/comercios/conductores y repositorios de Express.

## Arquitectura — cuatro aplicaciones, mismo backend

| Aplicación | Funciones | Lo que NO le corresponde |
| --- | --- | --- |
| `Expressdelivery` (Principal) | Cliente: Taxi, Envíos, Delivery/restaurantes. Conductor: Taxi, Envíos. | Nuevos repartos de pedidos comerciales en modo conductor; panel global. |
| `Express_Restaurante` | Operación del negocio: pedidos, productos, catálogo, horarios, promociones, liquidaciones y perfil. **Por construir** con diseño aprobado. | Administrar otras empresas o autorizar roles de conductor globales. |
| `Express_Repartidor` | Solo ofertas/entregas de pedidos comerciales; mapa, estados, ganancias, notificaciones. **Por construir**. | Taxi; envíos particulares `parcel`; permisos de superadmin. |
| `Adminexpress` (este repo) | Administración global de las tres anteriores y backend compartido; zonas, comercios, usuarios, conductores, repartidores, cupones, Plus, pagos, demos y releases. | Pantallas del cliente y panel operativo del dueño del comercio dentro del APK principal. |

Supabase único: `zgpijrznvaskgcmauwxx`. La autorización está en RLS/RPC y la cuenta; Preview/Producción por identidad y datos, no por URL ni frontend duplicado. Las migraciones SQL viven en Expressdelivery; **nunca** desplegar esquema duplicado para Restaurante/Repartidor.

## Código en este repositorio

- `lib/admin_panel.dart`: shell, navegación y accesos de Admin. Mantener un único panel.
- `lib/admin_delivery_unified.dart`: gestión Delivery, logística, comerciante, servicios.
- `lib/admin_marketplace.dart`: comerciantes, configuración, catálogo del administrador.
- `lib/admin_marketplace_phase2.dart`: promoción, cupones y Express Plus (revisar permisos y contratos del checkout antes de habilitar).
- `lib/admin_marketplace_demos.dart`: alta/consulta de restaurantes de prueba por zona y entorno. No convertir demo en comercio real ni exponer Producción Preview por cambiar UI.
- `lib/admin_delivery_settlements.dart`: liquidaciones del negocio/reparto; conservar transacciones e historial.
- `lib/admin_driver_quick_offers.dart`, `lib/admin_driver_document_requirements.dart`, `lib/admin_detail_dialogs.dart`: controles de conductor y autorizaciones.
- `lib/admin_single_app_release.dart`: trabajos/certificación Android oficial, Build Center; no generar APK adicional por separación comercial.
- `lib/partner_panel.dart`: capacidad heredada de panel de socios; **auditar rutas/permisos reales antes de eliminar o mover**.
- `lib/admin_environment_store.dart`, `lib/admin_runtime_scope.dart`: separación de canales y acceso; no omitir checks cuando nuevas apps se registren.

## Funciones que ya fueron consolidadas

- No recrear Admin en `Expressdelivery`: ya se retiró allí.
- No recrear web `/preview/` con diferentes funcionalidades: único `https://admin.expressviajes.online/`.
- Los servicios para pasajeros por zona usan editor unificado Viajes/Envíos/Delivery: ver `docs/ZONE_PASSENGER_SERVICES_UNIFIED_20261014.md`.
- Se unificó la sección «Servicios autorizados» del conductor, con permisos por categoría/vehículo; no duplicarla.
- La PR #235 de Principal excluye nuevas ofertas comerciales de su conductor, pero Admin sigue pudiendo operar y auditar pedidos/comercios históricos.

## Lo que se debe extraer versus conservar

- El **portal del negocio de clientes** vive hoy en el código heredado `Expressdelivery/lib/restaurant_portal_web.dart` y `marketplace_merchant_*.dart`; será migrado a `Express_Restaurante`. **El panel administrativo global aquí no se traslada** a esa app.
- La **recepción de entregas de comercios** irá a `Express_Repartidor`. Admin debe mantener configuración/aprobación de repartidor, zonificación, vehículo, canal, auditoría y control del despacho sin mezclar `parcel` y pedidos `marketplace_order_id`.
- Las tablas/RPC `marketplace_*` son nombres técnicos históricos usados por varias aplicaciones. Cambiar el nombre visible «Mercados» a «Restaurantes» / «Delivery» no autoriza renombrar SQL o borrar migraciones.
- No eliminar la lógica de liquidaciones ni pedidos activos hasta que nuevas apps consuman y terminen esos procesos y se verifique el historial.

## Dependencias pendientes de implementar y validar (no marcar como hechas)

**P0: Garantizar pedidos comerciales con repartidor real.**
Aislar tokens de notificación por app, crear registro de dispositivo vinculado a identidad/rol, validar RPC de despacho, ofertas y aceptación comercial; no permitir que la Principal reciba nuevas ofertas comerciales ni que los clientes generen pedidos sin receptor. Pruebas Preview→Producción con ciudades/monedas, sin QA real en cuentas de clientes.

**P1: App Restaurante.**
Implementar el mockup aprobado (web + Android, marca Express) con inicio, pedidos nuevos/activos, detalle, aceptar/preparar/listo/entregado, catálogo/productos/extras, horarios/promos, liquidaciones e historial. Reutilizar contratos merchant autorizados; propietario de negocio **no equivale** a `super_admin`.

**P1: Interfaz cliente y demos.**
PR `Expressdelivery#234` aún abierta al corte para cupones, Plus, etiquetas y retirar «Panel del Comercio» del perfil. Depende de migración y QA; contrastar Admin/API y no afirmar desplegada. Demos se filtran por canal y visibilidad independiente; no confundir «pendiente de publicar» con «oculto a clientes».

**P2: Calidad y operativa.**
Notificaciones con CLP para Iquique/BOB Trinidad, estados/pedidos, autorización de vehículo (Auto cubre Moto cuando aplica), no duplicar módulos, UI responsiva de Operaciones en Vivo, navegación fluida, vigilancia ligera de errores y reducción de llamadas Supabase sin cachear saldos/seguridad.

## Prohibiciones y criterio de entrega

1. No reactivar delivery/reparto global de Producción solo por compilar apps nuevas.
2. No conceder permisos vía UI sin RLS, RPC y entorno autorizados.
3. No borrar tablas ni modificar esquema productivo destructivamente; primero inventario de consumidores de cliente, conductor, comercio, repartidor, Admin y APK anteriores.
4. No fusionar PR parcialmente implementadas solo porque el mockup sea interactivo.
5. Cambios funcionales deben tener QA Flutter, SQL/RLS, push, mapa, estados, pago, historial, rollback y pruebas reales por canal/ciudad.
6. No falsificar pedidos, transacciones, órdenes o balances de demo.
7. Documentar qué se retiró, reemplazo, migración, SHA, entorno, riesgos y aprobación.

## Referencia maestra

`jorge2610g/Expressdelivery/docs/EXPRESS_CODE_AUDIT_AND_FOUR_APP_PLAN_20261014.md`
(alojada en rama documental mientras se revisa), además de `docs/START_HERE_ADMINEXPRESS.md`, `docs/admin-central-access.md`, `docs/CHANGELOG_ACTIVE.md`.
