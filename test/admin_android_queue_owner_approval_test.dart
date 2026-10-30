import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('official candidate uses the server-owned next Play build number', () {
    final source = File('lib/admin_single_app_release.dart').readAsStringSync();
    expect(source, contains("candidate['version_name']"));
    expect(source, contains("status['next_google_play_build']"));
    expect(source, contains("'admin_queue_single_app_candidate'"));
    expect(source, contains('com.express.usuario1'));
    expect(source, contains('Versión incorrecta'));
    expect(source, contains('el contador cambió'));
    expect(source, contains('No se publica en Producción'));
    expect(source, isNot(contains("const currentVersion = '1.6.3'")));
    expect(source, isNot(contains("'work/express-single-app-1.6.3-build142'")));
  });
}
