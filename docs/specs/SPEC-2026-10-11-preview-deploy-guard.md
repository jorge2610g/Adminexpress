# SPEC-2026-10-11 — Guard permanente para el despliegue de /preview/

| Campo | Valor |
|---|---|
| Estado | PROPUESTA, no aprobada. Requiere las decisiones D1 a D6 del propietario (sección 6). |
| Fecha | 2026-10-11 (UTC) |
| Autor | Claude (arquitectura y revisión). La implementación la hace la IA programadora que designe el propietario. |
| Repositorio | jorge2610g/Adminexpress |
| Referencias | origin/main = 242810931a0d230e79450d4137106437b2343e6e. Rama ChatGPT `chatgpt/admin-preview-independent-20261010` = aaae59949b80ba9c321067b1fbfee20f408e5ed3. Producción = 30e60582a337be3911671742d780b240793497df (no debe cambiar). |
| Archivos afectados | `.github/workflows/deploy-web.yml` (modificación propuesta), `docs/PREVIEW_AUTHORIZED.md` (nuevo), documentación de Preview. |

Esta spec no autoriza despliegues, dispatch ni pushes a main. En esta fase Claude no modificó workflows ni código de la app.

## 1. Problema

GitHub Pages sirve un único sitio: `/` (Producción) y `/preview/` (Preview). Cada despliegue publica el sitio completo. No existe ningún registro del SHA que debe estar en `/preview/`. Cualquier push con etiqueta, cualquier `preview-sha=` en un mensaje de commit y cualquier dispatch con `preview_source_sha` reemplaza `/preview/`.

Hoy eso ocurrió 11 veces, con 11 SHA distintos (sección 2.2). El módulo de suscripciones (`lib/admin_driver_subscriptions.dart`) existe en aaae599 y en f224384, y no existe en origin/main ni en 420db6c. Estuvo en vivo entre 03:41:20 y 03:53:48 UTC, y entre 04:16:41 y 04:22:27 UTC. Se perdió al publicarse 51fb7a9 (03:53:48), y de nuevo al publicarse dbbae54 (04:22:27) y 420db6c (04:24:56).

Objetivo: `/preview/` solo puede publicar el SHA que el propietario haya fijado en un archivo versionado. Ningún push o dispatch normal reemplaza `/preview/` con otro código. Producción no cambia.

## 2. Estado verificado

### 2.1 Condiciones de cada job

Lectura de `origin/main` (`git show origin/main:.github/workflows/deploy-web.yml`). El YAML se verificó con PyYAML 6.0.1 y las condiciones se revisaron a mano.

- `on`: push a `main`. `workflow_dispatch` con `preview_only` (boolean, default false) y `preview_source_sha` (string).
- `concurrency`: grupo `adminexpress-pages`, `cancel-in-progress: true`.
- Job `build` (Producción y Preview), `if`: `!contains(github.event.head_commit.message, '[deploy-preview-only]') && !(inputs.preview_only == true)`. No comprueba la rama. Construye Producción (`--base-href /`) y Preview (`--base-href /preview/`) desde el checkout del ref que ejecuta el run.
- Job `preview_only`, `if`: `contains(github.event.head_commit.message, '[deploy-preview-only]') || inputs.preview_only == true`. Fuente del SHA de Preview: en push, `github.sha`, salvo que el mensaje contenga `preview-sha=<40 hex>`, en cuyo caso gana ese valor. En dispatch, el input `preview_source_sha`. Solo valida 40 hex y, en dispatch, que no sea igual a `github.sha`. Restaura los bytes de Producción desde el run `38071887995` y compara 4 archivos con el sitio vivo.
- Job `deploy`, `if`: `always() && (needs.build.result == 'success' || needs.preview_only.result == 'success')`. Publica con `actions/deploy-pages` y verifica los `version.json` después de publicar.

Lectura de aaae599 (`chatgpt/admin-preview-independent-20261010`; esta rama no está en main):

- `on.push.branches`: `main` y la rama ChatGPT. `concurrency.cancel-in-progress: false`.
- `build`, `if`: `github.ref == 'refs/heads/main' && ...`. Sí restringe la rama.
- `preview_only`, `if`: `(github.ref == 'refs/heads/chatgpt/admin-preview-independent-20261010' && contains(...)) || (github.event_name == 'workflow_dispatch' && inputs.preview_only == true)`. Un push a main con etiqueta no ejecuta ningún job.
- Fuente del SHA: igual que en main. Run pinned de Producción: `38080952559`.
- Validaciones más estrictas que main: ausencia de `_previewUnlockAllModules = true`, presencia de `admin_preview_driver_subscription_candidates` en el JS compilado, `buildSha` estampado en el HTML, y comprobación en vivo de `index.html` y `main.dart.js`.

