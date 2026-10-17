import 'package:flutter_test/flutter_test.dart';

import 'package:adminexpress/admin_shared_global_timing.dart';

void main() {
  test('Preview write drops every shared global timing key', () {
    final clean = withoutSharedGlobalTiming({
      'currency': 'CLP',
      'offer_timeout_seconds': 20,
      'search_timeout_seconds': 180,
      'request_visible_seconds': 180,
      'scheduled_publish_before_minutes': 30,
      'driver_floating_offer_enabled': true,
    });
    expect(clean.containsKey('offer_timeout_seconds'), isFalse);
    expect(clean.containsKey('search_timeout_seconds'), isFalse);
    expect(clean.containsKey('request_visible_seconds'), isFalse);
    expect(clean.containsKey('scheduled_publish_before_minutes'), isFalse);
    expect(clean['currency'], 'CLP');
    expect(clean['driver_floating_offer_enabled'], true);
  });

  test('reads real shared timing from admin_settings_get only', () async {
    final values = await readSharedGlobalTiming((fn) async {
      expect(fn, 'admin_settings_get');
      return {
        'offer_timeout_seconds': 20,
        'search_timeout_seconds': 180,
        'request_visible_seconds': 180,
        'scheduled_publish_before_minutes': 30,
        'currency': 'CLP',
      };
    });
    expect(values, {
      'offer_timeout_seconds': 20,
      'search_timeout_seconds': 180,
      'request_visible_seconds': 180,
      'scheduled_publish_before_minutes': 30,
    });
  });

  test('empty or invalid response yields no timing values', () async {
    expect(await readSharedGlobalTiming((_) async => null), isEmpty);
  });
}
