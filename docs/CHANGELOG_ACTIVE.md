## 2026-10-14 · Ficha de conductor sin controles duplicados; Envíos Producción
- Corregida doble inclusión de **Servicios autorizados al conductor** y **Envíos permitidos por vehículo**. Cada sección se ve una sola vez; los permisos guardados no se modifican.
- La ficha permite leer y guardar grants Moto/Auto/Carga en el entorno que corresponda, sin fijar Preview. El RPC sigue siendo de administrador, con verificación del entorno y capacidad real del vehículo; depende de la migración coordinada en Expressdelivery.
- La casilla única «Servicios para pasajeros» sincroniza `driver_visible` de `parcel` y `delivery` con el estado de Envíos para esa zona. No crea autorización personal ni concede servicio a conductores no aprobados.
- Regresiones `test/admin_single_driver_permissions_test.dart` y `test/admin_zone_passenger_services_test.dart`. Respaldo `backup/before-driver-parcel-grants-editor-20261014`.

## 2026-10-14 · Un solo flujo para servicios de pasajeros por zona
- En Zonas de operación, el editor ofrece un único grupo de selección: Viajes, Envíos y Market. Se retiraron los selectores redundantes de modo de aterrizaje, servicio predeterminado y orden numérico. El orden queda fijo (Viajes, Envíos, Market) y el modo de inicio se guarda como `auto`.
- Al guardar, la misma operación sincroniza la visibilidad de pasajeros con el catálogo zonal por canal. Para Envíos actualiza tanto la clave del motor `parcel` como la clave `delivery` usada por la portada. Mantiene sin cambio autorizaciones de conductor, tarifas, reglas de ofertas, programación y métodos de pago. Una categoría de Taxi oculta permanece oculta; si ninguna está visible, usa una categoría disponible apropiada a CL/BO.
- Market requiere comercios activos y visibles en ese entorno y conserva el filtro zonal, aun con el módulo global habilitado. Se quitaron sus interruptores globales duplicados del editor de contenido Market.
- 0 servicios: no guardar. 1: entrada directa al único servicio. 2–3: portada. Cambios aislados en Preview mediante `admin_environment_config` y en Producción mediante RPC protegido.
- **No se cambiaron los flags comerciales de Producción ni se activaron Envíos/Market durante este desarrollo.** Respaldo `backup/before-unified-zone-services-20261014`. Regresión: `test/admin_zone_passenger_services_test.dart`.

## 2026-10-13 · Conductor document and service approvals
- Repaired missing widget in existing driver edit dialog: "Servicios autorizados al conductor" now visibly renders inside the conductor sheet instead of being an unreachable private helper.
- Driver work services ride/parcel/market keep individual pending/approved/rejected states and channel-scoped RPCs. No auto-approval.
- The shared Supabase country-from-zone normalization fixes identity document save, allowing the admin detail RPC to show saved evidence to authorized reviewers after the driver submits.
- QA required: open individual Preview and Production drivers, confirm independent service approvals, verify manual identity photos and per-photo review states; no cross-environment reads.
- Publication pending build and validation.

## 2026-10-13 · Publicación de panel central con Delivery unificado

- PR #86 fusionado en el único Adminexpress: comercios, pedidos, logística, liquidaciones y selección de servicios por zona.
- Deploy explícito en el dominio canónico `https://admin.expressviajes.online/`, **sin crear Admin Preview** y sin generar APK.
- Acceso Preview/Producción separado por identidad en Supabase; no activar Delivery para cuentas reales durante QA.
- La selección de uno a tres servicios requiere que la función de visibilidad del backend y la Web de Express queden actualizadas, verificadas en el PR #199.

## 2026-10-12 · Campeonato Express web

- Nueva página de conductor desde Mi perfil con Inicio, Top 10 y Premios; ranking real de viajes completados por zona/servicio y período.
- Administración de campañas, fechas, duración, premio 1/2/3, estado y reglas en Adminexpress.
- RPCs seguros, entorno fijo por cuenta y tabla con RLS; sin pagos automáticos ni cambios en Android.
- Respaldo: `backup/before-express-driver-championship-20261012`.
- Guía: `docs/CAMPEONATO_EXPRESS_20261012.md`.

## 2026-10-12 · Aumentos rápidos del conductor por ciudad y servicio

