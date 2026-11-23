import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el servicio por zona elige entre ofertas, precio fijo o ambos', () {
    final src = File('lib/admin_control_sections.dart').readAsStringSync();
    expect(src, contains("row?['price_mode'] ?? 'offer'"));
    expect(src, contains('admin_set_zone_service_price_mode_v1'));
    expect(src, contains('Ambos · el pasajero elige'));
    expect(src, contains('uno por'));
    // Solo en Producción: en Prueba no se guarda este modo.
    expect(src, contains('!_environment.isPreview &&'));
    // El interruptor viejo "Permitir precio fijo" ya no se muestra.
    expect(src, isNot(contains("title: const Text('Permitir precio fijo')")));
  });

  test('las tarifas se crean por separado para ofertas y precio fijo', () {
    final src = File('lib/admin_control_sections.dart').readAsStringSync();
    expect(src, contains("'p_price_mode': fareMode"));
    expect(src, contains('Esta tarifa es para'));
  });
  tarifasBotonVisible();
}

void tarifasBotonVisible() {
  test('Tarifas tiene un botón Nueva tarifa junto a la lista', () {
    final src = File('lib/admin_control_sections.dart').readAsStringSync();
    expect(src, contains("ValueKey('fare-new-inline')"));
  });
}
