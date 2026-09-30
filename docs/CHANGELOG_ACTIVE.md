# Adminexpress — Changelog activo

---

## 2026-09-30 — Referencia Express Dual

- Expressdelivery adopta la referencia visual Express Dual;
- Cliente + Conductor + Delivery permanecen dentro de una sola app;
- Adminexpress continúa separado y solo web;
- ningún cambio visual de Express vuelve a introducir Admin dentro del APK;
- los APK/AAB siguen compilándose únicamente bajo solicitud desde App Builder.

---

## 2026-09-30 — Build Android solo bajo solicitud

- los pushes normales de Expressdelivery ya no generan APK/AAB;
- el build 60 automático fue cancelado;
- Android se compila únicamente cuando el administrador lo solicita desde App Builder;
- el scheduler de GitHub Actions solo procesa trabajos Android que estén en cola.

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
