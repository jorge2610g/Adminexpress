/// Tiempos globales de Express. Viven solo en `app_settings` y son compartidos
/// con producción. Preview los muestra con los valores reales en solo lectura y
/// nunca los guarda en `admin_environment_config`, que la app no lee.
const List<String> kSharedGlobalTimingKeys = <String>[
  'offer_timeout_seconds',
  'search_timeout_seconds',
  'request_visible_seconds',
  'scheduled_publish_before_minutes',
];

const String kSharedGlobalTimingNote = 'compartido con producción';

/// Lee los tiempos reales mediante `admin_settings_get`, la misma fuente de
/// la que lee la app. [rpc] se inyecta para no acoplar este módulo al cliente.
Future<Map<String, dynamic>> readSharedGlobalTiming(
  Future<dynamic> Function(String fn) rpc,
) async {
  final value = await rpc('admin_settings_get');
  if (value is! Map) return <String, dynamic>{};
  final row = Map<String, dynamic>.from(value);
  return <String, dynamic>{
    for (final key in kSharedGlobalTimingKeys)
      if (row.containsKey(key)) key: row[key],
  };
}

/// Quita los tiempos compartidos antes de guardar en el almacén de Preview.
Map<String, dynamic> withoutSharedGlobalTiming(Map<String, dynamic> payload) {
  final clean = Map<String, dynamic>.from(payload);
  for (final key in kSharedGlobalTimingKeys) {
    clean.remove(key);
  }
  return clean;
}
