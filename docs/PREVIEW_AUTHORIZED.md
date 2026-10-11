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
preview_authorized_sha: 128eca468144cf59dbb9ea330f0adc15d77cf777
```