- Tres botones de contraoferta configurables en Adminexpress → Tarifas por zona, con regla general de ciudad y sobreescritura por servicio.
- Predeterminados CLP: +250/+500/+750; BOB: +1/+2/+3. La misma consulta del conductor incorpora incrementos de cada solicitud mediante RPC v4; no hay sondeo adicional.
- Mantiene importes persistidos, redondeo por solicitud, límites BOB, aislamiento Preview/Producción y permiso superadmin.
- Backup: `backup/before-driver-quick-offers-by-zone-service-20261012`.
- QA y liberación: `docs/DRIVER_QUICK_OFFER_STEPS_2026-10-12.md`.

## 2026-10-12 · Redondeo real de tarifas por moneda (rama en QA)

- Nueva política por moneda y canal (centavos / 0,50 / entero), sin modificar tarifas históricas.
- Cotizaciones y persistencia autoritativas para solicitudes, ofertas, viajes y entregas; ingresos brutos usan los valores almacenados.
- Selector en Adminexpress → Tarifas por zona; Preview y Producción usan la misma web, con configuración aislada.
- Respaldo: `backup/before-currency-rounding-20261012`. Rama: `feat/currency-fare-rounding-20261012`.
- **Pendiente:** migración Supabase, CI, QA funcional en cuentas Preview y deploy real. No afirmar publicado hasta verificaciones.
- Guía: `docs/CURRENCY_FARE_ROUNDING_2026-10-12.md`.

## 2026-10-11 — Migración de licencia aplicada; panel aún en QA

**Estado actualizado 2026-10-11:** el propietario autorizó aplicar la migración de licencia al Supabase compartido. Se ejecutó correctamente mediante Supabase y quedó registrada como versión `20261012021954`, nombre `driver_license_individual_evidence_review`. La función `admin_driver_license_review_part` y el trigger `trg_driver_license_part_states` existen; `anon` no tiene ejecución. La licencia existente de Producción mantiene estado `verified`. **No hay licencias de Preview registradas para QA E2E; la UI aún no está fusionada ni desplegada.** Conservar las ramas PR en borrador y exigir validación Preview antes de publicar la interfaz. La migración compartida es aditiva, no equivale a aprobación del flujo ni a publicación web.

---

## 2026-10-11 — QA pendiente: visor interno y licencia por fotografía

- Se sustituyó la apertura de URL externas por un visor modal dentro de la ficha del conductor, con zoom y URL privada firmada temporalmente.
- La licencia ahora presenta tarjetas de **Frente** y **Reverso** con aprobar/rechazar/reabrir independientes y estados verde, rojo y naranja; documentos heredados conservan el estado original.
- Requiere el RPC nuevo y trigger versionado en `Expressdelivery` (migración `20261012021954_driver_license_individual_evidence_review.sql`); no desplegar UI antes del backend. Sin mutación de Supabase en esta rama.
- Código único Preview/Producción en panel central; QA del entorno/rol y CI por ejecutar; no fusionado ni publicado.
- Respaldo `backup/before-license-photo-review-20261011`, rama `fix/license-photo-review-inline-20261011`.
- Especificación: `docs/DRIVER_LICENSE_INLINE_REVIEW_2026-10-11.md`.

---

## 2026-10-11 — Publicación web de revisión individual de documentos

- Se publica la ficha del conductor con aprobación/rechazo individual de frente, reverso, fotografía facial y foto de perfil.
- Esta publicación mantiene un único Adminexpress central y separa Preview/Producción por la cuenta autenticada.
- Backend compartido: migración de corrección individual ya aplicada antes de la publicación.

---

## 2026-10-11 — Revisión individual de evidencias del conductor

- La ficha del conductor deja de tratar el carné manual como un único bloque.
- Frente, reverso, fotografía facial y foto de perfil se aprueban/rechazan por separado.
- Rechazar una evidencia exige motivo y conserva todas las demás evidencias aprobadas.
- La ficha usa `admin_driver_kyc_bolivia_manual_review_part` para la revisión individual.
- Licencia y otros documentos adicionales continúan revisándose como documentos independientes.
- El mismo panel y la misma lógica se usan para Preview/Producción; cambia solamente el canal de datos de la cuenta.

---

# CHANGELOG ACTIVO

> **Regla de lectura:** la entrada más reciente define la arquitectura vigente. Entradas anteriores se conservan como historial de decisiones y no deben usarse para restaurar comportamientos retirados.

