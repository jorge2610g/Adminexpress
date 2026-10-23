import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20261023221937_wallet_debt_threshold_settings.sql',
  ).readAsStringSync();
  final ui = File('lib/admin_debt_management.dart').readAsStringSync();

  test('limits are separated by role, zone and authenticated runtime', () {
    expect(migration, contains('zone_wallet_debt_limits'));
    expect(
      migration,
      contains(
        "channel text not null check (channel in ('preview','production'))",
      ),
    );
    expect(migration, contains('primary key (channel, zone_id)'));
    expect(migration, contains('passenger_limit numeric(14,2)'));
    expect(migration, contains('driver_limit numeric(14,2)'));
    expect(migration, contains('admin_current_runtime_environment()'));
    expect(migration, contains('admin_assert_environment(v_channel)'));
    expect(migration, contains('admin_effective_zone_id(p_zone_id)'));
    expect(migration, contains("admin_operator_assert_module('payments')"));
  });

  test(
    'updates are auditable and lowering the driver cap takes effect now',
    () {
      expect(migration, contains('zone_wallet_debt_limit_audit'));
      expect(migration, contains('passenger_limit_before'));
      expect(migration, contains('driver_limit_after'));
      expect(migration, contains('online_status=\'offline\''));
      expect(
        migration,
        contains('t.status not in (\'completed\',\'cancelled\')'),
      );
      expect(
        migration,
        contains('d.status not in (\'delivered\',\'cancelled\')'),
      );
    },
  );

  test('panel has independent inputs for passenger and driver limits', () {
    expect(ui, contains("'admin_wallet_debt_limits_get_v1'"));
    expect(ui, contains("'admin_wallet_debt_limits_set_v1'"));
    expect(ui, contains("labelText: 'Tope pasajero'"));
    expect(ui, contains("labelText: 'Tope conductor'"));
    expect(ui, contains("'p_passenger_limit': passenger"));
    expect(ui, contains("'p_driver_limit': driver"));
    expect(ui, contains('Se bloquea al superarlo'));
  });
}