Consecuencias que determinan los despliegues:

1. Push a main sin `[deploy-preview-only]` en el último commit: se ejecuta `build` y se publican Producción y Preview desde main. Esto contradice `docs/CHANGELOG_ACTIVE.md` (línea 62), que dice que la actualización de Preview desde main solo ocurre con la etiqueta.
2. Push a main con la etiqueta en el último commit: se ejecuta `preview_only`. El SHA es el head del push o el `preview-sha=` del mensaje. Producción no se reconstruye.
3. Dispatch con `preview_only=true`: se ejecuta `preview_only` con el SHA del input. Acepta cualquier SHA de 40 hex del repositorio.
4. Dispatch con `preview_only=false` en origin/main: se ejecuta `build` desde el ref seleccionado, sin restricción de rama. Según la lectura de la condición, eso publicaría Producción desde esa rama. No se ha ejecutado hoy; no verificado en un run.
5. Solo se evalúa el mensaje del `head_commit` (último commit del push).
6. Cancelación: en origin/main, un run nuevo cancela el anterior del mismo grupo.

Dato relevante: 30e6058 no es ancestro de origin/main (`git merge-base --is-ancestor`). Un build desde main no reproduce Producción.

### 2.2 Línea de tiempo de hoy (2026-10-11, UTC)

Fuente: API de Actions (`list_workflow_runs` para `deploy-web.yml`). Hay 34 runs de hoy; la página contiene runs desde el 2026-10-05, así que cubre todo el día. El SHA de Preview se leyó del log del job `preview_only` (`git checkout --force <SHA>` y `HEAD is now at`) cuando hay log. Si no, se indica con `*` y es el `head_sha` del push, que es la regla del workflow.

| Run | Id | Inicio (UTC) | Evento | Rama | SHA de Preview | Conclusión | Publicación terminada |
|---|---|---|---|---|---|---|---|
| 199 | 38100138872 | 02:47:37 (encolado desde 00:56:43) | push | chatgpt | 3ec180a* | success | n/d* |
| 208 | 38107103114 | 03:02:28 | push | chatgpt | 232d6e3* | success | n/d* |
| 210 | 38107325006 | 03:06:33 | push | chatgpt | 294090b* | success | n/d* |
| 213 | 38108027140 | 03:19:53 | push | chatgpt | c3a2c5c* | success | n/d* |
| 219 | 38109073409 | 03:39:10 | push | chatgpt | f224384 | success | 03:41:20 |
| 220 | 38109719565 | 03:51:21 | dispatch | main | 51fb7a9 | success | 03:53:48 |
| 221 | 38110153058 | 03:59:48 | dispatch | main | d9538e6 | success | 04:02:09 |
| 225 | 38110644608 | 04:08:44 | dispatch | main | 53ddbfd | cancelled (04:10:18) | no |
| 226 | 38110676142 | 04:09:21 | push | chatgpt | 1f566ec* | cancelled | no |
| 227 | 38110724671 | 04:10:15 | dispatch | main | 4910f2f | failure en `flutter analyze` | no |
| 228 | 38110848098 | 04:12:34 | dispatch | main | 095c2a8 | success | 04:14:25 |
| 229 | 38110854659 | 04:12:41 | push | chatgpt | aaae599 | success | 04:16:41 |
| 230 | 38111234356 | 04:19:51 | dispatch | main | dbbae54 | success | 04:22:27 |
| 231 | 38111383237 | 04:22:35 | dispatch | main | 420db6c | success | 04:24:56 |

Notas:

- Los otros 20 runs de hoy (198, 200 a 207, 209, 211, 212, 214 a 218, 222 a 224) terminaron con conclusión `skipped`. Ningún job publicó.
- Los 7 dispatches de hoy fueron disparados por la cuenta `jorge2610g` (`actor` y `triggering_actor`). La API no distingue si fue manual o desde una herramienta.
- En los 9 runs cuyo log de job se revisó, el job `build` quedó `skipped`. Ningún run de hoy de los revisados reconstruyó Producción. En todos los `preview_only` revisados, la comprobación de bytes de Producción dio PASS.
- Publicaciones exitosas de `/preview/` hoy: 11, con 11 SHA distintos.
- Cancelación: el run 225 quedó cancelado a las 04:10:18, justo después de crearse el 227 (04:10:15). Es una inferencia por timestamps; no está confirmada en los logs.

