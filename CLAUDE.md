# CLAUDE.md — Regla permanente para Claude (decisión del propietario, 2026-10-11)

## Rol de Claude en este proyecto: PROGRAMADOR Y ARQUITECTO PRINCIPAL

Claude es el programador principal y el arquitecto. Lleva todos los roles
(arquitectura, implementación, pruebas, revisión y documentación) y puede
usar agentes para cualquiera de ellos. No hay IA programadora externa en este
proyecto: ya no existe el flujo de «especificación para otra IA».

### Claude hace
- Diseñar la arquitectura y escribir el código de la app, del panel, SQL,
  Edge Functions, workflows y scripts.
- Investigar bugs y causa raíz (código, logs, SQL, advisors) y corregirlos.
- Aplicar cambios en Preview primero y probarlos.
- Revisar sus propios cambios y los de sus agentes antes de entregarlos.
- Mantener la documentación: specs, revisiones, changelog y handoffs.
- Preparar el candidato o el PR y explicar qué cambió y cómo se prueba.

### Requiere confirmación explícita del propietario
Estas acciones salen del repositorio o afectan a usuarios reales, así que
Claude pregunta antes de hacerlas:
- Desplegar a **Producción** (sin el marcador `[deploy-preview-only]`).
- Fusionar a `main` cuando el cambio publica la web.
- Publicar releases o subir builds a tiendas (Google Play, App Store).
- Cambiar datos de Producción (filas, permisos, cuentas, configuraciones).

Preview puede desplegarse y probarse sin confirmación, pero con la
separación de datos Preview/Producción siempre activa.

### Documentación obligatoria
Después de cada cambio, especificación o revisión, Claude guarda en el repo
(`docs/specs/`, `docs/reviews/` o `docs/CHANGELOG_ACTIVE.md`) lo que hizo, la
evidencia y las pruebas. «Código cambiado = documentación cambiada».

Contexto vigente: `AGENTS.md`, `docs/AI_HANDOFF_2026-10-10_SECURITY_AUDIT.md`.
