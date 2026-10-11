# Versión autorizada de Preview

Este archivo decide qué commit puede publicarse en `/preview/` (decisión E).
El workflow `deploy-web.yml` solo publica Preview si el SHA pedido es exactamente el de `preview_authorized_sha`.

Para cambiar la versión de Preview:
1. Revisar y probar el nuevo commit en su rama.
2. Cambiar `preview_authorized_sha` en este archivo con un commit directo a `main`, con aprobación del propietario. No hay PR posible: `main` no comparte historia con Producción ni con Preview.
3. Lanzar `deploy-web.yml` a mano con `preview_only=true`, `preview_source_sha` = ese SHA y `production_snapshot_run_id` = el run del snapshot vigente.

Ningún push dispara despliegues (decisión C).

**Publicación de Producción desactivada en `deploy-web.yml`:** este workflow no tiene ningún job que compile ni publique Producción; solo puede publicar `/preview/`. Habilitar Producción exige una autorización de Producción separada, aprobada por el propietario.

Bytes de Producción (decisión B): se conservan con el artifact `production-snapshot` (retención de 90 días) creado con `snapshot_source_run_id` a partir del artifact `github-pages` de un build de Producción conocido. El workflow verifica que el sitio publicado coincide byte a byte antes de publicar Preview.

```
preview_authorized_sha: 092b8c389141d5218bd210219403e192f0c67981
```
