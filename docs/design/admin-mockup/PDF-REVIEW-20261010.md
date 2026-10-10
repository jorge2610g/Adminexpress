# Revisión visual PDF — 54 imágenes Claude (2026-10-10)

**Fuente**: PDF enviado por el propietario en esta conversación, 54 páginas. Las pantallas originales equivalentes están versionadas como `project/*.dc.html`, ordenadas en `project/canvas.json`; el contenido del PDF es referencia visual para el panel **Flutter real**, no imágenes para incrustar como sustituto de la UI.

**Guía original de Claude**: `STYLE.md` en la rama `claude/express-admin-audit-cp07ml`. Indica mismo menú, campos, textos, acciones y estados que el código existente; widgets Flutter Material 3, OSM, no crear funciones ni gráficos externos. La fuente `Plus Jakarta Sans` es OFL y se empaqueta en el repositorio.

## Matriz por imagen

| Página PDF | Pantalla | Componentes visibles que deben conservarse | Estado real tras revisión |
|---:|---|---|---|
| 1 | Dashboard | Héroe azul, 4 KPI, 3 accesos de color, estado, actividad y resumen | Parcial: estructura y KPI ya presentes; falta paridad por captura |
| 2 | Operación en vivo | Tira horizontal de zonas, contadores + pestañas a la izquierda y mapa grande a la derecha | Parcial: verificar mapa, altura y categorías de conductor |
| 3 | Viajes | Tabla con ruta/estado/categoría/tarifa/pasajero/conductor/pago/creado | Tabla creada; validar columnas/datos de RPC |
| 4 | Despacho manual | Listas de viaje/delivery con botones Asignar y paneles laterales de asignación | Pendiente de contraste; módulo solo Producción |
| 5 | Delivery | Tarjetas desplegables, estado, paquete, tarifa, hora y 4 detalles | Acordeón reconstruido con datos RPC; CI pendiente |
| 6 | Pedidos Delivery | Pedidos por comercio, chips de pago y total; detalle de comprobante | Pendiente de contraste; módulo solo Producción |
| 7 | Conductores | Tabla con identidad, vehículo, ciudad, aprobación, estado y menú completo | Tabla y menú reales; falta comparación visual final |
| 8 | Usuarios | Filtros de zona, ciudad y región; listado en columnas, chips QA, menú | Tabla y menú reales; faltan filtros y contraste |
| 9 | Seguridad / SOS | Tarjetas con alerta a la izquierda, fecha y Resolver a la derecha | Pendiente de contraste |
| 10 | Login | Marca degradado azul a la izquierda, tarjeta de acceso a la derecha | Estructura existente; fuente nueva; comparar |
| 11 | Estados de acceso | Carga, autorización, error y acceso denegado en tarjetas separadas | Pendiente de contraste funcional |
| 12 | Móvil | AppBar blanco compacto y drawer azul oscuro sobre contenido | Estructura existente; comparar en 390 px |
| 13 | Sidebar | Navegación de 248 px, grupos, compañía y SOS rojo | Existente; contrastar iconos y densidades |
| 14 | Topbar | Título, nuevo viaje, actualizar, notificaciones, cuenta, entorno y ámbito | Existente; comprobar altura y separación |
| 15 | Ficha del conductor | Fotos, datos personales/operación, vehículo, documentos, revisión y motivo de rechazo | Modal de cabecera blanca; funcionalidad ya disponible |
| 16 | Ficha del usuario | Perfil, resumen y lista de viajes recientes con guardar | Modal de cabecera blanca; verificar disposición |
| 17 | Detalle del viaje | Ruta, participantes, pago, movimientos y cronología | Modal de cabecera blanca; verificar agrupaciones |
| 18 | Pedido Delivery | Liquidación, comprobante, chat y acciones de aprobación/recepción | Pendiente de contraste; operaciones solo Producción |
| 19 | Express Market | Categorías, banners y comercio/productos en rejillas | Pendiente de contraste; módulo solo Producción |
| 20 | Delivery Fase 2 / Express Plus | Tarjetas de tarifa, plan y locales; pedidos fuera de página | Pendiente de contraste; módulo solo Producción |
| 21 | Prioridad conductores | Ranking con barras reputación, reseñas, experiencia y frecuencia | Pendiente de contraste; módulo solo Producción |
| 22 | Diálogos Market | Configuración, banner, comercio, categoría y producto | Pendiente de contraste campo a campo |
| 23 | Diálogos Fase 2 | Tarifas, Express Plus, accesos de locales y logística | Pendiente de contraste campo a campo |
| 24 | Configurar prioridad | Umbrales, pesos, metas y switches por entorno | Pendiente de contraste |
| 25 | Pagos / Billetera | Método por zona, recargas, contadores y movimientos | Pendiente de contraste; Producción |
| 26 | Tarifas | Reglas de zona, escalones por distancia y tarifas fijas | Pendiente de contraste |
| 27 | Suscripciones | Configuración, conductores, plan y pagos | Pendiente de contraste |
| 28 | Diálogos Pagos | Medios, Mercado Pago, aprobar/rechazar recarga | Pendiente de contraste sin tocar credenciales |
| 29 | Diálogos Tarifas | Tarifa sector, polígono, nueva tarifa y servicio | Pendiente de contraste |
| 30 | Diálogos Planes | Plan, conexión VeriPagos, asignación y exigencia | Pendiente de contraste |
| 31 | Reportes | Rango fecha, aviso QA y nueve KPI | Pendiente de contraste |
| 32 | Auditoría | Historial de acciones QA/REAL con marcas | Pendiente de contraste |
| 33 | Avisos | Enviar avisos, historial/telemetría y soporte | Pendiente de contraste |
| 34 | Identidad (revisión) | Listado de documentos y decisiones individuales | Consolidar con Conductores, según indicación expresa |
| 35 | Identidad (requisitos) | Centro de identidad y documentos requeridos | Consolidar con Conductores, según indicación expresa |
| 36 | Diálogos Identidad | Documento, alcance y validaciones; eliminar | Consolidar con Conductores, sin duplicar lógica |
| 37 | Servicios | Zona editada, catálogo, disponibilidad, ofertas, tipo de vehículo | Pendiente de contraste |
| 38 | Zonas y cobertura | Zonas y países, aliados y accesos | Unificación acordada; falta contraste |
| 39 | Seguridad de zonas | Sectores rojos y de prevención con dibujo poligonal | Pendiente de contraste |
| 40 | Configuración | General con 8 pestañas y resumen operativo | Pendiente de contraste |
| 41 | Configuración avanzada | Centro de control y cinco tarjetas | Pendiente de contraste |
| 42 | Builds | Builds Android, candidatos, aprobación y releases | Pendiente de contraste; no afectar release gate |
| 43 | Demanda y precios | Tiles estado, multiplicadores y formulario de demanda | Pendiente de contraste |
| 44 | Editar zona/cobertura | Radio O polígono, mapa y switches | Control excluyente existe; verificar guardado del modo |
| 45 | Crear/editar servicio | Catálogo, disponibilidad, flags de precios, ofertas, programados | Pendiente de contraste |
| 46 | Config. pestañas | Servicios, Pagos, Operación, Tarifas, Soporte, Seguridad y Admin | Pendiente de contraste |
| 47 | Diálogos avanzada | Búsqueda, mantenimiento, pagos legado, SOS y calificaciones | Pendiente de contraste |
| 48 | Aliados y liquidaciones | Resumen sindicato, pagos y conductores por zonas | Pendiente de contraste |
| 49 | Países, sindicatos y accesos | Crear país, sindicato, preparar QA y acceso al panel | Pendiente de contraste |
| 50 | Entornos de prueba | Entornos QA aislados con cuentas pasajero/conductor | Pendiente de contraste; mantener aislamiento |
| 51 | Carga QA | Mapa, radio, métricas, generador y limpiar escenario | Pendiente de contraste; no activar carga real |
| 52 | Socios resumen | Resumen sindicato con 3 KPI y tabla de permisos | Sistema compartido aplicado; faltan diferencias visuales |
| 53 | Socios conductores | Lista de afiliados y aprobaciones/rechazos | Sistema compartido aplicado; faltan diferencias visuales |
| 54 | Socios pagos/avisos | Liquidaciones y formulario push de socios | Sistema compartido aplicado; faltan diferencias visuales |

