# AdminExpress — control de ventana flotante de ofertas

> Estado: **IMPLEMENTADO Y DESPLEGADO · PRODUCCIÓN DESHABILITADA POR DEFECTO**
> Fecha de decisión: 2026-10-06
> Feature móvil objetivo: Preview **1.6.0+155**

## Objetivo

AdminExpress debe poder habilitar o deshabilitar globalmente la capacidad de que los conductores muestren ofertas de viaje sobre otras aplicaciones.

Nombre de switch recomendado:

**Permitir ventanas flotantes de ofertas**

Clave sugerida:
- `driver_floating_offer_enabled`

## Regla de control

El switch Admin solo habilita la **posibilidad** de usar la feature.

NO concede el permiso Android y NO puede obligar al conductor a utilizarla.

La ventana flotante solo funciona cuando:
- Admin = ON;
- conductor activó su ajuste local;
- Android concedió **Mostrar sobre otras aplicaciones**;
- conductor está online;
- existe oferta real vigente;
- app está en segundo plano.

## Entornos

Debe respetar el selector superior del panel:

- Prueba -> configuración Preview/shadow;
- Producción -> configuración real.

Nunca escribir Producción desde Prueba.

La misma UI Admin debe servir para ambos entornos.

## Comportamiento OFF

Si Admin lo pone OFF:
- Express deja de mostrar nuevas ventanas flotantes;
- overlays activos deben cerrarse de forma segura al recibir el cambio si técnicamente es viable;
- la app no debe borrar ni modificar el permiso Android del dispositivo;
- el usuario puede conservar su preferencia local para una futura reactivación, pero la feature efectiva queda deshabilitada.

## Comportamiento ON

Si Admin lo pone ON:
- la app puede ofrecer al conductor el ajuste **Ventana flotante de ofertas**;
- el conductor decide voluntariamente activarlo;
- si falta permiso Android, la app explica y abre la pantalla oficial del sistema;
- sin permiso no hay overlay.

## Alcance

Solo ofertas reales de viaje para conductor conectado.

No reutilizar este switch para:
- marketing;
- promociones;
- mensajes masivos;
- alarmas falsas;
- llamadas.

Las llamadas pasajero-conductor son una feature independiente.

## Dependencia con Expressdelivery

Contrato móvil completo:

`Expressdelivery/docs/FLOATING_DRIVER_OFFERS.md`

Cualquier implementación debe coordinar:
- AdminExpress;
- configuración/backend compartido;
- Expressdelivery Android;
- QA Preview/Producción.

## Estado

**IMPLEMENTADO.**

- UI: Configuración → Seguridad → **Permitir ventanas flotantes de ofertas**.
- Preview escribe solo el shadow `admin_environment_config`.
- Producción usa `admin_driver_floating_offer_update(boolean)`.
- Preview queda ON para validar Express +155.
- Producción queda OFF hasta habilitación explícita del propietario.
- Admin no puede conceder ni forzar `SYSTEM_ALERT_WINDOW`; ese permiso sigue siendo decisión del conductor en Android.
- Validación Preview/Producción y build web de AdminExpress quedaron en success el 2026-10-06.
