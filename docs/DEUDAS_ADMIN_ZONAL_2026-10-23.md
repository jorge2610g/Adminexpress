# Deudas y ajustes financieros por zona

**Estado:** implementado en la rama `feat/admin-zone-debt-management`; la migración todavía debe aplicarse y el panel debe publicarse antes de probarlo desde la cuenta Preview.

## Flujo del panel

En el menú de Adminexpress aparece **Deudas y ajustes**, dentro del permiso `payments`. Permite buscar y filtrar deudas de pasajeros y conductores por estado y tipo. La liquidación manual exige un motivo y registra deuda, actor, zona, canal, importe y fecha. También permite localizar una cuenta activa de la zona y asignar o descontar saldo con motivo obligatorio. El historial muestra importe, motivo y saldos anterior y nuevo.

## Seguridad y contabilidad

- La interfaz no escribe directamente en tablas financieras. Consulta y muta mediante RPCs `admin_finance_debts_v1`, `admin_finance_settle_debt_v1` y `admin_finance_adjust_wallet_v1`.
- Los RPCs toman el entorno de la identidad autenticada, validan el módulo `payments`, y resuelven la zona en el servidor con `admin_effective_zone_id`.
- Operadores solo pueden operar en su zona y deben tener asignado `payments`. `zone_monitor` conserva lectura de acuerdo con el control de módulo y no puede liquidar deudas ni ajustar saldo.
- Preview y Producción se filtran por `channel`; las cuentas QA y reales se excluyen cruzadamente.
- Liquidar una deuda actualiza `paid_at`, que es el estado usado por el backend para desbloquear viajes. La operación se guarda en una tabla de auditoría sin acceso directo para usuarios autenticados.
- Los ajustes de saldo generan un movimiento `adjustment` en el libro existente. La actualización del saldo regional ocurre por su trigger actual; en Producción también se sincroniza el saldo histórico compatible. No se permiten saldos negativos, moneda incompatible ni ajustes CLP con decimales.
- Los RPCs son transaccionales e idempotentes por actor, canal y clave de solicitud.

## Validación y publicación

La prueba estática de permisos está en `test/admin_zonal_debt_management_test.dart`. Antes de usarlo, ejecutar la suite Flutter y validar la migración con el Supabase local. Después, verificar con una cuenta Preview y datos de QA en el mismo panel; comprobar denegación de zona ajena y rol de solo lectura. La migración no se aplica automáticamente en Producción desde esta rama. No hay despliegue ni prueba de dinero real en este cambio.
