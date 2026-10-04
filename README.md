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
