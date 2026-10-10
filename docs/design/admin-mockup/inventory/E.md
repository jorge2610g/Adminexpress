# Notas E: Reportes, Auditoría, Builds, Demanda, Identidad, Sandbox, Carga QA

Fuente: `inventory/C1_reports_audit_qa.md` (C1:línea). Todos los artboards miden 1280×1160 y usan Sidebar + Topbar compartidos.
Restricción Flutter (STYLE.md): solo Material 3 + flutter_map. No hay gráficos, blur, blend ni bordes no uniformes con radio. Las tarjetas de borde son `Border.all`. Los mapas son TileLayer OSM + MarkerLayer + CircleLayer. En los mapas, el fondo SVG es solo un sustituto visual de los tiles OSM.

---

## 1. Reportes.dc.html. Sección 10 (env=preview, scope=none)
Cubre: encabezado (C1:28-30), fila Desde/Hasta/Actualizar (C1:32-39), bloque del canal Preview "Actividad de pruebas internas" (C1:47) y las 9 métricas (C1:50-60), en una cuadrícula de 4 columnas (C1:48).
No dibujados (son estados): carga, "Reintentar: …" y "No hay entornos autorizados para consultar reportes." (C1:64-67).
Correcciones de presentación:
- 'Cobrado' aparece como `Bs 2.145,50`. El código muestra el número sin moneda (C1:58, C1:427). La moneda debería salir del país de la zona (CLP en Chile).
- Las fechas Desde/Hasta llevan un chevron de selector. El código abre un DatePicker (C1:35-36).
- Pastilla "Preview" en el banner (presentación).
Iconos Material: calendar_today_outlined, event_outlined, refresh_rounded, science_rounded, local_taxi_rounded, task_alt_rounded, cancel_outlined, local_shipping_rounded, inventory_2_outlined, remove_shopping_cart_outlined, payments_outlined, person_add_alt_1_rounded, sos_rounded, expand_more_rounded.

## 2. Auditoria.dc.html. Sección 14 (env=preview, scope=none)
Cubre: encabezado y Actualizar (C1:154-157), filas con avatar QA/REAL, título, "admin · dd/MM/yyyy · HH:mm", entity_id y la pastilla QA/REAL (C1:164-168).
Correcciones de presentación:
- El código arma el título así: `action · entity_type`, cambiando `_` por espacio (C1:166). Saldrían cosas en inglés como "update · driver". Aquí se traducen: "Actualización · tarifa", "Aprobación · conductor", "Promoción · build", etc. Hace falta un diccionario action/entity_type → español.
- Las filas van dentro de una tarjeta con cabecera "Historial de acciones" y una leyenda QA/REAL. Es solo presentación: el código usa una Card por fila.
- La lista mezcla QA y REAL porque así se pidió. En el código solo hay un canal habilitado a la vez (allowPreview/allowProduction, C1:7-9). Con el panel en Preview, en la práctica todas las filas serían QA.
Iconos Material: refresh_rounded, science_rounded, history_rounded.

## 3. Builds.dc.html. Sección 12 (env=production, scope=none)
Cubre: encabezado (C1:75-77), tarjeta "Flujo único Android" (C1:88-102), bloque de detalles (C1:143-148), "Publicaciones de Producción" con "Publicar versión aprobada" y "Actualizar estado" (C1:104-108). La columna derecha muestra el diálogo abierto "Preparar APK y AAB reales de Express" con texto, Versión (1.6.1), Notas del candidato, "Siguiente versionCode…", Cancelar y Poner en cola (C1:110-117).
Estado de ejemplo: QA certificado, sin aprobar ni promover. Por eso Registrar pruebas y Aprobar están activos y "Promover APK/AAB" está deshabilitado (reglas en C1:100-102). La release 1.6.0 está 'ready' (Publicar activo) y la 1.5.9 está publicada (Publicar deshabilitado).
No dibujados: la tarjeta "Solo lectura" y el error (C1:81-84); los diálogos 2.2-2.5 (C1:119-139).
Correcciones de presentación:
- El status crudo en `Versión … · build … · {status}` (C1:144) se muestra traducido como chip: ready → "Listo", published → "Publicado".
- La línea "QA: … · Aprobación: … · Promovido: …" (C1:94) se parte en 3 chips de color, con el mismo texto.
- Los SHA van en monoespaciada.
Fallos del código: el diálogo Preparar descarta en silencio una versión vacía (C1:116, C1:428). El de certificar descarta en silencio menos de 30 caracteres (C1:123). Falta un mensaje de validación.
Iconos Material: phone_android_rounded, build_rounded, android, file_download_outlined, fact_check_outlined, verified_outlined, publish_outlined, cloud_upload_outlined, refresh, info_outline_rounded, tag_rounded.

