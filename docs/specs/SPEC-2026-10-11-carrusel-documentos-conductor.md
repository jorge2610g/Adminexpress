# SPEC 2026-10-11 · Documentos del conductor en carrusel y revisión de identidad unificada

Autor: Claude (arquitecto/revisor). Ejecuta: IA programadora designada por el propietario.
Estado: pendiente de implementación. No modificar backend ni RPC en esta spec.

## 1. Contexto y evidencia

Captura del panel de producción, ficha de conductor, sección «Documentos e identidad»:

- Tarjeta «Licencia de conducir» con estado **Aprobado**, botones Ver frente, Ver reverso, Rechazar y Reabrir revisión. Ese es el formato correcto.
- Debajo, sección «Revisión de identidad» con 3 filas «Verificación manual» (Pendiente, Pendiente, Aprobado). Son filas de solo lectura, sin botones y sin tarjeta.
- No aparece ninguna tarjeta de documento de identidad en la lista de documentos.
- Resumen operativo: Suscripción «Sin suscripción» (la zona Iquique tiene `enforce_access = false`, así que no se exige).

Código (`lib/admin_detail_dialogs.dart`):

- Líneas ~964–1097: `documents.map(...)` pinta **una columna vertical** de tarjetas con botones Aprobar, Rechazar y Reabrir revisión. Es el patrón que hay que reutilizar.
- Líneas ~1098–1120: «Revisión de identidad» pinta `verifications.take(3)` desde `detail['identity_verifications']`. Esa fuente es la tabla legada `identity_verifications`, sin acciones.
- Línea ~665: ambas listas vienen de `admin_driver_detail`.

Base de datos (solo lectura):

