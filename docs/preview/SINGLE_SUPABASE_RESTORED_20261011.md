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