## 2026-10-11 — Operación en vivo interactiva

- Los conductores ahora pueden aparecer en el mapa usando su última ubicación conocida.
- Estados visuales: disponible, en línea sin señal, en viaje y desconectado.
- Clic en marcador de conductor abre ficha flotante con datos operativos y última actualización de ubicación.
- Los viajes activos de la pestaña lateral son seleccionables.
- Seleccionar un viaje limpia la vista general y muestra únicamente A, B, conductor, pasajero y el recorrido de ese viaje.
- El recorrido usa OSRM con fallback A→B; no bloquea el mapa si el proveedor no responde.
- Deselect / **Mostrar todo** / cambio a Conductores restaura la vista general.
- Backend: `admin_driver_list_v3` se amplía de forma aditiva con latitud, longitud, heading y `location_updated_at`.
- La migración se aplicó al Supabase compartido y conserva el aislamiento por canal/zona.
- Paridad: `feat/live-ops-interactions-20261011` y `preview/live-ops-interactions-20261011` usan el mismo código.
- Pendiente siguiente etapa: desde Dashboard > Actividad reciente, acción **Ver viaje** debe navegar al viaje seleccionado.
- Documento: `docs/LIVE_OPERATIONS_INTERACTION_2026-10-11.md`.

---

## 2026-10-11 — Regla obligatoria de paridad Preview / Producción

- Todo cambio no visual de flujo, backend, permisos, RPC, SQL, configuración o comportamiento debe quedar funcionando también en Preview antes de merge.
- El código sigue siendo único y compartido; Preview y Producción no vuelven a tener implementaciones separadas.
- Para cambios funcionales/backend se crea una rama temporal `preview/<slug>` para validar el mismo código con datos Preview.
- Si QA detecta fallos, la corrección se hace en la rama principal del cambio y la rama Preview se sincroniza al mismo commit.
- No se permite “Producción ahora y Preview después” salvo excepción explícita del propietario.
- Los cambios visuales puros quedan exentos si no alteran flujo, consultas, permisos, estados ni acciones.
- Se añadió checklist de PR en `.github/PULL_REQUEST_TEMPLATE.md`.
- Regla completa: `docs/PREVIEW_PRODUCTION_PARITY_RULE.md`.

---

## 2026-10-11 — Adminexpress central por usuario, rol, zona y permisos

- Se retiró la arquitectura de dos páginas administrativas separadas.
- URL canónica única: `https://admin.expressviajes.online/`.
- `/preview/` queda como redirección de compatibilidad; ya no contiene otro bundle Flutter.
- Preview/Producción se determina por la cuenta autenticada mediante `admin_current_runtime_environment()` y `admin_access_context()`.
- `admin_users.allowed_modules` permite limitar módulos por usuario.
- `admin_users.zone_id` y el rol permiten operadores por ciudad/zona dentro del mismo panel.
- `admin_set_panel_access_v2` asigna entorno, rol, zona y módulos.
- Se retiró `ADMIN_ENV` como frontera web, `_previewScopedModules`, el selector manual de entorno y el mecanismo `PREVIEW_AUTHORIZED`.
- La verificación de identidad/documentos se consolida en la ficha del conductor; no debe volver a existir navegación lateral duplicada.
- `Deploy Adminexpress Central` construye un solo bundle raíz.
- Claude/Cloud, ChatGPT, Codex y otras IAs autorizadas pueden programar y editar todo el repositorio dentro de sus permisos técnicos; ver `docs/AI_AGENT_POLICY.md`.
- Se versionaron las migraciones `20261011210000_admin_runtime_environment_by_identity.sql` y `20261011211000_single_admin_access_scope.sql`.
- Respaldo previo: `backup/main-before-single-admin-by-user-20261011`.

---

## 2026-10-10 — Google OAuth de Preview retornaba a la web de pasajeros

- Vídeo de QA: seleccionar Google en `/preview/` termina en `https://expressviajes.online/` en vez del panel. No se confirmó ingreso administrativo; no retirar permisos del administrador anterior.
- Se fijó el `redirectTo` a la URL exacta `https://admin.expressviajes.online/preview/` en el cliente Preview, con guard CI. El código anterior usaba `Uri.base`.
- Queda **pendiente** validar/agregar esa URL exacta en Supabase principal **Authentication > URL Configuration > Redirect URLs**; el conector disponible no administra esa configuración. No tocar la Site URL global ni borrar retornos de la app de pasajeros.
- No cambiar claves, permisos, identidad ni desplegar Producción.
- Procedimiento en `docs/ADMIN_PREVIEW_GOOGLE_OAUTH_CALLBACK_2026-10-10.md`.

