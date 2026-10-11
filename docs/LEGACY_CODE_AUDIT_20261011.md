# Auditoría de código legado — Adminexpress — 2026-10-11

## Archivo de seguridad

El árbol completo previo a esta limpieza queda preservado en la rama:

`archive/legacy-code-20261011`

Commit base archivado:

`b5fb7c80d9dd066675434456bcb70c161bc75c15`

La rama de archivo no participa en compilación, CI ni despliegue.

## Código retirado del árbol activo

- `lib/admin_preview_config_sections.dart`: pantalla genérica Preview antigua, sin imports activos.
- `lib/admin_manual_identity.dart`: módulo de validación manual duplicado.
- `lib/admin_bolivia_kyc.dart`: pantalla KYC independiente; la revisión de fotos/documentos ya vive en `admin_detail_dialogs.dart`.
- `AdminIdentitySecurityPage` dentro de `lib/admin_control_sections.dart`: centro de identidad duplicado.
- dependencia `cupertino_icons`: no utilizada por el código activo.
- render condicional duplicado del selector de entorno en `admin_panel.dart`.

## Compatibilidad conservada

Los índices históricos 18 y 27 se mantienen como alias internos hacia Conductores para no romper referencias antiguas, pero ya no muestran ni compilan una segunda interfaz de identidad.

La ficha del conductor conserva revisión de documentos e identidad, incluidas las revisiones por fotografía.

## Hallazgos todavía activos

`AdminEnvironmentStore` sigue siendo necesario para herramientas QA realmente aisladas (por ejemplo, simuladores). Existen ramas antiguas de almacenamiento shadow dentro de módulos que hoy usan configuración compartida; deben simplificarse por módulo y con validación de RPC antes de borrarlas.

Los RPC históricos de identidad permanecen en Supabase mientras se valida que ningún cliente externo los invoque. No bloquean la compilación del panel y no se eliminaron en esta limpieza para evitar romper aplicaciones publicadas.

## Regla de publicación

CI ya no debe exigir archivos de identidad retirados. La validación exige que la revisión de identidad esté integrada en la ficha del conductor y que los archivos standalone no existan.
