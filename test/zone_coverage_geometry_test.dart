import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/zone_coverage_geometry.dart';

void main() {
  test('polygon coverage does not use legacy radius', () {
    expect(usesPolygonCoverage('polygon'), isTrue);
    expect(usesRadiusCoverage('polygon'), isFalse);
    expect(usesRadiusCoverage('radius'), isTrue);
  });
  test('eight saved points load', () {
    final points = parseZonePolygon([
      for (var i = 0; i < 8; i++) {'lat': -14.8 + i * 0.001, 'lng': -64.9 + i * 0.002}
    ]);
    expect(points, hasLength(8));
  });
  test('invalid shape is refused', () {
    expect(parseZonePolygon(null), isEmpty);
    expect(parseZonePolygon([{'lat': 92, 'lng': 1}]), isEmpty);
  });
}
