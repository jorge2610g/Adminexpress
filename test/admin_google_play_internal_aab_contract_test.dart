import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String panel;

  setUpAll(() {
    panel = File('lib/admin_single_app_release.dart').readAsStringSync();
  });

  test('internal AAB request is distinct from the original APK+AAB flow', () {
    expect(panel, contains('Future<void> _queueInternalAab() async'));
    expect(panel, contains("'p_artifact_type': 'aab'"));
    expect(panel, contains("'p_platform': 'android'"));
    expect(panel, contains("'p_version_name': '1.6.3'"));
    expect(panel, contains("'p_build_number': 141"));
    expect(panel, contains("'p_commit_sha': sourceSha"));
    expect(panel, contains("'admin_create_build_job'"));
    expect(panel, contains('Solo AAB'));
    expect(panel, contains('Preparar solo AAB · Build 141'));
  });

  test('request requires production admin capability and exact source SHA', () {
    expect(panel, contains('if (!canManage || busy) return;'));
    expect(panel, contains("RegExp(r'^[0-9a-f]{40}\$')"));
    expect(panel, contains('!RegExp'));
    expect(panel, contains('_call('));
  });

  test('normal candidate flow is preserved and no Play publish is triggered', () {
    expect(panel, contains("'admin_queue_single_app_candidate'"));
    expect(panel, contains('AAB en cola. Falta autorización de compilación en GitHub.'));
    expect(panel, contains("row['artifact_type'] == 'aab'"));
    expect(panel, isNot(contains("'admin_publish_internal_aab'")));
  });
}
