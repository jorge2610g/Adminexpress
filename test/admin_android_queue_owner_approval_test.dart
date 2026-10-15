import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('admin release displays pending explicit Android approval', () {
    final source = File('lib/admin_single_app_release.dart').readAsStringSync();
    expect(source, contains("const currentVersion = '1.6.2'"));
    expect(source, contains("data['version'] != currentVersion"));
    expect(source, contains('AUTORIZO APK QA'));
    expect(source, contains('no compila aún'));
    expect(source, contains('SHA, 1.6.2 y build 140'));
    expect(source, isNot(contains("?? '1.6.1'")));
  });
}
