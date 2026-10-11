# Versión autorizada de Preview

Este archivo decide qué commit puede publicarse en `/preview/` (decisión E).
El workflow `deploy-web.yml` solo publica Preview si el SHA pedido es exactamente el de `preview_authorized_sha`.

Para cambiar la versión de Preview:
1. Revisar y probar el nuevo commit en su rama.
2. Cambiar `preview_authorized_sha` en este archivo (vía PR a `main`, con aprobación del propietario).
3. Lanzar `deploy-web.yml` a mano con `preview_only=true`, `preview_source_sha` = ese SHA y `production_snapshot_run_id` = el run del snapshot vigente.

Ningún push dispara despliegues (decisión C). Producción solo se publica con `confirm_production = PUBLICAR PRODUCCION`.

Bytes de Producción (decisión B): se conservan con el artifact `production-snapshot` (retención de 90 días) creado con `snapshot_source_run_id` a partir del artifact `github-pages` de un build de Producción conocido. El workflow verifica que el sitio publicado coincide byte a byte antes de publicar Preview.

```
preview_authorized_sha: 9f2112c4b022080969882eb8708d256b9550f65b
```

## Cambios autorizados para esta revisión QA (2026-10-11)

La versión `9f2112c4b022080969882eb8708d256b9550f65b` pasó
`Validate Admin Preview Production Split` en GitHub Actions `38144362075`
y `38144358836` para los modos Producción y Preview.

- Suscripciones (22): asignación de planes QA ahora calcula la fecha real
  de vencimiento según duración y solo admite conductores `is_qa=true`.
- Prioridad conductores (25): conserva el canal Preview y filtros QA.
- Despacho manual (13): nuevo simulador de solicitudes y asignaciones QA
  guardadas únicamente en `admin_environment_config`; jamás llama a
  `admin_assign_ride_v2`, `admin_assign_delivery_v2` o sistemas push
  cuando el canal es Preview.
- Las zonas Bolivia/Chile continúan siendo las mismas dos zonas lógicas en
  la única base de datos Supabase (no duplicar bases).

**La autorización del SHA NO ejecuta una publicación.** La puesta en línea
solo puede solicitarse mediante `Actions > Deploy Adminexpress Web to GitHub
Pages > Run workflow` en la rama `main`, con `preview_only=true`,
`preview_source_sha=9f2112c4b022080969882eb8708d256b9550f65b` y
`production_snapshot_run_id=38117120868`. Dejar
`confirm_production` vacío. Ningún paso reconstruye Producción.
