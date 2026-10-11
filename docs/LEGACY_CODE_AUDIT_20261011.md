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


## Limpieza adicional del repositorio y base de datos

- Se retiraron del árbol activo los archivos de respaldo de Edge Functions y SQL marcados explícitamente como `backup` / `original_backup`; el contenido completo sigue disponible en `archive/legacy-code-20261011`.
- Los triggers de CI dejaron de incluir ramas históricas de 2026-10-06/07 y bases de trabajo ya cerradas; la validación activa queda en `main` y `chatgpt/admin-preview-independent-20261010`.
- En Supabase, `public.acl_backup_20261010_e6` y `public.admin_function_backup_20261010` tenían cero dependencias activas y fueron movidas a `archive_legacy`, fuera del esquema público.
- Los requisitos de documentos de conductores ahora son configuración compartida entre Preview y Producción; Preview ya no mantiene una copia shadow separada de esos requisitos.

## Hallazgos de seguridad y rendimiento (no borrados automáticamente)

- Supabase reporta tablas con RLS habilitado sin políticas directas. Varias son consumidas únicamente por RPC `SECURITY DEFINER`, por lo que no se deben borrar ni abrir políticas de forma masiva.
- Existen funciones `SECURITY DEFINER` ejecutables por `anon`; requieren revisión individual porque algunas pertenecen al arranque/login público y otras pueden necesitar restricción.
- Existen índices marcados como no usados y claves foráneas sin índice de apoyo. No se eliminan índices por contador de uso sin revisar tráfico real y planes de consulta.
- Persisten ramas de código shadow dentro de módulos antiguos; donde `usesSharedOperationalConfiguration` es siempre `true`, esas ramas son candidatas a simplificación posterior, pero se deben retirar por módulo para no borrar los simuladores QA que sí son intencionales.


## Archivo pendiente retirado del árbol activo

`docs/preview/migrations/20261011_dispatch_channel_qa_membership_guard_pending.sql` era una propuesta no desplegada marcada PENDING. Se retiró del árbol activo para que no pueda confundirse con migración vigente. La copia histórica permanece en `archive/legacy-code-20261011`.