### 2.3 Estado en vivo (lectura pública, 2026-10-11 04:37 UTC)

- `https://admin.expressviajes.online/version.json`: commit `30e60582a337be3911671742d780b240793497df`, `deployed_at` 2026-10-09T17:54:10Z, `environment` production.
- `https://admin.expressviajes.online/preview/version.json`: commit `420db6c98251be717f1c3a528bf0b63b2f7568cd`, `deployed_at` 2026-10-11T04:24:39Z, `environment` preview.
- `https://admin.expressviajes.online/preview/index.html`: `flutter_bootstrap.js?v=420db6c98251be717f1c3a528bf0b63b2f7568cd`.
- `https://admin.expressviajes.online/preview/main.dart.js`: 4.045.863 bytes; 0 apariciones de `admin_preview_driver_subscription_candidates`.

### 2.4 Hallazgos adicionales

- F1. Artefactos de Producción pinneados. origin/main usa el run `38071887995` (head `3cd62b6`; artefacto `github-pages` id 11677063172), que caduca el 2026-10-11T17:30:23Z. La rama ChatGPT usa el run `38080952559` (head `2428109`; artefacto 11680243385), que caduca el 2026-10-11T19:45:59Z. Ambos tienen retención de 1 día.
- F2. CHANGELOG_ACTIVE.md y admin-preview-production.md, así como el encargo original, citan el run `37969274447` como fuente de Producción. origin/main dejó de usarlo en el commit 280badb (sustitución del `run-id` en `deploy-web.yml`). Esa documentación está desactualizada.
- F3. `main` no tiene protección de rama: `gh api repos/jorge2610g/Adminexpress/branches/main/protection` responde 404 "Branch not protected". Quien tenga permiso de escritura puede empujar a main.
- F4. El gate de contenido de origin/main tiene 6 comprobaciones (`admin_zone_list_scoped`, `admin_driver_kyc_bolivia_manual_review_part`, `AdminEnvironmentLinkButton`, `const supabaseUrl = _productionUrl;`, el guard `_previewScopedModules` y la ausencia de la referencia al proyecto `xbphilqezmwfjfpdbwad`). Pasa para los 7 SHA probados (aaae599, f224384, 51fb7a9, d9538e6, 095c2a8, dbbae54, 420db6c), incluido 420db6c, que no tiene el módulo de suscripciones. El gate no detecta regresiones funcionales.
- F5. El analizador sí bloqueó el run 227: en 4910f2f hay 2 errores de sintaxis en `lib/admin_detail_dialogs.dart` (líneas 831 y 832). Es el único control de calidad que funcionó hoy.
- F6. La verificación de Producción contra el sitio vivo compara solo 4 archivos (`index.html`, `flutter_bootstrap.js`, `main.dart.js`, `version.json`). El resto del sitio solo se compara con el artefacto.
- F7. La rama ChatGPT (aaae599) tiene validaciones más estrictas que main, pero no están en main.
- F8. `AGENTS.md` exige que `.github/workflows/validate-preview-production-split.yml` siga en verde. El archivo existe en origin/main. No se ejecutó en esta fase.
- F9. En el repositorio no existen `docs/specs/`, `docs/AI_ROLES_WORKFLOW.md`, `docs/AI_RESPONSE_FORMAT.md` ni `docs/AI_HANDOFF_2026-10-10_SECURITY_AUDIT.md`, que cita la regla del proyecto. `CLAUDE.md` no existe en `/home/user/adminexpress`. Esta spec usa como formato de devolución el de la sección final.

### 2.5 Validación del YAML

- PyYAML 6.0.1 disponible. Los dos archivos (origin/main y aaae599) parsean sin error.
- `actionlint` no está instalado; no se ejecutó.
- No se modificó ningún workflow.

## 3. Propuesta

### 3.1 (a) Archivo de autorización: `docs/PREVIEW_AUTHORIZED.md`

Archivo nuevo, con un único bloque legible por máquina. Valor propuesto para revisión (decisión D1):

