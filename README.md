# Adminexpress

Panel administrativo web independiente de **Express**.

> Para cualquier IA/agente de código: leer primero `AGENTS.md` y `docs/AI_HANDOFF_2026-10-04.md`.

## Responsabilidad

Este repositorio contiene únicamente la administración de Express:

- operación en vivo;
- viajes y delivery;
- conductores y usuarios;
- seguridad / SOS;
- zonas y tarifas;
- pagos / billetera;
- reportes y configuración;
- despacho manual;
- auditoría;
- App Builder Android;
- historial y publicación de releases.

La aplicación de Pasajero + Conductor + Delivery vive en:

`jorge2610g/Expressdelivery`

Desde la limpieza de 2026-09-30, el código administrativo ya no existe dentro de `Expressdelivery`.

## Backend compartido

Adminexpress y Expressdelivery usan el mismo Supabase:

`zgpijrznvaskgcmauwxx`

El acceso al panel está protegido por la RPC `is_admin`.

No eliminar funciones/tablas administrativas del backend desde el repositorio Express: siguen siendo necesarias para Adminexpress.

> **Corrección de Builds, 2026-10-08:** las compilaciones y publicaciones
> son globales para **toda la aplicación Express**. El módulo `Builds`
> no solicita país ni zona y se puede abrir sin seleccionar ámbito geográfico.
> Solo los módulos operativos mantienen filtros obligatorios país/zona.
> La autorización por rol y la selección de entorno Prueba/Producción siguen
> vigentes para proteger los releases reales.
>
## Cambio 2026-10-08 — un solo APK público, sin app Preview permanente

La pestaña **Builds** usa ahora `AdminSingleAppReleasePage`:

1. En Producción, el administrador prepara un **candidato firmado de la única app** `com.express.usuario1`, build Google Play independiente.
2. Se descargan los APK/AAB de ese mismo candidato para hacer QA real en Android. Los datos de QA siguen protegidos en Supabase.
3. El administrador registra **qué comprobó**, certifica el SHA y hashes de esos mismos artefactos, aprueba y promueve **sin recompilar**.
4. La publicación a clientes sigue siendo un paso manual independiente. QA Web cotidiana y APK debug temporal por demanda viven en el repositorio Expressdelivery.

Backend: migración `20261008124200_single_app_android_release_gate.sql`, funciones `admin_queue_single_app_candidate`, `admin_single_app_release_status`, `admin_certify_single_app_candidate`, `admin_approve_single_app_candidate` y `admin_promote_single_app_candidate`. Se conservan registros históricos y respaldos; los mecanismos de Preview antiguo permanecen para recuperación sin intervenir el flujo nuevo.

**No publicar en Google Play sin probar el APK firmado y verificar la misma identidad/hash que el AAB aprobado.**

## App Builder

Adminexpress no compila Flutter dentro del navegador.

Flujo real:

```text
Adminexpress
  -> crea build_jobs
  -> GitHub Actions en Expressdelivery
  -> firma Android
  -> genera APK + AAB
  -> GitHub Release
  -> guarda URLs/estado en Supabase
  -> Adminexpress muestra Descargar / Publicar
```

La firma Android de producción usa:

- JKS persistente en almacenamiento privado;
- contraseñas cifradas en Supabase Vault;
- GitHub OIDC para autorizar al worker;
- ningún secreto dentro del frontend.

## Estado operativo actual

- panel principal usado: `admin.expressviajes.online`
- backend: `zgpijrznvaskgcmauwxx`
- Preview/Producción usan una sola UI y distinta capa de datos
- switches SMS Pasajeros/Conductores disponibles y OFF por defecto
- laboratorio QA soporta Mixto / Auto / Moto
- última validación y deploy conocidos del estado documentado: SUCCESS

## Deploy

GitHub Pages:

`https://jorge2610g.github.io/Adminexpress/`

Workflow:

`.github/workflows/deploy-web.yml`

## Continuidad

Leer antes de modificar arquitectura o releases:

- `AGENTS.md`
- `docs/AI_HANDOFF_2026-10-04.md`
- `docs/START_HERE_ADMINEXPRESS.md`
- `docs/CHANGELOG_ACTIVE.md`

No copiar nuevamente el panel Admin dentro de Expressdelivery.
