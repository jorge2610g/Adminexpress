import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/admin_environment_store.dart';

void main() {
  test('production and preview channels are resolved exactly', () {
    const prod = AdminEnvironmentStore('production');
    const qa = AdminEnvironmentStore('preview');
    expect(prod.isProduction, isTrue);
    expect(prod.isPreview, isFalse);
    expect(qa.isPreview, isTrue);
    expect(qa.isProduction, isFalse);
  });

  test('typo or empty channel cannot silently become production', () {
    for (final invalid in <String>['', 'preveiw', 'Preview', 'production ', 'qa']) {
      final store = AdminEnvironmentStore(invalid);
      expect(() => store.isPreview, throwsStateError,
          reason: 'Invalid channel $invalid must not default to Production');
      expect(() => store.isProduction, throwsStateError,
          reason: 'Invalid channel $invalid must not default to Production');
    }
  });
}