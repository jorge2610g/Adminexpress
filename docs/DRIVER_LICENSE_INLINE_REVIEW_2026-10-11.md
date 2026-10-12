# Ficha de conductor: visor interno y revisión de licencia por fotografía

**Estado actualizado 2026-10-11:** el propietario autorizó aplicar la migración de licencia al Supabase compartido. Se ejecutó correctamente mediante Supabase y quedó registrada como versión `20261012021954`, nombre `driver_license_individual_evidence_review`. La función `admin_driver_license_review_part` y el trigger `trg_driver_license_part_states` existen; `anon` no tiene ejecución. La licencia existente de Producción mantiene estado `verified`. **No hay licencias de Preview registradas para QA E2E; la UI aún no está fusionada ni desplegada.** Conservar las ramas PR en borrador y exigir validación Preview antes de publicar la interfaz. La migración compartida es aditiva, no equivale a aprobación del flujo ni a publicación web.


**Fecha:** 2026-10-11 · **Estado:** rama de revisión, aún NO publicada

## Problema
- «Ver frente», «Ver reverso» y «Ver» abrían una nueva pestaña/enlace mediante `launchUrl`.
- El carné mostraba cuatro filas con estados independientes, pero la licencia de conducir se renderizaba como una tarjeta compacta con aprobación documental global.

## Cambio
- Vista previa dentro del cuadro del conductor: `Dialog` con `InteractiveViewer`, imagen de Supabase Storage con URL firmada de 5 minutos, opción de cerrar y zoom. No se muestra el enlace firmado en otra pestaña.
- Licencia de conducir: tarjetas separadas **Frente** y **Reverso**, cada una con **Ver, Aprobar, Rechazar, Reabrir**. Verde=aprobado; rojo=rechazado; naranja=pendiente. No permite decidir sobre fotografías ausentes.
- RPC requerido: `admin_driver_license_review_part`; lo implementa la migración versionada de `Expressdelivery/supabase/migrations/20261012021954_driver_license_individual_evidence_review.sql`. La seguridad del RPC exige `is_admin()`, canal de la cuenta y versión de evidencia actual; preservar el estado de la cara opuesta y bloquear imágenes vacías.
- Documentos de licencia heredados con estado `verified` y fotos existentes muestran las dos caras aprobadas hasta que se cambie alguna imagen. El trigger resetea solo la cara cuya ruta cambia.
- Una sola web `admin.expressviajes.online`; entornos Preview y Producción dependen de la cuenta, **nunca** de dos builds.
- La lista histórica de `identity_verifications` se distingue de los estados de fotografías y muestra fecha de cada intento, evitando confundir «pendiente/pendiente/aprobado» con tres fotos distintas.

## Regla de promoción
1. Respaldo en `backup/before-license-photo-review-20261011`.
2. QA de código en rama `fix/license-photo-review-inline-20261011` y espejo `preview/license-photo-review-inline-20261011`.
3. Migración ya aplicada con autorización al Supabase compartido; falta validar con cuenta Preview y evidencia QA que `admin_environment_allowed` y los controles de aislamiento impiden acceder a datos de Producción.
4. Probar dos imágenes y 4 estados, concurrencia `p_expected_version`, rechazo con motivo, que no se reenvíe imagen aprobada y visor que no navegue fuera del panel.
5. Validar build web + pruebas unitarias. Solo después de aprobación/promoción fusionar ambos cambios y desplegar la web.
6. No modificar ni publicar Android. Supabase se modificó exclusivamente mediante la migración autorizada de licencia; si falla el QA de seguridad/permisos, **NO** fusionar la interfaz.

**Riesgo pendiente:** verificar con usuario Preview real que el cliente conductor reenvíe solamente la foto rechazada sin alterar la ruta de la foto aprobada. Esto no se certifica con Flutter unit tests solamente.
