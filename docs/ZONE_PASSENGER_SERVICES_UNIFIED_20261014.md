# Configuración única de servicios por zona · 2026-10-14

## Contrato
La única sección de la zona **Servicios para pasajeros** selecciona Viajes, Envíos y Express Market. No hay selector de "siempre/directo/auto", servicio predeterminado ni orden manual. Al guardar, el sistema fuerza `passenger_landing_mode=auto`, persiste las tarjetas seleccionadas y sincroniza las banderas reales de Viajes/Envíos sin editar las tarifas.

- 0 servicios: el formulario impide guardar.
- 1 servicio: se abre directamente **ese** módulo, no Taxi como respaldo.
- 2 o 3: se abre la portada solo con los módulos autorizados.
- Cambios de Preview se escriben en `admin_environment_config` (zona y `zone_services`). Producción utiliza los RPC administrativos existentes.
- Viajes respeta el estado de las categorías Moto, Express, Comfort y XL; al volver a activar Viajes tras ocultarlas todas usa una sola categoría inicial según país.
- Envíos sincroniza las claves `parcel` (motor de solicitudes real) y `delivery` (compatibilidad de portada), sin conceder permisos nuevos a conductores.
- Express Market requiere una tienda activa visible en ese canal. Al seleccionarlo en una zona lista puede habilitarse la bandera comercial de ese canal, pero **nunca** se activa en otro canal. El orden guardado por zona controla sus tarjetas.
- Las tarifas, permisos de trabajo del conductor, pagos y suscripciones siguen sus contratos y no se cambian por estos controles.

## Protección de producción
La migración versionada del repositorio Expressdelivery normaliza las antiguas zonas que traían `[ride, delivery, market]` por defecto a los servicios realmente disponibles y cambia el predeterminado de zonas nuevas a `[ride]`. Así, habilitar Market globalmente en una zona no descubre por accidente Market en otras zonas de Producción. La migración conserva la sombra de Preview.

## QA
1. Usar una cuenta Preview en Iquique y marcar solo Viajes, guardar y abrir Express Web: va directamente a Taxi.
2. Marcar solo Envíos y comprobar que la portada se omite y la pantalla de paquete permite ingresar detalles.
3. Marcar Viajes + Envíos: la portada muestra dos tarjetas. Agregar Market **solo si hay comercios activos visibles** y comprobar las tres.
4. Desmarcar Viajes: la lista de categorías de conductor y sus autorizaciones no deben cambiar.
5. Confirmar que Producción no hereda los cambios de Preview y que los controles de servicios están unificados.
6. Repetir tests de Flutter Adminexpress, Expressdelivery y build web en los dos repositorios.

Respaldos: `backup/before-unified-zone-services-20261014` en ambos repositorios.
