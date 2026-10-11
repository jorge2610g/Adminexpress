# Adminexpress — control de ventana flotante de ofertas

> Estado: implementado. Producción deshabilitada por defecto.

## Objetivo

Permitir al administrador habilitar o deshabilitar la posibilidad de mostrar ofertas de viaje sobre otras aplicaciones.

Clave:

`driver_floating_offer_enabled`

## Regla de control

El switch Admin solo habilita la posibilidad.

No concede el permiso Android `SYSTEM_ALERT_WINDOW` y no obliga al conductor a usarlo.

La función requiere:

- configuración Admin ON;
- preferencia local del conductor;
- permiso Android;
- conductor online;
- oferta vigente;
- app en segundo plano.

## Entorno

Adminexpress tiene una sola web.

La cuenta autenticada define Preview o Producción. No existe selector superior de entorno.

- cuenta Preview -> configuración QA/shadow;
- cuenta Producción -> configuración real.

Nunca permitir escritura cruzada de Preview hacia Producción.

## OFF

Al apagar:

- no mostrar nuevas ventanas;
- cerrar overlays activos cuando sea viable;
- no borrar permisos Android;
- conservar preferencia local si corresponde.

## ON

Al encender:

- la app puede ofrecer el ajuste;
- el conductor decide;
- si falta permiso, abrir la pantalla oficial del sistema.

## Alcance

Solo ofertas reales de viaje.

No reutilizar para marketing, promociones, alarmas falsas o llamadas.

Contrato móvil: `Expressdelivery/docs/FLOATING_DRIVER_OFFERS.md`.
