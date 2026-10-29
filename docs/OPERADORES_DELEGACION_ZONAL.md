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

## Acceso por acción en cada módulo

Al seleccionar un módulo, el administrador puede asignar por separado `view`, `edit` y `delete`. Editar o borrar requiere también ver. Los permisos se guardan en `admin_users.module_permissions` y se consultan desde `admin_access_context`; el menú filtra por `view` y los RPC de escritura validan `edit` o `delete` en el servidor.

Las cuentas antiguas con `module_permissions IS NULL` conservan sus permisos existentes hasta que un administrador guarde una matriz explícita. Las altas nuevas usan lectura por defecto. Ningún permiso de acción sustituye la preparación del módulo, el rol, el entorno Producción o la zona del servidor.

## Estado de implementación

El catálogo de la propuesta tiene 21 claves asignables. En el Supabase consultado, 11 módulos figuran con `runtime_ready=true` y 10 con `runtime_ready=false`. La matriz `view/edit/delete` está preparada en el PR #137, pero su migración aún no está aplicada: la columna `admin_users.module_permissions` y el guard por acción todavía no existen en la base compartida. Por tanto, la selección por acción aún no está disponible en el panel publicado.

La casilla `Borrar` solo guarda la intención y el guard puede validarla; no existen operaciones de borrado zonal implementadas en esta entrega. No se deben presentar esas casillas como borrados funcionales. El PR sigue en borrador hasta completar validación en Preview con la misma versión de código y comprobar las acciones de cada módulo.

## Orden de implementación

- **Fase A — Finanzas locales:** consulta de pagos, planes/montos de suscripción por zona y tarifas editables restringidas a `zone_service`.
- **Fase B — Clientes y promociones:** restaurantes, productos, descuentos, campañas e historial push con zona obligatoria.
- **Fase C — Operaciones locales:** despacho manual, pedidos, servicios, zonas, seguridad y ajustes que todavía invocan funciones exclusivas del superadministrador.
- **Fase D — Análisis:** reportes, liquidaciones zonales y optimización de operaciones según la autorización concedida.

Cada módulo pasa a `runtime_ready=true` únicamente después de revisar sus RPC, probar autorización real con dos zonas y aprobar CI. No se ejecutan migraciones o despliegues de interfaz por solo marcar una casilla.
