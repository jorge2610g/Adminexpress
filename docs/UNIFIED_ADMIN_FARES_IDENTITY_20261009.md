# Consolidación del administrador Express — estado actualizado 2026-10-11

## Navegación

### Zonas y cobertura

“Zonas y cobertura” mantiene la configuración de zona/cobertura sin duplicar páginas por entorno.

### Identidad

La validación de documentos e identidad **ya no tiene una opción lateral independiente**.

La revisión se realiza dentro de la **ficha del conductor**.

No volver a mostrar:

- Verificación de identidad;
- Verificación manual.

Los componentes internos pueden permanecer temporalmente para compatibilidad, pero la experiencia de administrador debe tener un único punto de revisión en la ficha.

## Una sola web Admin

Ya no existen dos webs sincronizadas.

URL única:

`https://admin.expressviajes.online/`

La cuenta decide Preview/Producción.

## Tarifas escalonadas

Se conserva la regla por zona/servicio:

- cada `up_to_km` es límite superior inclusivo;
- distancias ascendentes;
- precios positivos y no decrecientes;
- sin tramos, se usa la regla anterior;
- moneda según `currency_code`;
- backend protegido por autorización administrativa.

## Suscripción al conectar conductor

Si el backend exige suscripción, Android puede dirigir al conductor a planes/renovación.

La regla de exigir suscripción debe respetar la configuración backend vigente; el panel no debe inventar una exigencia cuando el ajuste está desactivado.

## Fuente de verdad

Ver `docs/admin-central-access.md` para acceso por usuario y `docs/AI_HANDOFF_2026-10-11.md`.
