import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El panel no debe ser más estricto que el servidor: la candidata 175 con
/// Play en 174 y reserva 176 es válida (el servidor exige build < reserva).
void main() {
  test('Aprobar y Promover usan la misma regla de contador que el servidor', () {
    final src = File('lib/admin_single_app_release.dart').readAsStringSync();
    expect(src, contains('candidateBuildNumber > storeBuildNumber'));
    expect(src, contains('candidateBuildNumber < nextBuildNumber'));
    expect(src, isNot(contains('candidateBuildNumber == nextBuildNumber')));
  });
}
