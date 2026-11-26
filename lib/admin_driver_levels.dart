import 'package:flutter/material.dart';

import 'core/admin_friendly_error.dart';
import 'core/supabase_client.dart';

/// Niveles de conductor (fase 1): Inicio, Pro y Élite, con los últimos 30 días. Solo informa:
/// no cambia quién recibe las solicitudes ni mueve dinero.
const Color _blue = Color(0xFF2563EB);
const Color _muted = Color(0xFF64748B);
const Color _line = Color(0xFFE7ECF3);
const Color _green = Color(0xFF15803D);
const Color _amber = Color(0xFFB45309);
const Color _violet = Color(0xFF7C3AED);

class AdminDriverLevelsRpc {
  static const list = 'admin_driver_levels_v1';
  static const settingsGet = 'admin_driver_level_settings_get_v1';
  static const settingsUpdate = 'admin_driver_level_settings_update_v1';

  static String label(String? level) => switch (level) {
        'elite' => 'Élite',
        'pro' => 'Pro',
        _ => 'Inicio',
      };

  static Color color(String? level) => switch (level) {
        'elite' => _violet,
        'pro' => _blue,
        _ => _muted,
      };

  /// Criterios que le faltan al conductor para el siguiente nivel, en texto corto.
  static List<String> missing(Map<String, dynamic> driver) {
    final criteria = driver['criteria'];
    if (criteria is! List) return const [];
    final out = <String>[];
    for (final c in criteria.whereType<Map>()) {
      if (c['met'] == true) continue;
      final value = c['value'];
      final target = c['target'];
      final unit = c['unit']?.toString() ?? '';
      final higher = c['higher_is_better'] != false;
      out.add(
        '${c['label']}: ${value ?? '—'}${unit == '%' ? ' %' : ''} '
        '(${higher ? 'mínimo' : 'máximo'} $target${unit == '%' ? ' %' : ''})',
      );
    }
    return out;
  }
}

