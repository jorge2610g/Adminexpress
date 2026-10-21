import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RPC de operador exige rol, zona, entorno y módulo habilitado', () {
    final file = File(
      'supabase/migrations/20261021010453_operator_capability_guard_hardening.sql',
    );
    expect(file.existsSync(), isTrue);
    final sql = file.readAsStringSync();

    expect(sql, contains("v_role is distinct from 'operator'"));
    expect(sql, contains('v_zone is null'));
    expect(sql, contains("admin_environment_allowed('production')"));
    expect(sql, contains("admin_current_runtime_environment() <> 'production'"));
    expect(sql, contains('p_module = any(coalesce(v_modules'));
    expect(sql, contains('c.runtime_ready = true'));
    expect(sql, isNot(contains("if v_role in ('super_admin','zone_monitor') then return")));
  });
}
