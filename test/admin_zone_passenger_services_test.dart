import 'package:flutter_test/flutter_test.dart';
import '../lib/core/admin_zone_passenger_services.dart';

Map<String, dynamic> service(String key, {
  bool enabled = false,
  bool visible = false,
  bool driverVisible = true,
}) => <String, dynamic>{
  'service_key': key,
  'enabled': enabled,
  'passenger_visible': visible,
  'driver_visible': driverVisible,
  'allow_bidding': false,
  'allow_fixed_price': true,
  'scheduled_enabled': false,
  'sort_order': 40,
};

void main() {
  test('one / two / three checked modules yield direct or landing', () {
    expect(zonePassengerStartHint(['ride']), contains('abrir Viajes directamente'));
    expect(zonePassengerStartHint(['delivery']), contains('abrir Envíos directamente'));
    expect(zonePassengerStartHint(['market']), contains('abrir Market directamente'));
    expect(zonePassengerStartHint(['ride', 'delivery']),
        contains('mostrar página de aterrizaje'));
    expect(zonePassengerStartHint(['ride', 'delivery', 'market']),
        contains('mostrar página de aterrizaje'));
    expect(zonePassengerStartHint([]), contains('Selecciona'));
  });

  test('existing visible taxi categories and driver grants are preserved', () {
    final items = [
      service('economy', enabled: true, visible: true),
      service('comfort', enabled: false),
      service('motorcycle', enabled: true, visible: false),
      service('delivery'),
      service('parcel'),
    ];
    final updates = zonePassengerServiceChanges(
      services: items, rides: true, parcels: false, countryCode: 'CL',
    );
    expect(updates.where((v) => zonePassengerRideServiceKeys
        .contains(v['service_key'])), isEmpty);
    expect(updates.every((v) => v['driver_visible'] == true), isTrue);
  });

  test('switching off Taxi hides passenger service without changing enabled',
      () {
    final updates = zonePassengerServiceChanges(
      services: [service('economy', enabled: true, visible: true)],
      rides: false, parcels: false, countryCode: 'CL',
    );
    final taxi = updates.singleWhere((v) => v['service_key'] == 'economy');
    expect(taxi['enabled'], isTrue);
    expect(taxi['passenger_visible'], isFalse);
    expect(taxi['driver_visible'], isTrue);
  });

  test('enabling Envíos syncs parcel engine and landing compatibility', () {
    final updates = zonePassengerServiceChanges(
      services: [
        service('economy', enabled: true, visible: true),
        service('parcel'),
        service('delivery'),
      ],
      rides: true, parcels: true, countryCode: 'CL',
    );
    expect(updates.map((v) => v['service_key']).toSet(),
        {'parcel', 'delivery'});
    expect(updates.every((v) => v['enabled'] == true &&
        v['passenger_visible'] == true), isTrue);
    expect(updates.every((v) => v['driver_visible'] == true), isTrue);
  });

  test('re-enabling single Taxi falls back to correct existing country type',
      () {
    final updates = zonePassengerServiceChanges(
      services: [
        service('economy'),
        service('motorcycle'),
      ],
      rides: true, parcels: false, countryCode: 'BO',
    );
    final moto = updates.singleWhere((v) => v['service_key'] == 'motorcycle');
    expect(moto['enabled'], isTrue);
    expect(moto['passenger_visible'], isTrue);
    expect(updates.where((v) => v['service_key'] == 'economy'), isEmpty);
  });
}
