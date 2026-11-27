import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Conductores tiene el filtro «En modo pasajero»', () {
    final src = File('lib/admin_panel.dart').readAsStringSync();
    expect(src, contains("'passenger_mode'"));
    expect(src, contains('En modo pasajero'));
  });
}
