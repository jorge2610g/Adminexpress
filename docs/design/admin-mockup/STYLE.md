# Guía para dibujar las pantallas del mockup Admin Express

Lienzo: `/tmp/claude-0/-home-user/94c7b379-ecbd-5360-8d73-257a3f83b0e2/scratchpad/admin-mock/project/`.
Ejemplos terminados que DEBES leer antes de empezar y copiar en estructura y estilo:
- `project/Main.dc.html` (Dashboard) y `project/Live.dc.html` (Operación en vivo).
- Componentes compartidos: `project/Sidebar.dc.html` (prop `active` = etiqueta EXACTA del menú; `readOnly` true para monitor de zona) y `project/Topbar.dc.html` (props `title`, `env` = preview|production, `scope` = admin|monitor|none).

Inventarios con los textos exactos del código (fuente de verdad, en español literal):
`/tmp/claude-0/-home-user/94c7b379-ecbd-5360-8d73-257a3f83b0e2/scratchpad/inventory/` → `A_core.md`, `B1_zones_fares_payments_dispatch.md`, `B2_settings_comms_services_identity.md`, `C1_reports_audit_qa.md`, `C2_market_subs_priority_partner.md`.

## Objetivo
Rediseño visual profesional del panel EXISTENTE. Cada pantalla debe tener exactamente las mismas secciones, campos, opciones, botones, pestañas, textos y estados que el código (según el inventario). No inventes funciones, no quites campos. Los datos de ejemplo deben ser verosímiles (Bolivia/Trinidad, Bs; Chile/Iquique, CLP), nunca lorem ipsum.

## Restricción obligatoria: todo debe poder implementarse en Flutter con las dependencias actuales
El proyecto (`/home/user/adminexpress/pubspec.yaml`) solo tiene: flutter (Material 3), supabase_flutter, flutter_map + latlong2 (OSM), url_launcher, cupertino_icons. NO hay librerías de gráficos, ni google_fonts, ni tablas de datos externas.
- Iconos: cada icono debe tener equivalente en Material Icons; en tus notas anota el nombre Material (`Icons.xxx_rounded`) de cada icono que dibujes (usa los del inventario cuando existan).
- Gráficos: solo los que se hacen con widgets básicos (barras = Container con altura, progreso = LinearProgressIndicator, anillo = CircularProgressIndicator). Nada de gráficos de líneas/áreas complejos.
- Mapas: solo lo que da flutter_map (TileLayer OSM, MarkerLayer, CircleLayer, PolygonLayer, PolylineLayer).
- Efectos permitidos: colores planos, LinearGradient, BoxShadow, bordes, radios. Prohibido: blur/backdrop-filter, blend modes, recortes con formas raras, animaciones CSS.
- Layout: todo debe mapear a Row/Column/Wrap/GridView/ListView/Stack, Card, TabBar, SegmentedButton, Chip/FilterChip, Switch/SwitchListTile, TextField, DropdownButtonFormField, Slider, PopupMenuButton, AlertDialog/Dialog, Drawer, NavigationRail. Tablas = filas hechas con Row dentro de ListView.
- Fuente: Plus Jakarta Sans se empaqueta como asset de fuente (sin paquete nuevo); si no, cae a la del sistema sin romper el diseño.

## Formato de archivo (.dc.html) — reglas que si se rompen fallan en silencio
- Copia el esqueleto de `Main.dc.html`: `<!doctype html>`, `<html lang="es">`, `<head>` con `<meta charset="utf-8">`, `<title>` propio y la línea EXACTA `<script src="./support.js"></script>`; `<body><x-dc>` con `<helmet>` (solo el `<link>` de Google Fonts Plus Jakarta Sans y `<style>body{margin:0;font-family:'Plus Jakarta Sans',sans-serif}button,input{font-family:inherit}</style>`), el markup, `</x-dc>`, y SIEMPRE el bloque `<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":W,"height":H}}'>` con `class Component extends DCLogic { renderVals() { return {...}; } }` (JS clásico, sin imports).
- Cierra todos los elementos, comillas en todos los atributos. `{{hole}}` es solo una búsqueda con puntos (`{{r.name}}`), nunca una expresión. Calcula todo en `renderVals()`.
- Repeticiones: `<sc-for list="{{rows}}" as="r" hint-placeholder-count="5">`. Condicionales: `<sc-if value="{{x}}" hint-placeholder-val="{{ true }}">`.
- Componentes: `<dc-import name="Sidebar" active="Viajes" hint-size="248px,1160px"></dc-import>` y `<dc-import name="Topbar" title="Viajes" env="preview" scope="admin" hint-size="1032px,168px"></dc-import>`. Nunca autocierres, nunca mayúsculas en el tag.
- Iconos: SVG inline de trazo (stroke) con `aria-hidden="true"`; puedes reutilizar los `path d` de `Sidebar.dc.html`. Nunca emoji. Botones de solo icono con `aria-label`.
- Usa `<button>`, `<input>`, `<label>` reales. Sin `<iframe>`, sin red salvo la fuente.
- No pongas notas explicativas dentro del artboard.

