import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El formulario del reto de conductores debe permitir elegir a quién va dirigido.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/admin_benefits.dart').readAsStringSync();
  });

  test('el reto de conductores muestra el selector Dirigido a', () {
    expect(source, contains("_dropdown('Dirigido a', _audience"));
    expect(source, contains("'drivers': 'Conductores', 'all': 'Todos los usuarios'"));
  });

  test('el reto guarda la audiencia elegida: conductores o todos', () {
    expect(source, contains("(_audience == 'all' ? 'all' : 'drivers')"));
    expect(source, contains("const {'drivers', 'all'}.contains(config['audience'])"));
  });
}
