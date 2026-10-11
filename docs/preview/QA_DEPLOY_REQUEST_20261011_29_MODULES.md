# Activación controlada de Admin Express Preview — 11 de octubre de 2026

El propietario ha autorizado continuar con la publicación de **Preview** después de que los dos jobs de validación de la rama concluyeran satisfactoriamente.

## Publicación autorizada

- URL de destino: https://admin.expressviajes.online/preview/
- Publicar únicamente la web compilada con `ADMIN_ENV=preview`.
- Conservar byte por byte los ficheros originales de Producción; abortar si no coinciden con el artefacto aprobado y la URL pública.
- Reutilizar la única base Supabase, las zonas, tarifas, pasarelas, suscripciones y configuraciones.
- Mostrar las 29 secciones en la interfaz Preview.
- Mantener separación bidireccional de identidades Conductor Prueba / Pasajero Prueba y sus solicitudes, viajes, ofertas y notificaciones.
- Mantener el veto de publicación de releases reales desde Preview.

## Advertencia de alcance

El desbloqueo completo de menús no certifica operaciones financieras E2E. Hay rutas de cobros, suscripciones y marketplace que permanecen simuladas o requieren guardas por titular en backend. No se deben sustituir por escrituras no verificadas sobre registros de clientes reales.

## Verificación del workflow

El job `preview_only` descarga el último artefacto aprobado, compara ficheros públicos de Producción y solo reemplaza `/preview/`. La verificación final contrasta la versión visible con el SHA del commit y comprueba que el marcador de Producción no cambió.

El mensaje de este commit lleva la etiqueta explícita de despliegue de Preview, sin fusionar PR #66 ni modificar `main`.
