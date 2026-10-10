# SPEC 2026-10-10 — Implementar en Flutter los mockups visuales del panel Admin

**Estado:** lista para la IA programadora. Claude revisa cada PR.
**Repo:** `jorge2610g/Adminexpress` · rama nueva desde `main` por fase (no desde ramas de auditoría).
**Fuente visual (en el repo, no depende de ninguna sesión):**
- `docs/design/admin-mockup/project/*.dc.html` — 54 pantallas + componentes (`Sidebar`, `Topbar`).
- `docs/design/admin-mockup/project/canvas.json` — mapa de páginas.
- `docs/design/admin-mockup/STYLE.md` — tokens, reglas y restricción Flutter-only.
- `docs/design/admin-mockup/inventory/*.md` — textos exactos, campos, opciones y condiciones Preview/Producción de cada pantalla. **Es la fuente de verdad de textos y campos.**
- Vista previa privada del propietario: https://claude.ai/artifact/KyNEu6p1djpauv15HQQawF (solo el propietario la puede abrir).

## 1. Regla principal
Los mockups definen **cómo se ve**. El código actual define **qué hace**. Solo cambia la presentación.

**Prohibido** en todas las fases:
- Cambiar RPC, nombres de parámetros (`p_channel`, `p_zone_id`…), consultas, filtros, orden de datos, permisos (`is_admin`, `allow_production`, `admin_assert_environment`) o el canal Preview/Producción.
- Agregar o quitar campos, botones, pestañas, opciones de dropdown o textos de negocio. Si un mockup muestra algo que el código no tiene, **no se implementa**; se anota en el PR.
- Agregar dependencias a `pubspec.yaml`.
- Usar librerías de gráficos, Google Fonts u otros paquetes. Solo Material 3, `flutter_map` (ya existe), iconos de Material.
- Efectos que Flutter no soporta bien: desenfoque, `backdrop-filter`, animaciones CSS.

**Permitido:** colores (tokens), espacios, radios, sombras simples (`BoxShadow`), degradados (`LinearGradient`), tipografía (tamaños y pesos), layout (`Row`, `Column`, `Wrap`, `GridView`, `LayoutBuilder`), y reordenar contenedores visuales.

Si un texto del mockup difiere del inventario, **gana el inventario** (es el texto real del código).

## 2. Traducción de tokens (mockup → Flutter)
Definir una sola vez en `lib/core/admin_design_tokens.dart` (según `docs/specs/SPEC-2026-10-10-admin-redesign-phases.md` §1.1):

| Token | Valor (mockup) | Uso |
|---|---|---|
| `bg` | `#F1F5F9` | fondo de página |
| `surface` | `#FFFFFF` | tarjetas |
| `border` | `#DDE6F0` / `#E3E8F0` | bordes de tarjeta |
| `ink` | `#0F172A` | texto principal |
| `muted` | `#64748B` | texto secundario |
| `sidebar` | `#0B1424` | barra lateral |
| `sidebarActive` | `#1B2B47` | ítem activo |
| `blue` | `#2563EB` | primario, selección |
| `blueSoft` | `#EAF2FF` | fondo suave azul |
| `ok` / `okSoft` | `#0B7A3E` / `#DDF5E6` | activo, aprobado |
| `warn` / `warnSoft` | `#9A5B00` / `#FFF1DC` | pendiente |
| `danger` / `dangerSoft` | `#C2273A` / `#FFE4E6` | rechazo, error |
| `previewInk` / `previewSoft` | `#B54708` / `#FFF7E6` | banner Preview |
| `prodInk` / `prodSoft` | `#14804A` / `#E8F8EF` | banner Producción |
| `radiusCard` | 16 | tarjetas |
| `radiusControl` | 10–11 | botones, campos |
| Breakpoints | `<600` teléfono · `600–1023` tablet · `≥1024` escritorio · `<1180` = menú compacto (ya existe en `admin_panel.dart`) |

Tipografía: Plus Jakarta Sans **no** se añade como paquete. Usar la fuente del sistema con los pesos del mockup (`w600`, `w700`, `w800`). Títulos de página 24–26 px `w800`.

## 3. Fases

### Fase 1 — Tema, shell y barra superior (un PR)
Corresponde a `SPEC-2026-10-10-admin-redesign-phases.md` §1.1–1.2 con los valores de la tabla.
- `lib/admin_panel.dart`: `_expressAdminTheme` lee los tokens. Sin cambiar colores fuera de esa función.
- `_Navigation` (barra lateral): mismo orden de grupos y de ítems que el código (`groups` en `admin_panel.dart`, líneas ~2241-2256). Ítems con icono, grupo en mayúsculas, badge de contador si el mockup lo muestra con dato real; si no hay dato, sin badge. Tarjeta de entorno (Preview ámbar / Producción verde) según `Sidebar.dc.html`.
- `_TopBar` (escritorio): buscador visual (sin búsqueda funcional nueva, solo si ya existe), pill de entorno, notificaciones, cuenta. Ver `Topbar.dc.html`.
- Compacto (<1180 px): AppBar + Drawer con el mismo menú (`Movil.dc.html`).
- **Corrección de código a aprovechar:** el botón "Nuevo viaje" de `_TopBar` debe respetar `showNewTrip` (hoy se muestra también al monitor de zona). Es lo único de comportamiento que se toca, y se documenta en el PR.