## Contradicciones/decisiones que no deben romper funcionalidades

- Las páginas 34–36 muestran Identidad separada; la **instrucción funcional posterior** del propietario pide integrar requisitos, documentos y foto en **Conductores**, evitando panel independiente redundante.
- Las páginas 38–39 y 44 muestran zonas/cobertura y seguridad; al editar la zona debe quedar **Radio O Polígono**, nunca ambos activos. Este selector ya existe en `AdminZoneCoverageEditor`.
- Las páginas 4, 6, 19–30, 33, 41–42, 47 y 51 muestran pantallas de Producción por bloqueo previsto en Preview; **no levantar ni simular accesos de Preview** para comparar imágenes.
- Mantener RPC y validación/roles tal como están. Los cambios en este PR son de presentación: no editar schema, funciones SQL, llaves ni datos reales.
- El PDF utiliza **datos simulados** (nombres, conteos, zonas) para el diseño. La aplicación debe mostrar datos reales del canal autorizado, no valores hardcodeados del PDF.

## Ajustes concretos efectuados a partir de las imágenes

- Página 5: `AdminDeliveryRow` vuelve a la presentación de acordeón, sustituida erróneamente por tabla en la iteración anterior; detalle Cliente, Repartidor, Pago y Creado. Estados en español.
- Páginas 7–8: menú completo de acciones en el propio renglón de Conductores/Usuarios, sin sacrificar fichas detalladas o checks de rol.
- Páginas 15–17: `_DialogFrame` cambia cabecera y pie del azul degradado a **blanco con icono azul y texto oscuro**.
- Todo el panel: `Plus Jakarta Sans` OFL empaquetada, declarada en `pubspec.yaml` y activa en `MaterialApp`.
- Pruebas de widget y `flutter analyze` deben pasar antes de publicar en Preview; no fusionar main ni tocar Producción.

## Criterio para marcar una página TERMINADA

1. Tomar captura de la **aplicación compilada** en viewport equivalente al artboard y comparar regiones y disposición con PDF.
2. Comprobar cada botón, diálogo, pestaña, estado vacío y de error, sin datos de Producción en Preview.
3. No considerar un mockup implementado por estar en `docs/design/` o porque sus tokens CSS estén copiados.
4. Conservar diferencias entre las pantallas que el propio PDF exige (p.ej. Delivery acordeón, Viajes tabla; configuración sin héroe en ciertas vistas).
