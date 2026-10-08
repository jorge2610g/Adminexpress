# Bolivia KYC · panel Didit/Manual
Cambios en PR #37, coordinados con Expressdelivery PR #124 y #123.

Al seleccionar **Bolivia** en el selector geográfico del panel y abrir **Didit**:
- Ver un contador Didit de hasta **30 sesiones** mensuales para Bolivia.
- Elegir **Automático (Didit hasta 30, después manual)**, **Preferir Didit** (respeta también 30) o **Manual Express**.
- Cambiar método solo para el canal seleccionado (**Pruebas** o **Producción**).
- Revisar solicitudes manuales de Bolivia: anverso, reverso, fotografía facial con URL firmada temporal.
- Aprobar únicamente la identidad, rechazarla con motivo o pedir una nueva captura. La aprobación total del conductor se realiza por separado.

Las imágenes continúan en el bucket privado `driver-onboarding`; el administrador no accede a secretos. Chile no está incluido.

No publicar el panel antes de las migraciones y los despliegues backend correspondientes.
Aún falta validar una política de retención automática/eliminación de evidencia temporal y una prueba QA real en Supabase antes de Producción.

Guía técnica general: `Expressdelivery/docs/BOLIVIA_DIDIT_30_MANUAL_KYC_20261008.md`.
