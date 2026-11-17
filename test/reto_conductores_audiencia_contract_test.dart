import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un reto de conductores debe guardarse con audiencia 'drivers'. Si se guarda
/// como 'passengers', my_benefits_overview lo oculta a los conductores.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/admin_benefits.dart').readAsStringSync();
  });

  test('el reto de conductores se guarda con audiencia drivers', () {
    expect(source, contains("'audience': _programType == 'driver_challenge'"));
    expect(source, contains("(_audience == 'all' ? 'all' : 'drivers')"));
  });

  test('al cargar un reto de conductores la audiencia es drivers', () {
    expect(source, contains("_audience = _programType == 'driver_challenge'"));
  });

  test('el selector de audiencia del reto ofrece Conductores', () {
    expect(source, contains("const {'drivers': 'Conductores'}"));
  });
}
