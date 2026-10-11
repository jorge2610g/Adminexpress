# SPEC 2026-10-11 — Preview: desbloqueo de Suscripciones (22) y Prioridad de conductores (25)

**Estado:** especificación. Esta rama no contiene cambios de código de la app.
**Rama:** `claude/preview-authorized-2026-10-11` (base `420db6c`; rama del PR #67: `claude/promote-identity-prod-2026-10-11`).
**Referencia de solo lectura:** `chatgpt/admin-preview-independent-20261010` @ `aaae599` (PR #66).
**Producción:** `30e6058` sin cambios. Todo lo que sigue aplica solo a Preview.

> **Actualización 2026-10-11 (HEAD `3d2a680`):** la rama ya contiene código (`3d2a680`, autor Claude). La línea «Estado» y la sección 7 describen `a430e0d`, no HEAD. Prevalece la **sección 11**.

---

## 1. Decisión de rol y bloqueos (leer primero)

- El `CLAUDE.md` cargado en esta sesión (decisión del propietario, 2026-10-10) dice que Claude no programa. Ante cambios de código, Claude escribe una especificación para la IA programadora. Por eso esta sesión **no aplica el port**.
- Esa versión de `CLAUDE.md` no existe en `420db6c`. Sus commits están en `claude/roles-claude-programa-2026-10-11` (`a0716e5`, `ad3e21a`).
- El commit `8c917dc` de esa misma rama (2026-10-11 03:41 UTC) cambia la regla a «Claude programa» y la presenta como decisión del propietario de 2026-10-11. No está en `main` ni en esta rama, así que no se ha tomado como vigente.
- **Decisión pendiente del propietario:** qué regla rige. Si confirma que Claude puede programar, esta especificación sirve de guion para aplicar el port en esta misma rama. Si no, la IA programadora lo ejecuta con el bloque de la sección 10.
- Flutter y Dart no están instalados en este entorno (`which flutter dart` no devuelve nada). No se ejecutaron `flutter analyze`, `flutter test` ni `flutter build web`.
- Los documentos que cita el `CLAUDE.md` (`docs/AI_ROLES_WORKFLOW.md`, `docs/AI_RESPONSE_FORMAT.md`, `docs/AI_HANDOFF_2026-10-10_SECURITY_AUDIT.md`) no existen en ninguna referencia del repositorio. El formato de devolución está en la sección 9.

## 2. Hallazgos verificados (solo lectura)

### 2.1 Las dos historias no tienen ancestro común

- `git merge-base 420db6c aaae599` no devuelve nada. `git diff --stat 420db6c aaae599 -- lib .github docs test`: 150 archivos, +19 530 / −3 242.
- No se puede hacer cherry-pick ni merge. El port es hunk a hunk.
- Tomar archivos completos de `aaae599` borra trabajo de identidad. Verificado con `git grep` sobre `aaae599`: no contiene «Identidad por revisar», ni `admin_identity_pending_driver_ids`, ni el carrusel horizontal (`scrollDirection: Axis.horizontal` está ausente en `admin_detail_dialogs.dart`), ni `docs/sql/2026-10-11_admin_identity_pending_driver_ids.sql`.

### 2.2 Commits de `aaae599` que importan

| Commit | Archivo | Qué hace | Portar |
|---|---|---|---|
| 4fc7655 | `lib/admin_panel.dart` (+4/−2) | Añade 22 y 25 a `_previewScopedModules` | Sí, solo el set y el comentario |
| bf5ead2 | `lib/admin_driver_subscriptions.dart` (+47/−20) | Candidatos QA en servidor; VeriPagos simulado en Preview; sin conductores reales en Preview | Sí, íntegro |
| 27d207e | `lib/admin_driver_subscriptions.dart` (+10/−6) | Preview no implica desconexión real ni pasarela | Sí, íntegro |
| fuera de la lista | `lib/admin_environment_store.dart` | Cierre fail-closed de canal (`_assertValidChannel`) | Sí, un hunk |
| fuera de la lista | `test/admin_environment_store_test.dart` | Prueba de canales | Sí, archivo nuevo |
| 029e961 | `docs/preview/migrations/20261011_shared_db_subscriptions_qa_candidates.sql` (+80) | Define la RPC de candidatos QA; ya existe en la base (2.4) | Sí, solo como documento. No ejecutar |
| b48b143, 7f4f11a | `.github/workflows/validate-preview-production-split.yml` | Aserciones de CI | Parcial, ver 3.6 |
| f224384, 1f566ec, aaae599 | `docs/preview/SINGLE_SUPABASE_RESTORED_20261011.md` | Documentación de la rama de ChatGPT | No |
| 20a7eef | `.github/workflows/deploy-web.yml` (+17/−2) | Despliegue y verificación de SHA | No |
| ec847f6 | `web/index.html` (+51/−3) | Banner de SHA y aviso de recarga | No en esta fase |

### 2.3 Guardia de Preview

- `420db6c`: `{0,1,2,3,4,5,6,7,8,10,11,14,16,17,18,27}`.
- `aaae599`: lo mismo más `22` y `25`.
- Las pantallas existen en `420db6c`: la sección 25 es `AdminDriverPriorityPage` (`case 25:` en `lib/admin_panel.dart:1355`) y la sección 22 es `AdminDriverSubscriptionsPage`.

### 2.4 Base de datos (solo SELECT sobre el catálogo; proyecto `zgpijrznvaskgcmauwxx`)

| Función | Firma | Estado |
|---|---|---|
| `admin_preview_driver_subscription_candidates` | `(p_zone_id uuid, p_search text)` | Existe. Lógica equivalente a 029e961: `is_admin`, `admin_environment_allowed('preview')`, `allow_preview`, zona activa, solo `audit_test_group_members` activos, máximo 200 filas |
| `admin_driver_priority_state_scoped` | `(p_channel text, p_zone_id uuid)` | Existe. Preview: solo conductores QA. Producción: solo los no QA |
| `admin_update_driver_priority_settings_v2` | `(p_channel text, ...)` | Existe. Preview escribe en `admin_environment_config` (vía `admin_environment_config_upsert`); Producción escribe en `driver_priority_settings` |
| `admin_driver_subscriptions` | `(p_search text)` y `(p_search text, p_zone_key text)` | Existe. **Sin canal** (datos reales) |
| `admin_zone_list_for_country`, `admin_zone_subscription_settings`, `admin_subscription_payment_list_v2` | sin `p_channel` | Existen. Solo deben llamarse en Producción |
| `admin_upsert_driver_subscription_plan`, `admin_set_driver_subscription_zone_settings` (con `p_enforce_access`), `admin_set_driver_subscription_provider_settings`, `admin_set_driver_subscription` | sin `p_channel` | Existen. Escriben datos reales; nunca desde Preview |
| `admin_identity_pending_driver_ids`, `admin_driver_kyc_bolivia_manual_review_part` | — | Existen (identidad) |

No hay constancia en el repositorio de quién aplicó la RPC de candidatos, ni de que coincida byte a byte con 029e961. La comparación fue de lógica, por lectura. No volver a aplicar el SQL.

### 2.5 Riesgo bloqueante en nuestra rama

En `420db6c`, `lib/admin_driver_subscriptions.dart`, en la rama `if (_environment.isPreview)` de la carga (líneas ~102–208):

- la línea 134 llama `admin_driver_subscriptions` con `p_zone_key` (sin canal; devuelve conductores reales);
- la línea 142 filtra QA en el navegador.

Hoy está protegido porque el módulo 22 está bloqueado en Preview. **Desbloquear 22 sin portar bf5ead2 expone conductores y suscripciones reales en Preview.**

Lo que sí está bien en `420db6c`: cada escritura con RPC sin canal está en la rama `else` de `if (_environment.isPreview)`. Verificado para plan (≈551–573), ajustes de zona (≈662–690), asignación (≈782–802) y proveedor (≈899–920). Las lecturas de producción van después de un `return;` de la rama Preview. El port no debe cambiar esto. La rama de verificación de proveedor (≈957) debe revisarse al portar.

### 2.6 CI de `aaae599`

Se extrajeron los bloques Python de `git show aaae599:.github/workflows/validate-preview-production-split.yml`, se guardaron en el scratchpad y se ejecutaron con `python3 -I` dentro del worktree.

- Bloque 1 (Builds, Auditoría y Reportes globales): PASS (rc 0).
- Bloque 2 (identidad solo manual): 5 de 5 PASS.
- Bloque 3 (guardas de Preview): con el archivo SQL presente en una copia temporal, 146 aserciones: 82 PASS y 64 FAIL. Sin ese archivo, el bloque se detiene con `FileNotFoundError` en la línea 138.

Clasificación de los 64 fallos:

- **En alcance de 22/25 (14):**
  - Cierre de canal en el store, líneas 19–23 (5).
  - `22` y `25` ausentes de `_previewScopedModules`, línea 77 (2).
  - Módulo Suscripciones, líneas 125, 126, 129, 130, 133, 134 y 135 (7). Cubren la RPC de candidatos, `p_zone_id`, la ausencia de `admin_driver_subscriptions` en Preview, la compuerta de zona, el filtro `is_qa` y la compuerta de VeriPagos.
- **Ya pasan en nuestra rama:** RPC de Prioridad con `p_channel` (líneas 146–152) y sección 22 (líneas 155–158). Por tanto, 25 solo necesita el guardia.
- **Fuera de alcance (50), no se portan en esta fase:**
  - Tarifas por distancia, países y pantallas de zonas, geo, servicios, tarifas y ajustes con `AdminEnvironmentStore(widget.channel)` (líneas 27–42, 48–49 en 5 pantallas, 51–54): 24.
  - Login, OAuth de Preview y sesión separada (líneas 83–102): 18.
  - Despliegue, run-id de artefacto y `EXPECTED_PRODUCTION_SHA` (líneas 111–113): 3.
  - Banner de SHA, aviso de recarga y verificación de despliegue (líneas 162–166): 5.

### 2.7 Identidad (presente, sin cambios)

- «Identidad por revisar (» → `lib/admin_panel.dart:4636`.
- `admin_identity_pending_driver_ids` → `lib/admin_panel.dart:395` y `docs/sql/2026-10-11_admin_identity_pending_driver_ids.sql`. La RPC existe en la base.
- Carrusel → `lib/admin_detail_dialogs.dart:1300–1301` (`SingleChildScrollView` con `scrollDirection: Axis.horizontal`). Tarjeta «Vehículo» en la línea 1243.
- Visor de documentos → `lib/admin_detail_dialogs.dart:495–497` (`showDialog<void>` con `Dialog`; viene de 4910f2f).

### 2.8 Símbolos y blobs

- Los hunks de bf5ead2 y 27d207e usan `_AdminSubNotice`, `_assignPlan`, `_maps`, `_snack`, `FilledButton` y `Text`. Todos existen en `420db6c`. No hacen falta imports nuevos.
- El store usa solo `StateError`, de `dart:core`. El paquete se llama `adminexpress`, así que el import del test es válido.
- Blobs previos para `git apply --3way`: `admin_driver_subscriptions.dart` = `a2d8904` (bf5ead2) y `011cfb5` (27d207e); `admin_panel.dart` = `8abb5da` (4fc7655); `admin_environment_store.dart` = `ea9780a`. Los cuatro existen en el repositorio.

## 3. Alcance mínimo (qué portar)

### 3.1 `lib/admin_panel.dart`

En `_previewScopedModules` (líneas 244–246 en `420db6c`) añadir `22` y `25`. Resultado: `{0,1,2,3,4,5,6,7,8,10,11,14,16,17,18,22,25,27}`. Actualizar el comentario como en 4fc7655. Nada más del archivo.

### 3.2 `lib/admin_driver_subscriptions.dart`

Aplicar íntegros bf5ead2 y 27d207e sobre este archivo. Puntos obligatorios:

a) `_isQaDriver` (línea 76): añadir al inicio `if (driver['is_qa'] == true) return true;`.

b) Carga Preview (líneas ≈133–143): reemplazar la llamada y el filtro por:

```dart
// QA-only server RPC: never download production driver subscriptions
// and filter them in a Preview browser.
final rawDrivers = await supabase.rpc(
  'admin_preview_driver_subscription_candidates',
  params: {
    'p_zone_id': widget.zoneId,
    'p_search': search.text.trim(),
  },
);
final qaDrivers = _maps(rawDrivers);
```

c) VeriPagos en Preview: `connected: false`, `simulated: true`, `verified_at: null` y mensajes «Preview: …», como en bf5ead2. Nunca decir que hay conexión real.

