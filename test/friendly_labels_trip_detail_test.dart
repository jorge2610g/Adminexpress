import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/admin_friendly_labels.dart';

void main() {
  test('historial del viaje en español', () {
    expect(friendlyStatus('driver_arriving'), 'Conductor en camino');
    expect(friendlyStatus('driver_waiting'), 'Conductor esperando al pasajero');
    expect(friendlyStatus('in_progress'), 'En curso');
    expect(friendlyStatus('completed'), 'Completado');
    expect(friendlyStatus('paid'), 'Pagado');
    expect(friendlyStatus('Ya en español'), 'Ya en español');
  });

  test('método de pago, modo de precio y demanda', () {
    expect(friendlyPaymentMethod('cash'), 'Efectivo');
    expect(friendlyPaymentMethod('wallet'), 'Billetera Express');
    expect(friendlyPricingMode('offer'), 'Oferta del pasajero');
    expect(friendlyDemand('normal'), 'Normal');
    expect(friendlyPaymentMethod('otro_raro'), 'otro_raro');
  });
}
