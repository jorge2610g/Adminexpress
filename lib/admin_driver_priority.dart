import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const _blue = Color(0xFF2563EB);
const _green = Color(0xFF16A34A);
const _orange = Color(0xFFF59E0B);
const _red = Color(0xFFDC2626);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _bg = Color(0xFFF1F5F9);

class AdminDriverPriorityPage extends StatefulWidget {
  final String channel;
  final String? countryCode;
  final String? zoneId;

  const AdminDriverPriorityPage({
    super.key,
    this.channel = 'preview',
    this.countryCode,
    this.zoneId,
  });

  @override
  State<AdminDriverPriorityPage> createState() =>
      _AdminDriverPriorityPageState();
}

class _AdminDriverPriorityPageState extends State<AdminDriverPriorityPage> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final zoneId = widget.zoneId;
    if (zoneId == null || zoneId.isEmpty) {
      return <String, dynamic>{
        'settings': <String, dynamic>{},
        'drivers': <Map<String, dynamic>>[],
      };
    }
    final value = await supabase.rpc(
      'admin_driver_priority_state_scoped',
      params: {
        'p_channel': widget.channel,
        'p_zone_id': zoneId,
      },
    );
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  double _num(Object? value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _int(Object? value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _refresh() => setState(() => future = _load());

  void _snack(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.toString())),
    );
  }

  String _label(String raw) {
    switch (raw) {
      case 'high':
        return 'Alta';
      case 'medium':
        return 'Media';
      default:
        return 'Baja';
    }
  }

  Color _levelColor(String raw) {
    switch (raw) {
      case 'high':
        return _green;
      case 'medium':
        return _orange;
      default:
        return _red;
    }
  }

  Future<void> _editSettings(Map<String, dynamic> settings) async {
    bool previewEnabled = settings['preview_enabled'] == true;
    bool productionEnabled = settings['production_enabled'] == true;
    bool previewEnforcement =
        settings['preview_enforcement_enabled'] == true;
    bool productionEnforcement =
        settings['production_enforcement_enabled'] == true;

    final high = TextEditingController(
      text: _num(settings['high_min_score'], 80).toStringAsFixed(0),
    );
    final medium = TextEditingController(
      text: _num(settings['medium_min_score'], 55).toStringAsFixed(0),
    );
    final ratingWeight = TextEditingController(
      text: _num(settings['rating_weight'], 35).toStringAsFixed(0),
    );
    final reviewsWeight = TextEditingController(
      text: _num(settings['reviews_weight'], 25).toStringAsFixed(0),
    );
    final experienceWeight = TextEditingController(
      text: _num(settings['experience_weight'], 20).toStringAsFixed(0),
    );
    final frequencyWeight = TextEditingController(
      text: _num(settings['frequency_weight'], 20).toStringAsFixed(0),
    );
    final reviewTarget = TextEditingController(
      text: _int(settings['review_target'], 20).toString(),
    );
    final experienceTarget = TextEditingController(
      text: _int(settings['experience_trip_target'], 100).toString(),
    );
    final frequencyTarget = TextEditingController(
      text: _int(settings['frequency_30d_target'], 30).toString(),
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Configurar prioridad de conductores'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: previewEnabled,
                    onChanged: widget.channel == 'preview'
                        ? (value) => setLocal(() => previewEnabled = value)
                        : null,
                    title: const Text('Mostrar prioridad en Preview'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: previewEnforcement,
                    onChanged: widget.channel == 'preview' && previewEnabled
                        ? (value) =>
                            setLocal(() => previewEnforcement = value)
                        : null,
                    title: const Text('Aplicar ranking al despacho Preview'),
                    subtitle: const Text(
                      'Ordena solicitudes, pero no bloquea conductores.',
                    ),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: productionEnabled,
                    onChanged: widget.channel == 'production'
                        ? (value) => setLocal(() => productionEnabled = value)
                        : null,
                    title: const Text('Mostrar prioridad en Producción'),
                    subtitle: const Text(
                      'Puedes administrarlo por separado; Producción está preparada para aplicar el ranking seguro.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: productionEnforcement,
                    onChanged:
                        widget.channel == 'production' && productionEnabled
                            ? (value) =>
                                setLocal(() => productionEnforcement = value)
                            : null,
                    title: const Text('Aplicar ranking al despacho Producción'),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Umbrales',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: high,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Alta desde',
                            suffixText: '/100',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: medium,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Media desde',
                            suffixText: '/100',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pesos del puntaje',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ratingWeight,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Reputación'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: reviewsWeight,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Reseñas'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: experienceWeight,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Experiencia'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: frequencyWeight,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Frecuencia'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Metas para llegar a 100%',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: reviewTarget,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Reseñas'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: experienceTarget,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Viajes experiencia',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: frequencyTarget,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Viajes / 30 días',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_update_driver_priority_settings_v2',
          params: {
            'p_channel': widget.channel,
            'p_enabled': widget.channel == 'preview'
                ? previewEnabled
                : productionEnabled,
            'p_enforcement_enabled': widget.channel == 'preview'
                ? previewEnforcement
                : productionEnforcement,
            'p_high_min_score': double.tryParse(high.text.trim()) ?? 80,
            'p_medium_min_score':
                double.tryParse(medium.text.trim()) ?? 55,
            'p_rating_weight':
                double.tryParse(ratingWeight.text.trim()) ?? 35,
            'p_reviews_weight':
                double.tryParse(reviewsWeight.text.trim()) ?? 25,
            'p_experience_weight':
                double.tryParse(experienceWeight.text.trim()) ?? 20,
            'p_frequency_weight':
                double.tryParse(frequencyWeight.text.trim()) ?? 20,
            'p_review_target':
                int.tryParse(reviewTarget.text.trim()) ?? 20,
            'p_experience_trip_target':
                int.tryParse(experienceTarget.text.trim()) ?? 100,
            'p_frequency_30d_target':
                int.tryParse(frequencyTarget.text.trim()) ?? 30,
          },
        );
        _refresh();
        _snack('Prioridad actualizada.');
      } catch (e) {
        _snack(e);
      }
    }

    high.dispose();
    medium.dispose();
    ratingWeight.dispose();
    reviewsWeight.dispose();
    experienceWeight.dispose();
    frequencyWeight.dispose();
    reviewTarget.dispose();
    experienceTarget.dispose();
    frequencyTarget.dispose();
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _metric(String label, double value) {
    final clamped = value.clamp(0, 100).toDouble();
    final color = clamped >= 75
        ? _green
        : clamped >= 50
            ? _orange
            : _red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              clamped.toStringAsFixed(0),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: clamped / 100,
            minHeight: 6,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final settings = data['settings'] is Map
              ? Map<String, dynamic>.from(data['settings'] as Map)
              : <String, dynamic>{};
          final drivers = _rows(data['drivers']);

          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prioridad de conductores',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Alta, Media y Baja según reputación, reseñas, experiencia y frecuencia.',
                          style: TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualizar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _editSettings(settings),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Configurar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    settings['preview_enabled'] == true
                        ? 'Preview visible'
                        : 'Preview oculto',
                    settings['preview_enabled'] == true ? _green : _muted,
                  ),
                  _pill(
                    settings['preview_enforcement_enabled'] == true
                        ? 'Ranking Preview activo'
                        : 'Ranking Preview apagado',
                    settings['preview_enforcement_enabled'] == true
                        ? _green
                        : _muted,
                  ),
                  _pill(
                    settings['production_enabled'] == true
                        ? 'Producción visible'
                        : 'Producción apagada',
                    settings['production_enabled'] == true ? _orange : _muted,
                  ),
                  _pill(
                    settings['production_enforcement_enabled'] == true
                        ? 'Ranking Producción activo'
                        : 'Ranking Producción apagado',
                    settings['production_enforcement_enabled'] == true
                        ? _red
                        : _muted,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: _blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'El ranking cambia solo el orden de solicitudes y nunca bloquea conductores. Alta prioriza cercanía, buena reputación del pasajero y mejor tarifa/km; Media prioriza cercanía y tarifa/km; Baja recibe flujo normal por antigüedad, sin castigos.',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Conductores · ' + drivers.length.toString(),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (drivers.isEmpty)
                const Center(child: Text('No hay conductores aprobados.'))
              else
                ...drivers.map((row) {
                  final priority = row['priority'] is Map
                      ? Map<String, dynamic>.from(row['priority'] as Map)
                      : <String, dynamic>{};
                  final metrics = priority['metrics'] is Map
                      ? Map<String, dynamic>.from(priority['metrics'] as Map)
                      : <String, dynamic>{};
                  final level = priority['level']?.toString() ?? 'low';
                  final color = _levelColor(level);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: color.withValues(alpha: .10),
                          child: Icon(
                            Icons.local_taxi_rounded,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row['name']?.toString() ?? 'Conductor',
                                style: const TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _pill(_label(level), color),
                                  _pill(
                                    'Puntaje ' +
                                        _num(priority['score'])
                                            .toStringAsFixed(1),
                                    _blue,
                                  ),
                                  _pill(
                                    (priority['completed_trips'] ?? 0)
                                            .toString() +
                                        ' viajes',
                                    _muted,
                                  ),
                                  _pill(
                                    (priority['review_count'] ?? 0).toString() +
                                        ' reseñas',
                                    _muted,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _metric(
                                'Reputación',
                                _num(metrics['rating']),
                              ),
                              const SizedBox(height: 8),
                              _metric(
                                'Reseñas',
                                _num(metrics['reviews']),
                              ),
                              const SizedBox(height: 8),
                              _metric(
                                'Experiencia',
                                _num(metrics['experience']),
                              ),
                              const SizedBox(height: 8),
                              _metric(
                                'Frecuencia',
                                _num(metrics['frequency']),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
