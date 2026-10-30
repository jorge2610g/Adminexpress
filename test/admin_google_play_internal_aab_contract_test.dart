import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String panel;

  setUpAll(() {
    panel = File('lib/admin_single_app_release.dart').readAsStringSync();
  });

  test('Android uses one official APK and AAB candidate flow', () {
    expect(panel, contains('Preparar candidata oficial APK + AAB'));
    expect(panel, contains("'admin_queue_single_app_candidate'"));
    expect(panel, contains('El flujo unificado genera APK + AAB del mismo commit'));
    expect(panel, contains('descargable para QA'));
    expect(panel, contains('No se publica en Producción'));
    expect(panel, isNot(contains('Future<void> _queueInternalAab() async')));
    expect(panel, isNot(contains('Preparar solo AAB')));
    expect(panel, isNot(contains("'p_artifact_type': 'aab'")));
  });

  test('Candidate request uses the current signed version and server counter', () {
    expect(panel, contains("candidate['version_name']"));
    expect(panel, contains("status['next_google_play_build']"));
    expect(panel, contains('el contador cambió'));
    expect(panel, contains('if (!canManage || busy) return;'));
    expect(panel, contains("'admin_queue_single_app_candidate'"));
    expect(panel, isNot(contains("'p_build_number': 141")));
    expect(panel, isNot(contains("'p_version_name': '1.6.3'")));
  });

  test('Internal candidate flow does not promote directly to Google Play', () {
    expect(panel, contains('No se publica en Producción'));
    expect(panel, contains('Probar la APK firmada'));
    expect(panel, contains('antes de promover ese mismo AAB a Producción'));
    expect(panel, isNot(contains("'admin_publish_internal_aab'")));
  });
}
