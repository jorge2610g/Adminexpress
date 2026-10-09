# Zonas de operación: radio O polígono (nunca ambos)

**Configuración > Zonas y cobertura > Nueva zona / Editar zona** permite escoger **una sola** cobertura:
- **Radio**: elegir centro en el mapa, indicar distancia en kilómetros. El panel dibuja un círculo.
- **Polígono**: dibujar 3 a 300 puntos geográficos. Se cierra y muestra el polígono; el radio anterior no influye.

El formulario guarda datos de zona y modo geográfico en una única transacción mediante `admin_zone_coverage_save`. Al escoger radio se desactivan todos los polígonos previamente activos; al escoger polígono hay exactamente un polígono principal activo y el radio queda inerte. Cambiar modo **no** borra la zona, sus servicios, tarifas, usuarios ni configuraciones comerciales.

**Seguridad** tiene una pestaña independiente para sectores de peligro/precaución. Ya no permite crear la cobertura operativa desde un segundo editor.

Ambos paneles, Preview y Producción, usan la misma configuración empresarial real en Supabase; las cuentas y viajes de pruebas permanecen por canal. El RPC comprueba autorización para el canal en el servidor. La función `service_zone_id_for_point` solo usa `coverage_mode`, sin fallback a radio desde polígono.

La migración inicial retuvo las reglas existentes: Trinidad (polígono) e Iquique (radio). Ningún registro de zona fue eliminado.
