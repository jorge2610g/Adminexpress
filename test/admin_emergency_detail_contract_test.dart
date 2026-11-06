import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contrato de la sección SOS del panel: detalle en dos columnas, resolución
/// con admin_resolve_emergency_v3 y aviso de alertas nuevas. Son comprobaciones
/// de fuente; la autorización real está en las RPC de Supabase.
void main() {
  late String panel;
  late String security;
  late String alertsView;
  late String dialog;
  late String pubspec;

  String between(String text, String start, String end) {
    final a = text.indexOf(start);
    final b = text.indexOf(end);
    expect(a, isNonNegative, reason: 'falta $start');
    expect(b, greaterThan(a), reason: 'falta $end después de $start');
    return text.substring(a, b);
  }

  setUpAll(() {
    panel = File('lib/admin_panel.dart').readAsStringSync();
    pubspec = File('pubspec.yaml').readAsStringSync();
    security = between(panel, '  Widget _security() {', '  void _openEmergencyDetail(');
    alertsView = between(
      panel,
      'class _SecurityAlertsView extends StatefulWidget',
      'class _EmergencyDetailDialog extends StatefulWidget',
    );
    dialog = between(
      panel,
      'class _EmergencyDetailDialog extends StatefulWidget',
      'class _ScopeSelectionRequired',
    );
  });

  group('lista de alertas', () {
    test('la sección usa la vista con refresco y no realtime', () {
      expect(security, contains('return _SecurityAlertsView('));
      expect(security, contains('revision: revision,'));
      expect(alertsView, contains('Duration(seconds: 10)'));
      expect(alertsView, contains('Timer.periodic(_pollEvery'));
      expect(alertsView, contains('_timer?.cancel();'));
      expect(alertsView, isNot(contains('onPostgresChanges')));
      expect(alertsView, isNot(contains('.stream(')));
    });

    test('el refresco se reinicia al cambiar la revisión del panel', () {
      expect(alertsView, contains('oldWidget.revision != widget.revision'));
    });

    test('la primera consulta fija la base y no suena por alertas antiguas', () {
      expect(alertsView, contains('final announce = _baselineReady && fresh.isNotEmpty;'));
    });

    test('una alerta nueva muestra banner con «Ver alerta» y suena', () {
      expect(alertsView, contains("'Ver alerta'"));
      expect(alertsView, contains('Nueva alerta SOS de'));
      expect(alertsView, contains('unawaited(_playAlert())'));
      expect(alertsView, contains("AssetSource(_alertAsset)"));
      expect(alertsView, contains("'sounds/alerta_sos.wav'"));
    });

    test('el sonido necesita un clic: botón «Activar sonido de alertas»', () {
      expect(alertsView, contains("'Activar sonido de alertas'"));
      expect(alertsView, contains('if (!_alertSoundUnlocked) return;'));
    });

    test('el audio y su archivo están declarados en el proyecto', () {
      expect(pubspec, contains('audioplayers:'));
      expect(pubspec, contains('- assets/sounds/alerta_sos.wav'));
      expect(
        File('assets/sounds/alerta_sos.wav').existsSync(),
        isTrue,
        reason: 'falta el asset de sonido',
      );
    });
  });

  group('detalle de la alerta', () {
    test('_security() abre el detalle al tocar una alerta', () {
      expect(security, contains('onTap: () => _openEmergencyDetail('));
      expect(security, contains('onOpenAlert: (row) => _openEmergencyDetail('));
    });

    test('llama admin_emergency_detail_v1 con p_emergency_id y p_channel', () {
      final open = between(
        panel,
        '  void _openEmergencyDetail(',
        '/// Sonido de alerta desbloqueado',
      );
      expect(open, contains("'admin_emergency_detail_v1'"));
      expect(open, contains("'p_emergency_id': emergencyId"));
      expect(open, contains("'p_channel': _sectionChannel(6)"));
    });

    test('pasajero a la izquierda y conductor a la derecha en pantalla ancha', () {
      expect(dialog, contains('final wide = screenWidth >= 900;'));
      final row = between(dialog, 'final people = wide', '\n        : Column(');
      expect(row.indexOf('passengerPanel'), lessThan(row.indexOf('driverPanel')));
      expect(row, contains('Row('));
    });

    test('en pantalla pequeña se apilan con el pasajero primero', () {
      final from = dialog.indexOf(
        ': Column(\n            crossAxisAlignment: CrossAxisAlignment.stretch,',
      );
      expect(from, isNonNegative, reason: 'falta la versión apilada');
      final stacked = dialog.substring(from, from + 220);
      expect(stacked.indexOf('passengerPanel'), lessThan(stacked.indexOf('driverPanel')));
    });

    test('muestra los datos pedidos de pasajero y conductor', () {
      for (final label in [
        "'Correo'",
        "'Zona'",
        "'Estado de cuenta'",
        "'Vehículo'",
        "'Placa'",
        "'Calificación'",
        "'Teléfono'",
      ]) {
        expect(dialog, contains(label));
      }
      expect(dialog, contains("'Copiar teléfono'"));
    });

    test('estados vacíos: sin conductor, sin viaje y sin ubicación', () {
      expect(dialog, contains("'Sin conductor asignado'"));
      expect(dialog, contains("'Sin viaje asociado'"));
      expect(dialog, contains("'Sin ubicación enviada'"));
      expect(dialog, contains("'Abrir en mapa'"));
      expect(dialog, contains("'https://www.google.com/maps?q=\$lat,\$lng'"));
    });

    test('error de la RPC con botón Reintentar', () {
      expect(dialog, contains("'Reintentar'"));
      expect(dialog, contains('No se pudo cargar el detalle de la alerta.'));
    });

    test('aviso cuando pasajero y conductor tienen el mismo teléfono', () {
      expect(dialog, contains('samePhone'));
      expect(
        dialog,
        contains('Mismo teléfono en ambas cuentas: revisa la cuenta de prueba.'),
      );
    });

    test('los teléfonos solo se copian al portapapeles, sin enviarlos', () {
      expect(dialog, contains('Clipboard.setData(ClipboardData(text: phone))'));
      expect(dialog, isNot(contains('http.post')));
      expect(dialog, isNot(contains('sendEmail')));
    });

    test('el panel importa url_launcher para abrir el mapa', () {
      expect(panel, contains("import 'package:url_launcher/url_launcher.dart';"));
      expect(dialog, contains('launchUrl(uri, mode: LaunchMode.externalApplication)'));
    });
  });

  group('resolver', () {
    test('usa admin_resolve_emergency_v3 y ya no la v2', () {
      expect(panel, contains("'admin_resolve_emergency_v3'"));
      expect(panel, isNot(contains("'admin_resolve_emergency_v2'")));
    });

    test('informa si el viaje se reanudó', () {
      expect(panel, contains("result['trip_resumed'] == true"));
      expect(panel, contains('Alerta resuelta. El viaje se reanudó.'));
      expect(
        panel,
        contains('El viaje sigue en emergencia porque hay otra alerta abierta.'),
      );
    });

    test('Resolver solo aparece para el admin central', () {
      expect(
        security,
        contains("final canResolve = !_readOnly && adminAccess['role'] != 'operator';"),
      );
      expect(security, contains("trailing: (_readOnly || adminAccess['role'] == 'operator')"));
      expect(dialog, contains('if (widget.canResolve)'));
    });
  });
}
