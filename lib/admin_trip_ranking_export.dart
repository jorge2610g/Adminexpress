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

/// Nombre del archivo de viajes, p. ej. `viajes-completados-mes-2026-11-16.csv`.
/// [status] es null para todos los viajes, o 'completed' / 'cancelled'.
String adminTripsFileName({
  required String period,
  String? status,
  required DateTime day,
}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final statusLabel = switch (status) {
    'completed' => 'completados',
    'cancelled' => 'cancelados',
    _ => 'todos',
  };
  final periodLabel = switch (period) {
    'today' => 'hoy',
    'week' => 'semana',
    'month' => 'mes',
    'custom' => 'rango',
    _ => 'periodo',
  };
  final stamp = '${day.year}-${two(day.month)}-${two(day.day)}';
  return 'viajes-$statusLabel-$periodLabel-$stamp.csv';
}

// ───────────────────────── Exportación completa de conductores y usuarios ─────────────────────────

/// Fecha como TEXTO legible (dd/mm/aaaa hh:mm) con un espacio al final. Sin ese espacio Excel la
/// convierte en fecha y, si la columna es angosta, muestra «##########» en vez del valor.
String adminCsvDateText(Object? raw) {
  final text = adminCsvDate(raw);
  return text.isEmpty ? '' : '$text ';
}

/// Teléfono para la hoja de cálculo. Un número válido lleva un espacio inicial para que Excel lo
/// deje como texto (conserva el «+» y no lo vuelve número). Cualquier otro valor pasa por la
/// protección normal contra fórmulas.
String _csvPhone(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (RegExp(r'^\+?[0-9 ()-]{6,20}$').hasMatch(text)) return ' $text';
  return text;
}

String _csvLabel(Map<String, String> labels, Object? value) {
  final key = value?.toString().trim() ?? '';
  if (key.isEmpty) return '';
  return labels[key.toLowerCase()] ?? key;
}

const Map<String, String> _approvalLabels = <String, String>{
  'approved': 'Aprobado',
  'pending': 'Pendiente',
  'rejected': 'Rechazado',
};
const Map<String, String> _onlineLabels = <String, String>{
  'online': 'En línea',
  'offline': 'Desconectado',
};
const Map<String, String> _accountLabels = <String, String>{
  'active': 'Activa',
  'blocked': 'Bloqueada',
  'suspended': 'Suspendida',
};
const Map<String, String> _subscriptionLabels = <String, String>{
  'active': 'Activa',
  'expired': 'Vencida',
  'cancelled': 'Cancelada',
  'pending': 'Pendiente',
};
const Map<String, String> _modeLabels = <String, String>{
  'passenger': 'Pasajero',
  'driver': 'Conductor',
};

/// Encabezados de la exportación de conductores, en el orden del archivo.
const List<String> adminDriversExportHeaders = <String>[
  'Nombre',
  'Correo',
  'Teléfono',
  'Teléfono verificado',
  'Estado de la cuenta',
  'Aprobación',
  'Conexión',
  'Fecha de alta',
  'Registro completado',
  'Licencia',
  'Tipo de vehículo',
  'Marca',
  'Modelo',
  'Color',
  'Placa',
  'Año',
  'Resumen del vehículo',
  'Ciudad',
  'Zona',
  'País',
  'Moneda',
  'Calificación',
  'Viajes completados',
  'Viajes cancelados',
  'Primer viaje completado',
  'Último viaje completado',
  'Métodos de pago',
  'Suscripción',
  'Suscripción vence',
  'Avisos de integridad',
  'Suspensiones',
  'Suspendido hasta',
  'Última ubicación',
  'ID',
];