```
# Preview autorizado

Única fuente del SHA que puede publicarse en /preview/. Se cambia solo mediante PR revisado.
Producción no se define en este archivo.

<!-- PREVIEW_AUTHORIZED:BEGIN -->
preview_authorized_sha: aaae59949b80ba9c321067b1fbfee20f408e5ed3
preview_required_paths: lib/admin_driver_subscriptions.dart
approved_by: PENDIENTE (propietario)
approved_at: PENDIENTE
<!-- PREVIEW_AUTHORIZED:END -->
```

Reglas de lectura. El workflow falla si no se cumplen:

- Exactamente un par BEGIN/END.
- `preview_authorized_sha` aparece una sola vez, con 40 caracteres hex en minúsculas.
- Cada ruta de `preview_required_paths` existe en el árbol de ese SHA (`git cat-file -e <sha>:<ruta>`). Una lista vacía está permitida.
- Claves desconocidas dentro del bloque: fallo.

Valor alternativo: `420db6c98251be717f1c3a528bf0b63b2f7568cd` (estado vivo actual). En ese caso `preview_required_paths` debe quedar vacío, porque ese SHA no tiene el módulo de suscripciones.

### 3.2 (b) Reglas de publicación de /preview/

1. Lectura de confianza. El bloque se lee de un commit ya revisado: en push, `github.event.before` (main antes del push); en dispatch, el HEAD de origin/main en el momento del run. Nunca del commit que se empuja ni de la rama desde la que se lanza el dispatch. Si `before` es `0000000`, fallo. Usar `fetch-depth` suficiente para acceder a ese commit.
2. Un único SHA publicable: `preview_authorized_sha`.
   - Push: se publica el autorizado. Si el mensaje trae `preview-sha=<X>` y X no es el autorizado, fallo.
   - Dispatch: si `preview_source_sha` está vacío, se publica el autorizado. Si trae un X distinto, fallo.
   - En ambos casos el fallo ocurre antes de publicar nada.
3. Triggers: `push` solo a `main`. No añadir ramas de ChatGPT ni de Claude.
4. Push a main sin `[deploy-preview-only]`: depende de la decisión D2 (sección 3.3). En ninguna opción puede dejar `/preview/` con código distinto del autorizado.
5. `concurrency`: mismo grupo, `cancel-in-progress: false`.
6. Se conservan los gates de contenido, el analizador, la verificación de Producción por hash y la verificación post-publicación. Se añade la comprobación de `preview_required_paths`.
7. Ningún job toma el SHA de Preview de otra fuente (`github.sha`, input de dispatch o mensaje de commit) si no coincide con el autorizado.

Matriz esperada (con la opción B de D2):

| Caso | Resultado esperado |
|---|---|
| push a main con etiqueta, sin `preview-sha` | publica el Preview autorizado; Producción sin cambios |
| push a main con etiqueta y `preview-sha` igual al autorizado | igual que el caso anterior |
| push a main con etiqueta y `preview-sha` distinto | falla antes de publicar |
| push a main sin etiqueta | `build` de Producción omitido; `/preview/` sin cambios |
| push a una rama distinta de main | ningún job (no está en triggers) |
| dispatch con `preview_only=true` e input vacío | publica el Preview autorizado |
| dispatch con `preview_only=true` e input igual al autorizado | igual que el caso anterior |
| dispatch con `preview_only=true` e input distinto | falla antes de publicar |
| dispatch con `preview_only=false`, desde cualquier rama | ningún job publicador |
| bloque ausente, duplicado, SHA mal formado, SHA inexistente o ruta requerida ausente | falla antes de publicar |

### 3.3 (c) Producción: decisión D2

El encargo pedía que el job de Producción no cambie. Hoy, el build publica Producción desde main en cada push sin etiqueta, y main no contiene 30e6058. No se pueden cumplir a la vez "Producción no cambia" y "no tocar el flujo documentado" sin decidirlo. Dos opciones:

- Opción A. Se mantiene el build de Producción en push sin etiqueta. Su parte de Preview se toma del SHA autorizado, no de main. Producción sigue cambiando con cada push normal, como documenta CHANGELOG_ACTIVE.md.
- Opción B (recomendada). El build se desactiva por defecto. Ningún push ni dispatch normal publica Producción ni Preview. Producción solo cambia con un workflow separado, aprobado por el propietario. Garantiza por construcción que Producción no cambia, pero modifica el flujo documentado y requiere aprobación explícita.

