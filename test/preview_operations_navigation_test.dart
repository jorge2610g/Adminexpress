import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/preview_operations_navigation.dart';

void main() {
  test('Preview contains exactly the twelve operational and QA sections', () {
    expect(previewOperationalSections, <int>{0, 1, 2, 3, 4, 5, 6, 13, 20, 21, 25, 29});
    for (var section = 0; section <= 32; section++) {
      expect(
        isSectionVisibleForRuntime('preview', section),
        previewOperationalSections.contains(section),
        reason: 'Preview section $section',
      );
    }
  });

  test('Production is not filtered by the Preview navigation policy', () {
    for (var section = 0; section <= 32; section++) {
      expect(isSectionVisibleForRuntime('production', section), isTrue);
    }
  });

  test('Global, payment, subscription, build, and operator sections are hidden in Preview', () {
    for (final section in <int>[7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 19, 22, 28, 32]) {
      expect(isSectionVisibleForRuntime('preview', section), isFalse);
    }
  });
}
