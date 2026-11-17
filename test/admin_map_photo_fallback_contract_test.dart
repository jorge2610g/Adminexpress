import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Si falla la miniatura del mapa, la foto original debe seguir apareciendo.
void main() {
  late String panel;

  setUpAll(() {
    panel = File('lib/admin_panel.dart').readAsStringSync();
  });

  test('la foto original se firma antes y no depende de la miniatura', () {
    final start = panel.indexOf('Future<_DriverMapPhotoUrls?> _signedDriverPhotoUrls');
    final end = panel.indexOf('String _zoneCountryCode(', start);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final body = panel.substring(start, end);

    final originalAt = body.indexOf("final original = await bucket.createSignedUrl(path, 3600);");
    final thumbAt = body.indexOf('transform: TransformOptions(');
    expect(originalAt, greaterThan(0));
    expect(thumbAt, greaterThan(originalAt));
    expect(body, contains('var thumb = original;'));
    expect(body, contains('} catch (_) {\n        thumb = original;\n      }'));
  });
}
