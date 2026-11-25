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

  test('porcentajes del resumen', () {
    expect(AdminDispatchRpc.percent(44, 103), '43%');
    expect(AdminDispatchRpc.percent(0, 0), '—');
  });

  test('alertas del resumen', () {
    // 7 días reales de Trinidad: 44 de 103 concretadas, 125 de 193 sin respuesta, 12 sin notificados.
    final alerts = AdminDispatchRpc.alerts({
      'requests': 103, 'concretadas': 44, 'sin_notificados': 12,
      'notificaciones': 193, 'ignoradas': 125,
    });
    expect(alerts.length, 3);
    expect(alerts.first, contains('43%'));
    // Con pocas solicitudes o buen servicio no hay alertas.
    expect(AdminDispatchRpc.alerts({'requests': 3, 'concretadas': 0, 'notificaciones': 4}), isEmpty);
    expect(
      AdminDispatchRpc.alerts({'requests': 20, 'concretadas': 15, 'notificaciones': 30, 'ignoradas': 5}),
      isEmpty,
    );
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
    final summarySql = File('supabase/migrations/20261125160000_dispatch_summary.sql').readAsStringSync();
    expect(summarySql, contains('function public.${AdminDispatchRpc.summary}('));
    expect(File('lib/admin_panel.dart').readAsStringSync(), contains('AdminDispatchHub('));
  });
}
