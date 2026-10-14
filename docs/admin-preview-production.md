# Adminexpress — web única

Decisión vigente del propietario: 14 de octubre de 2026.

- El panel de administración solo se publica en https://admin.expressviajes.online/.
- La web compilada es la misma para usuarios de prueba y usuarios reales.
- `preview` y `production` son entornos internos de datos asignados por la identidad autenticada; no son otra página, URL, bundle, aplicación o subdominio.
- La separación se aplica en backend mediante `admin_access_context()`, `admin_current_runtime_environment()`, `admin_environment_allowed(p_channel)` y reglas de rol, zona, RLS y RPC.
- No añadir rutas de publicación alternativas, selectores manuales de entorno, doble autenticación ni compilaciones con `ADMIN_ENV`.
- Los candidatos Android oficiales se producen desde Expressdelivery con `com.express.usuario1`; este panel no crea APK de pruebas paralelas.
- Probar cambios con una cuenta de pruebas en el dominio oficial sin mezclar viajes, tarifas, pedidos, conductores, documentos o pagos reales.