---

## 2026-10-09 — Sesiones independientes y acceso administrativo por canal

- Se detectó que las dos rutas del panel `/` (Producción) y
  `/preview/` compartían la sesión del mismo Supabase almacenada por
  origen en el navegador. Esto podía intercambiar sesiones al cambiar
  de panel o cerrar sesión.
- Solo **Preview** utiliza una nueva clave de sesión local; **Producción**
  conserva el almacenamiento original de Supabase para no desconectar
  administradores activos.
- El login por correo/contraseña, OAuth y la validación de sesiones
  restauradas consultan en servidor `admin_environment_allowed` para
  el canal fijo compilado. Las credenciales administrativas no permitidas
  para ese canal se rechazan antes de abrir la interfaz.
- No se rotó clave publishable/service-role ni se cambió Auth o
  `admin_users`. El usuario principal sigue con los permisos actuales
  hasta que exista una segunda identidad QA verificada; bloquearlo
  antes dejaría a Preview sin administrador.
- Procedimiento para invitar cuenta administrativa QA-only y recién
  entonces quitar permiso Preview al administrador principal:
  `docs/ADMIN_AUTH_SESSION_SEPARATION_2026-10-09.md`.
- **Todavía no hay aislamiento completo:** RPC legacy sin canal pueden
  autorizar operaciones en Producción a un usuario QA-only si solo
  hacen `is_admin()`; issue Expressdelivery #141.

---

## 2026-10-09 — Tarifa por distancia exclusivamente QA en Preview

La pantalla `AdminDistanceFaresEditor` tenía una vía de escritura compartida:
`admin_distance_fare_steps_replace` con `p_channel=preview` aún borraba/insertaba registros reales de `zone_distance_fare_steps`, pese a mostrar un canal QA. Se corrigió sin alterar el flujo de Producción:

- **Preview** lee/escribe solamente `admin_environment_config` mediante `AdminEnvironmentStore.previewGet/previewUpsert`, módulo `zone_distance_fare_steps`, clave determinística `zone_id::service_key`.
- **Producción** conserva exactamente sus RPC históricas `admin_distance_fare_steps_get` y `admin_distance_fare_steps_replace`.
- En Preview sin registros QA, se muestra la lista vacía (no se importan ni reutilizan precios reales); al guardar, sólo se registra la simulación.
- Los mensajes de confirmación distinguen Preview de Producción. CI verifica ambas rutas y analiza la pantalla.
- **No se hizo migración de datos**, ni se modificaron precios de viajes reales. Es una mejora de seguridad de UI; debe complementarse con denegación SQL de `p_channel=preview` y vigilancia de funciones heredadas sin canal.

---

## 2026-10-09 — Descartar canales administrativos inválidos de forma segura

- `AdminEnvironmentStore` conserva la misma interfaz pública (constructor `const`, getters `isPreview/isProduction`). Para valores válidos `preview` y `production`, el comportamiento no cambia.
- Si se introduce un canal inválido, ambos getters lanzan `StateError` también en compilaciones de lanzamiento. Antes `isProduction => !isPreview` interpretaba cualquier error tipográfico como Producción. Ahora se bloquea.
- Pruebas Flutter y CI verifican este comportamiento. No se cambian RPC, tablas, firmware, pagos ni artefactos Android. El guard en el cliente no sustituye autorización backend.
- Modo de despliegue: preservar el sitio raíz byte a byte mediante `[deploy-preview-only]`; ver `docs/QA_PREVIEW_PRODUCTION_ACCEPTANCE_2026-10-09.md`.

---

## 2026-10-09 — Corrección segura de publicación exclusiva de Preview (rama PR #51)

