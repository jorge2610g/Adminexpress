import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contrato de los filtros de estado de Conductores y Usuarios.
void main() {
  late String panel;

  setUpAll(() {
    panel = File('lib/admin_panel.dart').readAsStringSync();
  });

  test('conductores abre en pendientes y pide la lista filtrada por estado', () {
    expect(panel, contains("String driverStatus = 'pending';"));
    expect(panel, contains("'admin_driver_list_v5',"));
    expect(panel, contains("'admin_driver_count_v2',"));
    expect(panel, contains("'p_status': driverStatus,"));
    expect(panel, contains("label: 'Pendientes'"));
    expect(panel, contains("label: 'Activos'"));
    expect(panel, contains("label: 'Rechazados'"));
    expect(panel, contains("label: 'Suspendidos'"));
    expect(panel, contains("'No hay conductores pendientes.'"));
  });

  test('usuarios muestra todos por defecto y ofrece rechazados y bloqueados', () {
    expect(panel, contains('String? userStatus;'));
    expect(panel, contains("'admin_user_list_v5',"));
    expect(panel, contains("'admin_user_count_v2',"));
    expect(panel, contains("'p_status': userStatus,"));
    expect(panel, contains("label: 'Rechazados'"));
    expect(panel, contains("label: 'Bloqueados'"));
  });

  test('cambiar de filtro reinicia la lista con una clave nueva', () {
    expect(panel, contains("ValueKey('drivers-' + revision.toString() + driverStatus)"));
    expect(panel, contains("ValueKey('users-' + revision.toString() + (userStatus ?? 'all'))"));
  });
}
