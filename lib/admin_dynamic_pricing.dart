import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

class AdminDynamicPricingPage extends StatefulWidget {
  final String channel;
  final String? countryCode;
  final String? zoneId;

  const AdminDynamicPricingPage({
    super.key,
    this.channel = 'preview',
    this.countryCode,
    this.zoneId,
  });

  @override
  State<AdminDynamicPricingPage> createState() =>
      _AdminDynamicPricingPageState();
}

class _AdminDynamicPricingPageState extends State<AdminDynamicPricingPage> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void didUpdateWidget(covariant AdminDynamicPricingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel ||
        oldWidget.countryCode != widget.countryCode ||
        oldWidget.zoneId != widget.zoneId) {
      _refresh();
    }
  }

  Future<Map<String, dynamic>> _load() async {
    final zoneId = widget.zoneId;
    if (zoneId == null || zoneId.isEmpty) {
      return <String, dynamic>{
        'settings': <String, dynamic>{},
        'cities': <Map<String, dynamic>>[],
      };
    }
    final raw = await supabase.rpc(
      'admin_dynamic_pricing_qa_state_scoped',
      params: {
        'p_zone_id': zoneId,
        'p_channel': widget.channel,
      },
    );
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
  }

  void _refresh() => setState(() => future = _load());

  double _num(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _int(Object? value, int fallback) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _snack(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.toString())),
    );
  }

  Future<void> _configure(Map<String, dynamic> s) async {
    final channel = widget.channel;
    final zoneId = widget.zoneId;
    var enabled = s['enabled'] == true;

    TextEditingController c(Object? v, num fallback) =>
        TextEditingController(text: _num(v, fallback.toDouble()).toString());

    final lowRatio = c(s['low_ratio'], .50);
    final lowMultiplier = c(s['low_multiplier'], .90);
    final lowMinDrivers =
        TextEditingController(text: _int(s['low_min_drivers'], 2).toString());
    final radius = c(s['radius_km'], .75);
    final window =
        TextEditingController(text: _int(s['window_minutes'], 5).toString());
    final minRequests =
        TextEditingController(text: _int(s['min_requests'], 3).toString());
    final elevatedRatio = c(s['elevated_ratio'], 1.20);
    final highRatio = c(s['high_ratio'], 2.00);
    final criticalRatio = c(s['critical_ratio'], 3.00);
    final elevatedMultiplier = c(s['elevated_multiplier'], 1.10);
    final highMultiplier = c(s['high_multiplier'], 1.20);
    final criticalMultiplier = c(s['critical_multiplier'], 1.35);
    final maxMultiplier = c(s['max_multiplier'], 1.50);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            'Demanda dinámica · ' +
                (channel == 'preview' ? 'Preview' : 'Producción'),
          ),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    onChanged: (v) => setLocal(() => enabled = v),
                    title: const Text('Activar precio por demanda'),
                    subtitle: const Text(
                      'El servidor recalcula el precio recomendado y aplica el piso mínimo.',
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(child: _field(lowRatio, 'Ratio demanda baja')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(lowMultiplier, 'Multiplicador baja')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(lowMinDrivers, 'Conductores mín. baja')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _field(radius, 'Radio km')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(window, 'Ventana minutos')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(minRequests, 'Solicitudes mín.')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _field(elevatedRatio, 'Ratio elevada')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(highRatio, 'Ratio alta')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(criticalRatio, 'Ratio crítica')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _field(elevatedMultiplier, 'Mult. elevada')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(highMultiplier, 'Mult. alta')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(criticalMultiplier, 'Mult. crítica')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(maxMultiplier, 'Máximo')),
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

    if (ok == true) {
      try {
        await supabase.rpc(
          'admin_update_dynamic_pricing_settings',
          params: {
            'p_channel': channel,
            'p_enabled': enabled,
            'p_low_ratio': double.tryParse(lowRatio.text),
            'p_low_multiplier': double.tryParse(lowMultiplier.text),
            'p_low_min_drivers': int.tryParse(lowMinDrivers.text),
            'p_radius_km': double.tryParse(radius.text),
            'p_window_minutes': int.tryParse(window.text),
            'p_min_requests': int.tryParse(minRequests.text),
            'p_elevated_ratio': double.tryParse(elevatedRatio.text),
            'p_high_ratio': double.tryParse(highRatio.text),
            'p_critical_ratio': double.tryParse(criticalRatio.text),
            'p_elevated_multiplier':
                double.tryParse(elevatedMultiplier.text),
            'p_high_multiplier': double.tryParse(highMultiplier.text),
            'p_critical_multiplier':
                double.tryParse(criticalMultiplier.text),
            'p_max_multiplier': double.tryParse(maxMultiplier.text),
          },
        );
        if (mounted &&
            channel == widget.channel &&
            zoneId == widget.zoneId) {
          _refresh();
          _snack('Demanda dinámica actualizada.');
        }
      } catch (e) {
        _snack(e);
      }
    }

    for (final controller in [
      lowRatio,
      lowMultiplier,
      lowMinDrivers,
      radius,
      window,
      minRequests,
      elevatedRatio,
      highRatio,
      criticalRatio,
      elevatedMultiplier,
      highMultiplier,
      criticalMultiplier,
      maxMultiplier,
    ]) {
      controller.dispose();
    }
  }

  static Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _override(String cityKey, String level) async {
    try {
      await supabase.rpc(
        'admin_set_dynamic_pricing_qa_override',
        params: {
          'p_city_key': cityKey,
          'p_level': level,
          'p_minutes': 60,
        },
      );
      _refresh();
      _snack(level == 'automatic'
          ? 'Demanda automática restaurada.'
          : 'Simulación ' + level + ' activa por 60 minutos.');
    } catch (e) {
      _snack(e);
    }
  }

  String _pct(Object? raw) {
    final n = _num(raw, 1);
    final value = ((n - 1) * 100).round();
    return (value > 0 ? '+' : '') + value.toString() + '%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          final rawCities = data['cities'];
          final cities = rawCities is List
              ? rawCities
                  .whereType<Map>()
                  .map((x) => Map<String, dynamic>.from(x))
                  .toList()
              : <Map<String, dynamic>>[];
          final enabled = settings['enabled'] == true;

          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Demanda y precios',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Precio recomendado autoritativo · ' +
                              (widget.channel == 'preview'
                                  ? 'Preview'
                                  : 'Producción'),
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
                    onPressed: () => _configure(settings),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Configurar'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _stat('Estado', enabled ? 'Activo' : 'Apagado'),
                  _stat('Demanda baja', _pct(settings['low_multiplier'])),
                  _stat('Elevada', _pct(settings['elevated_multiplier'])),
                  _stat('Alta', _pct(settings['high_multiplier'])),
                  _stat('Crítica', _pct(settings['max_multiplier'])),
                  _stat(
                    'Radio',
                    (settings['radius_km']?.toString() ?? '-') + ' km',
                  ),
                  _stat(
                    'Ventana',
                    (settings['window_minutes']?.toString() ?? '-') + ' min',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Regla de seguridad: el pasajero puede aumentar su oferta, '
                    'pero nunca bajarla por debajo del precio recomendado vigente. '
                    'El servidor vuelve a calcular el piso al crear la solicitud.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              if (widget.channel == 'preview') ...[
                const SizedBox(height: 20),
                const Text(
                  'Simulación QA por ciudad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Solo Preview. Las simulaciones expiran automáticamente y no modifican Producción.',
                ),
                const SizedBox(height: 10),
                ...cities.map((city) {
                  final key = city['city_key']?.toString() ?? '';
                  final name = city['city_name']?.toString() ?? key;
                  final level = city['active'] == true
                      ? city['level']?.toString() ?? 'automatic'
                      : 'automatic';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name + ' · ' + level,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              for (final item in const [
                                ('automatic', 'Automático'),
                                ('low', 'Baja'),
                                ('normal', 'Normal'),
                                ('medium', 'Media'),
                                ('high', 'Alta'),
                                ('very_high', 'Muy alta'),
                                ('critical', 'Crítica'),
                              ])
                                OutlinedButton(
                                  onPressed: () => _override(key, item.$1),
                                  child: Text(item.$2),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
