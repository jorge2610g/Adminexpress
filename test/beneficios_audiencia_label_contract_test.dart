import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La lista de beneficios del panel muestra la audiencia en texto legible,
/// no el valor técnico (passengers / drivers / all).
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/admin_benefits.dart').readAsStringSync();
  });

  test('la lista usa el texto de audiencia en lugar del valor técnico', () {
    expect(source, contains("_audienceLabel(config['audience'], 'Pasajeros')"));
    expect(source, contains("_audienceLabel(config['audience'], 'Clientes')"));
    expect(source, isNot(contains("config['audience']?.toString() ?? 'Pasajeros'")));
  });

  test('el texto cubre pasajeros, conductores y todos', () {
    expect(source, contains("'drivers' => 'Conductores'"));
    expect(source, contains("'passengers' => 'Pasajeros'"));
    expect(source, contains("'all' => 'Todos los usuarios'"));
  });
}