### 3.4 Fuente de los bytes de Producción: decisión D3

Hoy el job `preview_only` restaura Producción desde un artefacto con 1 día de retención (F1). Opciones:

- Opción 1 (preferida). Asset inmutable de un GitHub Release con los bytes de Producción verificados, y su sha256 registrado en `PREVIEW_AUTHORIZED.md`. Requiere que el propietario cree o apruebe el release.
- Opción 2. Manifiesto sha256 de todos los archivos del sitio de Producción en el repositorio. El job descarga desde el sitio vivo y compara. Requiere generar el manifiesto con los bytes actuales (30e6058) antes de que caduque el artefacto, o desde el sitio vivo ya verificado.

Si nada cambia antes de las 17:30 UTC, el run de `preview_only` fallará al descargar el artefacto. El job `deploy` se omite, así que Producción queda intacta, pero `/preview/` no podrá actualizarse hasta resolver D3.

### 3.5 Pasos de implementación (para la IA programadora)

1. Crear `docs/PREVIEW_AUTHORIZED.md` con el bloque de 3.1. Si D1 no está confirmada, dejar `preview_authorized_sha` marcado como TODO y no publicar.
2. Modificar `.github/workflows/deploy-web.yml` según 3.2 y la opción elegida en D2.
3. Cambiar `cancel-in-progress` a `false` en el grupo `adminexpress-pages`.
4. Actualizar `docs/CHANGELOG_ACTIVE.md` y `docs/admin-preview-production.md` con el nuevo flujo. Corregir la referencia al run `37969274447`.
5. No tocar `lib/`, `test/`, `web/`, `pubspec.yaml` ni otros workflows.

## 4. Riesgos

| ID | Severidad | Riesgo | Evidencia | Mitigación |
|---|---|---|---|---|
| R1 | Crítica | Producción puede cambiar. El build de origin/main no filtra la rama. Un push sin etiqueta, o un dispatch con `preview_only=false` desde otra rama, publicaría ese código en `/`. | 2.1 puntos 1 y 4. 30e6058 no es ancestro de main. | D2 (opción B). Restringir el build a `refs/heads/main` o eliminarlo. |
| R2 | Crítica | `/preview/` puede reemplazarse con cualquier SHA. | 11 SHA distintos publicados hoy. | Bloque autorizado y validación previa. |
| R3 | Alta | La autorización es texto libre: `preview-sha=` en el mensaje y el input de dispatch se aceptan con solo validar el formato. | 2.1; runs 220 a 231. | Comparar con el SHA autorizado. |
| R4 | Alta | Autoautorización: un push puede cambiar el archivo y usarlo en el mismo run. main no tiene protección. | F3. | Leer desde `event.before`. D4 (PR obligatorio en main). |
| R5 | Alta | Los artefactos de Producción caducan hoy (17:30 y 19:45 UTC). | F1. | D3 antes de las 17:30 UTC. |
| R6 | Alta | El gate de contenido no detecta la pérdida de funciones. | F4. 420db6c no tiene el módulo de suscripciones. | `preview_required_paths` (D5) y revisión del SHA. |
| R7 | Media | Se cancelan deploys en curso. | `cancel-in-progress: true` en main; run 225 cancelado. | `cancel-in-progress: false`. |
| R8 | Media | La verificación post-publicación no previene nada, porque se ejecuta después de publicar. | Job `deploy`. | Mantener la validación previa a la publicación. |
| R9 | Media | Solo se evalúa el último commit del push. | 2.1, punto 5. | Cubierto por R1 y 3.2. |
| R10 | Media | La verificación de Producción en vivo cubre solo 4 archivos. | F6. | Manifiesto completo (D3, opción 2). |
| R11 | Media | Divergencia: la versión con mejores guardas (ChatGPT) no está en main. | F7. | Llevar esas guardas a main junto con este guard. |
| R12 | Baja | La documentación está desalineada: cita el run `37969274447` y dice que Preview desde main solo ocurre con etiqueta. | F2; 2.1 punto 1. | Actualizar la documentación (paso 4 de 3.5). |
| R13 | Operativa | Hasta que el guard esté en main, cualquier push etiquetado o dispatch puede cambiar `/preview/`. | Hoy ocurrió. | D6 (congelación). |
| R14 | Baja | Trazabilidad: los dispatches usan la cuenta del propietario y no se distingue si son manuales. | 2.2. | Registrar el origen de cada publicación en el informe. |