- La prueba desde una rama de trabajo generó un artefacto válido y conservó bytes de Producción, pero GitHub Pages bloqueó el job final por su entorno protegido. Se conserva la protección de GitHub Pages; **no** se abre a todas las ramas.
- La vía existente de actualización Preview desde `main` se activa exclusivamente con el mensaje de merge `[deploy-preview-only]`. El build y el despliegue de Producción quedan omitidos; la compilación de QA usa ese mismo SHA de merge.
- El workflow utiliza el último artefacto Prod probado contra el sitio real, run `37969274447` (SHA `30e60582a337be3911671742d780b240793497df`), y verifica la identidad **byte por byte** antes de preparar Preview. Si cambia Producción o falla algún hash, se aborta.
- Tras la publicación, comprueba `version.json` de ambos sitios: Preview debe mostrar el SHA publicado y Producción el SHA estable anterior. No modifica Supabase, APK, AAB, Google Play ni el sistema de pagos.
- Guía de aceptación y reversión: `docs/QA_PREVIEW_PRODUCTION_ACCEPTANCE_2026-10-09.md`.
- **Aún NO equivale a certificar aislamiento de todas las RPC administrativas** ni permite promociones de datos de prueba a Producción.

---

## 2026-10-09 — Prueba Preview-only de Pages, sin publicación

- Se ensayó `Deploy Adminexpress Web to GitHub Pages` en rama QA, run `37990890621`, fuente exacta `a8a12585181d484d4767c03cb4aaed64c314a50e`.
- El job `build` de Producción quedó **SKIPPED**. El job `preview_only` pasó: validó SHA QA, descargó artefacto de Producción, comparó bytes de la URL real con la copia, compiló Preview y confirmó el manifiesto SHA256 de todos los archivos no Preview.
- El job final `deploy` terminó en **FAILURE antes de ejecutar pasos**. No existe evidencia de publicación de la nueva Preview: considerar la URL en su estado anterior. No interpretar el artefacto compilado como versión publicada.
- El artefacto `github-pages` QA de ese run está guardado en Actions (ID `11644663644`), pero **no** se autorizó publicarlo por otra vía.
- Se restauró exactamente `.github/workflows/deploy-web.yml` desde `main` al terminar el ensayo; no quedó el trigger de push QA ni la alteración temporal de deploy en la PR.
- Supabase principal se consultó solo con `SELECT` después del ensayo: 0 países QA, 2 zonas QA shadow, 5 cuentas Preview, 6 Producción; el servidor todavía tiene un superadministrador de doble permiso.
- Ninguna migración / Edge Function / tabla / pago / Google Play se ha modificado en este ensayo. La separación backend total sigue pendiente; P0 documentado en Expressdelivery issue #141.

---

## 2026-10-09 — Preparación explícita de países QA (Preview solamente)

El panel de países dispone de **Preparar países QA** exclusivamente cuando `ADMIN_ENV=preview`. Bajo confirmación, consulta únicamente datos públicos básicos de referencia (nombre, ISO país, moneda y prefijo) y los guarda en el almacenamiento `admin_environment_config` con módulo `service_countries`. Los nuevos registros QA quedan con `active=false` y `driver_registration_enabled=false` por defecto; **nunca llama al RPC de escritura real `admin_upsert_country_coverage_v2`**. Respeta QA existente y omite países repetidos. No se ha pulsado el botón, sembrado datos, ni desplegado la rama. CI valida las guardias.

---

## 2026-10-09 — Registro automático de cambios de cada PR administrativa (QA, sin despliegue)

- CI nuevo `.github/workflows/release-change-inventory.yml`: corre en **toda PR hacia main** y verifica SHA de base, cabeza, commit de prueba y árbol Git; adjunta inventario de archivos con hashes SHA-256 y riesgo.
- Script y pruebas en `.github/scripts/release_change_manifest.py` y `.github/scripts/test_release_change_manifest.py`.
- Esta revisión ayuda a saber exactamente qué código cambiaría; NO comprueba por sí sola la seguridad de permisos Supabase, equivalencia de datos ni ausencia de bugs.
- Los cambios permanecen en PR #51 como borrador. No se fusionó ni se desplegó Producción.

---

## 2026-10-09 — Corrección QA de configuración por canal (EN PR, no desplegado)