/// CSV con todos los datos de cada conductor (filas de `admin_driver_export_v1`).
String adminDriversExportCsv(List<Map<String, dynamic>> rows) {
  final lines = <String>[
    adminDriversExportHeaders.map(adminCsvCell).join(';'),
  ];
  for (final row in rows) {
    final name = row['full_name']?.toString().trim() ?? '';
    lines.add(<Object?>[
      name.isEmpty ? 'Sin nombre' : name,
      row['email'],
      _csvPhone(row['phone']),
      row['phone_verified_at'] == null ? 'No' : 'Sí',
      _csvLabel(_accountLabels, row['account_status']),
      _csvLabel(_approvalLabels, row['approval_status']),
      _csvLabel(_onlineLabels, row['online_status']),
      adminCsvDateText(row['created_at']),
      adminCsvDateText(row['onboarding_completed_at']),
      row['license_number'],
      row['vehicle_type'],
      row['vehicle_brand'],
      row['vehicle_model'],
      row['vehicle_color'],
      row['vehicle_plate'],
      row['vehicle_year'],
      row['vehicle_summary'],
      row['city'],
      row['zone_name'],
      row['country'],
      row['currency_code'],
      row['rating'],
      row['completed_trips'] ?? 0,
      row['cancelled_trips'] ?? 0,
      adminCsvDateText(row['first_completed_at']),
      adminCsvDateText(row['last_completed_at']),
      row['accepted_payment_methods'],
      _csvLabel(_subscriptionLabels, row['subscription_status']),
      adminCsvDateText(row['subscription_expires_at']),
      row['integrity_warnings'],
      row['integrity_suspensions'],
      adminCsvDateText(row['integrity_suspended_until']),
      adminCsvDateText(row['location_updated_at']),
      row['user_id'],
    ].map(adminCsvCell).join(';'));
  }
  return '\uFEFF${lines.join('\r\n')}\r\n';
}

/// Encabezados de la exportación de usuarios (pasajeros y conductores).
const List<String> adminUsersExportHeaders = <String>[
  'Nombre',
  'Correo',
  'Teléfono',
  'Modo activo',
  'Estado de la cuenta',
  'Estado de conductor',
  'Zona',
  'Ciudad',
  'Región',
  'País',
  'Fecha de alta',
  'Viajes completados como pasajero',
  'Primer viaje como pasajero',
  'Último viaje como pasajero',
  'Viajes completados como conductor',
  'ID',
];

/// Indexa las filas del ranking (`admin_completed_trip_ranking_v1`) por usuario.
Map<String, Map<String, dynamic>> adminRankingById(
    List<Map<String, dynamic>> rows) {
  return <String, Map<String, dynamic>>{
    for (final row in rows)
      if (row['user_id'] != null) row['user_id'].toString(): row,
  };
}

/// CSV de usuarios (filas de `admin_user_list_v5`) con sus viajes completados como pasajero y como
/// conductor, tomados de los dos rankings.
String adminUsersExportCsv(
  List<Map<String, dynamic>> users, {
  Map<String, Map<String, dynamic>> passengerRanking = const {},
  Map<String, Map<String, dynamic>> driverRanking = const {},
}) {
  final lines = <String>[
    adminUsersExportHeaders.map(adminCsvCell).join(';'),
  ];
  for (final row in users) {
    final id = row['user_id']?.toString() ?? '';
    final name = row['full_name']?.toString().trim() ?? '';
    final asPassenger = passengerRanking[id];
    final asDriver = driverRanking[id];
    lines.add(<Object?>[
      name.isEmpty ? 'Sin nombre' : name,
      row['email'],
      _csvPhone(row['phone']),
      _csvLabel(_modeLabels, row['active_mode']),
      _csvLabel(_accountLabels, row['account_status']),
      _csvLabel(_approvalLabels, row['driver_status']),
      row['zone_name'],
      row['city'],
      row['region_department'],
      row['country'],
      adminCsvDateText(row['created_at']),
      asPassenger?['completed_trips'] ?? 0,
      adminCsvDateText(asPassenger?['first_completed_at']),
      adminCsvDateText(asPassenger?['last_completed_at']),
      asDriver?['completed_trips'] ?? 0,
      row['user_id'],
    ].map(adminCsvCell).join(';'));
  }
  return '\uFEFF${lines.join('\r\n')}\r\n';
}

/// Nombre del archivo de conductores, p. ej. `conductores-aprobados-2026-11-24.csv`.
String adminDriversFileName({String? status, required DateTime day}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final label = switch (status) {
    'approved' => 'aprobados',
    'pending' => 'pendientes',
    'rejected' => 'rechazados',
    _ => 'todos',
  };
  return 'conductores-$label-${day.year}-${two(day.month)}-${two(day.day)}.csv';
}

/// Nombre del archivo de clientes, p. ej. `clientes-2026-11-24.csv`.
String adminUsersFileName({required DateTime day}) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'clientes-${day.year}-${two(day.month)}-${two(day.day)}.csv';
}
