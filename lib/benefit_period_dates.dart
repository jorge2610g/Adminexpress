/// Fechas de un reto según su periodo. El servidor cuenta los ciclos por calendario
/// (día, semana de lunes a domingo, mes), así que el panel propone el mismo rango.
({DateTime start, DateTime end})? challengePeriodRange(
  String period,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);
  switch (period) {
    case 'daily':
      return (start: today, end: endOfDay(today));
    case 'weekly':
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final sunday = DateTime(monday.year, monday.month, monday.day + 6);
      return (start: monday, end: endOfDay(sunday));
    case 'monthly':
      final first = DateTime(today.year, today.month, 1);
      final last = DateTime(today.year, today.month + 1, 0);
      return (start: first, end: endOfDay(last));
    default:
      return null; // Personalizado: las fechas las elige el administrador.
  }
}

/// Texto bajo las fechas, p. ej. «Semana del 23/11/2026 al 29/11/2026».
String? challengePeriodHint(String period, DateTime start, DateTime? end) {
  String d(DateTime v) =>
      '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}';
  final label = switch (period) {
    'daily' => 'Día',
    'weekly' => 'Semana',
    'monthly' => 'Mes',
    _ => null,
  };
  if (label == null || end == null) return null;
  return label == 'Día' ? 'Día ${d(start)}' : '$label del ${d(start)} al ${d(end)}';
}
