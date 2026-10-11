# REVIEW 2026-10-11 · Preview vs Producción: validación de identidad en la ficha del conductor

Revisor: Claude (arquitecto/revisor). Este documento no cambia código, datos ni despliegues.

## Veredicto

**NO-GO para promover Preview completo a Producción.**

**GO parcial condicionado:** portar a Producción solo la validación de identidad en la ficha, después de corregir el defecto bloqueante de la sección 3.

## 1. Qué hay en Preview y no en Producción

Commits de referencia:

- Producción: `30e60582` (`backup/2026-10-09-before-preview-production-safety`), desplegada el 2026-10-09 17:54 UTC.
- Preview: `c3a2c5c3` (`[deploy-preview-only] qa: release isolated driver-priority module with production protected`), desplegada el 2026-10-11 03:22 UTC.
- Diferencia en `lib/`: 40 archivos, +6322 / −2868 líneas.

Cambios relevantes:

| Área | Archivos | Estado en Preview | Riesgo para Producción |
|---|---|---|---|
| Ficha del conductor, identidad | `lib/admin_detail_dialogs.dart`, `lib/admin_bolivia_kyc.dart`, `lib/admin_manual_identity.dart` | Revisión por foto (frente, reverso, selfie) con historial. Usa `admin_driver_kyc_bolivia_manual_review_part`, que existe en la base. | Medio. Ver sección 3. |
| Documentos no identidad (licencia, vehículo) | `lib/admin_detail_dialogs.dart` | Llama a `admin_driver_document_review_part_v2`, que **no existe** en la base. | **Bloqueante.** Aprobar o rechazar licencia falla en Preview. |
| Requisitos de documentos | `lib/admin_driver_document_requirements.dart` | Catálogo de requisitos (`admin_driver_document_requirement_list`). | Bajo. |
| Prioridad de conductores | `lib/admin_driver_priority.dart` | Módulo con RPC «shadow» solo de Preview (commit `8b1e0b7`). | **Alto.** No debe ir a Producción tal cual. |
| Pantalla de sección y diseño | `lib/core/*`, `lib/admin_panel.dart`, `lib/main.dart` | Rediseño con tokens y tablas nuevas. | Medio. Cambio visual amplio. |
| Marketplace, tarifas dinámicas, laboratorio de carga, auditoría, zonas | `lib/admin_marketplace*.dart`, `lib/admin_dynamic_pricing.dart`, `lib/admin_load_lab.dart`, `lib/admin_audit_sandbox.dart`, `lib/admin_country_coverage.dart`, `lib/admin_zone_coverage_editor.dart`, `lib/admin_distance_fares.dart` | Módulos bloqueados o con guardas de Preview. | **Alto.** No portar. |

## 2. Identidad en la ficha: estado real

