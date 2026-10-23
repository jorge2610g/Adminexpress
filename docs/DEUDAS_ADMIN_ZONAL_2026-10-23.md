# Deudas y ajustes financieros por zona

**Estado:** el módulo, navegación y corrección para permitir descuentos con saldo negativo están publicados en el panel canónico. Las migraciones `admin_finance_allow_debit_wallet` (`20261023183207`) y `admin_finance_target_email` (`20261023183433`) se aplicaron al Supabase oficial.

## Flujo del panel

En el menú de Adminexpress aparece **Deudas y ajustes**, dentro del permiso `payments`. Permite buscar y filtrar deudas de pasajeros y conductores por estado y tipo. La liquidación manual exige un motivo y registra deuda, actor, zona, canal, importe y fecha. También permite localizar una cuenta activa de la zona por nombre, correo, teléfono o ID y asignar o descontar saldo con motivo obligatorio. El correo se muestra en la lista y en los registros de deuda/ajuste, solo para operadores autorizados de la zona. El historial muestra importe, motivo y saldos anterior y nuevo.

## Seguridad y contabilidad

- La interfaz no escribe directamente en tablas financieras. Consulta y muta mediante RPCs `admin_finance_debts_v1`, `admin_finance_settle_debt_v1` y `admin_finance_adjust_wallet_v1`.
- Los RPCs toman el entorno de la identidad autenticada, validan el módulo `payments`, y resuelven la zona en el servidor con `admin_effective_zone_id`.
- Operadores solo pueden operar en su zona y deben tener asignado `payments`. `zone_monitor` conserva lectura de acuerdo con el control de módulo y no puede liquidar deudas ni ajustar saldo.
- Preview y Producción se filtran por `channel`; las cuentas QA y reales se excluyen cruzadamente.
- Liquidar una deuda actualiza `paid_at`, que es el estado usado por el backend para desbloquear viajes. La operación se guarda en una tabla de auditoría sin acceso directo para usuarios autenticados.
- Los ajustes de saldo generan un movimiento `adjustment` en el libro existente. La actualización del saldo regional ocurre por su trigger actual; en Producción también se sincroniza el saldo histórico compatible. Un descuento puede dejar el saldo negativo: ese negativo es una deuda administrativa y aparece en el saldo y en la auditoría con su motivo. Los créditos posteriores reducen primero ese saldo deudor. La moneda debe coincidir y CLP no admite decimales.
- Los RPCs son transaccionales e idempotentes por actor, canal y clave de solicitud.

## Validación y publicación

Las pruebas de contrato están en `test/admin_zonal_debt_management_test.dart`. Validar la RPC con revisión estática y pruebas automatizadas; no simular débitos en cuentas reales. Tras desplegar la migración y el panel canónico, un administrador puede probarlo desde la misma web con una cuenta de QA del entorno correspondiente. La función conserva idempotencia, restricción de rol/módulo/zona/canal, compatibilidad de moneda y auditoría; no se deben cruzar datos Preview/Producción.
