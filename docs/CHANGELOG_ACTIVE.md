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