- `admin_driver_detail` devuelve `documents` (todas las filas de `driver_documents`, sin filtrar identidad) e `identity_verifications` (tabla legada).
- La app Express decide si el conductor puede conectarse con `driver_documents`: busca un documento de identidad con `verification_method = 'manual'` y `status = 'verified'`. La regla está en `lib/driver_registration_gate.dart` (PR #163, pendiente de fusión). Mientras no se fusione, la app sigue usando la regla antigua, que toma solo el primer documento de identidad manual (el más reciente).
- Hay dos fuentes de verdad para identidad: `driver_documents` (la app la usa para bloquear) y `identity_verifications` (el panel la muestra sin acciones). Por eso el panel dice «Aprobado» y la app dice «Falta verificar».

Conclusión de la revisión: el panel no permite revisar la identidad que bloquea al conductor, y muestra una fuente distinta de la que usa la app.

## 2. Objetivo

1. Reemplazar la columna vertical de «Documentos e identidad» por un **carrusel horizontal** (desplazable de izquierda a derecha) con **una tarjeta por requisito**.
2. La primera tarjeta es **Documento de identidad**. Después van los demás requisitos en el orden del catálogo (`admin_driver_document_requirement_list`), por ejemplo Licencia de conducir, Vehículo, y los que se agreguen.
3. Cada tarjeta tiene el **mismo formato** que la tarjeta actual: título, chip de estado, Ver frente/Ver reverso/Ver foto facial, y los botones Aprobar, Rechazar, Reabrir revisión con su diálogo de motivo.
4. La sección «Revisión de identidad» deja de ser una lista suelta. Su contenido pasa a la tarjeta de identidad o a un bloque plegado «Historial legado (solo lectura)».

## 3. Reglas de datos

- Cada tarjeta de requisito toma las filas de `driver_documents` asociadas por `requirement_id`.
- Documentos sin requisito conocido van al final, en una tarjeta «Otros documentos».
- **Identidad (regla igual a la app):**
  - Si hay alguna fila de identidad manual con `status = 'verified'`, la tarjeta muestra **Aprobado** y usa esa fila para las fotos.
  - Si no, muestra la fila más reciente con su estado real (Pendiente, Rechazado, Sin enviar).
  - Mostrar todas las filas de identidad manual en un selector pequeño dentro de la tarjeta (por fecha), para que el revisor vea cada envío. Cada envío tiene sus propios botones de revisión.
- Estados visibles en español: `verified` → Aprobado, `pending` → Pendiente, `rejected` → Rechazado, sin fila → Sin enviar. Sin valores crudos.
- El carrusel no cambia nada en la base de datos por sí solo. Solo las acciones de los botones escriben, igual que hoy (`_reviewDocument`).

## 4. Restricciones

- No modificar RPC, migraciones ni Edge Functions.
- No quitar la tabla legada de la consulta `admin_driver_detail`; solo dejar de mostrarla como sección activa.
- Preview y Producción siguen aislados: no cambiar `_previewScopedModules` ni el guard de `_body` en `lib/admin_panel.dart`.
- Móvil y web: el carrusel debe funcionar con el mouse (flechas laterales) y con deslizamiento táctil. Ancho de tarjeta fijo (≈ 320 px), altura automática, sin scroll horizontal de la página entera.
- Reutilizar los widgets y textos existentes; no duplicar la lógica de `_reviewDocument`.
- Mantener los textos en español.

## 5. Criterios de aceptación

1. Un conductor con licencia aprobada y dos envíos de identidad (uno pendiente más reciente y uno aprobado más antiguo) muestra la tarjeta de identidad en **Aprobado**.
2. Un conductor con identidad solo pendiente muestra **Pendiente** con Aprobar y Rechazar.
3. El carrusel ordena: Identidad, luego requisitos en orden de catálogo, luego otros.
4. Cada tarjeta tiene Aprobar, Rechazar y Reabrir revisión según el estado, igual que hoy.
5. En la ficha no aparece la lista suelta de «Verificación manual».
6. `flutter analyze` sin errores nuevos. Una prueba de widget para el orden del carrusel y el estado de identidad.
7. Documentar el cambio en `docs/CHANGELOG_ACTIVE.md` (regla del repo: código cambiado = docs cambiados).

## 6. Preguntas abiertas para el propietario

- ¿Quitamos del todo la sección legada `identity_verifications` o la dejamos plegada como solo lectura? La spec propone plegada.
- ¿El correo del conductor de prueba que falla es el de la captura? Confirmar antes de aprobar identidades en producción.

---

## PROMPT PARA LA IA PROGRAMADORA

**Contexto.** Panel administrativo Express (`jorge2610g/Adminexpress`). Ficha de conductor en `lib/admin_detail_dialogs.dart`, sección «Documentos e identidad» (~líneas 963–1120). Los datos vienen de `admin_driver_detail` (`documents` = `driver_documents`; `identity_verifications` = legado). La app Express usa la regla descrita en `lib/driver_registration_gate.dart` del repo `Expressdelivery`.

**Lee antes de editar:** esta spec; `docs/CHANGELOG_ACTIVE.md`; `lib/admin_detail_dialogs.dart` líneas 640–700 y 960–1125; `lib/admin_driver_document_requirements.dart`.

**Tarea.**
1. Reemplazar la columna vertical de documentos por un carrusel horizontal con una tarjeta por requisito, identidad primero, luego requisitos del catálogo, luego «Otros documentos».
2. Aplicar la regla de identidad de la sección 3 (verificado si existe cualquier envío manual aprobado).
3. Mantener los botones y diálogos de revisión existentes en cada tarjeta.
4. Quitar la lista suelta «Revisión de identidad»; dejar el historial legado plegado y de solo lectura.
5. Documentar en `docs/CHANGELOG_ACTIVE.md`.

**Restricciones.** No tocar RPC, migraciones, Edge Functions ni `_previewScopedModules` / guard de `lib/admin_panel.dart`. No cambiar textos fuera de esta sección. Sin secretos en el código.

**Cómo probar.** `flutter analyze`; prueba de widget con: (a) licencia aprobada + identidad pendiente y aprobada, (b) identidad solo pendiente, (c) sin documentos. Verificar a mano en Preview el carrusel con mouse y con táctil en ancho de teléfono.

**Devolución.** Formato de `docs/AI_RESPONSE_FORMAT.md`: SHA, archivos cambiados, resultado de `flutter analyze`, capturas del carrusel en Preview, y lista de lo que no se pudo probar.
