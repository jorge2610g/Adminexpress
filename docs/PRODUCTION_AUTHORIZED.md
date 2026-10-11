# Versión autorizada de Producción

Este archivo decide qué commit se publica en la raíz `/` (Producción).

`deploy-web.yml` solo publica Producción con todas estas condiciones:
- `publish_production = true` y `preview_only` vacío o falso.
- `production_source_sha` igual a `production_authorized_sha` de este archivo.
- `preview_source_sha` igual a `preview_authorized_sha` de `docs/PREVIEW_AUTHORIZED.md`.
- `confirm_production = PUBLICAR PRODUCCION`.

Cambiar `production_authorized_sha` requiere un commit directo a `main` con aprobación del propietario. No hay PR posible: `main` no comparte historia con Producción ni con Preview.

Cada publicación de Producción reconstruye también `/preview/` desde `preview_authorized_sha`, para que Preview no quede desincronizado. Al final deja un `production-snapshot` nuevo de 90 días, que usan las siguientes publicaciones de Preview.

```
production_authorized_sha: 128eca468144cf59dbb9ea330f0adc15d77cf777
```
