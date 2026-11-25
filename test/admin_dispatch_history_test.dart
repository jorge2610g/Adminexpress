import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/admin_dispatch_history.dart';

void main() {
  test('periodos del registro de despachos', () {
    final now = DateTime(2026, 11, 25, 16, 30);
    expect(AdminDispatchRpc.periodStart('today', now), DateTime(2026, 11, 25));
    expect(AdminDispatchRpc.periodStart('7d', now), DateTime(2026, 11, 19));
    expect(AdminDispatchRpc.periodStart('30d', now), DateTime(2026, 10, 27));
  });

  test('resultados en español', () {
    expect(AdminDispatchRpc.outcomeLabel('vio_y_no_respondio'), 'La vio y no respondió');
    expect(AdminDispatchRpc.outcomeLabel('no_la_abrio'), 'No la abrió');
    expect(AdminDispatchRpc.outcomeLabel('acepto'), 'Aceptó');
  });

  test('las RPC existen en la migración y la sección está en Despacho manual', () {
    final sql = File('supabase/migrations/20261125150000_dispatch_unserved_registry.sql').readAsStringSync();
    for (final n in [AdminDispatchRpc.unserved, AdminDispatchRpc.drivers, AdminDispatchRpc.stats]) {
      expect(sql, contains('function public.$n('));
    }
    expect(File('lib/admin_panel.dart').readAsStringSync(), contains('AdminDispatchHub('));
  });
}
