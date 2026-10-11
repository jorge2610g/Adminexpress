# Admin Express Preview — retorno a una sola base Supabase

**Decisión del propietario: 11 de octubre de 2026.**
El proyecto separado Express Preview fue eliminado por el propietario y no
debe volver a utilizarse ni recrearse. Los dos sitios apuntan exclusivamente
al proyecto de Supabase principal `zgpijrznvaskgcmauwxx`.

| Sitio | Ruta | Base Supabase | Canal SQL | Sesión de navegador |
| --- | --- | --- | --- | --- |
| Producción | `/` | principal | `production` | original |
| Preview | `/preview/` | principal | `preview` | exclusiva de QA |

## Invariantes obligatorias

1. `ADMIN_ENV=preview` no concede acceso de producción. La autorización
   depende de `admin_users.allow_preview` y de las RPC protegidas
   `admin_environment_allowed('preview')`.
2. El usuario administrativo de Preview ya estaba registrado y autorizado en
   Supabase principal. No duplicar usuarios, contraseñas ni cuentas.
3. Preview usa `admin_environment_config` para configuraciones simuladas.
   Las tarifas escalonadas de Preview NO deben escribir en
   `zone_distance_fare_steps` usadas por pasajeros reales.
4. Solo los módulos con operación QA acotada están habilitados. Los módulos
   sin aislamiento comprobado deben fallar cerrados; no reactivar
   `_previewUnlockAllModules` mientras exista una sola base compartida.
5. No ejecutar las migraciones anteriores diseñadas para el proyecto
   Supabase eliminado ni sus Edge Functions; son historial y NO pertenecen
   a la arquitectura actual. La única nueva migración explícita del backend
   compartido es `20261011_shared_db_subscriptions_qa_candidates.sql`,
   verificada y aplicada únicamente para añadir una consulta de conductores
   QA de solo lectura (sin modificar registros ni pagos operativos).
6. GitHub Pages puede publicar únicamente `/preview/` usando el artefacto
   probado de Producción y su manifest SHA. Está prohibido mutar `main`,
   redesplegar la raíz, cambiar flags de producción o copiar credenciales.
7. Publicación no certifica todavía que las operaciones de extremo a extremo
   estén aisladas. Probar con datos de QA y nunca con pasajeros/pagos reales.

## Verificación de publicación
Consultar `/version.json` y `/preview/version.json`: **ambos deben tener el
mismo `supabase_project_ref`**, los canales deben diferir y el SHA de
Producción debe conservarse. Verificar autenticación con la cuenta QA que
ya existía en el proyecto principal.

## Validación automatizada

El código con una sola base y los dos modos `ADMIN_ENV` ha superado las
comprobaciones en GitHub Actions `38107126690` y `38107129351`, incluyendo
compilaciones web de Producción y Preview, resguardo de los módulos no
verificados y tarifas simuladas.

Este commit solicita publicar exclusivamente la nueva versión `/preview/`.

## Primer desbloqueo por auditoría · 2026-10-11

El módulo «Prioridad conductores» se habilita en Preview después de verificar
las dos RPC implicadas: la lectura `admin_driver_priority_state_scoped`
restringe los conductores por grupo QA y zona; la escritura
`admin_update_driver_priority_settings_v2` requiere autorización por canal
y persiste Preview en `admin_environment_config`, sin editar los parámetros
reales de prioridad. El cliente impide conmutar las opciones de Producción
cuando está en Preview. Los demás módulos no auditados permanecen bloqueados
hasta que su backend esté aislado por canal. CI compartida:
https://github.com/jorge2610g/Adminexpress/actions/runs/38107841701.

## Módulo desbloqueado: Suscripciones QA

- UI Preview sección 22: permite crear y modificar planes y ajustes de
  suscripción que se guardan exclusivamente en `admin_environment_config`.
- Nueva RPC de lectura `admin_preview_driver_subscription_candidates`: autoriza
  usuarios `allow_preview=true`, revisa ámbito de zona y devuelve únicamente
  conductores aprobados en `audit_test_group_members` (servidor, no filtro
  en navegador). `anon` no tiene privilegio de ejecución.
- Las asignaciones de plan Preview escriben solo en el almacén QA.
- La edición de métodos reales de cobro permanece DESACTIVADA en Preview.
  Cualquier verificación de VeriPagos en Preview se presenta como simulada;
  no se realizan llamadas ni se afirma conexión real.
- La función SQL nueva **se agregó** a la base única de Express, sin
  alteración de datos, política RLS ni funciones existentes.
- El flujo completo de cobros (pagos reales, renovación automática) no está
  habilitado en Preview; permanece pendiente de un simulador de pagos.
- Flutter CI: https://github.com/jorge2610g/Adminexpress/actions/runs/38108870181,
  PASS en ambas variantes de compilación.

## Diagnóstico de sesión desactualizada · 11/oct 2026

Una captura mostró la advertencia de «módulo bloqueado» en Suscripciones
incluso después de publicar la implementación. Se verificó que el código de
rama ya contiene el índice 22 en la lista segura de Preview, y que el
workflow Pages de la versión publicada terminó con éxito. La pestaña Flutter
permanece abierta entre despliegues, así que puede ejecutar JavaScript antiguo
hasta recargar la página; el botón de refresco de datos NO reinicia el código.

Para evitar diagnósticos confusos, la nueva compilación Preview inyecta su
SHA real en `web/index.html` y muestra `EXPRESS QA · <8 caracteres>` en el
pie de la página. Al volver a enfocar una pestaña desactualizada, consultará
su `/preview/version.json` con política no-cache y ofrecerá «Recargar» sin
interrumpir automáticamente formularios abiertos. El despliegue verificará
el marcador, el HTML de la versión correcta y que el JavaScript publicado
contenga la RPC QA `admin_preview_driver_subscription_candidates`.

Una pestaña que ya estaba abierta antes de esta actualización debe recargarse
manualmente una vez: Chrome en macOS `⌘ Shift R` o ventana privada. Esto
solo modifica el sitio /preview; la raíz de Producción conserva los mismos
bytes y la misma base Supabase compartida.

Pruebas CI de regresión del código: run 38110490545, success.

## INCIDENTE CONFIRMADO · Preview fue sobrescrito por despliegue obsoleto (04:02 UTC)

El diagnóstico anterior de caché resultó **incompleto**. Verificación del
workflow `main` despachado manualmente el 11/oct a las 03:59 UTC (run
`38110153058`): publicó **Preview SHA
`d9538e66f337c36c3ba4893ba6e52967592356bc`**, una versión anterior a
nuestro release de las 03:39 UTC. Su `_previewScopedModules` **no contiene
22 (Suscripciones) ni 25 (Prioridad conductores)**. El flujo manual de
`main` volvió a sobrescribir `/preview/` y provocó exactamente el bloqueo
de la captura del usuario. Producción no se modificó en ese despacho porque
`build` fue omitido y solo se publicó el artefacto combinado de Preview.

También el intento QA `38110676142` fue cancelado cuando otro workflow
de `main` (`38110724671`) tomó el mismo grupo de concurrencia
`adminexpress-pages`. Este segundo manual falló antes de publicar.

**Acción de corrección:** volver a publicar el commit QA actual desde rama
`chatgpt/admin-preview-independent-20261010`, sin cambios a `main`, y
verificar no solo `version.json` sino el SHA incrustado en `index.html`
y la presencia efectiva de `admin_preview_driver_subscription_candidates`
en el `main.dart.js` servido. No iniciar manualmente otro deploy desde main
con SHAs antiguos. Mantener ambas ramas como sitios del mismo Supabase,
con canales de datos separados.
