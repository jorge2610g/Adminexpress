> **Estado 2026-10-14:** las reglas de Preview y Producción de este documento quedan superadas en lo que contradigan `docs/ARQUITECTURA_UNICA_2026-10-14.md` (una app, una web, entorno decidido por la cuenta). Se conserva como histórico.

# SUPERADA — SPEC-2026-10-11 guard de /preview/

**Estado final:** SUPERADA por la arquitectura de panel único aprobada e implementada el 2026-10-11.

Esta spec proponía proteger un segundo bundle `/preview/`. Ese problema dejó de existir porque ya no se publica un segundo panel.

Regla vigente:

- una sola web en `admin.expressviajes.online`;
- `/preview/` solo redirige;
- entorno por identidad;
- deploy único con `Deploy Adminexpress Central`.

La frase histórica que limitaba a Claude a arquitectura/revisión **ya no aplica**. Claude/Cloud, ChatGPT, Codex y otras IAs autorizadas pueden programar según `docs/AI_AGENT_POLICY.md`.

No implementar las decisiones D1-D6 ni restaurar `PREVIEW_AUTHORIZED`.

El contenido detallado anterior se conserva en el historial de Git para auditoría.
