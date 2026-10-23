# Deudas y ajustes en Adminexpress

**Actualizado:** 2026-10-23
**Estado:** preparado en rama; pendiente de revisión, QA Preview/Producción y despliegue.

## Alcance

El módulo **Deudas y ajustes** se agrega al área financiera del único Adminexpress. Permite buscar cuentas por nombre o teléfono, filtrar pasajeros y conductores y revisar el saldo, las deudas por cancelación, los movimientos de billetera y las acciones administrativas anteriores de una zona.

## Acciones

- **Registrar pago manual recibido:** selecciona una o más deudas pendientes y registra un pago recibido fuera de la app. El método (efectivo, transferencia u otro) y un motivo son obligatorios; la referencia puede añadirse. La acción liquida las deudas seleccionadas y registra el operador, la zona, el entorno, la moneda, el total, las deudas y la fecha. No representa una verificación de Mercado Pago ni una condonación.
- **Ajustar saldo:** acredita un monto positivo o descuenta uno negativo. El backend agrega un movimiento firmado a la billetera; nunca modifica el balance por edición directa. El motivo es obligatorio, el saldo no puede quedar negativo y se conserva balance anterior/posterior, actor, zona, moneda, entorno y fecha.
- Las dos acciones notifican a la cuenta afectada y quedan en una bitácora administrativa sin permisos directos de lectura o escritura sobre la tabla de auditoría.

Si se requiere condonar deuda, debe añadirse como acción independiente y explícita con autorización y auditoría propias; no se representa como pago recibido.

## Autorización y aislamiento

- Todos los RPC validan sesión, entorno, módulo Pagos, zona efectiva y tipo de rol en el servidor.
- Un operador solo usa el módulo si `payments` está asignado; su zona se resuelve de nuevo desde `admin_users` y no acepta otra zona recibida desde el cliente. Los operadores actúan en Producción.
- Los operadores tienen permisos de lectura y escritura sólo cuando Pagos está asignado. Los roles de monitoreo no reciben permiso de escritura; el backend sólo les permitirá lectura si el contexto les concede explícitamente Pagos.
- `super_admin` necesita tener Pagos autorizado en `admin_access_context` y seleccionar una zona.
- Preview solo afecta cuentas de auditoría y filas `channel='preview'`; Producción excluye esas cuentas. Las funciones comprueban ambos lados antes de escribir.
- La migración no asigna el módulo Pagos a ningún operador ni cambia las capacidades existentes. El superadministrador conserva la asignación individual.

## Tablas/RPC

- Reutiliza `cancellation_fee_debts`, `wallet_country_accounts` y `wallet_transactions`.
- `admin_financial_adjustment_audit` guarda acciones de pago manual y ajuste de billetera.
- RPC de lectura: `admin_debt_wallet_list_v1`, `admin_debt_wallet_detail_v1`.
- RPC de escritura: `admin_settle_cancellation_debts_manual_v1`, `admin_adjust_wallet_balance_v1`.
- `admin_financial_assert_scope` comprueba el permiso, el canal y la zona efectiva.

## Pendiente

La migración y la interfaz no se han aplicado ni desplegado. Falta revisar la migración, ejecutar CI, validar con Preview sin tocar Producción, verificar que Producción conserve los controles financieros actuales y después publicar en la URL canónica cuando se autorice. No se han cambiado saldos ni liquidado deudas como parte de esta implementación.
