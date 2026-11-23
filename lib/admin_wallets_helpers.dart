import 'admin_trip_ranking_export.dart' show adminCsvCell, adminCsvDate;

/// Importe con la moneda de la zona (CLP sin decimales, el resto con dos).
String adminWalletMoney(dynamic amount, String currency) {
  final number = amount is num ? amount : num.tryParse('$amount') ?? 0;
  final decimals = currency.toUpperCase() == 'CLP' ? 0 : 2;
  return '$currency ${number.toStringAsFixed(decimals)}';
}

/// Encabezados del CSV de billeteras, en el orden del archivo.
const List<String> adminWalletsCsvHeaders = <String>[
  'Nombre',
  'Rol',
  'Correo',
  'Teléfono',
  'Saldo',
  'Moneda',
  'Transacciones',
  'Retiros pendientes',
  'Última actividad',
];

/// CSV de billeteras con `;` como separador y BOM, como el resto de exportaciones.
String adminWalletsCsv(List<Map<String, dynamic>> rows) {
  final lines = <String>[adminWalletsCsvHeaders.map(adminCsvCell).join(';')];
  for (final row in rows) {
    final name = row['full_name']?.toString().trim() ?? '';
    lines.add(<Object?>[
      name.isEmpty ? 'Sin nombre' : name,
      row['role'] == 'driver' ? 'Conductor' : 'Pasajero',
      row['email'],
      row['phone'],
      row['balance'] ?? 0,
      row['currency_code'],
      row['tx_count'] ?? 0,
      row['pending_withdrawals'] ?? 0,
      adminCsvDate(row['last_activity']),
    ].map(adminCsvCell).join(';'));
  }
  return '﻿${lines.join('\r\n')}\r\n';
}

/// Texto de "neto a liquidar" según el saldo de la billetera.
String adminWalletSettleText(dynamic net, String currency) {
  final value = net is num ? net : num.tryParse('$net') ?? 0;
  if (value > 0) {
    return 'Express debe pagarle ${adminWalletMoney(value, currency)}';
  }
  if (value < 0) {
    return 'Debe a Express ${adminWalletMoney(-value, currency)}';
  }
  return 'Al día: no hay nada que liquidar';
}