- Rama: `fix/preview-shared-config-isolation-20261009` desde main `30e60582a337be3911671742d780b240793497df`.
- Los editores Zonas, Seguridad geográfica, Servicios, Tarifas y Ajustes ya no fuerzan el entorno Production al abrirse desde Preview.
- La edición de métodos de pago por zona respeta `channel`; la cobertura QA recupera/guarda sus puntos poligonales en shadow.
- Adicionalmente, `AdminCountryCoveragePage` y `AdminDriverDocumentRequirementsPanel` dejan de forzar Production al listar, guardar o eliminar; Preview utiliza `AdminEnvironmentStore(widget.channel)` y su shadow QA. La comprobación CI ahora bloquea explícitamente esta regresión.
- El CI del panel valida que esos editores no vuelvan a usar configuración Production fija.
- **Sin cambios en main, Supabase, Android, firmas ni publicaciones.** Validación Flutter/QA pendiente antes de merge.
- **Bloqueador de seguridad:** la RPC backend `admin_zone_coverage_save` sigue pudiendo modificar configuración real incluso con `p_channel=preview`. Debe impedirse desde backend antes de activar pruebas completas.
- Documento: `docs/admin-preview-production.md`.

---

## 2026-10-09 — Admin Preview usa Supabase principal con datos QA aislados
- `/` y `/preview/` se conservan como dos páginas distintas.
- Ambas comparten Supabase `zgpijrznvaskgcmauwxx`; `ADMIN_ENV` fija canales `production` y `preview`.
- Se elimina del cliente web la referencia al proyecto Supabase secundario; el proyecto no se borra.
- Restaurado `admin_environment_config` para configuración Preview; consultas/acciones QA solo en `p_channel='preview'`.
- En Preview se bloquean preventivamente módulos que usan RPCs sin aislamiento por canal (pagos, marketplace, Builds, etc.).
- La primera publicación debe ser solo de `/preview/` con hash/bytes invariables en raíz Producción.

---

## Arquitectura vigente — 2026-10-09: dos bases y dos paneles web
- **Producción:** sitio raíz, proyecto Supabase `zgpijrznvaskgcmauwxx`.
- **Preview:** sitio `/preview/`, proyecto Supabase `xbphilqezmwfjfpdbwad`.
- Mismo código y navegación, pero compilaciones Flutter independientes; se suprimió el selector Prueba/Producción dentro de cada sitio.
- Cada proyecto físico mantiene su canal RPC: `preview` en Supabase Preview y `production` en Supabase Producción; el selector interno se eliminó.
- Login, sesión, permisos RLS, documentos, Storage y revisiones son independientes por proyecto. El panel Preview exige una cuenta de administrador autorizada **en Preview**, sin heredar permisos de Producción.
- Preview no habilita la promoción/publicación de Android; `productionAccess` se desactiva para Builds allí.
- Los registros antiguos de QA en Producción NO se migran ni borran automáticamente. No se han cambiado registros reales.
- Las instrucciones históricas sobre `admin_environment_config` describen el **modelo antiguo**, que no se utiliza en los dos despliegues nuevos.
- **Antes de publicar:** validar `flutter analyze`, ambos `flutter build web`, acceso Admin en cada proyecto y rechazo/corrección de selfie exclusivamente en Preview.

---

## 2026-10-08 — Builds, Auditoría y Reportes no tienen modo de entorno

- Eliminado el selector Prueba/Producción y el filtro obligatorio país/zona
  **solo** para los módulos globales Builds (12), Auditoría (14) y Reportes (10).
- Reportes muestra dos grupos visibles simultáneamente: resultados reales
  y métricas QA, sin combinar los datos en un único total engañoso.
- Auditoría reúne las acciones autorizadas en una sola cronología con
  origen REAL/QA por registro, manteniendo la comprobación de permisos RPC.
- Builds mantiene el control de publicación únicamente para quienes poseen
  `allow_production`; ya no depende del selector global para habilitarlo.
- Los demás módulos conservan el aislamiento hard de Preview/Producción,
  y los requisitos de zona que protegen operaciones de clientes.
- Respaldo de código: `backup/admin-global-modules-before-20261008`.
- Los workflows del panel verifican explícitamente la regresión y ejecutan
  `flutter analyze` y `flutter build web --release` antes del despliegue.

---

## 2026-10-07 — Documentos conductor separados por entorno

- `AdminDriverDocumentRequirementsPanel` ahora respeta `channel`.
- Producción lee/escribe `driver_document_requirements` reales.
- Prueba lee/escribe `admin_environment_config.driver_document_requirements` y ya no toca Producción.
- Edición, creación y borrado Preview usan `AdminEnvironmentStore`.
- CI ahora también valida PRs hacia `main` y exige que este módulo mantenga persistencia separada por entorno.
- Política vigente: BO = Carné activo / Licencia inactiva; CL = Cédula + Licencia activas.

