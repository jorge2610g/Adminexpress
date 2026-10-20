import 'package:adminexpress/admin_operators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final keys = operatorSelectorModules.map((m) => m.key).toList();

  test('Usuarios siempre va incluido como base del operador', () {
    expect(operatorBaseModule, 'users');
    expect(keys, contains(operatorBaseModule));
  });

  test('ningún módulo aparece dos veces en el selector', () {
    expect(keys.toSet().length, keys.length);
  });

  test('las funciones solo de administrador central no se pueden dar', () {
    for (final key in [
      'operators',
      'builds',
      'settings',
      'advanced_settings',
      'audit',
      'test_environments',
      'qa_load',
    ]) {
      expect(keys, isNot(contains(key)), reason: key);
    }
  });

  test('finanzas y análisis se pueden elegir aunque aún necesiten ajuste', () {
    expect(keys, containsAll(['payments', 'fares', 'subscriptions', 'reports']));
    expect(
      operatorSelectorModules.firstWhere((m) => m.key == 'payments').ready,
      isFalse,
    );
  });

  test('solo los módulos ya permitidos por el servidor están marcados como listos', () {
    final ready = operatorSelectorModules
        .where((m) => m.ready)
        .map((m) => m.key)
        .toSet();
    expect(ready, {
      'dashboard',
      'trips',
      'drivers',
      'users',
    });
  });
}
