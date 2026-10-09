import 'core/supabase_client.dart';

/// Environment-aware storage used by Adminexpress.
///
/// The two websites currently share the primary Supabase project.
/// Operational Production settings use existing RPCs; Preview configuration
/// edits for zones, polygons, fares, services, and app settings MUST remain
/// inside the `admin_environment_config` QA shadow.
///
/// Runtime-sensitive records (trips, identity reviews, wallets, payments)
/// additionally require server-side channel/identity assertions. This client
/// switch is not a substitute for authorization checks on privileged RPCs.
class AdminEnvironmentStore {
  final String channel;

  const AdminEnvironmentStore(this.channel);

  bool get isPreview => channel == 'preview';
  bool get isProduction => !isPreview;

  Future<List<Map<String, dynamic>>> previewList(String module) async {
    final value = await supabase.rpc(
      'admin_environment_config_list',
      params: {
        'p_environment': 'preview',
        'p_module': module,
      },
    );
    if (value is! List) return const [];

    final rows = <Map<String, dynamic>>[];
    for (final raw in value.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final payloadRaw = row['payload'];
      if (payloadRaw is! Map) continue;
      final payload = Map<String, dynamic>.from(payloadRaw);
      if (payload['_deleted'] == true) continue;
      payload['_record_key'] = row['record_key']?.toString() ?? 'default';
      rows.add(payload);
    }
    return rows;
  }

  Future<Map<String, dynamic>> previewGet(
    String module, {
    String recordKey = 'default',
  }) async {
    final value = await supabase.rpc(
      'admin_environment_config_get',
      params: {
        'p_environment': 'preview',
        'p_module': module,
        'p_record_key': recordKey,
      },
    );
    if (value is! Map) return <String, dynamic>{};
    final payload = Map<String, dynamic>.from(value);
    if (payload['_deleted'] == true) return <String, dynamic>{};
    payload['_record_key'] = recordKey;
    return payload;
  }

  Future<Map<String, dynamic>> previewUpsert(
    String module,
    String recordKey,
    Map<String, dynamic> payload,
  ) async {
    final clean = Map<String, dynamic>.from(payload)..remove('_record_key');
    final value = await supabase.rpc(
      'admin_environment_config_upsert',
      params: {
        'p_environment': 'preview',
        'p_module': module,
        'p_record_key': recordKey,
        'p_payload': clean,
      },
    );
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<void> previewSoftDelete(
    String module,
    Map<String, dynamic> row,
  ) async {
    final key = recordKey(row);
    final clean = Map<String, dynamic>.from(row)
      ..remove('_record_key')
      ..['_deleted'] = true
      ..['active'] = false;
    await previewUpsert(module, key, clean);
  }

  String createRecordKey(String prefix) =>
      prefix + '-' + DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  static String recordKey(
    Map<String, dynamic> row, {
    String fallback = 'default',
  }) {
    final explicit = row['_record_key']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final id = row['id']?.toString().trim();
    if (id != null && id.isNotEmpty) return id;
    final key = row['service_key']?.toString().trim();
    if (key != null && key.isNotEmpty) return key;
    final zoneKey = row['zone_key']?.toString().trim();
    if (zoneKey != null && zoneKey.isNotEmpty) return zoneKey;
    return fallback;
  }
}
