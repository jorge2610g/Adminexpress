import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el panel explica las razones nuevas de integridad en español', () {
    final src = File('lib/admin_trip_integrity.dart').readAsStringSync();
    expect(src, contains("'en_curso_muy_corto':"));
    expect(src, contains("'sin_movimiento_gps':"));
  });
}
