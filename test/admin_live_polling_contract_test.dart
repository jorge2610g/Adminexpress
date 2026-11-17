import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contrato de los sondeos automáticos del panel: el mapa en vivo y el SOS
/// se pausan con la pestaña oculta, y las zonas y fotos del mapa no se piden en
/// cada tick de 10 s.
void main() {
  late String panel;

  setUpAll(() {
    panel = File('lib/admin_panel.dart').readAsStringSync();
  });

  test('el mapa en vivo y el SOS no consultan con la pestaña oculta', () {
    final live = panel.substring(
      panel.indexOf('  void _autoRefreshLive() {'),
      panel.indexOf('  /// Per-section data filter.'),
    );
    expect(live, contains('!adminPageIsVisible()'));
    expect(
      panel,
      contains('if (_polling || !mounted || !adminPageIsVisible()) return;'),
    );
  });

  test('zonas y fotos del mapa se cachean en lugar de pedirse en cada tick', () {
    expect(panel, contains('Future<List<Map<String, dynamic>>> _liveZonesCached()'));
    expect(panel, contains('Duration(minutes: 10)'));
    expect(panel, contains('Future<Object?> _driverMapPhotoRows()'));
    expect(panel, contains('Duration(minutes: 5)'));
    final live = panel.substring(
      panel.indexOf('  Future<({Map<String, dynamic> state'),
      panel.indexOf('  // Zonas del país'),
    );
    expect(live, contains('await _liveZonesCached()'));
    expect(live, isNot(contains('await _filterZones()')));
  });

  test('el SOS usa la lista de emergencias y no el panel completo', () {
    expect(panel, contains("'admin_emergencies_list_v1'"));
    expect(panel, contains('loadAlerts: _emergenciesList,'));
    expect(panel, isNot(contains("loadAlerts: () async => _list((await _dashboardState(6))['emergencies'])")));
  });

  test('el intervalo visible del mapa sigue en 10 s (sin perder calidad)', () {
    expect(panel, contains('const Duration(seconds: 10),\n      (_) => _autoRefreshLive(),'));
  });
}
