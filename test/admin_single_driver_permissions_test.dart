import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Driver sheet shows each service authorization panel only once', () {
    final code = File('lib/admin_detail_dialogs.dart').readAsStringSync();
    expect(RegExp(r'_workPermissionPanel\(\),').allMatches(code).length, 1);
    expect(RegExp(r'_parcelVehiclePermissionsPanel\(\),').allMatches(code).length, 1);
  });

  test('Vehicle grants load and save in the selected environment', () {
    final code = File('lib/admin_detail_dialogs.dart').readAsStringSync();
    expect(code, contains("'p_channel': widget.channel,"));
    expect(code, contains(".eq('channel', widget.channel)"));
    expect(code, isNot(contains("Disponible primero en Preview.")));
  });
}
