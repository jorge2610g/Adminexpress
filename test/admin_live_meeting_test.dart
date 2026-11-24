import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/admin_live_meeting.dart';

void main() {
  test('solo se aceptan enlaces de Google Meet', () {
    expect(AdminLiveMeetingRpc.isMeetUrl('https://meet.google.com/abc-defg-hij'), isTrue);
    expect(AdminLiveMeetingRpc.isMeetUrl('http://meet.google.com/abc'), isFalse);
    expect(AdminLiveMeetingRpc.isMeetUrl('https://zoom.us/j/123'), isFalse);
    expect(AdminLiveMeetingRpc.isMeetUrl('https://meet.google.com.evil.com/x'), isFalse);
  });

  test('la hora de apagado pasa a mañana si ya pasó', () {
    final now = DateTime(2026, 11, 24, 22, 0);
    expect(AdminLiveMeetingRpc.endsAt(const TimeOfDay(hour: 21, minute: 0), now),
        DateTime(2026, 11, 25, 21, 0));
    expect(AdminLiveMeetingRpc.endsAt(const TimeOfDay(hour: 23, minute: 0), now),
        DateTime(2026, 11, 24, 23, 0));
    expect(AdminLiveMeetingRpc.endsAt(null, now), isNull);
  });

  test('las RPC existen en la migración', () {
    final sql = File('supabase/migrations/20261124190000_live_meetings.sql').readAsStringSync();
    for (final n in [AdminLiveMeetingRpc.get, AdminLiveMeetingRpc.save, AdminLiveMeetingRpc.end]) {
      expect(sql, contains('function public.$n('));
    }
  });
}
