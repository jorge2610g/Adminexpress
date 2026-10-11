# Bolivia KYC · Didit / Manual — actualizado 2026-10-11

Al trabajar con una cuenta autorizada para Bolivia:

- mostrar contador Didit de hasta 30 sesiones mensuales;
- permitir Automático / Preferir Didit / Manual Express;
- revisar anverso, reverso y fotografía facial mediante URL temporal;
- aprobar identidad, rechazar con motivo o pedir nueva captura;
- la aprobación total del conductor sigue siendo una decisión separada.

## Entorno

Ya no existe un selector Prueba/Producción.

El entorno lo determina la cuenta autenticada:

- cuenta Preview -> flujo de prueba;
- cuenta Producción -> flujo real.

No permitir que una cuenta Preview escriba sobre identidad real.

## Navegación

La revisión de identidad se realiza dentro de la **ficha del conductor**, no en un menú lateral independiente.

Las imágenes permanecen en el bucket privado `driver-onboarding`. El frontend no accede a secretos.

Chile no forma parte de esta guía.

Guía técnica móvil: `Expressdelivery/docs/BOLIVIA_DIDIT_30_MANUAL_KYC_20261008.md`.
