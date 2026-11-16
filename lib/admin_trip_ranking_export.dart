/// Exportación CSV del ranking de viajes completados (conductores y usuarios).
///
/// Funciones puras: no tocan la red ni el navegador, para poder probarlas.
/// Las filas vienen de la RPC `admin_completed_trip_ranking_v1`.
library;

/// Encabezados en el orden en que salen en el archivo.
const List<String> adminTripRankingHeaders = <String>[
  'Posición',
  'Nombre',
  'ID',
  'Viajes completados',
  'Primer viaje completado',
  'Último viaje completado',
];

/// Escapa una celda para CSV con `;` como separador (Excel en configuración
/// hispana). Además neutraliza valores que una hoja de cálculo interpretaría
/// como fórmula (`=`, `+`, `-`, `@`), porque los nombres los escriben los
/// propios usuarios.
String adminCsvCell(Object? value) {
  var text = value?.toString() ?? '';
  if (text.isNotEmpty && '=+-@\t\r'.contains(text[0])) {
    text = "'$text";
  }
  final needsQuotes = text.contains(';') ||
      text.contains('"') ||
      text.contains('\n') ||
      text.contains('\r');
  final escaped = text.replaceAll('"', '""');
  return needsQuotes ? '"$escaped"' : escaped;
}

/// Fecha local en formato dd/mm/aaaa hh:mm. Vacío si no es una fecha válida.
String adminCsvDate(Object? raw) {
  final parsed = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (parsed == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

/// Construye el CSV completo. Lleva BOM UTF-8 para que Excel muestre las tildes
/// y usa CRLF como fin de línea.
String adminTripRankingCsv(List<Map<String, dynamic>> rows) {
  final lines = <String>[
    adminTripRankingHeaders.map(adminCsvCell).join(';'),
  ];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final name = row['full_name']?.toString().trim() ?? '';
    lines.add(<Object?>[
      i + 1,
      name.isEmpty ? 'Sin nombre' : name,
      row['user_id'],
      row['completed_trips'] ?? 0,
      adminCsvDate(row['first_completed_at']),
      adminCsvDate(row['last_completed_at']),
    ].map(adminCsvCell).join(';'));
  }
  return '﻿${lines.join('\r\n')}\r\n';
}

/// Nombre del archivo, p. ej. `ranking-conductores-2026-11-15.csv`.
String adminTripRankingFileName({
  required bool drivers,
  required DateTime day,
}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp = '${day.year}-${two(day.month)}-${two(day.day)}';
  return 'ranking-${drivers ? 'conductores' : 'usuarios'}-$stamp.csv';
}

/// Encabezados del CSV de viajes, en el orden del archivo.
const List<String> adminTripsHeaders = <String>[
  'Fecha',
  'Estado',
  'Categoría',
  'Pasajero',
  'Conductor',
  'Origen',
  'Destino',
  'Tarifa final',
  'Moneda',
  'Pago',
  'Completado',
];

/// CSV de viajes: una fila por viaje, con el orden que llegue del servidor.
/// No incluye teléfonos ni correos.
String adminTripsCsv(List<Map<String, dynamic>> rows) {
  final lines = <String>[
    adminTripsHeaders.map(adminCsvCell).join(';'),
  ];
  for (final row in rows) {
    lines.add(<Object?>[
      adminCsvDate(row['created_at']),
      row['status'],
      row['category'],
      row['passenger_name'],
      row['driver_name'],
      row['pickup_address'],
      row['destination_address'],
      row['final_fare'],
      row['currency'] ?? row['currency_code'],
      row['payment_status'],
      adminCsvDate(row['completed_at']),
    ].map(adminCsvCell).join(';'));
  }
  return '\uFEFF${lines.join('\r\n')}\r\n';
}

/// Nombre del archivo de viajes, p. ej. `viajes-mes-2026-11-16.csv`.
String adminTripsFileName({required String period, required DateTime day}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final label = switch (period) {
    'today' => 'hoy',
    'week' => 'semana',
    'month' => 'mes',
    'custom' => 'rango',
    _ => 'periodo',
  };
  final stamp = '${day.year}-${two(day.month)}-${two(day.day)}';
  return 'viajes-$label-$stamp.csv';
}
