# Adminexpress — Changelog activo

---

## 2026-09-30 — Separación definitiva y App Builder Android

- Adminexpress queda como único frontend administrativo;
- el código Admin se retiró de `Expressdelivery`;
- App Builder conectado a `build_jobs`;
- compilación Android ejecutada en GitHub Actions;
- APK + AAB generados automáticamente;
- GitHub Releases usado para distribución permanente de binarios;
- firma Android de producción persistente;
- JKS almacenado de forma privada;
- passwords de firma cifrados en Supabase Vault;
- worker protegido mediante GitHub OIDC;
- descarga de APK/AAB disponible desde el historial de builds;
- publicación de actualización separada de compilación;
- la app móvil puede consultar releases publicados mediante `latest_app_release`.

### Primer build firmado confirmado

- Express v1.5.19 · build 59;
- APK generado correctamente;
- AAB generado correctamente;
- `signing_mode=production`;
- instalación APK validada en dispositivo Android.

### Siguiente release

- Express v1.5.20 · build 60;
- incluye limpieza del repositorio Express y corrección reforzada de cancelación.
