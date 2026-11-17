import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El formulario de beneficios muestra el nombre de la zona, no su UUID.
void main() {
  late String benefits;
  late String panel;

  setUpAll(() {
    benefits = File('lib/admin_benefits.dart').readAsStringSync();
    panel = File('lib/admin_panel.dart').readAsStringSync();
  });

  test('el panel pasa el país a la página de beneficios', () {
    expect(
      panel,
      contains(
        '        return AdminBenefitsPage(\n'
        '          channel: _sectionChannel(35),\n'
        '          zoneId: adminZoneId,\n'
        '          countryCode: adminCountryCode,\n'
        '        );',
      ),
    );
  });

  test('el nombre de la zona sale de la misma RPC que el resto del panel', () {
    expect(benefits, contains("'admin_zone_list_for_country'"));
    expect(benefits, contains("'p_country_code': country"));
  });

  test('la línea Zona ya no imprime el identificador técnico', () {
    expect(benefits, isNot(contains(r'Zona: ${widget.zoneId ?? ')));
    expect(benefits, contains("'Zona seleccionada'"));
  });
}
