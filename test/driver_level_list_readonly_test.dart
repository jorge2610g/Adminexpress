import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la lista de solicitudes usa la lectura de nivel sin escritura', () {
    final sql = File('supabase/migrations/20261126120000_driver_level_list_readonly_fix.sql').readAsStringSync();
    expect(sql, contains('driver_level_for_list'));
    expect(sql, contains('stable security definer'));
    expect(sql, isNot(contains('insert into')));
  });
}
