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

  test('habilitaciones de producción respetan las dependencias del mapa', () {
    expect(
      operatorNormalizedModules({'live_operations'}),
      containsAll(['users', 'live_operations', 'dashboard', 'drivers']),
    );
    final reduced = operatorToggledModules(
      {'users', 'live_operations', 'dashboard', 'drivers'}, 'drivers', false,
    );
    expect(reduced, isNot(contains('live_operations')));
    expect(reduced, contains('dashboard'));
    expect(reduced, isNot(contains('drivers')));
  });

  test('Delivery de lectura está disponible pero funciones sensibles no', () {
    expect(operatorNormalizedModules(
      {'users', 'delivery', 'manual_dispatch', 'payments'}),
      {'users', 'delivery'},
    );
    expect(operatorSelectorModules.firstWhere((m) => m.key == 'delivery').ready, isTrue);
    expect(operatorSelectorModules.firstWhere((m) => m.key == 'manual_dispatch').ready, isFalse);
    expect(operatorNormalizedModules({'safety_sos'}),
      containsAll(['safety_sos','dashboard','drivers']));
    final revoked = operatorToggledModules(
      {'users','safety_sos','dashboard','drivers'}, 'dashboard', false);
    expect(revoked, isNot(contains('safety_sos')));
  });

  test('solo los módulos ya permitidos por el servidor están marcados como listos', () {
    final ready = operatorSelectorModules
        .where((m) => m.ready)
        .map((m) => m.key)
        .toSet();
    expect(ready, {
      'dashboard',
      'live_operations',
      'trips',
      'drivers',
      'users',
      'delivery',
      'safety_sos',
    });
  });
}