d) «Editar métodos de suscripción» deshabilitado en Preview, con el aviso `_AdminSubNotice`.

e) Preview: no mostrar conductores reales («Conductores de producción: no visibles en Preview») y mostrar «Asignar / Editar plan QA» solo para conductores QA.

f) 27d207e: textos de exigencia «simulada» en Preview y compuerta de VeriPagos solo con `!_environment.isPreview`.

Método: `git show bf5ead2 -- lib/admin_driver_subscriptions.dart | git apply --3way`, luego lo mismo con 27d207e, y revisar cada hunk a mano. No usar cherry-pick ni copiar el archivo entero.

Verificación: `grep -n "'admin_driver_subscriptions'"` solo puede aparecer en la rama no-Preview (después del `return;`). `grep -n "admin_preview_driver_subscription_candidates"` debe aparecer en la carga Preview.

### 3.3 `lib/admin_environment_store.dart`

En `420db6c`, `isProduction => !isPreview` (líneas 18–19) deja pasar canales inválidos a Producción. Portar el único hunk de `git diff 420db6c aaae599 -- lib/admin_environment_store.dart`: comentario de cabecera, `_assertValidChannel()` y los getters `isPreview` / `isProduction` validados. Los demás métodos son iguales en ambas ramas.

### 3.4 `test/admin_environment_store_test.dart`

