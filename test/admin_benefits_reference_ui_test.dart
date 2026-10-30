import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/admin_benefits.dart').readAsStringSync();

  test('benefit modules expose their own screenshot-shaped table columns', () {
    for (final label in [
      'Código', 'Módulo', 'Tipo', 'Usos', 'Vigencia', 'Audiencia',
      'Disparador', 'Activaciones', 'Umbral', 'Premio conductor',
      'Participando', 'Otorgados', 'Cobrados', 'Créditos', 'Meta',
      'Recompensa', 'Completados',
    ]) {
      expect(source, contains("'$label'"));
    }
    expect(source, contains("'coupon' => const ['Código'"));
    expect(source, contains("'loyalty' => const ['Nombre', 'Umbral'"));
    expect(source, contains("'driver_challenge' => const ['Nombre', 'Meta'"));
  });

  test('coupon and loyalty editors keep their dedicated fields and modal action', () {
    expect(source, contains("_textField('Código *', _code"));
    expect(source, contains("_textField('Máximo de descuento (Bs)'"));
    expect(source, contains("_textField('Umbral N (viajes pagados)'"));
    expect(source, contains("_textField('Tope del viaje gratis (Bs)'"));
    expect(source, contains('showDialog<void>'));
    expect(source, contains("_infoBox('Se guardará como borrador"));
  });

  test('same-day driver credits and MLM plan-payment duration have separate controls', () {
    expect(source, contains("'commission_start_same_day': _sameDayCredits"));
    expect(source, contains("'plan_payment_percent': double.tryParse(_leaderPercent.text.trim())"));
    expect(source, contains("'lifetime': _lifetime"));
    expect(source, contains('cada pago de plan confirmado'));
  });
}
