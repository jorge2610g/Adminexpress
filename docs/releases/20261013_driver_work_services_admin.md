# Publicación Admin Express — servicios independientes del conductor

- Conductor: Taxi, Paquetería y Delivery de comercios se autorizan por separado desde su ficha.
- Misma página web central para cuentas Preview y Producción.
- Producción conserva Delivery desactivado; las autorizaciones solo habilitan trabajos donde el servicio de la zona esté operativo.
- La migración segura de permisos ya fue aplicada y revisada en Supabase.
- Requiere validación de versión publicada en admin.expressviajes.online.

- Permisos por tipo de Envíos: en la ficha del conductor, cada vehículo activo tiene casillas independientes para Moto, Auto y Carga. Se guarda por RPC de administración en Preview y ningún permiso nace activado automáticamente.
- La capacidad limita asignaciones incompatibles: moto no puede autorizar Auto/Carga; un auto no puede autorizar Carga. No se cambia el flujo de Taxi ni se activan módulos en Producción.
- Aprobación global del trabajo de Envíos y permiso específico del vehículo son requisitos acumulativos.