Archivo nuevo, tal cual de `aaae599`: canales exactos y canales inválidos que lanzan `StateError`.

### 3.5 `docs/preview/migrations/20261011_shared_db_subscriptions_qa_candidates.sql`

Archivo nuevo, tal cual de `aaae599`. Es documentación de una RPC que ya existe en la base. **No ejecutar contra ninguna base.** La CI lo lee (línea 138).

### 3.6 `.github/workflows/validate-preview-production-split.yml` (decisión del propietario)

- **Recomendado:** añadir un paso nuevo con solo las aserciones de 22/25, store y SQL de `aaae599` (bloque 3, líneas 19–23, 77, 125–135 y 137–158), más el paso `flutter test test/admin_environment_store_test.dart`. No borrar ni cambiar pasos existentes. No desactivar ninguna aserción.
- **Alternativa:** portar el bloque completo. Quedaría en rojo con 50 fallos fuera de alcance. `AGENTS.md` exige que este workflow siga en verde, así que no se recomienda.

### 3.7 `docs/CHANGELOG_ACTIVE.md`

Entrada nueva al inicio, con fecha 2026-10-11 (regla del repositorio: código cambiado = documentación cambiada).

## 4. No portar

- `lib/admin_detail_dialogs.dart` y `lib/admin_control_sections.dart`: tienen identidad, carrusel y visor de nuestra rama. La versión de `aaae599` no los tiene.
- `lib/admin_panel.dart`, salvo el set de 3.1. El resto difiere en 1 058 líneas y eliminaría el filtro de identidad.
- `docs/sql/2026-10-11_admin_identity_pending_driver_ids.sql`: debe permanecer.
- `lib/admin_driver_priority.dart`: `aaae599` cambia la UI con tokens y widgets que no existen en `420db6c`. La lógica de 25 ya es correcta.
- `lib/core/*`, `web/index.html`, `.github/workflows/deploy-web.yml`, `docs/preview/SINGLE_SUPABASE_RESTORED_20261011.md`.
- Cualquier SQL nuevo o migración aplicada a la base.

