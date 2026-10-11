# Solicitud de despliegue PREVIEW ONLY — 2026-10-10

Este commit activa exclusivamente el job `preview_only` del workflow
`.github/workflows/deploy-web.yml` en la rama
`chatgpt/admin-preview-independent-20261010`.

## Garantías de publicación

- `build` de Producción solo corre con `refs/heads/main`.
- El job Preview restaura una copia conocida de los archivos de la web de
  Producción y compara byte a byte `index.html`, `flutter_bootstrap.js`,
  `main.dart.js` y `version.json` con la web pública.
- Antes de crear el artefacto Pages, confirma que todos los archivos fuera
  de `/preview/` conservan su hash.
- Preview se compila con `ADMIN_ENV=preview`, Supabase
  `xbphilqezmwfjfpdbwad` y sesión Auth independiente.
- Producción: `ADMIN_ENV=production`, Supabase `zgpijrznvaskgcmauwxx`.
- Este commit no toca `main` ni cambia Supabase Producción.
- GitHub Pages sigue pudiendo negar el despliegue por restricciones del
  entorno `github-pages`; **no burlar protecciones ni publicar sin éxito
  del job de despliegue y validación de marcadores**.

## Estado
Acceso a módulos Preview no equivale aún a paridad funcional E2E. No operar
pagos o mensajería reales; usar usuarios y credenciales TEST independientes.
