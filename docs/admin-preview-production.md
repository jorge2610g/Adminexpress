## Corrección en rama de QA · 2026-10-09 (sin desplegar)

Se detectó una discrepancia: cinco editores de configuración obtenían
`AdminEnvironmentStore('production')` aunque la web estuviera compilada
con `ADMIN_ENV=preview`. En esa situación el formulario QA podía invocar
RPC operativas y modificar zonas, cobertura, tarifas o ajustes reales.

La rama `fix/preview-shared-config-isolation-20261009` cambia los cinco
editores a `AdminEnvironmentStore(widget.channel)`; la edición de métodos
de pago por zona recibe el canal del llamador. El formulario de cobertura
lee y persiste su polígono Preview en el shadow QA, sin consultar la cobertura
real para editar. **Producción conserva exactamente la misma ruta lógica**.

**Esta rama NO equivale a aislamiento completo ni debe fusionarse sin QA:**
- La auditoría adicional detectó el mismo error en el catálogo de países y requisitos documentales de conductor. La rama QA también corrige su lectura/escritura por canal, sin tocar la base real.
- la app móvil consume aún algunas configuraciones operativas principales;
  la cobertura Preview guardada en shadow puede no aplicarse al cálculo de rutas;
- la RPC `admin_zone_coverage_save` acepta `p_channel='preview'` y escribe
  `service_zones` reales en el backend principal. Se debe corregir con una
  migración compatible y pruebas antes de habilitar acceso Preview libre;
- hay que revisar todas las llamadas desde las páginas de países, seguridad,
  servicios y otros editores secundarios, además de RLS, Storage y webhooks;
- la publicación inicial debe ser solo del sitio Preview y los bytes del
  sitio Producción deben permanecer sin cambios.

No editar ni desplegar migraciones, credenciales, pagos o bases de datos en
Producción hasta que los tests de aislamiento y el QA físico estén aprobados.

---

## Arquitectura vigente — 2026-10-09: dos sitios web y Supabase compartido, nunca datos mezclados
- Producción: raíz `/`, proyecto `zgpijrznvaskgcmauwxx`, canal `production`.
- Prueba: ruta `/preview/`, **mismo proyecto** `zgpijrznvaskgcmauwxx`, canal `preview`.
- La antigua base separada `xbphilqezmwfjfpdbwad` no recibe solicitudes de los dos paneles; permanece intacta hasta decisión expresa del titular.
- Ambas páginas comparten la infraestructura de autenticación y almacenamiento, pero los administradores únicamente pueden operar canales permitidos. Las RPCs operativas verifican `allow_preview`/`allow_production` y entorno del registro destino; los usuarios QA requieren marca de entorno.
- Ajustes, zonas, servicios y tarifas QA se almacenan en `admin_environment_config` con `p_environment='preview'`. La tabla `service_zones` de producción NO se modifica desde Prueba.
- El cambio de página no cambia la conexión ni eleva permisos, solo usa un binario web compilado con `ADMIN_ENV` diferente.
- Preview bloquea módulos con RPCs no aisladas por canal. Válidos: Dashboard, Operación en vivo, Viajes, Delivery, Conductores, Usuarios, Seguridad/SOS, Zonas, Tarifas, Reportes, Configuración, Auditoría, Servicios, Verificación de identidad y Verificación manual. Bloqueados: Builds, finanzas, marketplace, suscripciones y otros no auditados.
- La separación es responsabilidad del backend y del guard de UI. Si un módulo se añade a la lista segura, debe auditarse todo su árbol y cada RPC, incluidas las escrituras y Storage.
- Desplegar inicialmente solo Preview, preservar bytes de Producción y comprobar lectura/edición QA con un administrador autorizado.

---

# Adminexpress — regla Preview / Producción

## Regla obligatoria

Adminexpress tiene **una sola interfaz administrativa**.

Preview y Producción deben usar:
- la misma navegación;
- las mismas páginas;
- los mismos botones, formularios, pestañas y funciones;
- el mismo código de presentación.

El selector de entorno **solo puede cambiar la capa de datos**.

## Separación de datos

- `production`: usa las tablas, RPC y servicios operativos reales.
- `preview`: usa datos QA/Preview y `admin_environment_config` para la configuración aislada.
- Una escritura realizada en Preview nunca debe modificar configuración, pagos, zonas, tarifas, credenciales o registros de Producción.
- Los usuarios QA pueden vivir en almacenamiento compartido únicamente cuando están marcados explícitamente como QA/Preview y todas las consultas los filtran por entorno.

## Nueva funcionalidad

Toda función nueva del panel debe implementarse una sola vez y recibir el entorno como parámetro.

Correcto:

```dart
AdminSettingsPage(channel: adminChannel)
```

Incorrecto:

```dart
adminChannel == 'preview'
    ? PreviewSettingsPage()
    : ProductionSettingsPage()
```

No se deben crear árboles de navegación separados ni versiones simplificadas de una pantalla para Preview.

## Excepción de herramientas QA

Las herramientas de QA pueden estar visibles en el árbol común, pero sus acciones deben permanecer aisladas de Producción. Nunca deben crear viajes, pagos, usuarios o configuración real desde el entorno Preview.

## Validación automática

El workflow `.github/workflows/validate-preview-production-split.yml` bloquea:
- referencias a `AdminPreviewModulePage` desde el panel principal;
- navegación diferente por entorno;
- pérdida de los parámetros `channel` en los módulos principales.

Además ejecuta `flutter analyze` y un build web de humo antes de aceptar el cambio.


## Estado operativo 2026-10-04

Además de la regla anterior:

- verificación SMS de Pasajeros y Conductores usa switches independientes y datos separados por entorno;
- el laboratorio QA usa `scope` + `channel` y no puede reutilizar el default de Producción cuando está en Prueba;
- el laboratorio admite `service_mode=mixed|car|motorcycle`;
- Iquique genera CLP; Trinidad genera BOB;
- cleanup de Prueba y Producción debe permanecer aislado;
- un error de aislamiento backend NO se corrige eliminando la guarda: se corrige el caller que envió el entorno incorrecto.

### Release Android

Preview/Producción también están separados por gate, no por UI:

`Preview build -> aprobación -> mismo SHA -> Producción`

La tabla `app_release_gate` es autoritativa. No crear un job Producción desde un SHA distinto al Preview aprobado.


## Runtime Scope duro · 2026-10-07

El selector superior ya no es solo visual. Cada selección crea un workspace:

`AdminRuntimeScope(environment, countryCode, zoneId)`

Reglas:

- al cambiar entorno se desmonta el contenido del entorno anterior;
- Preview no reutiliza país/zona de Producción: usa `admin_environment_config`;
- acciones de usuario/conductor/viaje usan RPC scoped con `p_channel`;
- el backend valida acceso del administrador al entorno y runtime del registro objetivo;
- una cuenta Admin puede tener acceso a ambos entornos sin duplicar correo;
- permisos backend: `allow_preview` y `allow_production`;
- los monitores de zona permanecen Producción-only;
- entrar a Producción desde Prueba requiere confirmación;
- nuevas RPC operativas sensibles deben incluir entorno explícito o quedar bloqueadas por el validador CI.

El objetivo es que un bug del frontend no pueda convertir una operación Preview en una mutación silenciosa de Producción.
