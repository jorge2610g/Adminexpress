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
preview_authorized_sha: d09183ebcc5d13dc781666ae7aa2e2ec76c2771b
```

## Cambios autorizados para esta revisión QA (2026-10-11)

La versión `b5fb7c80d9dd066675434456bcb70c161bc75c15` pasó
`Validate Admin Preview Production Split` en GitHub Actions `38161230883`
y `38161227132`. El despliegue Preview `38161478333` terminó correctamente y verificó que Producción quedó sin cambios. La revisión `b5fb7c80d9dd066675434456bcb70c161bc75c15` elimina del menú la validación de identidad duplicada; la revisión de documentos e identidad permanece dentro de la ficha del conductor.

- Los 29 módulos del panel quedan navegables en Preview.
- Zonas, cobertura, servicios, tarifas, pagos, proveedores y configuración usan el proyecto Supabase compartido según la versión QA validada.
- Se mantiene la protección de publicación de Producción (`productionAccess: allowProduction && !adminIsPreview`).
- El aislamiento ya existente de actores de prueba se mantiene; este cambio no crea un aislamiento adicional.

**La autorización del SHA NO ejecuta una publicación.** La puesta en línea
solo puede solicitarse mediante `Actions > Deploy Adminexpress Web to GitHub
Pages > Run workflow` en la rama `main`, con `preview_only=true`,
`preview_source_sha=b5fb7c80d9dd066675434456bcb70c161bc75c15` y
`production_snapshot_run_id=38117120868`. Dejar
`confirm_production` vacío. Ningún paso reconstruye Producción.


## Reparación integral Preview 2026-10-11

- Preview autorizado: `6e1b5ee838c81efb01bf41aeb34c4f90c0fddbe0`.
- Los módulos administrativos usan la base Supabase compartida según el alcance normal del administrador.
- Se retiraron guards heredados de `production` en RPC activas que bloqueaban Preview, manteniendo `is_admin()`.
- La publicación real de Producción continúa protegida por el flujo manual de release.