Aspecto positivo: el analizador bloqueó el commit 4910f2f (F5). Esa comprobación se conserva.

## 5. Pruebas

Ninguna prueba de esta sección dispara workflows ni publica. Las pruebas de despliegue real son P8 y requieren autorización expresa del propietario.

- P1. Sintaxis. `python3 -c` con `yaml.safe_load` sobre el nuevo `deploy-web.yml`. Debe pasar. Si `actionlint` está disponible en el entorno del programador, ejecutarlo también.
- P2. Matriz de condiciones. Comprobar las condiciones `if` del nuevo workflow contra la matriz de 3.2, caso por caso, con el resultado esperado escrito junto a cada comprobación.
- P3. Resolución del SHA. Extraer el paso de resolución y validación a un script, y probarlo con variables de entorno simuladas (`EVENT_NAME`, `PUSH_SHA`, `BEFORE_SHA`, `COMMIT_MESSAGE`, `INPUT_PREVIEW_SHA`) sobre un repositorio git temporal en el directorio de scratchpad. Casos mínimos:
  - bloque válido y push con etiqueta sin `preview-sha`: publica el autorizado;
  - `preview-sha` distinto: falla;
  - dispatch con input vacío: publica el autorizado;
  - dispatch con otro SHA: falla;
  - bloque ausente, duplicado, SHA corto, SHA inexistente o ruta requerida ausente: falla;
  - un push que modifica el archivo en el mismo commit no altera el resultado (se lee `event.before`).
- P4. Gate local. Para el SHA autorizado, ejecutar con `git grep` sobre ese SHA las comprobaciones G1 a G6 y las rutas requeridas. Debe pasar. Repetir con un SHA no autorizado y comprobar que el resultado es el esperado.
- P5. Diff. `git diff --name-only origin/main...HEAD` debe listar solo `deploy-web.yml`, `docs/PREVIEW_AUTHORIZED.md` y la documentación de 3.5. No debe aparecer ningún archivo de `lib/`, `test/`, `web/` ni `pubspec.yaml`.
- P6. Producción intacta (solo lectura). Antes y después de cualquier prueba, `https://admin.expressviajes.online/version.json` debe mostrar el commit `30e60582a337be3911671742d780b240793497df`.
- P7. Validación de AGENTS.md. Leer `validate-preview-production-split.yml` y comprobar que el cambio no rompe sus expectativas. Ejecutarlo solo cuando el propietario ordene abrir el PR.
- P8. Pruebas de despliegue. Solo con autorización expresa del propietario, después del merge: (a) dispatch con `preview_only=true` y un SHA no autorizado: debe fallar sin publicar; (b) dispatch con `preview_only=true` y sin input: `/preview/version.json` debe mostrar el SHA autorizado y Producción debe seguir en 30e6058; (c) push sin etiqueta a main: `/preview/` y Producción sin cambios.

## 6. Decisiones del propietario (bloqueantes)

- D1. SHA autorizado para `/preview/`: aaae599 (incluye suscripciones y pasa G1 a G6), 420db6c (estado vivo) u otro.
- D2. Producción: opción A o B (recomendada B).
- D3. Fuente de los bytes de Producción: release asset o manifiesto. Antes de las 17:30 UTC de hoy.
- D4. Protección de main: exigir PR revisado y bloquear el push directo. Es un ajuste de GitHub que hace el propietario, no Claude.
- D5. ¿El módulo de suscripciones es requisito de Preview? Si lo es, `preview_required_paths` lo incluye.
- D6. Congelación inmediata: mientras el guard no esté en main, no ejecutar dispatch ni publicar commits con `[deploy-preview-only]` en main ni en la rama ChatGPT.

## 7. Criterios de aceptación

- El SHA de `/preview/` es siempre el autorizado. Un intento con otro SHA falla antes de publicar.
- Un push sin etiqueta a main no cambia `/preview/` ni Producción (opción B).
- Producción permanece en 30e6058 y sus bytes no cambian.
- Las pruebas P1 a P5 pasan. El diff se limita a los archivos permitidos.
- La documentación refleja el flujo nuevo y no cita el run `37969274447` como fuente vigente.

## 8. Fuera de alcance

