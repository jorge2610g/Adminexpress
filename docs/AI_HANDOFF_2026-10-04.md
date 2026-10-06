# Adminexpress — AI handoff operativo (2026-10-04)

> Documento autoritativo de continuidad para otra IA o desarrollador.
>
> Refleja el estado actual del panel después de las correcciones de QA, SMS, branding y release realizadas el 2026-10-04.

## 1. Rol del repositorio

`Adminexpress` es el único frontend administrativo de Express.

App operativa:
- repo: `jorge2610g/Expressdelivery`

Backend compartido:
- Supabase project ref: `zgpijrznvaskgcmauwxx`

Panel web usado actualmente:
- `admin.expressviajes.online`

GitHub Pages sigue siendo parte del pipeline de deploy del repo.

No volver a incluir código Admin dentro de Expressdelivery.

---

## 2. Estado actual

Commit de referencia al crear este documento:

- `00d0e481da98cb584d3421be61dc4636fc7697c6`

Última validación conocida:
- Validate Admin Preview Production Split: SUCCESS
- Deploy Adminexpress Web to GitHub Pages: SUCCESS

Cambios inmediatamente recientes:
- switches SMS pasajeros/conductores
- mejor manejo de errores QA
- laboratorio QA con selector Auto / Moto / Mixto
- correcciones de aislamiento Preview/Producción

---

## 3. Arquitectura visual

Archivos principales:

- `lib/main.dart`
- `lib/admin_panel.dart`
- `lib/admin_control_sections.dart`
- `lib/admin_load_lab.dart`
- `lib/admin_environment_store.dart`
- `lib/admin_preview_config_sections.dart`

El panel usa una sola estructura de navegación.

Preview y Producción NO deben tener árboles distintos.

Correcto:

`Widget(channel: adminChannel)`

Incorrecto:

`adminChannel == 'preview' ? PreviewPage() : ProductionPage()`

---

## 4. Selector Producción / Prueba

El selector superior cambia la capa de datos.

Producción:
- datos reales
- configuración real
- clientes reales
- operaciones reales

Prueba:
- datos Preview/QA
- configuración shadow donde corresponda
- cuentas QA
- channel `preview`

El diseño, componentes, botones y funciones deben ser equivalentes.

Workflow que protege esto:

`.github/workflows/validate-preview-production-split.yml`

El workflow valida:
- navegación común
- parámetros `channel`
- analyze
- build web smoke

No desactivar esta protección para hacer pasar un cambio.

---

## 5. Verificación SMS

En:

**Configuración -> Seguridad**

deben existir:

- Verificación SMS · Pasajeros
- Verificación SMS · Conductores

Campos Producción:

- `app_settings.sms_verification_passenger_enabled`
- `app_settings.sms_verification_driver_enabled`

Preview:
- valores equivalentes dentro de configuración Preview/shadow

Estado esperado:
- pasajeros OFF
- conductores OFF

La app puede salir a Producción con SMS apagado.

Al configurar Twilio/proveedor:
- el administrador decide qué rol activar

RPC Producción:
- `admin_phone_verification_settings_update`

No guardar credenciales Twilio en Flutter Web.

---

## 6. Pagos y reglas por país

### Chile

Viajes:
- Efectivo

Moneda:
- CLP

### Bolivia

Viajes:
- Efectivo
- QR del conductor

Moneda:
- BOB

El QR del conductor es pago directo al conductor.

No configurar Mercado Pago administrativo como pago de tarifa normal de viaje.

Mercado Pago / otros rails administrativos:
- suscripciones
- recargas

Las pantallas Admin deben respetar `use_rides` y configuración por zona.

---

## 7. Laboratorio de carga QA

UI:

`lib/admin_load_lab.dart`

Backend:

`Expressdelivery/supabase/functions/express-load-lab/index.ts`

### Controles

Debe permitir elegir:

Entorno:
- Prueba (aislado)
- Producción (real)

Ciudad:
- Trinidad
- Iquique

Servicio QA:
- Mixto · Auto + Moto
- Solo Auto
- Solo Moto

Además:
- demanda
- cantidad de conductores
- cantidad de solicitudes
- radio
- Crear escenario
- Limpiar prueba

### Parámetro backend

`service_mode`:

- `mixed`
- `car`
- `motorcycle`

Default:
- `mixed`

### Reglas de generación

Iquique:
- CLP

Trinidad:
- BOB

Preview:
- `channel=preview`

Producción:
- `channel=production`

### Mixto

Conductores:
- mitad Auto
- mitad Moto

Solicitudes:
- Auto -> `category=economy`
- Moto -> `category=motorcycle`

### Push

LOADTEST:
- push suprimido

### Cleanup

La limpieza debe estar aislada por entorno.

Un cleanup Preview no puede borrar escenario sintético de Producción.
Un cleanup Producción no debe tocar Preview.

---

## 8. Incidente QA corregido 2026-10-04

### Síntoma 1

Prueba devolvía HTTP 500:

`Una cuenta QA/Preview no puede crear datos de Producción`

