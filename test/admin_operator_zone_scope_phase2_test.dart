import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fase 2 mantiene control de modulo, zona y entorno en servidor', () {
    final file = File('supabase/migrations/20261020143000_operator_zone_scope_phase2.sql');
    expect(file.existsSync(), isTrue);
    final sql = file.readAsStringSync();
    expect(sql, contains('admin_operator_assert_module'));
    expect(sql, contains('admin_operator_assert_record'));
    expect(sql, contains("v_assigned is distinct from v_target_zone"));
    expect(sql, contains("admin_current_runtime_environment() <> 'production'"));
    for (final target in ['user','driver','trip','merchant','partner']) {
      expect(sql, contains("p_kind='$target'"));
    }
    for (final section in [
      'admin_user_detail_v2', 'admin_driver_detail_v2', 'admin_trip_detail_v2',
      'admin_update_user_profile_v2', 'admin_user_list_v4',
      'admin_driver_list_v3', 'admin_trip_list_v4', 'admin_delivery_list_v4',
    ]) {
      expect(sql, contains(section));
    }
    expect(sql, contains('revoke all on function'));
    expect(sql, contains('operator_contact_update'));
    expect(sql, isNot(contains('drop table ')));
  });
}
