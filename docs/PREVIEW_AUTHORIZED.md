> **Estado 2026-10-14:** las reglas de Preview y Producción de este documento quedan superadas en lo que contradigan `docs/ARQUITECTURA_UNICA_2026-10-14.md` (una app, una web, entorno decidido por la cuenta). Se conserva como histórico.

# HISTÓRICO / SUPERADO — Preview autorizado

Este archivo **ya no es un contrato de despliegue vigente**.

El mecanismo `preview_authorized_sha` pertenecía a la arquitectura con dos bundles web y fue retirado el 2026-10-11.

Arquitectura actual:

- una sola web: `https://admin.expressviajes.online/`;
- `/preview/` redirige a `/`;
- el entorno lo determina la cuenta autenticada;
- el workflow vigente es `Deploy Adminexpress Central`.

No editar este archivo para autorizar una versión Preview ni reintroducir su lógica en CI.

Fuente de verdad:

- `AGENTS.md`
- `docs/AI_HANDOFF_2026-10-11.md`
- `docs/admin-central-access.md`

El contenido anterior permanece disponible en el historial de Git para auditoría.