---

## 2026-10-07 — Runtime Scope Admin · separación dura Prueba / Producción

- Adminexpress mantiene **una sola UI**, pero ahora el selector superior crea un workspace de datos independiente por entorno;
- al cambiar Prueba ↔ Producción se destruye el subárbol Stateful del entorno anterior y se descartan futures/cachés visuales para impedir datos residuales;
- entrar a Producción requiere confirmación explícita y el backend informa si la cuenta Admin tiene acceso a Preview/Producción;
- `admin_users` incorpora permisos separados `allow_preview` / `allow_production`; los monitores de zona permanecen fijados a Producción;
- país/zona en Prueba se cargan desde `admin_environment_config.service_zones`, no desde la configuración real de Producción;
- fichas de usuarios/conductores/viajes y acciones sensibles usan RPC v2 con `p_channel` y el backend bloquea un registro cuyo runtime pertenece al otro entorno;
- Entornos de prueba no carga ni muestra grupos QA cuando el selector está en Producción;
- App Builder filtra historial/acciones según entorno activo: Preview en Prueba y candidatos/releases reales en Producción;
- Supabase autoritativo: `admin_environment_allowed`, `admin_assert_environment`, `admin_assert_target_environment` y wrappers scoped;
- auditoría v2 resuelve el entorno de acciones legacy por cuenta objetivo para no mezclar eventos Preview en la vista de Producción.

---

## 2026-10-06 — Ventana flotante de ofertas — implementada

- Configuración → Seguridad incorpora **Permitir ventanas flotantes de ofertas**;
- la misma UI respeta el selector Preview/Producción;
- Preview persiste en `admin_environment_config` y queda ON para validar Express +155;
- Producción persiste mediante RPC administrativa y queda OFF por defecto;
- Admin jamás concede el permiso Android del conductor;
- validación de separación Preview/Producción, `flutter analyze` y build web: SUCCESS;
- despliegue AdminExpress: SUCCESS.

---

## 2026-10-06 — Ventana flotante de ofertas — requisito

- documentado switch Admin **Permitir ventanas flotantes de ofertas**;
- debe respetar selector Prueba/Producción y persistencia separada;
- Admin solo habilita la capacidad: no concede el permiso Android;
- el conductor mantiene decisión local y voluntaria por dispositivo;
- clave sugerida: `driver_floating_offer_enabled`;
- alcance exclusivo: ofertas reales para conductor conectado;
- documento: `docs/FLOATING_DRIVER_OFFERS_ADMIN.md`;
- estado: **IMPLEMENTADO**; Preview ON para QA de +155 y Producción OFF por defecto.

- se documenta futuro switch global **Permitir ventanas flotantes de ofertas**;
- debe respetar selector Prueba/Producción y el aislamiento de configuración;
- Admin solo habilita/disponibiliza la función: nunca concede ni fuerza el permiso Android de superposición;
- el conductor conserva un switch individual y consentimiento explícito en Android;
- con Admin OFF no se muestran overlays aunque el permiso del teléfono siga concedido;
- implementación móvil y permiso nativo se realizan en Expressdelivery;
- estado: implementado en AdminExpress; Producción móvil continúa deshabilitada.

---

# Adminexpress — Changelog activo

---

## 2026-10-05 — Países, cobertura y expansión administrable

- agregado **Países y cobertura** dentro del módulo Zonas;
- el administrador puede crear países por código ISO (CL, BO, BR, AR, etc.), moneda y estado activo/inactivo;
- cada país controla por separado registro de conductores y Didit;
- Didit puede activarse/desactivarse por país y aceptar Workflow IDs sin exponerlos en la UI una vez guardados;
- las ciudades ya no usan un país escrito libremente: deben pertenecer a un país maestro;
- cada zona tiene switch propio para habilitar/deshabilitar registro de conductores;
- un país inactivo bloquea todas sus zonas en la app aunque las ciudades sigan configuradas;
- Prueba conserva la misma UI y persiste solo en el almacenamiento shadow, sin escribir Producción.

---

## 2026-10-05 — Panel dedicado Didit

