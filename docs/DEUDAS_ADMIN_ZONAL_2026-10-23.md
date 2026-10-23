# Deudas y ajustes financieros por zona

**Estado:** la gestión zonal existente está publicada. El control configurable del tope descrito abajo está implementado en esta rama y requiere integrar su migración coordinada con Express antes de quedar activo.

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
- El backend bloquea al pasajero al solicitar Taxi y al conductor al conectarse, enviar/aceptar Taxi, Envíos o Delivery cuando la deuda de su rol supera el tope de su zona. Envíos solicitados por pasajeros no se bloquean. Si una deuda nueva supera el tope, se desconecta al conductor si no tiene un servicio activo; los trabajos activos pueden terminar.
- Saldos negativos históricos solo se clasifican cuando todos los movimientos de la billetera son ajustes administrativos completados y el negativo actual coincide exactamente con los débitos administrativos no cubiertos. Los saldos mixtos que incluyan comisiones, recargas u otros movimientos se excluyen para revisión manual.
- La billetera móvil muestra el monto y motivo del ajuste. Pasajeros con deuda pueden hacer un abono desde la misma billetera; el saldo pendiente reduce primero la deuda, y un remanente queda disponible. Preview solo permite simular el pago en cuentas QA.
- Los RPCs son transaccionales e idempotentes por actor, canal y clave de solicitud.

## Tope configurable por tipo de cuenta

En **Deudas y ajustes** se configuran por separado **Tope pasajero** y **Tope conductor**, usando la moneda de la zona seleccionada. El servidor guarda cada par de valores por zona y por canal (`preview` o `production`) y verifica el módulo `payments`, el usuario autenticado y el alcance zonal antes de leer o guardar. Los cambios se registran en `zone_wallet_debt_limit_audit`.

- El bloqueo se activa solo cuando la deuda acumulada es **mayor** que el tope. Con 10 BOB configurados, 9 BOB y exactamente 10 BOB siguen permitidos; 10,01 BOB supera el tope.
- Se suman las deudas administrativas pendientes y las de cancelación impagas del rol en uso. El saldo de comisiones no se mezcla con esta deuda.
- Un valor de 0 —también el valor inicial si la zona aún no tiene configuración— conserva la regla estricta anterior: cualquier deuda positiva supera el tope.
- Al guardar un tope de conductor menor que su deuda actual, el backend lo desconecta si está libre. Los viajes y entregas activos pueden terminar; no podrá conectarse ni aceptar otro trabajo hasta que vuelva a quedar dentro del tope.
- En zona, canal, moneda y rol, Prueba y Producción permanecen separados. No se cambia deuda, saldo ni el estado de una cuenta al configurar el límite.

## Validación y publicación

Las pruebas de contrato están en `test/admin_zonal_debt_management_test.dart` y `test/admin_wallet_debt_limits_test.dart`. No simular débitos en cuentas reales. Para probar la configuración usa una cuenta QA del entorno `PRUEBA`; verifica allí que 9/10 BOB no bloqueen y que una deuda superior a 10 sí lo haga. No cruces datos Preview/Producción.
