import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guard conserva RPC de lectura central y limita escritura a operadores', () {
    final file = File(
      'supabase/migrations/20261021011624_operator_module_guard_restore_central_reads.sql',
    );
    expect(file.existsSync(), isTrue);
    final sql = file.readAsStringSync();

    expect(sql, contains("v_role in ('super_admin', 'zone_monitor')"));
    for (final module in [
      'dashboard',
      'users',
      'drivers',
      'trips',
      'marketplace',
      'delivery',
      'delivery_orders',
      'partners',
    ]) {
      expect(sql, contains("'$module'"));
    }
    expect(sql, contains("v_role is distinct from 'operator'"));
    expect(sql, contains("admin_environment_allowed('production')"));
    expect(sql, contains('c.runtime_ready = true'));
    expect(sql, isNot(contains("'fares'")));
    expect(sql, isNot(contains("'payments'")));
    expect(sql, isNot(contains("'subscriptions'")));
    expect(sql, isNot(contains("'notifications'")));
  });
}
