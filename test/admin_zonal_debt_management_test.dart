import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20261023173108_admin_zonal_debt_management_20261023.sql',
  ).readAsStringSync();
  final debitMigration = File(
    'supabase/migrations/20261023183207_admin_finance_allow_debit_wallet.sql',
  ).readAsStringSync();
  final emailMigration = File(
    'supabase/migrations/20261023183433_admin_finance_target_email.sql',
  ).readAsStringSync();
  final adjustmentDebtMigration = File(
    'supabase/migrations/20261023192317_admin_adjustment_wallet_debt.sql',
  ).readAsStringSync();
  final ui = File('lib/admin_debt_management.dart').readAsStringSync();
  final panel = File('lib/admin_panel.dart').readAsStringSync();

  test(
    'finance RPCs enforce server-side module, environment and zone scope',
    () {
      expect(migration, contains("admin_operator_assert_module('payments')"));
      expect(migration, contains('admin_current_runtime_environment()'));
      expect(migration, contains('admin_assert_environment(v_channel)'));
      expect(migration, contains('admin_effective_zone_id(p_zone_id)'));
      expect(migration, contains("v_role not in ('super_admin','operator')"));
      expect(migration, contains('public.is_active_audit_user'));
      expect(migration, contains('set search_path ='));
    },
  );

  test('central admins can use finance while operators keep module guards', () {
    expect(
        migration, contains("v_admin_role not in ('super_admin','operator')"));
    expect(migration, contains("if v_admin_role='operator' then"));
    expect(migration, contains("if v_role='operator' then"));
    expect(migration, contains('No autorizado para liquidar deudas'));
    expect(migration, contains('No autorizado para ajustar billeteras'));
  });

  test('all finance RPC bodies terminate as valid PL/pgSQL blocks', () {
    expect('\nend;\n\$fn\$;'.allMatches(migration).length, 3);
  });

  test(
    'manual settlement and wallet changes are reasoned, atomic and auditable',
    () {
      expect(migration, contains('admin_financial_operations'));
      expect(
        migration,
        contains('idempotency_key unique(actor_id,channel,idempotency_key)'),
      );
      expect(migration, contains("set paid_at=now()"));
      expect(migration, contains("'adjustment','completed'"));
      expect(migration, contains('mirror_legacy_wallet_delta'));
      expect(debitMigration, contains('v_after:=v_before+v_delta'));
      expect(debitMigration,
          isNot(contains('El ajuste no puede dejar saldo negativo')));
      expect(debitMigration,
          isNot(contains('El ajuste dejaría negativa la billetera histórica')));
      expect(debitMigration,
          isNot(contains('No se puede debitar: la billetera no tiene saldo')));
      expect(debitMigration,
          contains('mirror_legacy_wallet_delta(p_user_id,v_currency,v_delta)'));
      expect(migration, contains('trim(p_reason)'));
      expect(
        migration,
        contains(
          'revoke all on public.admin_financial_operations from public, anon, authenticated',
        ),
      );
    },
  );

  test('panel exposes debts only through the payments module', () {
    expect(panel, contains("33: 'payments'"));
    expect(panel, contains("('Deudas y ajustes'"));
    expect(panel, contains("('FINANZAS', [9, 8, 22, 33])"));
    expect(panel, contains('AdminDebtManagementPage('));
  });

  test('admin debit creates a scoped debt and credits reduce it FIFO', () {
    expect(adjustmentDebtMigration, contains('admin_wallet_adjustment_debts'));
    expect(
        adjustmentDebtMigration,
        contains(
            'alter table public.admin_wallet_adjustment_debts enable row level security'));
    expect(
        adjustmentDebtMigration,
        contains(
            'revoke all on public.admin_wallet_adjustment_debts from public,anon,authenticated'));
    expect(adjustmentDebtMigration,
        contains("v_debt_amount:=greatest(0,-v_after)-greatest(0,-v_before)"));
    expect(adjustmentDebtMigration,
        contains('apply_admin_adjustment_debt_credit'));
    expect(adjustmentDebtMigration, contains('order by d.created_at,d.id'));
    expect(
        adjustmentDebtMigration, contains('admin_finance_adjustment_debts_v1'));
    expect(adjustmentDebtMigration,
        contains('admin_finance_settle_adjustment_debt_v1'));
    expect(
      adjustmentDebtMigration,
      contains("if coalesce(v_role,'') not in ('super_admin','operator') then"),
    );
  });

  test(
    'UI invokes only scoped RPCs for debt settlement and wallet adjustment',
    () {
      expect(ui, contains("'admin_finance_debts_v1'"));
      expect(ui, contains("'admin_finance_settle_debt_v1'"));
      expect(ui, contains("'admin_finance_adjust_wallet_v1'"));
      expect(ui, contains("'admin_finance_adjustment_debts_v1'"));
      expect(ui, contains("'admin_finance_settle_adjustment_debt_v1'"));
      expect(ui, contains("'p_reason': reason"));
      expect(ui, contains("'p_idempotency_key'"));
      expect(ui, isNot(contains(".from('wallet_accounts').update")));
      expect(ui, isNot(contains(".from('cancellation_fee_debts').update")));
      expect(
          ui,
          contains(
              'la diferencia quedará como deuda administrativa en negativo'));
      expect(ui, contains('Deuda registrada. Saldo deudor:'));
      expect(emailMigration, contains('left join auth.users au on au.id=u.id'));
      expect(emailMigration, contains('au.email'));
      expect(ui, contains("target['email'] ?? 'Sin correo'"));
    },
  );
}
