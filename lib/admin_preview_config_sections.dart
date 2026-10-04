import 'dart:convert';

import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const _previewBlue = Color(0xFF2563EB);
const _previewInk = Color(0xFF0F172A);
const _previewMuted = Color(0xFF64748B);
const _previewBg = Color(0xFFF1F5F9);

class AdminPreviewModulePage extends StatefulWidget {
  final String module;
  final String title;
  final String subtitle;

  const AdminPreviewModulePage({
    super.key,
    required this.module,
    required this.title,
    required this.subtitle,
  });

  @override
  State<AdminPreviewModulePage> createState() => _AdminPreviewModulePageState();
}

class _AdminPreviewModulePageState extends State<AdminPreviewModulePage> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final value = await supabase.rpc(
      'admin_environment_config_list',
      params: {
        'p_environment': 'preview',
        'p_module': widget.module,
      },
    );
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  void _refresh() => setState(() => future = _load());

  void _snack(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.toString())),
    );
  }

  String _label(String key) {
    const labels = <String, String>{
      'currency': 'Moneda',
      'min_ride_fare': 'Tarifa mínima viaje',
      'min_delivery_fare': 'Tarifa mínima delivery',
      'commission_percent': 'Comisión (%)',
      'service_radius_km': 'Radio de servicio (km)',
      'ride_enabled': 'Viajes habilitados',
      'delivery_enabled': 'Delivery habilitado',
      'dispatch_mode': 'Modo de despacho',
      'dispatch_radius_km': 'Radio de despacho (km)',
      'offer_timeout_seconds': 'Tiempo de oferta (segundos)',
      'timezone': 'Zona horaria',
      'default_country': 'País predeterminado',
      'support_phone': 'Teléfono de soporte',
      'support_whatsapp': 'WhatsApp de soporte',
      'name': 'Nombre',
      'city': 'Ciudad',
      'country': 'País',
      'active': 'Activo',
      'radius_km': 'Radio (km)',
      'zone_key': 'Clave de zona',
      'currency_code': 'Moneda',
      'scope_type': 'Alcance',
      'service_key': 'Servicio',
      'base_fare': 'Tarifa base',
      'per_km': 'Por km',
      'per_minute': 'Por minuto',
      'minimum_fare': 'Tarifa mínima',
      'surge_multiplier': 'Multiplicador',
      'description': 'Descripción',
      'icon_key': 'Icono',
      'vehicle_type': 'Tipo de vehículo',
      'enabled': 'Habilitado',
      'allow_bidding': 'Permitir ofertas',
      'allow_fixed_price': 'Precio fijo',
      'passenger_visible': 'Visible pasajero',
      'driver_visible': 'Visible conductor',
      'scheduled_enabled': 'Programados',
      'sort_order': 'Orden',
    };
    return labels[key] ??
        key
            .split('_')
            .map((part) => part.isEmpty
                ? part
                : part[0].toUpperCase() + part.substring(1))
            .join(' ');
  }

  bool _editableKey(String key, Object? value) {
    if (const {
      'id',
      'created_at',
      'updated_at',
      'updated_by',
      'center_latitude',
      'center_longitude',
      'zone_id',
    }.contains(key)) {
      return false;
    }
    return value == null ||
        value is String ||
        value is num ||
        value is bool ||
        value is List ||
        value is Map;
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    final recordKey = row['record_key']?.toString() ?? 'default';
    final raw = row['payload'];
    final payload = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    final values = <String, Object?>{...payload};
    final controllers = <String, TextEditingController>{};

    for (final entry in payload.entries) {
      if (!_editableKey(entry.key, entry.value) || entry.value is bool) continue;
      final value = entry.value;
      controllers[entry.key] = TextEditingController(
        text: value is List || value is Map
            ? const JsonEncoder.withIndent('  ').convert(value)
            : value?.toString() ?? '',
      );
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(widget.title + ' · Prueba'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                children: payload.entries
                    .where((entry) => _editableKey(entry.key, entry.value))
                    .map((entry) {
                  final key = entry.key;
                  final value = values[key];
                  if (value is bool) {
                    return SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: value,
                      onChanged: (next) => setLocal(() => values[key] = next),
                      title: Text(_label(key)),
                    );
                  }
                  final controller = controllers[key]!;
                  final numeric = value is num;
                  final structured = value is List || value is Map;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controller,
                      minLines: structured ? 4 : 1,
                      maxLines: structured ? 10 : 1,
                      keyboardType: numeric
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: _label(key),
                        helperText:
                            structured ? 'JSON exclusivo de Preview' : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar en Prueba'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      for (final entry in controllers.entries) {
        final original = payload[entry.key];
        final text = entry.value.text.trim();
        if (original is int) {
          values[entry.key] = int.tryParse(text) ?? original;
        } else if (original is double || original is num) {
          values[entry.key] = double.tryParse(text) ?? original;
        } else if (original is List || original is Map) {
          try {
            values[entry.key] = jsonDecode(text);
          } catch (_) {
            _snack('JSON inválido en ' + _label(entry.key));
            return;
          }
        } else {
          values[entry.key] = text;
        }
      }

      final next = <String, dynamic>{...payload, ...values};
      try {
        await supabase.rpc(
          'admin_environment_config_upsert',
          params: {
            'p_environment': 'preview',
            'p_module': widget.module,
            'p_record_key': recordKey,
            'p_payload': next,
          },
        );
        _refresh();
        _snack('Guardado solo en Prueba. Producción no fue modificada.');
      } catch (e) {
        _snack(e);
      }
    }

    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  String _recordTitle(Map<String, dynamic> row) {
    final raw = row['payload'];
    final payload =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return (payload['name'] ??
            payload['service_key'] ??
            payload['zone_key'] ??
            payload['scope_type'] ??
            row['record_key'] ??
            'Registro')
        .toString();
  }

  String _summary(Map<String, dynamic> row) {
    final raw = row['payload'];
    final payload =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final visible = payload.entries
        .where((e) =>
            _editableKey(e.key, e.value) &&
            !const {'name', 'service_key', 'zone_key'}.contains(e.key))
        .take(4)
        .map((e) => _label(e.key) + ': ' + (e.value ?? '—').toString())
        .join(' · ');
    return visible.isEmpty ? 'Configuración Preview' : visible;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Reintentar: ' + snapshot.error.toString()),
            ),
          );
        }

        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return ColoredBox(
          color: _previewBg,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF5C36A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science_rounded,
                        color: Color(0xFFB54708)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title + ' · PRUEBA AISLADA\n' + widget.subtitle,
                        style: const TextStyle(
                          color: _previewInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Actualizar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay configuración Preview cargada para este módulo.',
                      style: TextStyle(color: _previewMuted),
                    ),
                  ),
                )
              else
                ...rows.map(
                  (row) => Card(
                    margin: const EdgeInsets.only(bottom: 9),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEAF2FF),
                        child: Icon(Icons.tune_rounded, color: _previewBlue),
                      ),
                      title: Text(
                        _recordTitle(row),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        _summary(row),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: FilledButton.icon(
                        onPressed: () => _edit(row),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('Editar'),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Los cambios de esta pantalla se guardan exclusivamente en Preview. '
                'No escriben en las tablas de Producción.',
                style: TextStyle(
                  color: _previewMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
