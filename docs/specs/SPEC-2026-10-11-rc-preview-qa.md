# Lista de QA del candidato del rediseño en Preview (2026-10-11)

Estado: candidato de la rama `claude/redesign-rc-2026-10-11`. Todavía no está publicado en Preview. Producción no cambia.

## Antes de empezar
- Entra con un administrador que tenga `allow_preview`. Si existe, usa uno sin `allow_production`: así compruebas que Preview no depende de Producción.
- Anota el commit que muestra `/preview/version.json` cuando esté publicado.

## Pasos
1. **Acceso.** El panel abre en Preview. Solo aparecen los módulos de la lista de Preview. Zonas (7), Tarifas (8) y Cobertura (17) muestran el mensaje de bloqueo.
2. **Conductores.** La lista carga solo conductores de QA. El filtro «Identidad por revisar (N)» cuenta solo las filas visibles. Aprueba y rechaza un caso de identidad de QA. El cambio aparece solo en Preview.
3. **Ficha del conductor.** El carrusel muestra la identidad primero. El documento se abre dentro de la app. La cuadrícula de vehículo aparece una sola vez.
4. **Ajustes (11).** Los valores que se ven son los de QA. Al guardar solo cambia la configuración de Preview. Comprueba que `app_settings` de Producción no cambia (`updated_at` sin cambios).
5. **Servicios (16).** Los cambios se guardan como configuración de QA. No aparecen en Producción.
6. **Requisitos de documentos (dentro de Identidad, 18).** Los cambios se guardan como configuración de QA.
7. **Suscripciones (22) y Prioridad (25).** Solo filas de QA. No aparecen conductores reales. El editor de métodos de pago no se puede abrir en Preview.
8. **Auditoría (14) y Reportes (10).** Solo datos de Preview. No aparecen filas de Producción.
9. **Módulos bloqueados en Preview.** Sandbox (20), Laboratorio de carga (21), Mercado (23), Mercado fase 2 (24 y 26) y Precios dinámicos (28) siguen bloqueados. No los abras en Preview hasta que se apruebe su QA.

## Registrar fallos
Anota el módulo, la acción, el mensaje que se muestra, la hora (UTC) y la cuenta usada.

## Criterio de salida
- Ninguna escritura en configuración de Producción desde Preview.
- Ninguna fila de Producción visible en Preview.
- Los módulos bloqueados siguen bloqueados.
- El flujo de identidad (aprobar y rechazar) funciona sin errores en pantalla.