Causa:
- laboratorio omitía `channel`
- DB aplicaba default Producción

Solución:
- Preview -> channel preview
- Producción -> channel production

La protección backend era correcta y NO debía eliminarse.

### Síntoma 2

Admin mostraba 100 solicitudes pero conductor Auto veía 0.

Causa:
- laboratorio generaba todo como `motorcycle`

Solución:
- selector Auto/Moto/Mixto
- backend genera tipo correcto
- escenario existente fue reparado a 50 Auto + 50 Moto

### Síntoma 3

Error UI:

`minified:Uf(... [object Object] ...)`

Solución:
- mejorar extracción de error
- mantener una sola función `_friendlyError`

Hubo un build fallido por duplicar `_friendlyError`; luego se eliminó el duplicado y el deploy volvió a SUCCESS.

No reintroducir una segunda función con el mismo nombre.

---

## 9. Cómo validar el laboratorio

### Pasajero

Con escenario Mixto Producción en Iquique:

- servicio Express/Auto -> debe ver autos
- servicio Moto -> debe ver motos

El mapa usa backend `nearby_online_driver_markers`.

### Conductor

Conductor Auto:
- debe ver solicitudes `economy`

Conductor Moto:
- debe ver solicitudes `motorcycle`

Si muestra 0:

revisar:
1. entorno
2. channel
3. categoría
4. vehículo activo
5. zona
6. radio
7. expiración
8. estado online
9. aprobación
10. suscripción/dispatch
11. método de pago compatible

No aumentar artificialmente resultados ignorando estos filtros.

---

## 10. App Builder

Adminexpress crea trabajos en:

`build_jobs`

Tipos:

Preview:
- `preview-apk+aab`

Producción:
- `apk+aab`

Expressdelivery workflow:
- `.github/workflows/build-android.yml`

### Gate

Tabla:
- `app_release_gate`

Flujo obligatorio:

`Preview -> QA -> aprobar Preview -> mismo SHA -> Producción`

No permitir Producción con otro SHA.

### Producción actual

Último release generado:

- Express `1.5.87+131`
- SHA `45c2aff26cd27229e445461d2f129023bf6f60df`
- package `com.express.usuario1`
- firma `production`

### Preview Shorebird

Base reciente:

- `1.5.87+131`
- package `com.express.usuario.preview`

Una base nueva puede requerir reinstalar APK Preview una vez.

---

## 11. Branding del panel

Marca global:
- **Express**

No usar “Express Delivery” como nombre global del panel.

“Delivery” permanece como módulo específico.

El panel de captura histórica todavía podía mostrar “Express Delivery” arriba; si se toca branding, unificar con **Express** y logo oficial, sin afectar el nombre del módulo Delivery.

---

## 12. Seguridad

Acceso:
- Supabase Auth
- `is_admin`

RPCs administrativos:
- deben validar admin
- usar `SECURITY DEFINER` solo con controles explícitos y `search_path` seguro

Nunca exponer en frontend:
- service role
- secrets de pagos
- secrets SMS
- GitHub PAT
- keystore
- passwords

---

## 13. Preview config

`admin_environment_config` sirve para configuración aislada de Preview.

No mover configuración real de Producción a una tabla Preview solo para simplificar UI.

La UI puede reutilizar componentes; la persistencia debe respetar el canal.

---

## 14. Build web / deploy

Workflow:

`.github/workflows/deploy-web.yml`

Antes de merge importante:
- `flutter analyze`
- build web smoke
- Validate Admin Preview Production Split

No confiar en que un analyze verde garantiza deploy; el build web también debe pasar.

---

## 15. Errores y mensajes

Nunca mostrar al operador:
- `[object Object]`
- nombres minificados sin mensaje útil
- errores crudos imposibles de leer si se puede extraer backend `error/message`

`_friendlyError` debe:
- revisar details
- error anidado
- message
- fallback de texto

Mantener solo una implementación.

---

## 16. Relación con Expressdelivery

Cuando un cambio afecta:

### Solo UI Admin
Editar Adminexpress.

### Edge Function / migración compartida
La fuente debe quedar versionada en Expressdelivery si allí vive el backend.

### App móvil
Editar Expressdelivery.

### Feature con UI Admin + backend
Puede requerir commits coordinados en ambos repos.

Documentar siempre los dos lados.

---

## 17. Estado del QA automático de app

El QA Android vive en Expressdelivery.

Último estado conocido:
- build del APK QA exitoso
- proceso app vivo
- 0 fatales Android confirmados
- 0 fallos nuevos confirmados de producto
- certificación no concluyente por harness/autenticación Maestro/Visual AI

No usar color rojo de Actions como única señal para bloquear o revertir.
Leer verdict y evidencia.

Pero tampoco marcar QA como sano cuando faltan pruebas obligatorias.

---

## 18. Checklist para otra IA

Antes de editar:
- [ ] leer AGENTS
- [ ] leer este handoff
- [ ] confirmar Supabase ref
- [ ] confirmar entorno
- [ ] identificar si cambio vive en Admin, App o backend

