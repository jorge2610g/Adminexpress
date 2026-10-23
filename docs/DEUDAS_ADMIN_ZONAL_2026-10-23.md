# Deudas y ajustes financieros por zona

**Estado:** implementación en el código; migraciones y publicación pendientes. La migración `20261023192317_admin_adjustment_wallet_debt.sql` agrega el registro de deuda administrativa que bloquea nuevos servicios hasta el pago; el panel expone esas deudas y permite liquidarlas con motivo. El flujo requiere aplicar también la migración compartida `20261023192321_enforce_admin_adjustment_debt.sql` de Expressdelivery antes de publicar el panel actualizado.

## Flujo del panel

En el menú de Adminexpress aparece **Deudas y ajustes**, dentro del permiso `payments`. Permite buscar y filtrar deudas de pasajeros y conductores por estado y tipo. La liquidación manual exige un motivo y registra deuda, actor, zona, canal, importe y fecha. También permite localizar una cuenta activa de la zona por nombre, correo, teléfono o ID y asignar o descontar saldo con motivo obligatorio. El correo se muestra en la lista y en los registros de deuda/ajuste, solo para operadores autorizados de la zona. El historial muestra importe, motivo y saldos anterior y nuevo.

## Seguridad y contabilidad

- La interfaz no escribe directamente en tablas financieras. Consulta y muta mediante RPCs `admin_finance_debts_v1`, `admin_finance_settle_debt_v1` y `admin_finance_adjust_wallet_v1`.
- Los RPCs toman el entorno de la identidad autenticada, validan el módulo `payments`, y resuelven la zona en el servidor con `admin_effective_zone_id`.
- Operadores solo pueden operar en su zona y deben tener asignado `payments`. `zone_monitor` conserva lectura de acuerdo con el control de módulo y no puede liquidar deudas ni ajustar saldo.
- Preview y Producción se filtran por `channel`; las cuentas QA y reales se excluyen cruzadamente.
- Liquidar una deuda actualiza `paid_at`, que es el estado usado por el backend para desbloquear viajes. La operación se guarda en una tabla de auditoría sin acceso directo para usuarios autenticados.
- Los ajustes de saldo generan un movimiento `adjustment` en el libro existente. La actualización del saldo regional ocurre por su trigger actual; en Producción también se sincroniza el saldo histórico compatible. Un descuento puede dejar el saldo negativo: ese negativo es una deuda administrativa y aparece en el saldo y en la auditoría con su motivo. Los créditos posteriores reducen primero ese saldo deudor. La moneda debe coincidir y CLP no admite decimales.
- Solo la parte del descuento que deja la billetera en negativo genera deuda administrativa pendiente; un saldo negativo por comisiones se mantiene separado. La deuda conserva el motivo del operador. Créditos del panel, liquidación manual y recargas verificadas reducen la deuda en orden FIFO y en la misma transacción.
- El backend bloquea al pasajero al solicitar Taxi y al conductor al conectarse, enviar/aceptar Taxi, Envíos o Delivery, mientras quede deuda administrativa. Envíos solicitados por pasajeros no se bloquean. Al registrar una deuda se desconecta al conductor si no tiene un servicio activo; los trabajos activos pueden terminar.
- Los saldos negativos históricos no se clasifican automáticamente: pueden provenir de comisiones. Deben revisarse en la auditoría antes de crear una deuda administrativa nueva.
- La billetera móvil muestra el monto y motivo del ajuste. Pasajeros con deuda pueden hacer un abono desde la misma billetera; el saldo pendiente reduce primero la deuda, y un remanente queda disponible. Preview solo permite simular el pago en cuentas QA.
- Los RPCs son transaccionales e idempotentes por actor, canal y clave de solicitud.

## Validación y publicación

Las pruebas de contrato están en `test/admin_zonal_debt_management_test.dart`. Validar la RPC con revisión estática y pruebas automatizadas; no simular débitos en cuentas reales. Tras desplegar la migración y el panel canónico, un administrador puede probarlo desde la misma web con una cuenta de QA del entorno correspondiente. La función conserva idempotencia, restricción de rol/módulo/zona/canal, compatibilidad de moneda y auditoría; no se deben cruzar datos Preview/Producción.
