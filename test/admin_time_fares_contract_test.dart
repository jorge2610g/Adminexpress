import 'dart:io';

import 'package:adminexpress/admin_time_fares.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tarifas por horario (tarifa nocturna, de madrugada, etc.) en el panel.
void main() {
  test('resume los días de una tarifa por horario', () {
    expect(timeFareDaysLabel([1, 2, 3, 4, 5, 6, 7]), 'Todos los días');
    expect(timeFareDaysLabel([1, 2, 3, 4, 5]), 'Lun a Vie');
    expect(timeFareDaysLabel([6, 7]), 'Sáb, Dom');
    expect(timeFareDaysLabel([5]), 'Vie');
    expect(timeFareDaysLabel([1, 3, 5]), 'Lun, Mié, Vie');
  });

  test('el editor usa las funciones del panel y solo escribe en Producción', () {
    final editor = File('lib/admin_time_fares.dart').readAsStringSync();
    expect(editor, contains("'admin_fare_time_rules_list'"));
    expect(editor, contains("'admin_fare_time_rule_upsert'"));
    expect(editor, contains("'admin_fare_time_rule_delete'"));
    expect(editor, contains("'p_channel': widget.channel"));
    expect(editor, contains('bool get _isPreview => widget.channel == \'preview\';'));
    expect(editor, contains('Tarifa nocturna'));
  });

  test('la pantalla de tarifas por zona incluye el editor de horarios', () {
    final screen = File('lib/admin_control_sections.dart').readAsStringSync();
    expect(screen, contains("import 'admin_time_fares.dart';"));
    expect(screen, contains('AdminTimeFaresEditor('));
    expect(
      screen.indexOf('AdminDistanceFaresEditor('),
      lessThan(screen.indexOf('AdminTimeFaresEditor(')),
    );
  });

  test('la migración exige Producción y valida horarios y cruces', () {
    final sql = File(
      'supabase/migrations/20261119130000_admin_fare_time_rules.sql',
    ).readAsStringSync();
    expect(sql, contains("p_channel is distinct from 'production'"));
    expect(sql, contains('El horario se cruza con la tarifa'));
    expect(sql, contains('La hora de inicio y la de fin no pueden ser iguales'));
    expect(sql, contains('revoke execute on function public.admin_fare_time_rule_upsert'));
  });
}
