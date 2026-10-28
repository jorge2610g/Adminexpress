# Memoria IA — Admin Express (Adminexpress)

Leer esto antes de tocar nada. Actualizado: 2026-10-28.
Reglas superiores: `AGENTS.md`. Parte compartida con Express: `Express-Oficina-IA/docs/MEMORIA_COMPARTIDA.md`.

## 1. Qué es
- Panel administrativo único: `https://admin.expressviajes.online/`.
- Mismo código para cuentas Preview y Producción. El backend decide el contexto por la cuenta autenticada, no por URL ni selector.
- Backend compartido con Express (Supabase `zgpijrznvaskgcmauwxx`).
- Una sola configuración de ciudades, zonas, tarifas y servicios, compartida con Express y Restaurante.

## 2. Estado actual
- `main`: último commit `b1fb2fe` (2026-10-26), documenta la sincronización automática de Google Play Producción.
- Pantalla de distribución: muestra la versión detectada en Play. Al guardar «Versión actual» se publica esa build para la verificación de actualizaciones de la app.
- Versión de Producción de referencia: Express 1.6.4 build 152 (según Express `docs/CURRENT_STATE_HANDOFF_20261027.md`). Verificar en vivo antes de decidir nada.
- Handoff de entornos (`docs/UNIFIED_ACCOUNT_ENVIRONMENT_HANDOFF_20261026.md`): menciona la build 148 como candidato. **Está desactualizado.** No usarlo como estado actual.
- PRs abiertos:
  - #131 (26-oct): usar la versión seleccionada para pruebas internas. Revisar antes de tocarla.
  - #137 (28-oct, borrador): permisos de lectura, edición y borrado por módulo. En curso.
  - #118, #100, #84, #82, #67, #66, #64, #63: borradores o antiguos. Históricos.

## 3. Cómo se publica
- **Web del panel:** `https://admin.expressviajes.online/`. Única URL permitida. No crear Admin Preview ni sitios espejo.
- **Sincronización de Play:** `sync-play-production.yml` (en Express) lee Producción cada 15 min con `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. Es solo lectura.
- **Actualización de usuarios:** detectar una build no basta. Un administrador debe seleccionarla y configurarla en «Distribución de actualizaciones · Producción».
- **Actualización crítica:** solo con orden expresa del propietario. Afecta a apps con build menor al valor configurado.
- **Avisos a usuarios:** acción separada, solo con orden expresa.

## 4. Qué NO tocar sin orden
- No activar actualización crítica, ni enviar avisos, ni cambiar «Versión actual» de Producción.
- No cambiar ciudades, tarifas, servicios ni flags comerciales de zona por un despliegue técnico. Eso es configuración de negocio.
- No recrear Admin Preview, `ADMIN_ENV`, `_previewScopedModules` ni una copia del catálogo de ciudades.
- No subir ni promover Android a Play. Ese proceso vive en Express.
- No ejecutar ni editar migraciones ya aplicadas.
- No poner secretos, service-role keys ni JSON de cuentas de servicio en Git o en el chat.

## 5. Abierto y cerrado
- **Abierto:** #131 y #137 pendientes de revisión.
- **Abierto:** el handoff del 26-oct tiene el candidato 148 desactualizado. Actualizarlo o reemplazarlo por esta memoria.
- **Abierto:** confirmar qué cuenta de Play está en el secreto `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (ver memoria de Express).

## 6. Registro de sesiones de IA (obligatorio)
Cada IA que entre o cambie algo añade una entrada al final:
- **Fecha y hora de entrada**, y qué se va a revisar.
- **Qué cambió:** archivos y motivo.
- **Qué NO cambió:** lo que se revisó y se dejó igual.
- **Pruebas:** qué se probó, sobre qué commit, con qué resultado. Si no se probó, decirlo.
- **Despliegues y publicaciones:** qué se subió, a dónde y con qué versión. Si no hubo, escribir «sin despliegue».
- **Qué quedó abierto** y cuál es el siguiente paso.

### Entradas
- **2026-10-28 · Creación de esta memoria.** Cambió: `docs/MEMORIA_IA.md` y `CLAUDE.md` (ahora apunta aquí). No cambió: código, workflows, `main`, Play, Supabase. Pruebas: no aplica (solo documentación). Despliegues: ninguno. Abierto: #131, #137, handoff 148 desactualizado.
