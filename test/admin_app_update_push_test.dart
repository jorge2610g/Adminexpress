import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el aviso de actualización usa el envío dirigido y muestra los conteos', () {
    final src = File('lib/admin_single_app_release.dart').readAsStringSync();
    expect(src, contains("'admin_send_app_update_push_v1'"));
    expect(src, contains("'admin_app_update_audience_v1'"));
    expect(src, isNot(contains("'admin_send_announcement_v4'")));
    expect(src, contains('Ya actualizados (no recibirán)'));
    final sql = File('supabase/migrations/20261125170000_app_update_push_targeting.sql').readAsStringSync();
    expect(sql, contains('function public.admin_send_app_update_push_v1('));
    expect(sql, contains('function public.register_native_push_token_v3('));
  });
}