List<Map<String, dynamic>> _rows(Object? v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : const [];

/// Pestañas de la sección: prioridad de solicitudes (la de siempre) y niveles.
class AdminDriverPriorityHub extends StatelessWidget {
  final String channel;
  final String? zoneId;
  final bool canEditSettings;
  final Widget priority;

  const AdminDriverPriorityHub({
    super.key,
    required this.channel,
    required this.zoneId,
    required this.canEditSettings,
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Material(
            color: Colors.white,
            child: TabBar(
              tabs: [
                Tab(text: 'Prioridad de solicitudes'),
                Tab(text: 'Niveles'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                priority,
                AdminDriverLevelsPage(
                  channel: channel,
                  zoneId: zoneId,
                  canEditSettings: canEditSettings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDriverLevelsPage extends StatefulWidget {
  final String channel;
  final String? zoneId;
  final bool canEditSettings;

  const AdminDriverLevelsPage({
    super.key,
    required this.channel,
    required this.zoneId,
    required this.canEditSettings,
  });

  @override
  State<AdminDriverLevelsPage> createState() => _AdminDriverLevelsPageState();
}

class _AdminDriverLevelsPageState extends State<AdminDriverLevelsPage> {
  int revision = 0;
  bool saving = false;
  final controllers = <String, TextEditingController>{};
  Map<String, dynamic>? loadedSettings;

  static const fields = <(String, String)>[
    ('window_days', 'Días de la ventana'),
    ('pro_min_trips', 'Pro: viajes mínimos'),
    ('elite_min_trips', 'Élite: viajes mínimos'),
    ('pro_min_rating', 'Pro: calificación mínima'),
    ('elite_min_rating', 'Élite: calificación mínima'),
    ('pro_min_response', 'Pro: respuesta mínima (%)'),
    ('elite_min_response', 'Élite: respuesta mínima (%)'),
    ('pro_max_cancel', 'Pro: cancelaciones máximas (%)'),
    ('elite_max_cancel', 'Élite: cancelaciones máximas (%)'),
  ];

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message is String ? message : friendlyError(message))),
    );
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final zone = widget.zoneId;
    if (zone == null || zone.isEmpty) return const [];
    if (widget.canEditSettings) {
      final s = await supabase.rpc(AdminDriverLevelsRpc.settingsGet);
      if (s is Map) {
        loadedSettings = Map<String, dynamic>.from(s);
        for (final f in fields) {
          final text = loadedSettings![f.$1]?.toString() ?? '';
          (controllers[f.$1] ??= TextEditingController()).text = text;
        }
      }
    }
    final value = await supabase.rpc(
      AdminDriverLevelsRpc.list,
      params: {'p_channel': widget.channel, 'p_zone_id': zone},
    );
    return _rows(value);
  }

  Future<void> _save() async {
    if (saving) return;
    final payload = <String, dynamic>{};
    for (final f in fields) {
      final text = controllers[f.$1]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final n = num.tryParse(text.replaceAll(',', '.'));
      if (n == null) {
        _toast('«${f.$2}» no es un número válido.');
        return;
      }
      payload[f.$1] = n;
    }
    setState(() => saving = true);
    try {
      await supabase
          .rpc(AdminDriverLevelsRpc.settingsUpdate, params: {'p': payload});
      if (!mounted) return;
      setState(() => revision++);
      _toast('Umbrales guardados.');
    } catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text('Niveles de conductor',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text(
          'Inicio, Pro y Élite según los últimos 30 días: viajes, calificación, respuesta a solicitudes y cancelaciones. '
          'Por ahora solo informa: no cambia quién recibe las solicitudes ni da premios.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey('levels-$revision'),
          future: _load(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const LinearProgressIndicator();
            }
            if (snap.hasError) return Text(friendlyError(snap.error));
            final drivers = snap.data ?? const <Map<String, dynamic>>[];
            int count(String level) =>
                drivers.where((d) => d['level'] == level).length;
            final active = drivers
                .where((d) =>
                    ((d['metrics'] as Map?)?['trips'] as num? ?? 0) > 0 ||
                    ((d['metrics'] as Map?)?['notified'] as num? ?? 0) > 0)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _Count('Élite', count('elite'), _violet),
                  _Count('Pro', count('pro'), _blue),
                  _Count('Inicio', count('inicio'), _muted),
                  _Count('Conductores aprobados', drivers.length, _green),
                ]),
                if (widget.canEditSettings && loadedSettings != null) ...[
                  const SizedBox(height: 16),
                  _SettingsCard(
                      controllers: controllers, saving: saving, onSave: _save),
                ],
                const SizedBox(height: 16),
                const Text('Conductores',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (active.isEmpty)
                  const Text('Sin actividad en el periodo.',
                      style: TextStyle(color: _muted))
                else
                  for (final d in active) _DriverLevelCard(driver: d),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Count(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ]),
      );
}

class _SettingsCard extends StatelessWidget {
  final Map<String, TextEditingController> controllers;
  final bool saving;
  final VoidCallback onSave;
  const _SettingsCard(
      {required this.controllers, required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Umbrales', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final f in _AdminDriverLevelsPageState.fields)
                SizedBox(
                  width: 210,
                  child: TextField(
                    controller: controllers[f.$1],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: f.$2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar umbrales'),
          ),
        ],
      ),
    );
  }
}

class _DriverLevelCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  const _DriverLevelCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    final level = driver['level']?.toString();
    final m = driver['metrics'] is Map
        ? Map<String, dynamic>.from(driver['metrics'] as Map)
        : <String, dynamic>{};
    final missing = AdminDriverLevelsRpc.missing(driver);
    final color = AdminDriverLevelsRpc.color(level);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(driver['name']?.toString() ?? 'Conductor',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(AdminDriverLevelsRpc.label(level),
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            '${m['trips'] ?? 0} viajes · calificación ${m['rating'] ?? '—'} (${m['rating_count'] ?? 0}) · '
            'respuesta ${m['response_rate'] == null ? '—' : '${m['response_rate']} %'} de ${m['notified'] ?? 0} avisos · '
            'cancelaciones ${m['cancel_rate'] ?? 0} % · sospechosos abiertos ${m['integrity_flags'] ?? 0}',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Para ${AdminDriverLevelsRpc.label(driver['next_level']?.toString())} le falta: ${missing.join(' · ')}',
              style: const TextStyle(
                  fontSize: 12, color: _amber, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
