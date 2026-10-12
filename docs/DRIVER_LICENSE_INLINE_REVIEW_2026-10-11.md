# Ficha de conductor: visor interno y revisión de licencia por fotografía

**Fecha:** 2026-10-11 · **Estado:** rama de revisión, aún NO publicada

## Problema
- «Ver frente», «Ver reverso» y «Ver» abrían una nueva pestaña/enlace mediante `launchUrl`.
- El carné mostraba cuatro filas con estados independientes, pero la licencia de conducir se renderizaba como una tarjeta compacta con aprobación documental global.

## Cambio
- Vista previa dentro del cuadro del conductor: `Dialog` con `InteractiveViewer`, imagen de Supabase Storage con URL firmada de 5 minutos, opción de cerrar y zoom. No se muestra el enlace firmado en otra pestaña.
- Licencia de conducir: tarjetas separadas **Frente** y **Reverso**, cada una con **Ver, Aprobar, Rechazar, Reabrir**. Verde=aprobado; rojo=rechazado; naranja=pendiente. No permite decidir sobre fotografías ausentes.
- RPC requerido: `admin_driver_license_review_part`; lo implementa la migración versionada de `Expressdelivery/supabase/migrations/20261012015500_driver_license_individual_evidence_review.sql`. La seguridad del RPC exige `is_admin()`, canal de la cuenta y versión de evidencia actual; preservar el estado de la cara opuesta y bloquear imágenes vacías.
- Documentos de licencia heredados con estado `verified` y fotos existentes muestran las dos caras aprobadas hasta que se cambie alguna imagen. El trigger resetea solo la cara cuya ruta cambia.
- Una sola web `admin.expressviajes.online`; entornos Preview y Producción dependen de la cuenta, **nunca** de dos builds.

## Regla de promoción
1. Respaldo en `backup/before-license-photo-review-20261011`.
2. QA de código en rama `fix/license-photo-review-inline-20261011` y espejo `preview/license-photo-review-inline-20261011`.
3. Primero aplicar y validar la migración con cuenta Preview y evidencia QA, confirmando que `admin_environment_allowed` y aislamiento impiden acceder a Producción desde QA.
4. Probar dos imágenes y 4 estados, concurrencia `p_expected_version`, rechazo con motivo, que no se reenvíe imagen aprobada y visor que no navegue fuera del panel.
5. Validar build web + pruebas unitarias. Solo después de aprobación/promoción fusionar ambos cambios y desplegar la web.
6. No modificar ni publicar Android, ni cambiar Supabase real fuera del release autorizado. Si el backend no está listo, **NO** fusionar la UI que llama al RPC.

**Riesgo pendiente:** verificar con usuario Preview real que el cliente conductor reenvíe solamente la foto rechazada sin alterar la ruta de la foto aprobada. Esto no se certifica con Flutter unit tests solamente.
