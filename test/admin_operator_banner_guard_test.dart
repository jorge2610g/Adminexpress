import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20261021023917_admin_operator_banner_module_guard.sql';

  String functionBody(String sql, String name) {
    final start = sql.indexOf('create or replace function public.$name');
    expect(
      start,
      greaterThanOrEqualTo(0),
      reason: '$name must be in the migration',
    );
    final next = sql.indexOf('\ncreate or replace function', start + 1);
    return sql.substring(start, next < 0 ? sql.length : next);
  }

  final migration = File(migrationPath).readAsStringSync();

  test(
    'el guard de banners queda con search_path vacío y módulo marketplace',
    () {
      for (final name in [
        'admin_landing_banner_save_v1',
        'admin_landing_banners_list_v1',
      ]) {
        final body = functionBody(migration, name);
        expect(
          body,
          contains(
            "perform public.admin_operator_assert_module('marketplace')",
          ),
        );
        expect(body, contains("set search_path = ''"));
        expect(body, contains("c.module_key = 'marketplace'"));
        expect(body, contains('c.runtime_ready = true'));
        expect(body, contains('public.admin_effective_zone_id(p_zone_id)'));
      }
    },
  );

  test('el guard exige autorización antes de leer o escribir banners', () {
    final save = functionBody(migration, 'admin_landing_banner_save_v1');
    final list = functionBody(migration, 'admin_landing_banners_list_v1');
    expect(
      save.indexOf(
        "perform public.admin_operator_assert_module('marketplace')",
      ),
      lessThan(save.indexOf('insert into public.passenger_landing_banners')),
    );
    expect(
      list.indexOf(
        "perform public.admin_operator_assert_module('marketplace')",
      ),
      lessThan(list.indexOf('from public.passenger_landing_banners')),
    );
    expect(save, contains('b.zone_id = v_zone_id'));
    expect(save, contains('b.channel = p_channel'));
    expect(save, contains('current_banner.zone_id = excluded.zone_id'));
    expect(save, contains('if v_id is null then'));
    expect(save, contains('insert into public.admin_audit_log'));
    expect(list, contains('b.zone_id = v_zone_id'));
    expect(list, contains('b.channel = p_channel'));
  });

  test(
    'solo authenticated y service_role conservan execute al aplicar el fix',
    () {
      expect(migration, contains('from public, anon;'));
      expect(migration, contains('to authenticated, service_role;'));
    },
  );

  test('el rollback cierra el acceso sin restaurar el guard anterior', () {
    final rollback = File(
      'supabase/rollback/20261021023917_admin_operator_banner_module_guard_rollback.sql',
    ).readAsStringSync();
    expect(rollback, contains('from public, anon, authenticated;'));
    expect(rollback, isNot(contains('to authenticated')));
  });
}
