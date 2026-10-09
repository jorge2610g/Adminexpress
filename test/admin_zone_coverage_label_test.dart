import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/admin_zone_coverage_label.dart';

void main() {
  test('polygon coverage never reports the stored, inactive radius', () {
    final zone = <String, dynamic>{
      'name': 'Trinidad',
      'coverage_mode': 'polygon',
      'radius_km': 25,
    };
    expect(adminZoneCoverageSummary(zone), 'Polígono');
  });

  test('radio reports only the active radius', () {
    final zone = <String, dynamic>{
      'name': 'Iquique',
      'coverage_mode': 'radius',
      'radius_km': 25,
    };
    expect(adminZoneCoverageSummary(zone), 'Radio 25 km');
  });

  test('missing coverage mode never silently defaults to radius', () {
    expect(adminZoneCoverageSummary(<String, dynamic>{
      'radius_km': 25,
    }), 'Sin información');
  });
}