### Fase 2 — Pantallas de sección por patrón (un PR por grupo)
Cada pantalla conserva sus datos y callbacks. Solo cambia el contenedor visual.
- **Patrón A · Dashboard** (`Main.dc.html`, `Reportes.dc.html`): cabecera de página, tarjetas KPI, bloques de actividad. Sin gráficos nuevos: barras con `Container` si ya existen datos; si no, no se dibujan.
- **Patrón B · Lista con panel de detalle** (`Viajes`, `Delivery`, `Pedidos`, `Conductores`, `Usuarios`, `SOS`, `Pagos`, `Suscripciones`, `Auditoria`, `Market`): filtros arriba, tabla con filas `Row` dentro de `ListView`, chips de estado, avatar con iniciales, menú de acciones `PopupMenuButton`. En teléfono: tarjetas en lugar de tabla.
- **Patrón C · Configuración con formulario** (`Configuracion`, `ConfiguracionTabs`, `ConfigAvanzada`, `Servicios`, `Tarifas`, `Demanda`, `Zonas`, `Avisos`): pestañas `TabBar`, tarjetas por bloque, campos con etiqueta arriba, interruptores `Switch`.
- **Patrón D · Mapa en vivo** (`Live.dc.html`, `Viajes` mapa, `Despacho`, `GeoSeguridad`): `flutter_map` existente, capas de marcadores y círculos. Leyenda como tarjeta.
- **Patrón E · Herramientas QA** (`Sandbox`, `CargaQA`, `Builds`): tarjetas de grupo, controles, banner de entorno.

Orden de PR sugerido: (1) Dashboard + Operación en vivo, (2) Conductores + Usuarios + SOS + Viajes, (3) Pagos/Tarifas/Suscripciones/Zonas, (4) Configuración y Avisos, (5) Market/Fase 2/Prioridad, (6) QA y Builds.

### Fase 3 — Diálogos (un PR)
`DlgConductor`, `DlgUsuario`, `DlgViaje`, `DlgPedido`, `DlgMarket`, `DlgFase2`, `DlgPrioridad`, `DlgPlan`, `DlgPagos`, `DlgTarifa`, `DlgZona`, `DlgConfig`, `DlgAvanzada`, `DlgAliados`, `DlgIdentidad`. Mismos campos y validaciones de `admin_detail_dialogs.dart` y de los demás archivos citados en el inventario. Estilo: `AlertDialog` de Material con cabecera, secciones con fondo `#F8FAFC` y borde `#E2E8F0`, pie con acciones.

### Fase 4 — Estados y acceso (un PR)
`Login` (solo visual; sin cambiar la lógica de autenticación ni el flujo Google en Preview), `Estados` (cargando, acceso denegado, sin autorización, error con Reintentar).

## 4. Criterios de aceptación por PR
1. `flutter analyze --no-fatal-warnings --no-fatal-infos lib` sin errores fatales. Pegar la salida.
2. `flutter test` en verde. Pegar el conteo.
3. **Diff funcional cero:** en el PR, listar que ninguna llamada `supabase.rpc`, `.from(...)`, `.insert/.update` ni condición de permiso cambió. Se verifica con `git diff -G "rpc\(|from\(|p_channel|is_admin|allow_production|admin_assert"` y el resultado debe ser vacío o solo reordenamiento de línea idéntica.
4. Capturas en 360, 768, 1024 y 1440 px de cada pantalla tocada, comparadas con el artboard correspondiente. Diferencias explicadas en el PR.
5. Sin scroll horizontal de página en 360 px.
6. Textos: todo literal del inventario; ningún texto en inglés visible (los estados se traducen: `approved`→`Aprobado`, `online`→`En línea`, `pending`→`Pendiente`, etc.).
7. `CHANGELOG_ACTIVE.md` con una entrada por PR.

## 5. Restricciones de seguridad
- No tocar `supabase/`, Edge Functions ni Producción.
- No cambiar `ADMIN_ENV` ni la lógica de canal.
- No quitar ninguna verificación de entorno existente.

## 6. Qué no implementar todavía
- Gráficos nuevos de líneas o áreas (fuera de Flutter-only).
- Búsqueda global (`Ctrl K`) funcional: solo el campo visual, si el PR no tiene datos reales para buscar.
- Cambios de comportamiento que el mockup sugiera y el código no tenga (anotar en el PR).

## 7. Formato de devolución
Por PR: enlace, rama, fase, archivos cambiados, salida de analyze y test, capturas, lista de diferencias respecto al mockup con motivo, y confirmación del diff funcional cero.
