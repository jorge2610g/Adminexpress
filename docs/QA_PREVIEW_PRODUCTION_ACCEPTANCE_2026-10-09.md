# HISTÓRICO / SUPERADO — protocolo QA Preview/Producción 2026-10-09

Este protocolo correspondía al modelo de dos páginas y despliegues independientes.

No usarlo para publicaciones actuales.

Modelo vigente:

- una sola web;
- entorno por usuario;
- un solo bundle;
- permisos backend por cuenta, rol y zona.

Para validar cambios actuales:

1. comprobar `admin_access_context()`;
2. confirmar el entorno asignado a la cuenta;
3. probar módulos permitidos;
4. verificar que operadores no puedan salir de su zona/rol;
5. ejecutar las validaciones del repositorio;
6. desplegar solo mediante `Deploy Adminexpress Central` cuando exista autorización.

Ver `docs/AI_HANDOFF_2026-10-11.md`.

El protocolo anterior se conserva en el historial Git.
