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
    expect(source, contains("title: Text(_programType == 'coupon' ? 'Cupón activo'"));
    expect(source, contains("'reward_destination': _programType == 'activation' || _programType == 'loyalty'"));
  });

  test('same-day driver credits and MLM plan-payment duration have separate controls', () {
    expect(source, contains("'commission_start_same_day': _sameDayCredits"));
    expect(source, contains("'plan_payment_percent': double.tryParse(_leaderPercent.text.trim())"));
    expect(source, contains("'lifetime': _lifetime"));
    expect(source, contains('cada pago de plan confirmado'));
  });

  test('referrals screen loads real dashboard metrics and plan commission history', () {
    expect(source, contains("'admin_driver_referral_dashboard'"));
    expect(source, contains("'p_status': _referralFilter"));
    expect(source, contains("_referralsPanel() => FutureBuilder"));
    expect(source, contains("'Comisión acreditada'"));
    expect(source, contains("'Pagos de plan'"));
    expect(source, contains("onChanged: (value) {\n                        if (value == null) return;"));
  });

  test('benefits forms and list controls adapt to phone and tablet widths', () {
    expect(source, contains('final compact = screen.width < 600;'));
    expect(source, contains('screen.width - inset * 2'));
    expect(source, contains('constraints.maxWidth < 700'));
    expect(source, contains('MediaQuery.sizeOf(context).width < 720 ? 10 : 16'));
    expect(source, contains('alignment: WrapAlignment.end'));
    final panel = File('lib/admin_panel.dart').readAsStringSync();
    expect(panel, contains('constraints.maxWidth < 1180'));
    expect(panel, contains('drawer: compact'));
  });
}
