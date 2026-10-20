# Administración delegada por zona — EXPRESS

## Propósito

Un superadministrador decide qué permisos concede a cada operador. Cada operador trabaja **solo sobre su zona asignada** en el entorno Producción. La base de datos sigue siendo única: nunca se crean proyectos separados para delegar ciudades.

## Reglas obligatorias

1. **Denegar por defecto.** Todo módulo puede quedar configurado como permiso, pero únicamente se abre cuando su implementación server-side tiene autorización zonal validada. Las casillas no sustituyen esa autorización.
2. **Zona del servidor.** La zona efectiva proviene de `admin_users.zone_id`, no de un identificador enviado por la aplicación. Toda lectura y escritura comprueba pertenencia. El operador no puede cambiar su zona.
3. **Protección por módulo.** Confirmar sesión activa, rol, `allowed_modules`, ambiente Producción, módulo preparado, zona de cada fila y autoría en cambios. Las acciones y consultas por ID se protegen igual que los listados.
4. **Precios locales.** Cada zona mantiene tarifas, multiplicadores, descuentos, promociones y planes de suscripción propios. No se permite a operadores editar reglas con `zone_id IS NULL`, alcance `global`, catálogos maestros ni parámetros de otras zonas.
5. **Pagos.** Operadores consultan solo movimientos y suscripciones atribuibles a su zona. Las claves de pasarelas, pagos globales, desembolsos irreversibles y credenciales financieras permanecen bajo control central hasta existir controles especializados.
6. **Push.** Nunca se aceptan campañas zonales con `zone_id NULL` ni con zona diferente. Tanto el cálculo de audiencia como el envío y el historial deben filtrar la zona efectiva. La opción de audiencia «Todos» significa «Todos en mi zona», nunca toda la plataforma.
7. **Creación y desactivación.** El superadministrador puede marcar cualquier subconjunto y desactivar el acceso. No se conceden todos los módulos automáticamente. Revocar un módulo corta su acceso inmediatamente, sin depender del menú.
8. **Auditoría y recuperación.** Cambios locales registran administrador, recurso, zona y fecha. Cada módulo nuevo exige pruebas de zona propia, zona ajena, ID ajeno, otro módulo, usuario sin sesión y compatibilidad con el superadministrador.

## Estado de implementación

La migración `20261020171000_operator_module_capabilities.sql` introduce un catálogo con 21 claves asignables y solo 7 con autorización zonal previamente comprobada. Los otros 14 comienzan en `runtime_ready=false`. Esta migración por sí sola **no completa** la delegación operativa ni debe fusionarse sin actualizar el alta de operadores, pruebas y las rutas frontend.

## Orden de implementación

- **Fase A — Finanzas locales:** consulta de pagos, planes/montos de suscripción por zona y tarifas editables restringidas a `zone_service`.
- **Fase B — Clientes y promociones:** restaurantes, productos, descuentos, campañas e historial push con zona obligatoria.
- **Fase C — Operaciones locales:** despacho manual, pedidos, servicios, zonas, seguridad y ajustes que todavía invocan funciones exclusivas del superadministrador.
- **Fase D — Análisis:** reportes, liquidaciones zonales y optimización de operaciones según la autorización concedida.

Cada módulo pasa a `runtime_ready=true` únicamente después de revisar sus RPC, probar autorización real con dos zonas y aprobar CI. No se ejecutan migraciones o despliegues de interfaz por solo marcar una casilla.
