import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin release queues the unified 1.6.3+142 APK and AAB candidate', () {
    final source = File('lib/admin_single_app_release.dart').readAsStringSync();
    expect(source, contains("const currentVersion = '1.6.3'"));
    expect(source, contains("data['version'] != currentVersion"));
    expect(
      source,
      contains("status['next_google_play_build']?.toString() != '142'"),
    );
    expect(source, contains('AUTORIZO APK+AAB PRUEBAS INTERNAS'));
    expect(source, contains("'admin_queue_single_app_candidate'"));
    expect(source, contains('actions/workflows/build-android.yml'));
    expect(source, contains('work/express-single-app-1.6.3-build142'));
    expect(source, contains('mismo commit'));
    expect(source, isNot(contains('Preparar solo AAB')));
    expect(source, isNot(contains("'p_artifact_type': 'aab'")));
    expect(source, isNot(contains("const currentVersion = '1.6.2'")));
    expect(source, isNot(contains("?? '1.6.1'")));
  });
}