- agregado **Didit · Centro de identidad** dentro del grupo Seguridad;
- usa una sola UI y respeta el selector global Prueba/Producción;
- Prueba consulta únicamente `provider_environment=sandbox`;
- Producción consulta únicamente `provider_environment=production`;
- muestra sesiones, estados, país, workflow, documento, Face Match, liveness, scores, advertencias y tiempos;
- detalle separado **Enviado a Didit / Recibido de Didit**;
- el panel no muestra API Keys, Signing Secrets, tokens temporales ni imágenes biométricas;
- lectura protegida por la política RLS administrativa existente de `identity_verifications`.

---

## 2026-10-04 — Handoff IA, SMS y laboratorio QA Auto/Moto

- agregado `AGENTS.md` y `docs/AI_HANDOFF_2026-10-04.md` para continuidad con otra IA;
- Configuración > Seguridad incorpora switches independientes de verificación SMS para Pasajeros y Conductores, OFF por defecto;
- se mantiene una sola UI para Preview/Producción y se documenta el release gate exact SHA;
- laboratorio QA corrige `channel` Preview/Producción y moneda CLP/BOB por ciudad;
- laboratorio QA agrega selector `Mixto · Auto + Moto`, `Solo Auto` y `Solo Moto`;
- limpieza QA queda aislada por entorno;
- mensajes de error del laboratorio dejan de mostrar `[object Object]`;
- se corrigió una duplicación de `_friendlyError` que bloqueaba el build web;
- validación Preview/Producción y deploy web quedaron en SUCCESS;
- Producción Android vigente documentada como Express 1.5.87+131, SHA `45c2aff26cd27229e445461d2f129023bf6f60df`.

---

## 2026-10-03 — Multizona, filtros operativos y telemetría

- Zonas admite varios métodos de pago por ciudad, con método principal compatible con la app publicada;
- cada método puede habilitarse por separado para Viajes, Delivery, Suscripciones y Billetera;
- se agregó Región / departamento a la configuración geográfica de zonas;
- Pagos / Billetera administra métodos dinámicos por zona y filtra movimientos por Hoy, Semana, Mes o rango de fechas;
- Viajes y Delivery consultan Hoy por defecto y filtran desde backend por período;
- Usuarios puede consultarse por zona, ciudad y región/departamento sin cargar todo el historial;
- Suscripciones muestra y configura los métodos habilitados por zona y filtra pagos por período;
- Notificaciones / Avisos estima alcance antes del envío y muestra telemetría de campañas;
- Aliados y sindicatos incorpora dashboard financiero, comisiones y liquidaciones;
- Configuración avanzada deja explícito que sus interruptores de pagos son compatibilidad global para builds antiguos;
- el backend conserva los campos legados de pago para no romper la app móvil actualmente publicada.

---

## 2026-09-30 — Referencia Express Dual

- Expressdelivery adopta la referencia visual Express Dual;
- Cliente + Conductor + Delivery permanecen dentro de una sola app;
- Adminexpress continúa separado y solo web;
- ningún cambio visual de Express vuelve a introducir Admin dentro del APK;
- los APK/AAB siguen compilándose únicamente bajo solicitud desde App Builder.

---

## 2026-09-30 — Build Android solo bajo solicitud

- los pushes normales de Expressdelivery ya no generan APK/AAB;
- el build 60 automático fue cancelado;
- Android se compila únicamente cuando el administrador lo solicita desde App Builder;
- el scheduler de GitHub Actions solo procesa trabajos Android que estén en cola.

---

## 2026-09-30 — Separación definitiva y App Builder Android

- Adminexpress queda como único frontend administrativo;
- el código Admin se retiró de `Expressdelivery`;
- App Builder conectado a `build_jobs`;
- compilación Android ejecutada en GitHub Actions;
- APK + AAB generados automáticamente;
- GitHub Releases usado para distribución permanente de binarios;
- firma Android de producción persistente;
- JKS almacenado de forma privada;
- passwords de firma cifrados en Supabase Vault;
- worker protegido mediante GitHub OIDC;
- descarga de APK/AAB disponible desde el historial de builds;
- publicación de actualización separada de compilación;
- la app móvil puede consultar releases publicados mediante `latest_app_release`.

### Primer build firmado confirmado

- Express v1.5.19 · build 59;
- APK generado correctamente;
- AAB generado correctamente;
- `signing_mode=production`;
- instalación APK validada en dispositivo Android.

### Siguiente release

- Express v1.5.20 · build 60;
- incluye limpieza del repositorio Express y corrección reforzada de cancelación.
