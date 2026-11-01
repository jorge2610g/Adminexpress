import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final fareRounding = File('lib/admin_fare_rounding.dart').readAsStringSync();
  final panel = File('lib/admin_panel.dart').readAsStringSync();

  test('redondeo de tarifas no guarda tras una carga fallida', () {
    // The failure flag must exist, be set in the load catch block, and be
    // cleared at the start of every load.
    expect(fareRounding, contains('bool _loadFailed = false;'));
    expect(fareRounding, contains('_loadFailed = true;'));
    expect(fareRounding, contains('_loadFailed = false;'));

    // Saving is blocked both in the handler and on the button.
    expect(
      fareRounding,
      contains('if (_saving || _loading || _loadFailed) return;'),
    );
    expect(
      fareRounding,
      contains('onPressed: (_saving || _loadFailed) ? null : _save,'),
    );
  });

  test('redondeo de tarifas no usa 0.01 por defecto al leer un valor inválido',
      () {
    // Only the load path is checked: the display example also uses 0.01.
    expect(
      fareRounding,
      isNot(matches(RegExp(r"tryParse\(raw\['increment'\][^;]*\?\? 0\.01"))),
      reason: 'An unreadable increment must be a load failure, not a default.',
    );
    expect(
      fareRounding,
      contains("if (value == null) throw StateError('Respuesta inválida"),
    );
  });

  test('panel no muestra botón de notificaciones sin función', () {
    expect(panel, isNot(contains("tooltip: 'Notificaciones'")));
    expect(panel, isNot(contains('Icons.notifications_none_rounded')));
    // The account menu must remain in the header.
    expect(panel, contains("tooltip: 'Cuenta'"));
  });
}
