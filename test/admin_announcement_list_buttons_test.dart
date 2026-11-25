import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la lista de avisos del panel incluye los botones (migración de corrección)', () {
    final sql = File('supabase/migrations/20261125180000_admin_announcement_list_buttons.sql').readAsStringSync();
    expect(sql, contains('a.buttons'));
    expect(sql, contains('as buttons'));
  });
}
