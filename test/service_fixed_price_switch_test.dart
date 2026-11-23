import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el servicio por zona tiene el interruptor de precio fijo uno a uno', () {
    final src = File('lib/admin_control_sections.dart').readAsStringSync();
    expect(src, contains("row?['price_mode'] == 'fixed'"));
    expect(src, contains('admin_set_zone_service_price_mode_v1'));
    expect(src, contains('uno por'));
    // Solo en Producción: en Prueba no se guarda este modo.
    expect(src, contains('!_environment.isPreview &&'));
  });
}
