# Operación en vivo — interacción de mapa

**Fecha:** 2026-10-11  
**Estado:** implementado y validado antes de merge  
**Paridad:** mismo código Preview / Producción

## Objetivo

Hacer que Operación en vivo permita supervisar visualmente conductores y viajes sin salir del mapa.

## Conductores

El mapa muestra la última ubicación conocida de cada conductor cuando existe:

- verde: disponible;
- azul: en línea sin señal / ubicación con más de 2 minutos;
- naranja: en viaje;
- rojo: desconectado.

Al pasar el mouse se muestra nombre + estado. Al hacer clic se abre una ficha flotante con:

- nombre;
- estado;
- teléfono y correo;
- vehículo;
- calificación;
- viajes completados;
- hora de la última ubicación.

El backend continúa usando el mismo RPC por canal/zona. La migración
`20261011223500_live_operations_driver_location.sql` solo añade al JSON existente:

- `latitude`;
- `longitude`;
- `heading_degrees`;
- `location_updated_at`.

## Viaje seleccionado

En la pestaña **Viajes**, cada viaje activo es seleccionable.

Mientras existe una selección:

- desaparecen del mapa los otros viajes, delivery, SOS y conductores ajenos;
- se muestra **A** (origen);
- se muestra **B** (destino);
- se muestra conductor;
- se muestra pasajero;
- se dibuja el recorrido estimado A → B;
- el mapa se centra en los puntos del viaje.

El recorrido se consulta a OSRM. Si OSRM no responde, el panel mantiene un
fallback directo entre A y B para no bloquear la supervisión.

Al tocar **Mostrar todo**, tocar nuevamente el mismo viaje o cambiar a
**Conductores**, vuelve la vista general.

## Preview / Producción

No existen dos implementaciones. La misma UI consume `admin_dashboard_state_v2`
según el entorno de la cuenta autenticada.

Rama de QA sincronizada:

`preview/live-ops-interactions-20261011`

## Pendiente del siguiente bloque

Dashboard / Actividad reciente:

- hacer clic en un viaje reciente;
- ofrecer **Ver viaje**;
- navegar directamente al viaje correspondiente.

Ese punto quedó anotado pero no pertenece a este cambio.
