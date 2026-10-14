import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('driver service permissions and parcel grants share one section', () {
    final source = File('lib/admin_detail_dialogs.dart').readAsStringSync();

    expect(
      'Servicios autorizados al conductor'.allMatches(source).length,
      1,
    );
    expect(
      'Envíos permitidos por vehículo'.allMatches(source).length,
      0,
    );
    expect(
      '_parcelVehiclePermissionsPanel(),'.allMatches(source).length,
      1,
    );
    expect(
      'Tamaños de paquete por vehículo'.allMatches(source).length,
      1,
    );
    expect(
      source,
      contains('no recibirá ofertas'),
    );
    // The distinct administrative RPCs must remain available.
    expect(source, contains('admin_set_driver_work_permission'));
    expect(source, contains('admin_set_driver_parcel_vehicle_grant'));
  });
}
