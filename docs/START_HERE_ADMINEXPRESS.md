# ADMINEXPRESS — START HERE

> Handoff operativo del panel administrativo de Express.
>
> Última actualización: 2026-09-30.

## 1. Rol del repositorio

`Adminexpress` es el único frontend administrativo de Express.

No debe compilarse dentro del APK/AAB y no debe volver a copiarse a `Expressdelivery`.

URL web:

`https://jorge2610g.github.io/Adminexpress/`

Repositorio de la app operativa:

`jorge2610g/Expressdelivery`

## 2. Backend

Supabase project ref:

`zgpijrznvaskgcmauwxx`

Adminexpress comparte el backend con la app Express.

Seguridad de acceso:

- autenticación Supabase;
- RPC `is_admin`;
- funciones administrativas SECURITY DEFINER con validación de administrador.

## 3. Módulos administrativos

El panel contiene:

- Dashboard;
- operación;
- Viajes;
- Delivery;
- Conductores;
- Usuarios;
- Seguridad/SOS;
- Zonas;
- Tarifas;
- Pagos/Billetera;
- Reportes;
- Configuración;
- Despacho;
- Auditoría;
- App Builder.

Archivos principales:

- `lib/main.dart`
- `lib/admin_panel.dart`
- `lib/admin_control_sections.dart`

## 4. App Builder Android

El botón Compilar Android no ejecuta Flutter en el navegador.

Los pushes de Expressdelivery no disparan builds Android. Adminexpress es el punto de inicio intencional: crea el `build_jobs` y el scheduler de GitHub Actions recoge únicamente trabajos que estén en cola.

Flujo:

1. Adminexpress crea un registro en `build_jobs`.
2. El workflow `Build Express Android` de `jorge2610g/Expressdelivery` toma el trabajo.
3. GitHub Actions instala Flutter.
4. Recupera la firma Android mediante un worker protegido por GitHub OIDC.
5. Compila APK release.
6. Compila AAB release.
7. Crea un GitHub Artifact temporal.
8. Crea un GitHub Release permanente con APK/AAB.
9. Actualiza `build_jobs` con estado `ready`, URLs y `signing_mode=production`.
10. Adminexpress muestra Descargar APK / Descargar AAB / Publicar actualización.

## 5. Firma Android

La identidad de firma debe permanecer estable para todas las actualizaciones futuras.

Implementación actual:

- archivo JKS: bucket privado `android-signing`;
- alias: `express-release`;
- passwords: Supabase Vault;
- worker: `android-build-worker`;
- autenticación del worker: token OIDC de GitHub Actions;
- no hay passwords/JKS dentro del repositorio.

No regenerar el JKS salvo que exista un plan explícito de migración de firma.

## 6. Publicación de actualización

Compilar y publicar son acciones distintas.

Un build `ready` puede descargarse/probarse sin anunciarse a clientes.

`admin_publish_build` publica la versión en `app_releases`.

La app móvil consulta `latest_app_release('android')` y compara el `build_number` con el instalado.

## 7. Separación con Expressdelivery

Desde 2026-09-30 se retiraron de `Expressdelivery`:

- `admin_panel.dart`;
- `admin_control_sections.dart`;
- rutas web Admin;
- prototipos antiguos no usados.

Toda función administrativa nueva debe agregarse aquí.

## 8. Regla de documentación

Cuando cambie:

- el App Builder;
- firma Android;
- Google Play;
- modelo de releases;
- seguridad Admin;
- deploy;
- backend administrativo;

actualizar este documento y `docs/CHANGELOG_ACTIVE.md`.


## 9. Dirección visual de la app operativa

La app `jorge2610g/Expressdelivery` adoptó la referencia **Express Dual**: una sola app para Cliente + Conductor + Delivery.

Adminexpress sigue siendo un producto web separado. No copiar esta UI administrativa dentro del APK/AAB.

La compilación Android continúa iniciándose únicamente desde App Builder cuando el administrador lo decide.