## Pantallas de sección (1280 × 1160)
Raíz: `<div style="width:1280px;height:1160px;display:flex;background:#F1F5F9;color:#0F172A;font-family:'Plus Jakarta Sans',sans-serif;overflow:hidden">` → Sidebar → columna `flex:1;min-width:0;display:flex;flex-direction:column` → Topbar → `<main style="flex:1;min-height:0;padding:22px 24px;display:flex;flex-direction:column;gap:16px">`.
- Encabezado de página (cuando el código tiene título/subtítulo): título 24–26px peso 800 letter-spacing -.3px; subtítulo 13px #64748B peso 600; acciones a la derecha.
- Si la sección usa el héroe degradado del código (`_Header`): `linear-gradient(120deg,#0F2854,#174B91 55%,#0D6B8D)` radio 20, como en Main.
- Pestañas (TabBar del código): barra blanca con pestaña activa en #2563EB y subrayado 2px; o control segmentado `background:#E6EBF3;border-radius:12px;padding:4px` con la activa en blanco.

## Tokens (vienen del tema del código)
- Fondo #F1F5F9 · tarjeta #FFFFFF borde 1px #DDE6F0 radio 16–18 · texto #0F172A · secundario #64748B · bordes de input #D0D5DD radio 10 · divisores #EEF1F5/#F1F5F9.
- Primario #2563EB (suave #EAF2FF) · cian #22D3EE · navy #0B1220.
- Éxito/Producción #14804A sobre #E8F8EF · Preview/aviso #B54708 sobre #FFF7E6 · Peligro #D92D20 sobre #FFE4E8 · Morado #7C3AED sobre #EDE5FF · Naranja #D97706 sobre #FFEED0.
- Botón primario: alto 40, radio 10, fondo #2563EB, texto blanco 13px 800. Secundario: blanco, borde #D0D5DD, texto #0F172A. Peligro: blanco, borde #F0B8BF, texto #D92D20. Botón de texto: sin borde, #2563EB.
- Chip de estado: píldora con punto 6px del color + texto 11–12px 700–800.
- Interruptor (Switch): pista 40×24 radio 12 (#2563EB encendido / #C5CEDD apagado) con perilla blanca 18px.
- Campo de formulario: etiqueta 11px 700 #64748B arriba, caja alto 38–40 con valor de ejemplo o placeholder (#98A2B3), texto de ayuda/hint debajo 11px #64748B. Dropdown con chevron. Campo deshabilitado: fondo #F2F4F7 y texto #98A2B3. Unidades como sufijo dentro de la caja (km, min, %, Bs, /100).
- Tablas: cabecera #F8FAFC, texto 11px 800 #64748B mayúsculas letter-spacing .4px; filas 13–13.5px; avatar de iniciales 32–38px.

## Estados crudos del código
Donde el código muestra códigos en inglés (approved, online, pending, in_progress…), el mockup muestra la etiqueta en español (Aprobado, En línea, Pendiente, En curso…) y lo registras en tus notas como "corrección de presentación".

## Entorno por pantalla
Usa `env="preview"` salvo que el código bloquee la sección en Preview (secciones 9, 12, 13, 15, 19, 21, 22, 23, 24, 25, 26, 28 están bloqueadas en Preview por el shell → dibújalas con `env="production"`). Sección 20 (Entornos de prueba) se dibuja en Preview. Reportes (10), Builds (12) y Auditoría (14) no tienen barra de ámbito: `scope="none"`.

## Diálogos (artboards "Dlg…", 1280 × 1000 salvo que se indique otro tamaño)
Fondo del artboard `rgba(15,23,42,.06)` sobre #E9EEF5. Diálogo(s) blancos radio 16, sombra `0 24px 60px rgba(15,23,42,.18)`, ancho según el código (480–820px). Cabecera: título 19–20px 800 + subtítulo; cuerpo con secciones (`background:#F8FAFC;border:1px solid #E2E8F0;border-radius:14px;padding:14px` con título 13px 800 e icono azul); pie con acciones a la derecha (Cancelar texto + primario). Si un artboard agrupa varios diálogos, colócalos lado a lado o en cuadrícula, cada uno con su título. Si no caben todos los campos, prioriza: todos los campos de configuración deben aparecer.

## Entrega
1. Escribe cada archivo con tu herramienta de archivos directamente en `project/<Nombre>.dc.html` (no uses shell para generarlos, no scripts). No publiques nada, no toques `canvas.json`, `Main`, `Live`, `Sidebar`, `Topbar` ni archivos de otros agentes. No abras navegador ni Playwright.
2. Escribe `notes/<tu-letra>.md` en `/tmp/claude-0/-home-user/94c7b379-ecbd-5360-8d73-257a3f83b0e2/scratchpad/admin-mock/notes/` con: por cada artboard, qué secciones/diálogos del código cubre, y la lista de correcciones de presentación o fallos del código que encontraste (con file:line del inventario).
3. Responde solo con la lista de archivos escritos.