Antes de merge:
- [ ] analyze
- [ ] build web
- [ ] preview/production validator
- [ ] no secretos
- [ ] no duplicar árboles Preview/Producción
- [ ] no activar SMS sin autorización
- [ ] documentar

Antes de release Android:
- [ ] Preview exacto
- [ ] QA revisado
- [ ] aprobación
- [ ] mismo SHA
- [ ] firma production
- [ ] URLs APK/AAB
- [ ] release gate actualizado

---

## 19. Decisiones de producto que no se deben revertir sin autorización

- Admin separado de app
- una sola UI Admin
- Preview/Producción aislados
- SMS por rol, OFF por defecto
- Chile CLP
- Bolivia BOB
- viaje Chile efectivo
- viaje Bolivia efectivo + QR conductor
- pasarelas Admin no cobran viajes normales
- release gate exact SHA
- firma Android persistente
- QA Auto/Moto/Mixto
- push LOADTEST suprimido
- errores legibles para administrador

---

## 20. Archivos/documentos relacionados

En este repo:
- `AGENTS.md`
- `docs/START_HERE_ADMINEXPRESS.md`
- `docs/admin-preview-production.md`
- `docs/CHANGELOG_ACTIVE.md`

En Expressdelivery:
- `AGENTS.md`
- `docs/AI_HANDOFF_2026-10-04.md`
- `docs/QA_AUTOMATION.md`
- `docs/SAFE_IMPLEMENTATION_ROADMAP.md`


## 21. Selector global y snapshot QA por entorno (2026-10-04)

El Laboratorio QA debe obedecer directamente el selector superior **Producción / Prueba**.

Implementación actual:
- `AdminLoadLabPage(channel: adminChannel)`;
- `preview` se traduce a `scope=sandbox`;
- `production` se traduce a `scope=production`;
- el selector interno de entorno deja de ser editable para evitar dos fuentes de verdad;
- al cambiar el selector superior, la pantalla borra de inmediato el snapshot visual anterior y carga el nuevo;
- al cambiar ciudad ocurre la misma limpieza visual;
- la lectura usa `admin_audit_load_snapshot_v2(p_scope,p_city_key)`.

No borrar automáticamente el escenario del otro entorno al alternar pestañas. La separación correcta es:
- datos de Prueba permanecen en Prueba;
- datos de Producción permanecen en Producción;
- cada vista consulta únicamente su scope;
- si no existe escenario activo para esa vista, debe mostrar LIMPIO / 0, no reutilizar el snapshot anterior.

El RPC legado `admin_audit_load_snapshot()` no debe volver a usarse en esta pantalla porque no filtra por entorno.

## 22. Países y cobertura administrable (2026-10-05)

La expansión geográfica ya no requiere cambios de código para agregar un país.

En **Zonas -> Países** el administrador puede:
- crear un país mediante ISO-2 y moneda ISO-3;
- activar/desactivar el país completo;
- activar/desactivar registro de conductores;
- activar/desactivar Didit;
- guardar Workflow IDs de Didit para Producción/Prueba sin que el panel vuelva a mostrarlos;
- crear después ciudades/zonas asociadas al país.

Regla operativa:
- país activo + zona activa = cobertura potencial;
- GPS fuera de una zona activa = la app bloquea servicio y registro;
- país inactivo = ninguna de sus zonas responde como cobertura;
- una zona puede bloquear solo el registro de conductores manteniendo su configuración;
- Preview usa la misma UI y almacenamiento shadow; no modifica Producción.

Backend compartido:
- `service_countries`;
- `identity_verification_country_settings`;
- `admin_country_list`;
- `admin_upsert_country_coverage`;
- `admin_upsert_zone_v3`.


---

## 23. Ventana flotante de ofertas para conductor (decisión 2026-10-06)

**Estado: PENDIENTE DE IMPLEMENTAR.**

AdminExpress debe incorporar un switch global:

**Permitir ventanas flotantes de ofertas**

Contrato:
- misma UI para Prueba/Producción;
- cada entorno persiste su propio valor;
- clave sugerida: `driver_floating_offer_enabled`;
- ON habilita la posibilidad de uso en la app;
- OFF impide overlays;
- el switch Admin jamás concede el permiso Android del dispositivo.

La app del conductor debe tener además su propio ajuste voluntario **Ventana flotante de ofertas** y solo funcionar si Android concedió **Mostrar sobre otras aplicaciones**.

Condiciones efectivas:
1. Admin ON;
2. conductor ON;
3. permiso Android ON;
4. conductor online/disponible;
5. oferta real vigente;
6. app en segundo plano.

Al rechazar o expirar, la ventana desaparece sin abrir Express. Al aceptar, la app valida backend y entra al viaje.

No usar esta opción para publicidad, promociones, llamadas falsas o para saltarse políticas de full-screen intent.

Documento específico Admin:
- `docs/FLOATING_DRIVER_OFFERS_ADMIN.md`

Contrato móvil:
- `jorge2610g/Expressdelivery/docs/FLOATING_DRIVER_OFFERS.md`

Otra IA debe tratar esto como requisito documentado, no como feature ya implementada.
