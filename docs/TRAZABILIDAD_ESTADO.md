# Trazabilidad de estado — Adminexpress

Propósito: una sola línea de tiempo que avanza en un solo sentido. Lo antiguo no se borra; se marca con su estado final para que nadie reabra un error ya corregido ni dé por pendiente algo que nunca se hizo.

Fecha de corte: **2026-11-01**. Base: `main` en `bda192c`.

## Leyenda

- **HECHO**: está en `main` y se comprobó contra el código o las migraciones aplicadas.
- **SUPERADO**: el contenido fue reemplazado por trabajo posterior en `main`. **No reabrir** ni fusionar la PR: la rama es más antigua y borraría código nuevo.
- **INCONCLUSO**: falta algo concreto para cerrarlo. Se dice qué falta.
- **DECISIÓN**: requiere una orden del propietario antes de actuar.
- **HISTÓRICO**: solo referencia; no describe el estado actual.

## Estado vigente

| Tema | Estado | Referencia |
|---|---|---|
| Panel central único en `admin.expressviajes.online` | HECHO | `bda192c` |
| Sindicatos (administración) | HECHO | `bda192c` |
| Beneficios y referidos | HECHO | `87dfe7f`, `c78b45c`, `5b13a6f` |
| Deudas y ajustes por zona | HECHO | `567e073`, `6300ef7`, PR #124 |
| Aislamiento Preview/Producción por cuenta | HECHO | migraciones aplicadas de octubre 10–11 |
| Revisión de identidad y documentos en la ficha | HECHO | `5c94633`, `6541fdf` |
| Configuración única de servicios por zona | HECHO | `80e2588` (#93), `56868a4` (#95) |
| Sincronización automática con Play Producción | HECHO | `e56b6a2`, `b1fb2fe` (#135, #136) |

## Línea de tiempo de PRs abiertos (17)

### SUPERADOS — no reabrir

Cierre pendiente en GitHub de las PR de esta lista: ver `docs/CIERRE_PR_LISTA_A.md`. Hasta que se cierren, siguen abiertas y su contenido no debe fusionarse.

| PR | Tema | Motivo | Evidencia |
|---|---|---|---|
| #118 | Deudas y ajustes por zona | Ya fusionado en main con otro número | `567e073`, PR #124. La rama borra 614 líneas de main. |
| #84 | Panel Delivery unificado | Reemplazado por la configuración de servicios por zona | `80e2588` (#93), `56868a4` (#95) |
| #5 | Suscripciones de conductores (2 de octubre) | Reemplazado por la versión actual en main | La rama borra 777 líneas de `lib/admin_driver_subscriptions.dart` |
| #33 | Aislamiento final Preview/Producción | Reemplazado por las migraciones de aislamiento aplicadas | `strict_runtime_channel_isolation_and_admin_live_scope` en Supabase |
| #56 | Documentos de cambios de backend de octubre 10 | Reemplazado por `START_HERE` y `AI_HANDOFF_2026-10-11` | Docs vigentes en main |
| #59, #60, #61 | Revisión de documentos e identidad | Reemplazado por la ficha de conductor actual | `5c94633`, `6541fdf` (confirmar con el autor si hace falta) |
| #62, #63, #64, #66 | Rediseño del panel y desbloqueo de Preview (octubre 10–11) | Reemplazado por cuenta única y navegación actual | Docs vigentes; las ramas tienen cientos de commits de diferencia |
| #67 | Identidad en la ficha (desde Preview) | Reemplazado por la ficha actual | `5c94633` (confirmar con el autor si hace falta) |

### INCONCLUSOS — falta algo concreto

| PR | Qué falta | Estado |
|---|---|---|
| #82 | Premios numéricos de campeonato e historial de créditos. El backend `driver_championships` está aplicado en Supabase, pero la PR difiere de `lib/admin_driver_championship.dart` en `main` (77 líneas nuevas, 34 borradas). | Hay que revisar qué aporta la PR antes de cerrarla. |

### DECISIÓN del propietario

| PR | Pregunta |
|---|---|
| #137 | Permisos de lectura, edición y borrado por módulo para operadores. Tiene una migración `20261028163325_operator_module_permissions.sql` **no aplicada** en Supabase, y se solapa con `2cf430f` (endurecimiento de operadores) ya en main. ¿Se aplica la migración o se retira la PR? |
| #131 | Honrar la versión elegida para Internal. Se decide junto con la PR de Express #322. |
| #100 | Tiempos globales reales de Preview en solo lectura. No aparece en main. ¿Se necesita todavía? |

## Inconsistencias conocidas

1. **Migraciones con versión distinta en el repo y en Supabase** (archivo del repo → versión aplicada): `20261026032432` → `20261026042837`; `20261026043600` → `20261026050049`; `20261026234131` → `20261026234434`; `20261027000500` → `20261027000558`; `20261031062041` → `20261031064126`. Estado: INCONCLUSO. Las migraciones aplicadas no se editan (AGENTS.md). Hay que documentar la correspondencia o crear una migración de alineación con orden del propietario.
2. **Este documento de Admin y la documentación de Express** tenían estados distintos para los mismos temas. Esta línea de tiempo es la referencia de Admin; la de Express está en `CURRENT_STATE_HANDOFF_20261027.md`, sección «Estado vigente».
3. **`START_HERE_ADMINEXPRESS.md`** dice «última actualización 2026-10-11». Estado: HISTÓRICO en su parte de fechas; se apunta a este documento.
4. **`CHANGELOG_ACTIVE.md`** cita PRs fusionados (#119–#125) que no se pueden vincular a las PR abiertas. Estado: se conserva como historia.

## Cómo mantener este documento

- Cada cambio de estado se agrega como una fila nueva con fecha; no se borra la anterior.
- Un tema pasa a HECHO solo con una referencia verificable (commit, PR fusionada o migración aplicada).
- Antes de cerrar una PR, comprobar que su contenido no es más antiguo que `main`.
