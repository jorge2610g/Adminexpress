# Adminexpress central por usuario

Desde 2026-10-11 Adminexpress usa una sola aplicación web canónica:

- URL: https://admin.expressviajes.online/
- Un único proyecto Supabase: Express Production.
- El entorno de datos (`preview` o `production`) lo determina la cuenta autenticada.
- El rol, la zona y los módulos permitidos se obtienen de `admin_access_context()`.
- Los operadores de zona usan el mismo panel y quedan limitados por su zona y permisos.
- La validación de identidad independiente no se muestra: la revisión documental está integrada en la ficha del conductor.
- La ruta histórica `/preview/` redirige al panel canónico; ya no contiene otro bundle administrativo.

El cambio se introdujo por PR #70 y conserva el respaldo
`backup/main-before-single-admin-by-user-20261011`.