## 4. Demanda.dc.html. Sección 28 (env=production, scope=admin)
Cubre: encabezado con subtítulo "· Producción", Actualizar y Configurar (C1:368-371); 7 stat tiles con los valores por defecto (C1:373-384); regla de seguridad (C1:386-387). El diálogo "Demanda dinámica · Producción" está abierto como panel: SwitchListTile y los 13 campos en 4 filas de 3/3/3/4 con sus valores por defecto, Cancelar y Guardar (C1:397-418). La tarjeta secundaria "Simulación QA por ciudad" lleva la marca "Solo en Preview" (C1:389-395). En el código solo aparece con channel=='preview'.
Correcciones de presentación:
- El título de cada ciudad usa la clave cruda del nivel (C1:392): "Trinidad · automatic". Se traduce a "Trinidad · Automático" e "Iquique · Alta".
- Se añaden sufijos de unidad dentro de los campos: km, min y x en los multiplicadores. El código no tiene unidades ni hints (C1:399).
- Cada stat tile lleva un punto de color.
Fallos del código:
- La tile 'Crítica' muestra max_multiplier en lugar de critical_multiplier (C1:380, C1:430). Aquí aparece +50% (max 1.5), igual que el código. Con critical 1.35 debería ser +35%.
- Guardar en Producción no pide confirmación (C1:418).
- Los números inválidos se envían como null, sin validación (C1:399).
- Sin zona no hay estado vacío (C1:366, C1:422).
- Carga QA no ofrece el nivel 'low' y esta página sí (C1:395).
Iconos Material: refresh_rounded, tune_rounded, trending_up_rounded, verified_user_rounded (regla de seguridad).

## 5. Identidad.dc.html. Sección 18, pestaña 1 (env=preview, scope=admin). También vale para la sección 27.
Cubre: TabBar blanco con "Revisión de documentos" activa y "Requisitos de identidad" (C1:14-16). Encabezado "Verificación manual" (C1:182-184). Tarjeta del panel con el contador "Identidades por revisar: 4" y la lista (C1:187-197). Diálogo "Revisión individual de identidad" abierto a la derecha (C1:204-218) con 3 espacios de foto en distintos estados:
- Frente Aprobada, con Rechazar y Reactivar.
- Reverso Rechazada, con Motivo, Aprobar y Reactivar.
- Fotografía facial Pendiente, con Aprobar y Rechazar.
Así se ven los tres botones. Pie: texto y Cerrar.
En la sección 27 es la misma pantalla sin TabBar, con el Sidebar en "Verificación manual" (C1:19).
Correcciones de presentación:
- El subtítulo de la lista `Carné {n} · {status}` muestra el status crudo (pending…) (C1:196, C1:431). Se traduce: Pendiente, Aprobada, Rechazada.
- Las fotos se dibujan como miniaturas de 220×124 al lado del texto. El código usa 360×200 en contain, apiladas (C1:212). Hay que ajustar el layout a filas en Flutter.
- "Identidad: Pendiente" aparece como chip.
No dibujados: el confirm por foto con "Motivo del rechazo" y Confirmar (C1:220-228), y los estados de error y vacío (C1:192, C1:202).
Iconos Material: fact_check_outlined, settings_outlined, refresh, hourglass_empty, verified_user_outlined, chevron_right, check_circle_outline, highlight_off, restart_alt, badge_outlined, credit_card_outlined, face_outlined (marcadores de foto).

