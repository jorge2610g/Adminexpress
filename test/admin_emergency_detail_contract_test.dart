import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contrato del detalle de alertas SOS en el panel. Son comprobaciones de
/// fuente: la autorización real está en admin_emergency_detail_v1.
void main() {
  late String panel;
  late String security;
  late String dialog;

  setUpAll(() {
    panel = File('lib/admin_panel.dart').readAsStringSync();
    final start = panel.indexOf('  Widget _security() {');
    final end = panel.indexOf('class _EmergencyDetailDialog extends');
    expect(start, isNonNegative, reason: 'falta _security()');
    expect(end, greaterThan(start));
    security = panel.substring(start, end);
    final dialogStart = panel.indexOf('class _EmergencyDetailDialog extends');
    final dialogEnd = panel.indexOf('class _ScopeSelectionRequired');
    expect(dialogStart, isNonNegative);
    expect(dialogEnd, greaterThan(dialogStart));
    dialog = panel.substring(dialogStart, dialogEnd);
  });

  test('_security() abre el detalle al tocar una alerta', () {
    expect(security, contains('onTap: () {'));
    expect(security, contains('showDialog<void>('));
    expect(security, contains('_EmergencyDetailDialog('));
  });

  test('_security() llama admin_emergency_detail_v1 con p_emergency_id y p_channel', () {
    expect(security, contains("'admin_emergency_detail_v1'"));
    expect(security, contains("'p_emergency_id': emergencyId"));
    expect(security, contains("'p_channel': _sectionChannel(6)"));
  });

  test('el detalle muestra las secciones pedidas y no queda vacío', () {
    for (final title in [
      "'Alerta'",
      "'Pasajero'",
      "'Conductor'",
      "'Ubicación'",
    ]) {
      expect(dialog, contains(title));
    }
    expect(dialog, contains("'Sin conductor asignado'"));
    expect(dialog, contains("'Sin ubicación enviada'"));
    expect(dialog, contains("'Sin viaje ni envío asociado'"));
    expect(dialog, contains("'Abrir en mapa'"));
    expect(dialog, contains("'https://www.google.com/maps?q=\$lat,\$lng'"));
    expect(dialog, contains("'Reintentar'"));
    expect(dialog, contains('No se pudo cargar el detalle de la alerta.'));
  });

  test('los teléfonos solo se copian al portapapeles, sin enviarlos', () {
    expect(dialog, contains('Clipboard.setData(ClipboardData(text: phone))'));
    expect(dialog, contains("'Copiar teléfono'"));
    expect(dialog, isNot(contains('http.post')));
    expect(dialog, isNot(contains('sendEmail')));
  });

  test('Resolver solo aparece para el admin central y usa la RPC existente', () {
    expect(
      security,
      contains("final canResolve = !_readOnly && adminAccess['role'] != 'operator';"),
    );
    expect(security, contains('canResolve: canResolve,'));
    expect(dialog, contains('if (widget.canResolve)'));
    expect(panel, contains("'admin_resolve_emergency_v2'"));
  });

  test('el panel importa url_launcher para abrir el mapa', () {
    expect(panel, contains("import 'package:url_launcher/url_launcher.dart';"));
    expect(dialog, contains('launchUrl(uri, mode: LaunchMode.externalApplication)'));
  });
}
