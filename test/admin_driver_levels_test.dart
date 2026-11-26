import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/admin_driver_levels.dart';

void main() {
  test('nombres de nivel', () {
    expect(AdminDriverLevelsRpc.label('elite'), 'Élite');
    expect(AdminDriverLevelsRpc.label('pro'), 'Pro');
    expect(AdminDriverLevelsRpc.label('inicio'), 'Inicio');
    expect(AdminDriverLevelsRpc.label(null), 'Inicio');
  });

  test('lo que le falta al conductor para el siguiente nivel', () {
    final missing = AdminDriverLevelsRpc.missing({
      'criteria': [
        {'label': 'Viajes completados', 'value': 12, 'target': 12, 'unit': 'viajes', 'higher_is_better': true, 'met': true},
        {'label': 'Respuesta a solicitudes', 'value': 20.8, 'target': 30, 'unit': '%', 'higher_is_better': true, 'met': false},
        {'label': 'Cancelaciones', 'value': 20, 'target': 15, 'unit': '%', 'higher_is_better': false, 'met': false},
      ],
    });
    expect(missing.length, 2);
    expect(missing.first, contains('mínimo 30 %'));
    expect(missing.last, contains('máximo 15 %'));
    expect(AdminDriverLevelsRpc.missing({}), isEmpty);
  });

  test('las RPC existen en la migración', () {
    final sql = File('supabase/migrations/20261126100000_driver_levels_phase1.sql').readAsStringSync();
    for (final n in [AdminDriverLevelsRpc.list, AdminDriverLevelsRpc.settingsGet, AdminDriverLevelsRpc.settingsUpdate]) {
      expect(sql, contains('function public.$n('));
    }
  });
}
