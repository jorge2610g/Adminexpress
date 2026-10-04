# Adminexpress — regla Preview / Producción

## Regla obligatoria

Adminexpress tiene **una sola interfaz administrativa**.

Preview y Producción deben usar:
- la misma navegación;
- las mismas páginas;
- los mismos botones, formularios, pestañas y funciones;
- el mismo código de presentación.

El selector de entorno **solo puede cambiar la capa de datos**.

## Separación de datos

- `production`: usa las tablas, RPC y servicios operativos reales.
- `preview`: usa datos QA/Preview y `admin_environment_config` para la configuración aislada.
- Una escritura realizada en Preview nunca debe modificar configuración, pagos, zonas, tarifas, credenciales o registros de Producción.
- Los usuarios QA pueden vivir en almacenamiento compartido únicamente cuando están marcados explícitamente como QA/Preview y todas las consultas los filtran por entorno.

## Nueva funcionalidad

Toda función nueva del panel debe implementarse una sola vez y recibir el entorno como parámetro.

Correcto:

```dart
AdminSettingsPage(channel: adminChannel)
```

Incorrecto:

```dart
adminChannel == 'preview'
    ? PreviewSettingsPage()
    : ProductionSettingsPage()
```

No se deben crear árboles de navegación separados ni versiones simplificadas de una pantalla para Preview.

## Excepción de herramientas QA

Las herramientas de QA pueden estar visibles en el árbol común, pero sus acciones deben permanecer aisladas de Producción. Nunca deben crear viajes, pagos, usuarios o configuración real desde el entorno Preview.

## Validación automática

El workflow `.github/workflows/validate-preview-production-split.yml` bloquea:
- referencias a `AdminPreviewModulePage` desde el panel principal;
- navegación diferente por entorno;
- pérdida de los parámetros `channel` en los módulos principales.

Además ejecuta `flutter analyze` y un build web de humo antes de aceptar el cambio.
