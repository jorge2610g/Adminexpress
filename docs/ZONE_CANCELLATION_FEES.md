# Configuración de cobros por cancelación

El panel de Tarifas permite a un superadministrador activar o desactivar el cobro por zona y definir montos distintos para pasajero y conductor. Las zonas nuevas comienzan con el cobro apagado.

La configuración sigue el entorno de la cuenta autenticada y se guarda para la zona seleccionada.

La migración correspondiente se aplicó a Express Production el 2026-10-22 y quedó registrada como `20261022200756`. La verificación posterior encontró cero zonas configuradas o activas y cero deudas; por lo tanto, ningún cobro está habilitado.

Este PR mantiene los cambios del editor en el repositorio. El despliegue del panel único se realiza después de integrar el PR mediante el workflow oficial de Adminexpress.
