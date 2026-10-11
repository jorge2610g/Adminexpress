# SPEC 2026-10-10 — Rediseño del panel Admin (por fases)

**Estado:** propuesta de arquitectura. Fase 1 lista para la IA programadora; fases 2 y 3 se especifican después de revisar la fase 1.
**Alcance:** solo presentación (tema, layout, componentes visuales). No cambia RPC, consultas, permisos, `p_channel`, `ADMIN_ENV`, ni flujos de negocio.

## Diagnóstico (evidencia de lectura)

- `lib/admin_control_sections.dart`: 9.567 líneas. `lib/admin_panel.dart`: 5.095 líneas. Ambos mezclan layout, estilo y lógica.
- El tema existe (`_expressAdminTheme` en `lib/admin_panel.dart`, líneas 32–190), pero los colores, espaciados y tamaños se repiten a mano en cada módulo.
- El responsive está resuelto archivo por archivo (10 archivos con `LayoutBuilder` o `MediaQuery`). No hay breakpoints comunes.
- Hay un `Drawer` solo en móvil y un ancho de corte de 900 px en `lib/main.dart:264`. No hay una navegación única para escritorio, tablet y teléfono.

## Principios

1. **Un solo sistema visual:** tokens (colores, espacios, radios, tipografía) y componentes compartidos. Ningún módulo define colores o tamaños sueltos.
2. **Un solo shell:** navegación lateral en escritorio, `NavigationRail` en tablet, `Drawer` en teléfono, con los mismos elementos y el mismo orden.
3. **Breakpoints únicos:** `< 600` teléfono, `600–1023` tablet, `≥ 1024` escritorio. Definidos una sola vez.
4. **Sin cambios de comportamiento.** Cada botón, filtro, tabla y diálogo llama exactamente lo mismo que antes.
5. **Migración incremental:** un módulo por PR. Nunca un rediseño de toda la app en un solo cambio.

## Fase 1 — Base visual y shell (esta spec)

### 1.1 Tokens
Crear `lib/core/admin_design_tokens.dart` con:
- Colores: `AdminColors` (fondo, superficie, borde, texto primario/secundario, acento, éxito, advertencia, error). Derivados del tema existente para no cambiar la identidad.
- Espacios: `AdminSpacing` (4, 8, 12, 16, 24, 32).
- Radios: `AdminRadius` (8, 12, 16).
- Tipografía: `AdminText` (título de página, título de sección, cuerpo, etiqueta, cifra).
- Breakpoints: `AdminBreakpoints.phone = 600`, `AdminBreakpoints.desktop = 1024`.

Regla: `_expressAdminTheme` pasa a leer estos tokens. No se cambia ningún color visible en esta fase; solo se centralizan.

### 1.2 Shell de navegación
Crear `lib/core/admin_shell.dart` con un único widget `AdminShell` que reciba la lista de módulos y el módulo activo:
- `≥ 1024`: barra lateral fija con los módulos y la indicación de entorno (Preview/Producción) siempre visible.
- `600–1023`: `NavigationRail` colapsado.
- `< 600`: `Drawer` con los mismos módulos y el mismo orden.
- El entorno activo debe mostrarse en el encabezado en todos los tamaños. Es una protección visual contra operar en Producción por error.

`lib/main.dart` y `lib/admin_panel.dart` dejan de tener su propia navegación. Deben llamar a `AdminShell`.

### 1.3 Contenedor de página
Crear `AdminPageScaffold` con:
- Título de página, subtítulo opcional y zona de acciones a la derecha (colapsa debajo del título en teléfono).
- Área de contenido con ancho máximo (1280 px) centrada en escritorio.
- Padding con `AdminSpacing`. Nunca valores fijos por módulo.

### 1.4 Piezas comunes
Crear en `lib/core/admin_widgets.dart`, sin lógica de negocio:
- `AdminCard` (superficie, borde, radio y padding de tokens).
- `AdminMetricTile` (etiqueta, cifra, variación opcional).
- `AdminStatusChip` (estado con color de token).
- `AdminEmptyState` y `AdminErrorState` (con botón Reintentar, como ya existe en el conductor).
- `AdminResponsiveGrid` (1 columna en teléfono, 2 en tablet, 3 o 4 en escritorio).

### 1.5 Migración de la fase 1
Migrar solo estos módulos a `AdminShell` y `AdminPageScaffold`: **Resumen/inicio** y **Zonas**. El resto sigue como está y se migra en fases siguientes.

## Fuera de alcance (fase 1)
- No tocar la lógica de `admin_control_sections.dart` más allá de reemplazar contenedores visuales en los módulos migrados.
- No cambiar nombres de RPC, parámetros `p_channel` ni llamadas a `admin_assert_environment`.
- No cambiar permisos ni la visibilidad de módulos según rol.
- No cambiar textos de negocio ni idioma.

## Restricciones
- Cambios pequeños y revisables. Máximo un módulo migrado por PR.
- Sin dependencias nuevas.
- Sin cambios en Supabase, Edge Functions, migraciones ni configuración de entorno.
- Todo el texto visible en español.

## Cómo probar
1. `flutter analyze lib` sin errores fatales.
2. `flutter test` en verde (agregar tests de los breakpoints y de que `AdminShell` muestra el entorno activo).
3. Pruebas visuales en ancho 360, 768, 1024 y 1440 px, en Chrome. Sin desbordes ni scroll horizontal de página.
4. Confirmar que en Preview y en Producción los módulos migrados llaman a los mismos RPC que antes (comparar con `git diff`).

## Fases siguientes (no implementar todavía)
- **Fase 2:** migrar Conductores, Viajes y Pasajeros (tablas responsive: en teléfono, tarjetas en lugar de tablas anchas).
- **Fase 3:** migrar Pagos, Tarifas, Marketplace y Configuración. Revisar diálogos y formularios largos.

## Formato de devolución
Seguir `docs/AI_RESPONSE_FORMAT.md`: commit, archivos cambiados, salida de analyze y test, y capturas de los cuatro anchos de pantalla.

---

## PROMPT PARA LA IA PROGRAMADORA

Repo `jorge2610g/adminexpress`, rama `claude/express-admin-audit-cp07ml` (crear rama nueva desde ella si la política del repo lo pide; indícalo). Lee `docs/specs/SPEC-2026-10-10-admin-redesign-phases.md` y ejecuta **solo la Fase 1** (secciones 1.1 a 1.5). Migra únicamente los módulos Resumen y Zonas.

No cambies RPC, consultas, parámetros `p_channel`, permisos, lógica de negocio ni configuración de Supabase. No toques migraciones ni Edge Functions. Si algo de la spec no es claro, detente y pregunta antes de adivinar.

Pruebas: `flutter analyze lib` y `flutter test`, más capturas en 360, 768, 1024 y 1440 px. Devuelve el resultado con el formato de `docs/AI_RESPONSE_FORMAT.md`.