## 5. Riesgos y decisiones

| # | Nivel | Riesgo | Mitigación |
|---|---|---|---|
| R1 | Bloqueante | Desbloquear 22 sin el hunk de carga expone conductores reales en Preview | No desbloquear 22 sin el punto 3.2 b |
| R2 | Alto | Un canal inválido cae en Producción | Punto 3.3 |
| R3 | Alto | Las RPC de escritura de Suscripciones no reciben canal; el aislamiento depende de la rama del cliente | Verificar cada rama (2.5). Recomendación al propietario: añadir `p_channel` y aserción de servidor en una migración futura, con revisión aparte |
| R4 | Alto | Flutter no está disponible: la compilación no está verificada | No mergear sin `flutter analyze` y los dos `flutter build web` |
| R5 | Medio | CI en rojo si se porta el bloque completo | Punto 3.6 |
| R6 | Medio | Historias sin ancestro: pérdida de identidad si se toman archivos completos | Sección 4 |
| R7 | Medio | Regla de rol en conflicto (`CLAUDE.md` cargado frente a `8c917dc`) | Sección 1 |
| R8 | Bajo | La RPC de candidatos ya está en la base sin constancia en el repositorio | Confirmar en el historial de migraciones |

## 6. Pruebas exigidas

Con Flutter disponible (CI o entorno local):

1. `flutter pub get` y `flutter analyze` sin errores nuevos.
2. `flutter test test/admin_environment_store_test.dart`, y el resto de tests existentes.
3. `flutter build web --release --dart-define=ADMIN_ENV=production`.
4. `flutter build web --release --base-href /preview/ --dart-define=ADMIN_ENV=preview`.
5. El bloque nuevo de aserciones con `python3 -I`: todas en PASS.
6. Greps: `_previewScopedModules` contiene 22 y 25; `admin_driver_subscriptions` aparece solo fuera de Preview; la identidad sigue presente («Identidad por revisar», `admin_identity_pending_driver_ids`, `scrollDirection: Axis.horizontal`, `Dialog(` en `admin_detail_dialogs.dart`).

Manual en Preview (solo lectura en la base; sin escrituras en Producción):

7. Suscripciones muestra solo conductores QA. No aparece ningún conductor real.
8. Crear o editar un plan QA y asignar plan: se guarda en `admin_environment_config`. Las tablas reales no cambian (comprobar con SELECT).
9. VeriPagos en Preview muestra «simulado» y no llama a `driver-subscription-admin` (revisar la red del navegador).
10. Prioridad muestra solo QA, y guardar escribe solo en la configuración de Preview.
11. Identidad, carrusel, filtro y visor sin regresión.
12. Producción (`/`) sin cambios visibles en Suscripciones ni Prioridad.

## 7. Estado de esta sesión

- Commits: solo documentación (este archivo y `docs/CHANGELOG_ACTIVE.md`). Sin cambios de código.
- Base de datos: tres consultas de solo lectura sobre el catálogo (funciones, firmas, columnas y definiciones). Ninguna escritura.
- No hubo push a `main`, ni PR, ni merge, ni despliegue, ni ejecución de workflows.

## 8. Bloque de verificación reproducible

- `git merge-base 420db6c aaae599` (vacío); `git diff --stat 420db6c aaae599 -- lib .github docs test`.
- `git show aaae599:.github/workflows/validate-preview-production-split.yml`, extracción de los tres bloques `python3 - <<'PY'`, ejecución con `python3 -I` dentro del worktree.
- `git grep` de `_previewScopedModules`, `Identidad por revisar`, `admin_identity_pending_driver_ids`, `scrollDirection: Axis.horizontal` sobre `420db6c` y `aaae599`.
- `which flutter dart` (sin salida).

## 9. Formato de devolución

`docs/AI_RESPONSE_FORMAT.md` no existe en el repositorio. Esta es la forma que se pide:

1. SHA del commit y lista de archivos cambiados, con motivo de cada uno.
2. Mapa de cada hunk portado a su commit de origen (bf5ead2, 27d207e, 4fc7655, store, test, SQL).
3. Salida literal de `flutter analyze`, `flutter test` y los dos builds, o «no disponible» con el motivo.
4. Salida del bloque de aserciones.
5. Resultado de los greps de la sección 6.
6. Confirmación de que no hubo escrituras en la base, despliegues ni cambios en Producción.
7. Desviaciones respecto de esta especificación y por qué.

## 10. PROMPT PARA LA IA PROGRAMADORA

