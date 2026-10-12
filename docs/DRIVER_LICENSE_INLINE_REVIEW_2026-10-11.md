# Ficha de conductor: visor interno y revisión de licencia por fotografía

**Estado actualizado 2026-10-11 (publicación de interfaz autorizada):** el propietario confirmó expresamente que Adminexpress debe seguir siendo **una sola web** y solicitó integrar el cambio en `main` y probarlo con cuentas Preview antes de operar con datos reales. Migración compartida de licencia `20261012021954` ya aplicada y verificada, con RPC `admin_driver_license_review_part` y trigger `trg_driver_license_part_states`; `anon` sin permiso de ejecución. La licencia existente de Producción mantiene su estado `verified`. Backend Expressdelivery PR #170 fusionado (`bf3d648f985be9f76235fb592057946762fc2df2`) y UI Adminexpress PR #75 fusionada (`3be0a1ee4868a7b08b0d4d4fda4fa2d4a4807592`). El commit de UI activa el workflow `Deploy Adminexpress Central` con `[deploy-admin-central]`. **La disponibilidad efectiva en la URL pública debe comprobarse por version.json/CI antes de declarar el despliegue completado.** No existen aún licencias Preview aptas para QA completo.


**Fecha:** 2026-10-11 · **Estado:** código fusionado en `main`; despliegue web solicitado automáticamente, verificación de publicación y QA E2E pendientes

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

## Excepción autorizada y control de QA
1. Respaldo en `backup/before-license-photo-review-20261011`.
2. Código validado en ramas `fix/license-photo-review-inline-20261011` y `preview/license-photo-review-inline-20261011`, que apuntaron al mismo commit; pruebas unitarias y compilación CI en verde antes de merge.
3. Migración ya aplicada con autorización al Supabase compartido; falta validar con cuenta Preview y evidencia QA que `admin_environment_allowed` y los controles de aislamiento impiden acceder a datos de Producción.
4. Probar dos imágenes y 4 estados, concurrencia `p_expected_version`, rechazo con motivo, que no se reenvíe imagen aprobada y visor que no navegue fuera del panel.
5. **Excepción expresa del propietario:** fusionar y publicar la misma interfaz compartida antes del QA E2E, para realizar QA con cuentas Preview. No se crea otra web ni otro bundle; el ámbito operativo sigue ligado a la cuenta autenticada. La interfaz pasa a estar disponible también para cuentas de Producción una vez se publique.
6. No modificar ni publicar Android. Si falla el QA de seguridad, permisos o aislamiento, detener uso real y preparar corrección/rollback de la interfaz web compartida. No operar sobre datos de Producción para las pruebas de Preview.

**Riesgo pendiente:** validar con administrador Preview y conductor/pasajero de Preview las dos fotografías, aprobación y rechazo individual, cambio de versión al subir foto corregida, notificaciones y aislamiento por entorno/rol/zona. La foto ya aprobada no debe cambiar; esto no queda certificado con Flutter unit tests. Este release no incluye APK/AAB de Android.
