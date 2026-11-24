import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/20261124140000_operator_full_view.sql')
      .readAsStringSync();

  test('los detalles de operador devuelven el contenido completo del administrador', () {
    for (final kind in ['trip', 'driver', 'user']) {
      expect(sql, contains('admin_${kind}_detail_payload'));
    }
    // Ya no se arman versiones recortadas con listas vacías para el operador.
    expect(sql, isNot(contains("'status_history', '[]'")));
    expect(sql, isNot(contains("'ratings', '[]'")));
    expect(sql, contains("return public.admin_trip_detail_payload(p_trip_id);"));
    expect(sql, contains("return public.admin_user_detail_payload(p_user_id);"));
    expect(sql, contains("v_result := public.admin_driver_detail_payload(p_user_id);"));
  });

  test('se conserva la comprobación de módulo y de zona del operador', () {
    expect(sql, contains("admin_operator_assert_record('trips', 'trip', p_trip_id)"));
    expect(sql, contains("admin_operator_assert_record('users', 'user', p_user_id)"));
    expect(sql, contains("admin_operator_assert_record('drivers', 'driver', p_user_id)"));
  });

  test('los documentos del conductor siguen su permiso propio', () {
    expect(sql, contains("admin_can('drivers.view_documents'"));
  });

  test('el contenido interno no queda expuesto a los usuarios', () {
    expect(sql, contains('revoke all on function public.%I(%s) from public, anon, authenticated'));
    expect(sql, contains('revoke all on function public.admin_operator_assert_any_module(text[]) from public, anon, authenticated;'));
  });

  test('conductores libres: el operador solo ve su zona', () {
    expect(sql, contains('v_zone := public.admin_effective_zone_id(null);'));
    expect(sql, contains('(v_zone is null or dp.zone_id = v_zone)'));
  });

  test('permisos por vehículo legibles para el operador con acceso a conductores', () {
    expect(sql, contains("admin_can('drivers.view', public.admin_zone_of_user(driver_id))"));
  });

  test('resolver un SOS depende del permiso, no del rol', () {
    final source = File('lib/admin_panel.dart').readAsStringSync();
    expect(source, contains("final canResolve = _can('safety_sos.resolve');"));
    expect(source, isNot(contains("final canResolve = !_readOnly && adminAccess['role'] != 'operator';")));
  });
}
