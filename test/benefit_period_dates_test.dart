import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/benefit_period_dates.dart';

void main() {
  // Miércoles 25/11/2026.
  final now = DateTime(2026, 11, 25, 9, 30);

  test('semanal: de lunes a domingo de la semana en curso', () {
    final r = challengePeriodRange('weekly', now)!;
    expect(r.start, DateTime(2026, 11, 23));
    expect(r.end, DateTime(2026, 11, 29, 23, 59, 59));
  });

  test('la semana cruza de mes y de año', () {
    final r = challengePeriodRange('weekly', DateTime(2026, 12, 31))!;
    expect(r.start, DateTime(2026, 12, 28));
    expect(r.end, DateTime(2027, 1, 3, 23, 59, 59));
  });

  test('diario y mensual', () {
    final d = challengePeriodRange('daily', now)!;
    expect(d.start, DateTime(2026, 11, 25));
    expect(d.end, DateTime(2026, 11, 25, 23, 59, 59));
    final m = challengePeriodRange('monthly', now)!;
    expect(m.start, DateTime(2026, 11, 1));
    expect(m.end, DateTime(2026, 11, 30, 23, 59, 59));
    expect(challengePeriodRange('monthly', DateTime(2028, 2, 10))!.end.day, 29);
  });

  test('personalizado no propone fechas', () {
    expect(challengePeriodRange('custom', now), isNull);
  });

  test('texto de ayuda', () {
    final r = challengePeriodRange('weekly', now)!;
    expect(challengePeriodHint('weekly', r.start, r.end),
        'Semana del 23/11/2026 al 29/11/2026');
    expect(challengePeriodHint('custom', r.start, r.end), isNull);
    final d = challengePeriodRange('daily', now)!;
    expect(challengePeriodHint('daily', d.start, d.end), 'Día 25/11/2026');
  });
}