## 6. Sandbox.dc.html. Sección 20 (env=preview, scope=admin)
Cubre: héroe con degradado, título, subtítulo, píldoras ENTORNOS 2 y CUENTAS QA 5, y "Nuevo entorno" (C1:245-251). Aviso de aislamiento (C1:253-254). Dos tarjetas de grupo (C1:259-271):
- "Auditoría Trinidad": activa, AISLADO / ACTIVO, Switch encendido, 2 pasajeros y 2 conductores (uno con punto gris).
- "QA Iquique": pausada, PAUSADO / AISLADO, Switch apagado, 1 pasajero y "Sin conductor asignado".
Cada columna tiene contador, botón para quitar (aria "Quitar del entorno") y Añadir pasajero / Añadir conductor.
Diálogo pequeño "Nuevo entorno de prueba" con Nombre (hint Auditoría Cuba), Identificador (hint auditoria-cuba), ayuda, Cancelar y Crear (C1:279-284).
No dibujados: la puerta de Producción, el error, el estado vacío y los diálogos Añadir/Quitar (C1:234-243, C1:256-257, C1:286-295).
Notas: el código no valida el identificador en el cliente aunque la ayuda pide formato (C1:283). El switch no pide confirmación (C1:277).
Iconos Material: science_rounded, add_rounded, verified_user_rounded, person_outline_rounded, drive_eta_rounded, person_rounded, close_rounded, person_add_alt_1_rounded.

## 7. CargaQA.dc.html. Sección 21 (env=production, banner de Producción, scope=admin)
Cubre: encabezado (C1:305-307), banner de ámbito de Producción (C1:310), los 7 controles (Entorno de solo lectura "Producción (real)", Ciudad QA, Servicio QA, Demanda Preview, Conductores, Solicitudes, Radio de prueba) con sus valores por defecto, y los botones Aplicar demanda, Recrear escenario (hay run activo), Limpiar prueba y Actualizar (C1:313-326). También las 7 métricas (C1:338-347) y el mapa con conductores azules (#2563EB, two_wheeler) y solicitudes naranjas (#F97316, location_on), la capa superior y la atribución OSM (C1:349-354). Por último, el resumen del run (C1:356-358).
Correcciones de presentación:
- El aviso verde con `result.toString()` crudo (C1:336, C1:429) se sustituye por una tarjeta "Escenario creado" con pares clave/valor: Ejecución, Entorno, Ciudad QA, Servicio QA, Conductores y Solicitudes sintéticas, Radio, Duración. Hay que mapear las claves reales del Map que devuelve `express-load-lab`.
- "Run {id}" (C1:358) se traduce a "Ejecución {id}". El resumen va en una tarjeta con el título "Escenario activo", que es de presentación.
- Las métricas se ven en una fila de 7. El código pone 6 por fila y la 7.ª pasa a la siguiente (C1:338).
- Mapa: unos 520 px de alto frente a 620 en el código (C1:349). A su derecha va la columna de resultado. El círculo del radio se dibuja con CircleLayer.
No dibujados: el confirm "Lanzar carga QA en producción" (C1:330-332) y el aviso de error (C1:335).
Fallo del código: no hay indicador de carga inicial; las métricas quedan en blanco (C1:360).
Iconos Material: warning_amber_rounded, verified_outlined, expand_more_rounded, trending_up_rounded, science_rounded, cleaning_services_rounded, refresh_rounded, bolt_rounded, layers_rounded, location_city_rounded, drive_eta_rounded, local_taxi_rounded, speed_rounded, two_wheeler_rounded, location_on_rounded, check_circle_rounded.