- **Preview** ya tiene la validación dentro de «Documentos e identidad», con aprobar o rechazar por foto (frente, reverso, selfie), motivo de rechazo e historial (`driver_manual_identity_review_history`).
- La RPC `admin_driver_kyc_bolivia_manual_review_part` actualiza `driver_documents.review_parts` y el estado lo calcula el trigger `trg_driver_kyc_bolivia_part_states`. Ese trigger solo actúa para documentos manuales de identidad. Cuando las tres partes están aprobadas, el estado pasa a `verified`, que es la regla que lee la app Express (PR #163).
- **Producción** solo muestra «Revisión de identidad» con las filas legadas de `identity_verifications`, sin acciones. Por eso la captura del propietario muestra «Aprobado» en el panel y «Falta verificar» en la app.
- Conclusión: el flujo correcto de identidad ya existe en Preview. Falta portarlo a Producción.

## 3. Defectos encontrados (bloqueantes y no bloqueantes)

### B1 · Bloqueante · RPC inexistente en Preview para documentos no identidad

- `lib/admin_detail_dialogs.dart` (`_reviewDocument`): para requisitos que no son identidad llama a `admin_driver_document_review_part_v2`.
- Consulta a la base (solo lectura): esa función **no existe**. Sí existen `admin_upsert_driver_document_v2` (la que usa Producción) y `admin_driver_kyc_bolivia_manual_review_part` (solo identidad).
- Efecto: en Preview, Aprobar o Rechazar licencia o vehículo falla con error de RPC.
- Corrección propuesta: usar `admin_upsert_driver_document_v2` para no identidad, con los mismos parámetros que Producción.

### B2 · Bloqueante para portar · Módulo de prioridad con RPC solo de Preview

- `lib/admin_driver_priority.dart` usa una RPC «shadow» que no debe existir en Producción.
- Corrección: dejarlo fuera del paquete de promoción y mantenerlo bajo guarda de Preview.

### N1 · No bloqueante · Filas legadas sin acción

- La sección «Revisión de identidad» de Producción muestra `identity_verifications` (legado). Dejar de mostrarla como sección activa, como ya pide la spec `SPEC-2026-10-11-carrusel-documentos-conductor.md`.

### N2 · No bloqueante · Cola de pendientes

- La cola de identidades pendientes existe en el módulo «Verificación manual» (`lib/admin_manual_identity.dart`). Se mantiene. Lo que pidió el propietario es poder aprobar desde la ficha de cada conductor, y eso ya está en Preview.

## 4. Propuesta de promoción por partes

1. **Corregir B1 en Preview**, desplegar solo a `/preview/` (marcador `[deploy-preview-only]`) y probar licencia y vehículo, aprobar y rechazar.
2. **Probar identidad en Preview** con un conductor real de prueba: aprobar frente, reverso y selfie, y comprobar que `driver_documents.status` pasa a `verified` y que la app deja conectarse (PR #163 fusionado).
3. **Promover a Producción solo el paquete de identidad y documentos**: `lib/admin_detail_dialogs.dart` (sección documentos e identidad), `lib/admin_bolivia_kyc.dart`, `lib/admin_manual_identity.dart`, `lib/admin_driver_document_requirements.dart`. Sin marketplace, sin prioridad, sin rediseño global.
4. **Decisión del propietario** para el resto del diff (rediseño, marketplace, tarifas, prioridad): quedan en Preview hasta nueva revisión.

## 5. Lo que no pude verificar

- No confirmé en vivo cómo se ve la ficha en Preview con un conductor real: el acceso de Preview requiere la sesión del administrador de prueba.
- No compilé el código (no hay Flutter en este entorno).
- No revisé el diff línea por línea de los 40 archivos. La revisión se hizo por áreas y por RPC.

## 6. Pendiente de decisión del propietario

- Autorizar el paquete de promoción (punto 3) después de probar en Preview.
- Confirmar si el módulo de prioridad y el rediseño global se quedan en Preview.

---

## PROMPT PARA LA IA PROGRAMADORA

**Contexto.** Repo `jorge2610g/Adminexpress`. Rama de trabajo: `claude/spec-driver-docs-carousel-2026-10-11` (o una nueva desde `main`). Este review está en `docs/reviews/REVIEW-preview-vs-prod-identidad-ficha-2026-10-11.md`.

**Tarea 1 (bloqueante B1).** En `lib/admin_detail_dialogs.dart`, método `_reviewDocument`, para requisitos que no son identidad, cambiar la RPC `admin_driver_document_review_part_v2` por `admin_upsert_driver_document_v2`, con los parámetros que ya usa Producción (`p_document_id`, `p_driver_id`, `p_document_type`, `p_document_number`, `p_document_url`, `p_status`, `p_expires_at`, `p_notes`, `p_channel`). No tocar la rama de identidad.

**Tarea 2.** Mantener `lib/admin_driver_priority.dart` y el resto del diff fuera del paquete de promoción. No añadir flags nuevos.

**Restricciones.** No modificar migraciones ni RPC en la base. No quitar las guardas de Preview (`_previewScopedModules`, guard de `_body` en `lib/admin_panel.dart`). Despliegue solo a Preview con `[deploy-preview-only]`.

**Cómo probar.** `flutter analyze`. En Preview: aprobar y rechazar licencia y vehículo; aprobar identidad por frente, reverso y selfie y comprobar `driver_documents.status = 'verified'` en la base (solo lectura).

**Devolución.** Formato de `docs/AI_RESPONSE_FORMAT.md`: SHA de Preview, archivos cambiados, `flutter analyze`, resultado de las pruebas en Preview y lo que no se pudo probar.