```
PROMPT PARA LA IA PROGRAMADORA — Preview: desbloqueo de Suscripciones (22) y Prioridad (25)

CONTEXTO
- Repo: jorge2610g/Adminexpress (panel administrativo web en Flutter).
- Trabaja SOLO en la rama claude/preview-authorized-2026-10-11 (base 420db6c).
- No hagas push a main, no abras PR, no hagas merge, no despliegues, no ejecutes workflows.
- No escribas en la base de datos. Solo SELECT si lo necesitas. No apliques el SQL de la sección 3.5.
- Producción está en 30e6058 y no debe cambiar. Estos cambios son solo para Preview.
- La rama ya contiene: revisión de identidad por foto, carrusel de documentos, casillas de vehículo, visor de documentos, quitar la pestaña duplicada, y el filtro «Identidad por revisar» con la RPC admin_identity_pending_driver_ids. Nada de eso debe perderse ni cambiar.

QUÉ LEER PRIMERO
1. docs/specs/SPEC-2026-10-11-preview-suscripciones-prioridad.md, completo. Secciones 2, 3 y 4 son obligatorias.
2. AGENTS.md y docs/admin-preview-production.md (reglas Preview/Producción).
3. Referencia de solo lectura: commit aaae599 del branch chatgpt/admin-preview-independent-20261010. El objeto está en el clon local. Si falta: git fetch origin chatgpt/admin-preview-independent-20261010.

TAREA EXACTA (en este orden)
1. lib/admin_panel.dart: en _previewScopedModules (líneas 244–246) añade 22 y 25. Actualiza el comentario como en 4fc7655. No toques nada más del archivo.
2. lib/admin_driver_subscriptions.dart: porta íntegros bf5ead2 y 27d207e, hunk a hunk. Puedes usar git show <sha> -- lib/admin_driver_subscriptions.dart | git apply --3way y resolver conflictos a mano. Obligatorio:
   a) _isQaDriver: añade if (driver['is_qa'] == true) return true;
   b) La carga Preview llama a admin_preview_driver_subscription_candidates con p_zone_id y p_search, y usa qaDrivers = _maps(rawDrivers). Ya no llama admin_driver_subscriptions ni filtra en el cliente.
   c) En Preview ninguna llamada RPC sin canal puede ejecutarse. Las escrituras y lecturas de producción quedan en la rama else o después de return.
   d) VeriPagos en Preview: connected false, simulated true, verified_at null, mensajes «Preview: …».
   e) Preview: sin editar métodos de cobro reales; sin conductores reales; «Asignar / Editar plan QA» solo para QA.
   f) Compuertas de VeriPagos con !_environment.isPreview.
3. lib/admin_environment_store.dart: porta el único hunk de git diff 420db6c aaae599 -- lib/admin_environment_store.dart: _assertValidChannel() y los getters isPreview / isProduction validados. Canales inválidos lanzan StateError. Resto igual.
4. test/admin_environment_store_test.dart: archivo nuevo, tal cual de aaae599.
5. docs/preview/migrations/20261011_shared_db_subscriptions_qa_candidates.sql: archivo nuevo, tal cual de aaae599. Solo documentación. NO lo ejecutes.
6. .github/workflows/validate-preview-production-split.yml: añade un paso nuevo con SOLO las aserciones de 22/25, store y SQL, copiadas literalmente de aaae599 (bloque 3, líneas 19–23, 77, 125–135, 137–158), y el paso flutter test test/admin_environment_store_test.dart. No borres ni cambies pasos existentes. No desactives ninguna aserción.
7. docs/CHANGELOG_ACTIVE.md: entrada con fecha 2026-10-11 que describa el port y su alcance.

NO PORTAR
- lib/admin_detail_dialogs.dart, lib/admin_control_sections.dart, docs/sql/2026-10-11_admin_identity_pending_driver_ids.sql, lib/core/*, lib/admin_driver_priority.dart, web/index.html, .github/workflows/deploy-web.yml, docs/preview/SINGLE_SUPABASE_RESTORED_20261011.md.
- Cualquier otro archivo de aaae599 fuera de los 7 puntos.
- No copies archivos enteros de aaae599: las historias no tienen ancestro común.
- No añadas aserciones de tarifas, países, zonas, login, despliegue ni web/index.html. Quedan fuera de esta fase.

RESTRICCIONES
- No cambies identidad, carrusel, filtro «Identidad por revisar», visor ni RPC. No añadas RPC ni migraciones.
- Mantén las etiquetas de Preview ya existentes. No toques la UI de Producción.

CÓMO PROBAR
- flutter pub get; flutter analyze; flutter test test/admin_environment_store_test.dart; flutter build web --release --dart-define=ADMIN_ENV=production; flutter build web --release --base-href /preview/ --dart-define=ADMIN_ENV=preview.
- Si Flutter no está disponible en tu entorno, dilo explícitamente. No declares nada como verificado.
- El bloque nuevo de aserciones debe pasar con python3 -I dentro de la rama.
- grep -n "'admin_driver_subscriptions'" lib/admin_driver_subscriptions.dart: solo fuera de la rama Preview.
- grep -n "admin_preview_driver_subscription_candidates" lib/admin_driver_subscriptions.dart: en la carga Preview.
- grep -n "Identidad por revisar\|admin_identity_pending_driver_ids\|scrollDirection: Axis.horizontal" lib/admin_panel.dart lib/admin_detail_dialogs.dart: presentes.

FORMATO DE DEVOLUCIÓN
Responde en español con:
(1) SHA del commit y archivos cambiados con motivo;
(2) mapa de cada hunk portado a su SHA de origen;
(3) salida literal de analyze, test y builds, o «no disponible» con el motivo;
(4) salida del bloque de aserciones;
(5) resultado de los greps;
(6) confirmación de que no hubo escrituras en base, despliegues ni cambios en Producción;
(7) desviaciones respecto de esta spec y por qué.
Haz push solo a claude/preview-authorized-2026-10-11.
```

