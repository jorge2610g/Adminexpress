## Flujo permanente exigido por el propietario (2026-10-12)

1. Para Adminexpress, «despliega» significa solo `https://admin.expressviajes.online/`: misma web y mismo código para cuenta Preview o Producción, con datos/zonas/roles filtrados por identidad desde backend.
2. Para pasajero/conductor, «despliega» significa solo `https://expressviajes.online/` (Expressdelivery), QA Web primero. No crear otra web de pruebas.
3. No generar APK con cambios de web, ni versiones «APK Preview» o «QA» alternativas. Solo cuando el propietario diga **«genera APK»**, y tras verificar web o necesidad nativa, generar el único paquete oficial `com.express.usuario1` para prueba Android; Play Store/AAB requieren autorización por separado.
4. Secuencia: código único -> CI y seguridad -> despliegue canónico -> comprobar SHA/version.json -> probar con cuenta Preview -> arreglar -> Android solo a petición. Nunca afectar datos o configuraciones de taxi Producción para facilitar QA.
5. Esta regla prevalece sobre referencias antiguas de Preview web/Android o Shorebird. Ver `AGENTS.md`.

# Claude / Cloud — reglas de trabajo en Adminexpress

> **Vigente desde 2026-10-14:** prevalece sobre las secciones de aislamiento y paridad de este archivo la guía `docs/ARQUITECTURA_UNICA_2026-10-14.md`.

## REGLA ABSOLUTA DEL PROPIETARIO (2026-10-12): UNA WEB + UNA APP

- **Una sola web administrativa:** https://admin.expressviajes.online/ (repositorio Adminexpress). No crear Admin Preview, sitio espejo, Vercel Preview, GitHub Pages externo ni una segunda URL para pruebas.
- **Una sola aplicación Android oficial:** Expressdelivery, package `com.express.usuario1`. No crear, compilar, desplegar ni actualizar un APK con package `com.express.usuario.preview` o `com.express.usuario.qa`.
- **Prueba y Producción son contextos internos de datos, NO aplicaciones ni despliegues independientes.** La cuenta autenticada determina el contexto en Supabase; nunca por URL, selector manual ni una APK diferente.
- Cuando se pida «probar en Preview», «subir a prueba», «ver en prueba» o similar, usar el **mismo panel/la misma app** con una cuenta de prueba y datos de prueba aislados. No interpretar esas palabras como autorización para crear otra web/aplicación.
- Cualquier cambio de esta arquitectura exige una revocación expresa de esta regla por parte del propietario, no una inferencia a partir de la palabra «Preview».
- El código publicado es compartido: proteger funciones todavía no aprobadas con controles de acceso/feature flags y reglas backend; no exponerlas a producción solo porque se despliegue el mismo bundle.
- Las ramas temporales y los PR de revisión son permitidos; no representan otra web ni otra app. Mantener CI y QA en el mismo código y probar el APK oficial firmado antes de publicarlo.
- No borrar ni relajar el aislamiento de conductores, zona de prueba y solicitudes de prueba (RLS, RPC y permisos). Tarifas, pagos, suscripciones y configuración compartida se mantienen iguales a Producción; cambiarlas requiere orden expresa del propietario. Mantener en servicio taxi y producción.


Claude, Cloud, ChatGPT, Codex y cualquier otra IA **autorizada por el propietario** pueden programar en este repositorio. No existe una regla vigente que limite a Claude/Cloud a arquitectura, lectura o revisión.

## Alcance autorizado del repositorio

Un agente de IA con credenciales/conector válidos puede, cuando la tarea del propietario lo requiera:

- leer todo el repositorio;
- crear, editar, mover o borrar código y documentación;
- modificar Flutter/Dart, SQL, migraciones, tests y GitHub Actions;
- crear ramas, commits y pull requests;
- actualizar esquemas o RPC de Supabase cuando el cambio esté autorizado;
- preparar y ejecutar despliegues cuando el propietario haya autorizado ese alcance;
- corregir documentación obsoleta.

La autorización documental **no sustituye** los permisos técnicos del proveedor: el agente solo puede usar las credenciales, conectores y permisos que realmente tenga disponibles. Nunca debe inventar acceso ni exponer secretos.

## Fuente de verdad

Leer en este orden antes de cambiar arquitectura:

1. `AGENTS.md`
2. `docs/START_HERE_ADMINEXPRESS.md`
3. `docs/AI_HANDOFF_2026-10-11.md`
4. `docs/admin-central-access.md`
5. `docs/CHANGELOG_ACTIVE.md`

Los documentos marcados **HISTÓRICO / SUPERADO** no son instrucciones vigentes.

## Arquitectura vigente

- Una sola web: `https://admin.expressviajes.online/`.
- `/preview/` es solo una ruta heredada que redirige al panel central.
- Un solo Supabase principal: `zgpijrznvaskgcmauwxx`.
- Preview/Producción se determina por la cuenta autenticada, no por build, URL ni selector.
- Rol, zona y módulos se resuelven con `admin_access_context()`.
- `account_runtime_bindings.environment` fija `preview` o `production`.
- La verificación de identidad está integrada en la ficha del conductor; no debe recrearse un menú duplicado.

## Paridad obligatoria Preview / Producción

Para cualquier cambio no visual, Claude/Cloud y cualquier otro agente deben aplicar `docs/PREVIEW_PRODUCTION_PARITY_RULE.md`.

En resumen: una sola implementación compartida; el mismo commit se valida con una cuenta Preview antes del merge. No se crean ramas `preview/<slug>` ni una segunda versión del código.

## Reglas de seguridad

- No guardar service-role keys, passwords, tokens, keystores ni secretos en Git.
- No reintroducir `ADMIN_ENV`, un segundo bundle web ni `_previewScopedModules`.
- No crear una segunda página administrativa por entorno.
- No publicar Producción o Google Play sin autorización explícita del propietario y validaciones verdes.
- Mantener trazabilidad con ramas/commits/migraciones y actualizar documentación cuando cambie una regla operativa.
- Antes de cualquier cambio se crea una copia de seguridad (rama `backup/<tema>-<fecha>`) en cada repositorio afectado, subida al remoto. Ver §9 de `docs/ARQUITECTURA_UNICA_2026-10-14.md`.