- Auditoría de RPC, Supabase, APK/AAB, pagos y datos reales de Producción.
- Cambios en la app Flutter.
- Configurar la protección de la rama main (decisión y acción del propietario, D4).

## 9. Evidencia reproducible (solo lectura)

- `gh api repos/jorge2610g/Adminexpress/actions/runs/<id>` y `.../actions/runs/<id>/jobs`, para los runs de la tabla 2.2.
- `git show origin/main:.github/workflows/deploy-web.yml` y `git show aaae599:.github/workflows/deploy-web.yml`.
- `git show 280badb -- .github/workflows/deploy-web.yml` (sustitución del run-id).
- `gh api repos/jorge2610g/Adminexpress/actions/runs/38071887995/artifacts` y `.../38080952559/artifacts`.
- `curl -sS https://admin.expressviajes.online/version.json` y `.../preview/version.json`.

## PROMPT PARA LA IA PROGRAMADORA

Contexto
- Repositorio jorge2610g/Adminexpress (Flutter web). GitHub Pages sirve Producción (`/`) y Preview (`/preview/`) con un único deploy: cada publicación reemplaza el sitio completo.
- Hoy `/preview/` se reemplazó 11 veces con SHA distintos (sección 2.2 de esta spec). Producción debe seguir en `30e60582a337be3911671742d780b240793497df`.
- Esta spec es la fuente. No decidas por tu cuenta lo que esté en la sección 6: si falta una decisión, para y pregunta.

Leer antes de editar
1. `docs/specs/SPEC-2026-10-11-preview-deploy-guard.md` (este archivo), completo.
2. `.github/workflows/deploy-web.yml` de origin/main (`git show origin/main:.github/workflows/deploy-web.yml`).
3. `AGENTS.md` y `docs/admin-preview-production.md`.
4. `docs/CHANGELOG_ACTIVE.md`, sección "2026-10-09 — Corrección segura de publicación exclusiva de Preview".

Tarea exacta
1. Crea `docs/PREVIEW_AUTHORIZED.md` con el bloque de la sección 3.1. Si el propietario no confirmó D1, deja `preview_authorized_sha` como TODO y no publiques ni inventes un SHA.
2. Modifica `.github/workflows/deploy-web.yml` según las reglas 1 a 7 de la sección 3.2, la matriz de la sección 3.2 y la opción que el propietario elija en D2 (por defecto, B).
3. Cambia `cancel-in-progress` a `false` en el grupo `adminexpress-pages`.
4. Implementa la lectura de confianza del bloque (`github.event.before` en push; HEAD de origin/main en dispatch) y la validación de la sección 3.1.
5. Actualiza `docs/CHANGELOG_ACTIVE.md` y `docs/admin-preview-production.md` con el nuevo flujo, y corrige la referencia al run `37969274447`.
6. No toques `lib/`, `test/`, `web/`, `pubspec.yaml` ni otros workflows. No añadas workflows nuevos.

Restricciones
- No hagas push a main. No ejecutes `workflow_dispatch` ni ningún despliegue. No hagas merge. No abras PR salvo orden expresa del propietario.
- No escribas en Supabase ni en ninguna base de datos. No toques datos de Producción ni de Preview.
- No cambies los bytes de Producción ni el SHA `30e60582a337be3911671742d780b240793497df`.
- No añadas secretos ni cambies los permisos del workflow.
- Si algo de esta spec no es posible o contradice el repositorio, para y pregunta. No improvises.

Cómo probar (sin desplegar)
- P1 (sintaxis YAML), P2 (matriz de condiciones), P3 (script de resolución con variables simuladas), P4 (gate local con `git grep`) y P5 (diff permitido). Anota el comando y la salida de cada prueba.
- P6: comprueba que `version.json` de Producción sigue en 30e6058. Solo lectura.
- No ejecutes P8 sin autorización expresa del propietario.

Entrega
- Crea una rama nueva. La base puede ser origin/main o la rama `claude/preview-deploy-guard-2026-10-11`, que solo añade esta spec.

Formato de devolución (`docs/AI_RESPONSE_FORMAT.md` no existe en el repositorio; usa este)
1. Rama y SHA del commit.
2. Lista de archivos cambiados.
3. Resumen del cambio por bloque de `deploy-web.yml`.
4. Salida de P1 a P6, copiada tal cual.
5. Decisiones que tomaste y decisiones pendientes (D1 a D6).
6. Riesgos que no pudiste verificar.