## 11. Actualización 2026-10-11 (HEAD `3d2a680`): decisión de esta sesión y prompt vigente

### 11.1 Estado verificado (solo lectura; sin consultas a la base)

- HEAD `3d2a680` sobre `a430e0d` y `420db6c`. `a430e0d` es solo documentación. **`3d2a680` sí contiene código**: `lib/admin_panel.dart` (7 y 17 salen de `_previewScopedModules`), `.github/workflows/validate-preview-production-split.yml` (7 y 17 pasan a la lista de bloqueados) y `docs/CHANGELOG_ACTIVE.md`. Autor del commit: `Claude <noreply@anthropic.com>`. La cabecera y la sección 7 describen `a430e0d`, no HEAD.
- `_previewScopedModules` en HEAD: `{0,1,2,3,4,5,6,8,10,11,14,16,18,27}`. No contiene 22 ni 25.
- Bloques Python del workflow actual, ejecutados con `python3 -I` desde la raíz del worktree (rc 0 en los tres): **bloque A** (líneas 86–134, «global Builds, Audit, Reports»), **bloque B** (140–159, «identidad solo manual») y **bloque C** (166–215, «same physical Supabase; immutable Preview channel; unsafe modules fail closed»). El bloque C contiene las listas `for safe` (línea 198) y `for blocked` (línea 200) de `_previewScopedModules`.
- Bloque 3 de `aaae599` ejecutado sobre HEAD: aborta en la línea 19 de su script (`void _assertValidChannel()` en el store). No hay recuento: el bloque aborta en el primer fallo.
- Ausentes en HEAD: `_assertValidChannel` en `lib/admin_environment_store.dart`; `admin_preview_driver_subscription_candidates` en `lib/admin_driver_subscriptions.dart`; `test/admin_environment_store_test.dart`; `docs/preview/migrations/20261011_shared_db_subscriptions_qa_candidates.sql`.
- Identidad presente: «Identidad por revisar (» en `lib/admin_panel.dart:4639`; `admin_identity_pending_driver_ids` en `lib/admin_panel.dart:398`; `scrollDirection: Axis.horizontal` en `lib/admin_panel.dart:3372` y `lib/admin_detail_dialogs.dart:1301`.
- `lib/admin_driver_subscriptions.dart` de HEAD: la carga Preview (desde la línea 102) todavía llama a `'admin_driver_subscriptions'` (línea 134) y filtra QA en el navegador (línea 142). Riesgo R1 vigente.
- Flutter no está instalado. No se ejecutaron `flutter analyze`, `flutter test` ni los builds.

### 11.2 Decisión de esta sesión

- **No se aplica el port.** La petición de portar `bf5ead2`, `27d207e`, el set de `4fc7655`, el store, el test, el SQL documental, los pasos de CI y el CHANGELOG no se ejecuta. El `CLAUDE.md` cargado en esta sesión dice que Claude no programa y que, ante cambios de código, escribe una especificación. Esta sección y el prompt de 11.5 son esa especificación.
- Regla vigente: la del `CLAUDE.md` cargado (decisión del propietario, 2026-10-10). El commit `8c917dc` (autor Claude, 2026-10-11 03:41 UTC, rama `claude/roles-claude-programa-2026-10-11`) la cambia a «Claude programa». No está en `main` ni en esta rama, así que no se toma como vigente. Sigue pendiente la decisión del propietario (R7).
- `3d2a680` fue escrito por Claude en esta rama, lo que contradice la regla vigente. Esta sesión no lo revierte, porque revertirlo también sería editar código. Decisión pendiente del propietario: mantenerlo (solo bloquea dos módulos en Preview) o revertirlo con la IA programadora (R9).
- Si el propietario confirma que Claude puede programar, el prompt de 11.5 puede ejecutarse en esta misma rama en una sesión con esa autorización.

### 11.3 Correcciones a la sección 3.6 y a la sección 10

1. **Listas del bloque C.** Desbloquear 22 y 25 exige cambiar dos listas existentes: añadir `'22'` y `'25'` a `for safe` (línea 198) y quitarlos de `for blocked` (línea 200). Sin eso, el bloque C falla en cuanto 22 y 25 entran en el conjunto. Es la única edición permitida a un paso existente. La regla «no cambiar pasos existentes» de 3.6 queda limitada a esto.
2. **Lista de seguros copiada de `aaae599`.** La línea 260 de `aaae599` (cabecera de `for safe in [...]`) incluye `'7'` y `'17'`. En HEAD no están en el conjunto, así que la aserción fallaría. Usar `['0','1','2','3','4','5','6','8','10','11','14','16','18','22','25','27']`. No incluir 7 ni 17 en ningún paso.
3. **Preámbulo del paso nuevo.** Las aserciones copiadas usan `panel` y `env_store`, definidas en líneas que no se copian. Sin preámbulo el paso falla con `NameError`. `subscriptions`, `sql` y `priority` sí se definen dentro del rango copiado.
4. **Rangos de `aaae599` (líneas del archivo YAML):** 203–207 (store), 260–261 (seguros, con la corrección del punto 2) y 307–342 (suscripciones, SQL, prioridad y sección 22). La línea 317 es `assert "selectedZone == null || _environment.isPreview" in subscriptions`; copiarla completa (contiene `||`).
5. **Ubicación en el workflow:** el paso nuevo de aserciones va después del paso «Guard shared Supabase and fail-closed Preview routing» (línea 162) y antes de «Analyze admin modules» (línea 218). El paso `flutter test test/admin_environment_store_test.dart` va después de «Verify active polygon vs radio zone labels» (línea 237).

### 11.4 Riesgos abiertos

| # | Nivel | Riesgo | Estado |
|---|---|---|---|
| R1 | Bloqueante | Desbloquear 22 sin portar bf5ead2 expone conductores reales en Preview | Vigente. 22 sigue bloqueado en HEAD. |
| R4 | Alto | Flutter no disponible: compilación y tests sin verificar | Abierto |
| R7 | Medio | Regla de rol en conflicto (CLAUDE.md cargado frente a `8c917dc`) | Decisión del propietario |
| R9 | Medio | `3d2a680` contiene código escrito por Claude en esta rama | Decisión del propietario: mantener o revertir |
| R10 | Medio | La sección 3.6 y el prompt de la sección 10 no cubrían las listas del bloque C, los 7 y 17 ni el preámbulo | Corregido en 11.3 |

### 11.5 PROMPT PARA LA IA PROGRAMADORA (vigente; sustituye a la sección 10 para HEAD `3d2a680`)

```
PROMPT PARA LA IA PROGRAMADORA — Preview: Suscripciones (22) y Prioridad (25), sobre HEAD 3d2a680

CONTEXTO
- Repo: jorge2610g/adminexpress (panel administrativo web en Flutter).
- Rama: claude/preview-authorized-2026-10-11. Trabaja SOLO en esta rama. HEAD 3d2a680 (sobre a430e0d y 420db6c).
- Producción está en 30e6058 y no debe cambiar. Estos cambios son solo para Preview.
- Prohibido: push a main, PR, merge, despliegues, ejecutar workflows de GitHub y escribir en la base de datos. SELECT solo si lo necesitas. No apliques el SQL de docs/preview/migrations.
- No toques ni reviertas lo que ya existe: identidad por foto, carrusel de documentos, casillas de vehículo, visor de documentos, quitar la pestaña duplicada y el filtro «Identidad por revisar» con admin_identity_pending_driver_ids. 3d2a680 deja Zonas (7) y Cobertura (17) fuera de Preview: no los reabras.

QUÉ LEER PRIMERO
1. docs/specs/SPEC-2026-10-11-preview-suscripciones-prioridad.md: secciones 2, 3, 4 y 11 son obligatorias. La sección 11 prevalece sobre la cabecera y la sección 10.
2. AGENTS.md y docs/admin-preview-production.md.
3. Referencia de solo lectura: commit aaae599 (si falta: git fetch origin chatgpt/admin-preview-independent-20261010). Otros commits de referencia: 4fc7655 (comentario y set), bf5ead2 y 27d207e (suscripciones).

TAREA (en este orden)
1. lib/admin_panel.dart: en _previewScopedModules añade 22 y 25. Resultado: {0,1,2,3,4,5,6,8,10,11,14,16,18,22,25,27}. Actualiza el comentario como en 4fc7655, sin reabrir 7 ni 17. No toques nada más del archivo.
2. lib/admin_driver_subscriptions.dart: porta bf5ead2 y 27d207e hunk a hunk (git show <sha> -- lib/admin_driver_subscriptions.dart | git apply --3way, y resuelve a mano). No copies el archivo entero de aaae599. Obligatorio:
   a) _isQaDriver: al inicio, if (driver['is_qa'] == true) return true;
   b) Carga Preview: llama a 'admin_preview_driver_subscription_candidates' con 'p_zone_id': widget.zoneId y 'p_search': search.text.trim(); usa final qaDrivers = _maps(rawDrivers);. Ya no llama a 'admin_driver_subscriptions' ni filtra QA en el navegador.
   c) En Preview ninguna RPC sin canal puede ejecutarse. Las escrituras (plan, ajustes de zona, asignación, proveedor) quedan en la rama else de if (_environment.isPreview). Las lecturas de producción quedan después de return;. Revisa la verificación de proveedor (≈957 en HEAD): en Preview no llama a la Edge Function driver-subscription-admin.
   d) VeriPagos en Preview: connected: false, simulated: true, verified_at: null, mensajes que empiecen por «Preview: ». Nunca decir que hay conexión real.
   e) Preview: «Editar métodos de suscripción» deshabilitado, con aviso _AdminSubNotice; no editar métodos de cobro reales; no mostrar conductores reales («Conductores de producción: no visibles en Preview»); «Asignar / Editar plan QA» solo para conductores QA.
   f) Compuertas de VeriPagos con !_environment.isPreview (27d207e) y textos «simulada» en Preview.
3. lib/admin_environment_store.dart: porta solo el hunk de `git diff 420db6c aaae599 -- lib/admin_environment_store.dart`: comentario de cabecera, _assertValidChannel() y getters isPreview / isProduction validados. Canales inválidos lanzan StateError('Canal administrativo inválido: operación bloqueada'). El resto no cambia.
4. test/admin_environment_store_test.dart: archivo nuevo, tal cual: git show aaae599:test/admin_environment_store_test.dart
5. docs/preview/migrations/20261011_shared_db_subscriptions_qa_candidates.sql: archivo nuevo, tal cual: git show aaae599:docs/preview/migrations/20261011_shared_db_subscriptions_qa_candidates.sql. Solo documentación. NO se ejecuta.
6. .github/workflows/validate-preview-production-split.yml:
   6a) Paso existente, bloque C (líneas 166–215, el que contiene _previewScopedModules): añade '22' y '25' a la lista for safe (línea 198) y quítalos de la lista for blocked (línea 200). Es la única edición permitida a un paso existente y es obligatoria, porque sin ella el bloque C falla.
   6b) Paso nuevo `- name: Preview 22/25 guards`, después del paso de la línea 162 y antes del de la línea 218, con run: | y un bloque python3 - <<'PY' … PY. Contenido, en este orden:
       - Preámbulo (3 líneas, con 10 espacios de indentación como el resto del bloque):
           from pathlib import Path
           env_store = Path('lib/admin_environment_store.dart').read_text()
           panel = Path('lib/admin_panel.dart').read_text()
       - Líneas 203–207 de aaae599 (aserciones del store).
       - Líneas 260–261 de aaae599, con UNA corrección: la lista debe ser ['0','1','2','3','4','5','6','8','10','11','14','16','18','22','25','27']. No incluyas '7' ni '17'.
       - Líneas 307–342 de aaae599, literales (la línea 317 contiene ||).
     Extracción: git show aaae599:.github/workflows/validate-preview-production-split.yml | sed -n '203,207p;260,261p;307,342p'
   6c) Paso nuevo `- name: Store channel tests` con run: flutter test test/admin_environment_store_test.dart, después del paso de la línea 237.
   No cambies una aserción para que pase: si falla, corrige la app. No borres pasos ni desactives aserciones. No añadas aserciones de tarifas, países, zonas, login, despliegue ni web/index.html.
7. docs/CHANGELOG_ACTIVE.md: entrada nueva con fecha 2026-10-11 que describa el port y su alcance (22 y 25 en Preview, store fail-closed, RPC de candidatos QA, aserciones de CI).

NO PORTAR
- lib/admin_detail_dialogs.dart, lib/admin_control_sections.dart, docs/sql/2026-10-11_admin_identity_pending_driver_ids.sql, lib/core/*, lib/admin_driver_priority.dart, web/index.html, .github/workflows/deploy-web.yml, docs/preview/SINGLE_SUPABASE_RESTORED_20261011.md.
- Ningún otro archivo de aaae599. No copies archivos enteros de aaae599: no tienen ancestro común.
- No revertas 3d2a680 ni reabras 7 y 17 sin decisión del propietario.

RESTRICCIONES
- No cambies identidad, carrusel, filtro «Identidad por revisar», visor de documentos ni RPC. No añadas RPC ni migraciones.
- No toques la UI de Producción.

CÓMO PROBAR
- flutter pub get; flutter analyze; flutter test test/admin_environment_store_test.dart; flutter build web --release --dart-define=ADMIN_ENV=production; flutter build web --release --base-href /preview/ --dart-define=ADMIN_ENV=preview.
- Si Flutter no está en tu entorno, dilo. No declares nada como verificado.
- Python: el paso nuevo y los bloques A, B y C deben pasar con python3 -I desde la raíz de la rama.
- grep -n "'admin_driver_subscriptions'" lib/admin_driver_subscriptions.dart: solo fuera de la rama Preview.
- grep -n "admin_preview_driver_subscription_candidates" lib/admin_driver_subscriptions.dart: en la carga Preview.
- grep -n "Identidad por revisar\|admin_identity_pending_driver_ids\|scrollDirection: Axis.horizontal" lib/admin_panel.dart lib/admin_detail_dialogs.dart: presentes.
- En _previewScopedModules deben estar 22 y 25, y no 7 ni 17.

FORMATO DE DEVOLUCIÓN (docs/AI_RESPONSE_FORMAT.md no existe en el repo; usa este)
Responde en español con:
(1) SHA del commit y archivos cambiados con motivo;
(2) mapa de cada hunk portado a su SHA de origen (4fc7655, bf5ead2, 27d207e, hunk de store, test, SQL, pasos de CI);
(3) salida literal de flutter analyze, flutter test y los dos builds, o «no disponible» con el motivo;
(4) salida del paso nuevo y de los bloques A, B y C con python3 -I;
(5) resultado de los greps;
(6) confirmación de que no hubo escrituras en base de datos, despliegues, ejecución de workflows ni cambios en Producción;
(7) desviaciones respecto de esta spec y por qué.
Haz push solo a claude/preview-authorized-2026-10-11.
```
