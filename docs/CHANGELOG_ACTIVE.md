# Adminexpress — Changelog activo

---

## 2026-10-04 — Handoff IA, SMS y laboratorio QA Auto/Moto

- agregado `AGENTS.md` y `docs/AI_HANDOFF_2026-10-04.md` para continuidad con otra IA;
- Configuración > Seguridad incorpora switches independientes de verificación SMS para Pasajeros y Conductores, OFF por defecto;
- se mantiene una sola UI para Preview/Producción y se documenta el release gate exact SHA;
- laboratorio QA corrige `channel` Preview/Producción y moneda CLP/BOB por ciudad;
- laboratorio QA agrega selector `Mixto · Auto + Moto`, `Solo Auto` y `Solo Moto`;
- limpieza QA queda aislada por entorno;
- mensajes de error del laboratorio dejan de mostrar `[object Object]`;
- se corrigió una duplicación de `_friendlyError` que bloqueaba el build web;
- validación Preview/Producción y deploy web quedaron en SUCCESS;
- Producción Android vigente documentada como Express 1.5.87+131, SHA `45c2aff26cd27229e445461d2f129023bf6f60df`.

---

## 2026-10-03 — Multizona, filtros operativos y telemetría

- Zonas admite varios métodos de pago por ciudad, con método principal compatible con la app publicada;
- cada método puede habilitarse por separado para Viajes, Delivery, Suscripciones y Billetera;
- se agregó Región / departamento a la configuración geográfica de zonas;
- Pagos / Billetera administra métodos dinámicos por zona y filtra movimientos por Hoy, Semana, Mes o rango de fechas;
- Viajes y Delivery consultan Hoy por defecto y filtran desde backend por período;
- Usuarios puede consultarse por zona, ciudad y región/departamento sin cargar todo el historial;
- Suscripciones muestra y configura los métodos habilitados por zona y filtra pagos por período;
- Notificaciones / Avisos estima alcance antes del envío y muestra telemetría de campañas;
- Aliados y sindicatos incorpora dashboard financiero, comisiones y liquidaciones;
- Configuración avanzada deja explícito que sus interruptores de pagos son compatibilidad global para builds antiguos;
- el backend conserva los campos legados de pago para no romper la app móvil actualmente publicada.

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
