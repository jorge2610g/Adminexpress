import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/admin_driver_requests.dart';

void main() {
  final sql = File(
    'supabase/migrations/20261124180000_driver_profile_change_requests.sql',
  ).readAsStringSync();

  test('las RPC del panel existen en la migración o en las ya aplicadas', () {
    expect(sql, contains('function public.${AdminDriverRequestsRpc.list}('));
    expect(sql, contains('function public.${AdminDriverRequestsRpc.review}('));
  });

  test('títulos de solicitud en lenguaje del propietario', () {
    expect(AdminDriverRequestsRpc.title({'request_kind': 'photo'}),
        'Quiere cambiar su foto de perfil');
    expect(AdminDriverRequestsRpc.title({'request_kind': 'name'}),
        'Quiere cambiar su nombre');
    expect(AdminDriverRequestsRpc.title({'request_kind': 'phone'}),
        'Quiere cambiar su teléfono');
    expect(
      AdminDriverRequestsRpc.title(
          {'request_kind': 'service', 'service_key': 'parcel'}),
      contains('Paquetería'),
    );
  });
}
