/// Importes con el formato de la casa: miles con punto y decimales con coma.
///
/// 1672.76 con CLP → «CLP 1.672,76»; 1500 con BOB → «Bs 1.500». Si la moneda no
/// se conoce no se inventa un símbolo: se muestra solo el número.
String adminMoney(Object? value, String? currency) {
  final number = value is num ? value : num.tryParse('${value ?? ''}'.trim());
  if (number == null) return '—';
  final code = (currency ?? '').trim().toUpperCase();
  final prefix = switch (code) {
    'CLP' => 'CLP ',
    'BOB' => 'Bs ',
    '' => '',
    _ => '$code ',
  };
  final parts = number.abs().toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final decimals = parts[1] == '00' ? '' : ',${parts[1]}';
  return '$prefix${number < 0 ? '-' : ''}$whole$decimals';
}
