import 'package:flutter/material.dart';

import 'core/admin_design_tokens.dart';

import 'core/supabase_client.dart';
import 'admin_environment_store.dart';

/// Production distance fares use the existing operational RPCs.
/// Preview reads/writes only the isolated QA shadow: it MUST NEVER alter
/// zone_distance_fare_steps consumed by real passenger fare calculations.
class AdminDistanceFaresEditor extends StatefulWidget {
  const AdminDistanceFaresEditor({
    super.key,
    required this.channel,
    required this.zone,
    required this.services,
  });
  final String channel;
  final Map<String, dynamic> zone;
  final List<Map<String, dynamic>> services;

  @override
  State<AdminDistanceFaresEditor> createState() =>
      _AdminDistanceFaresEditorState();
}

class _Step {
  _Step({required double upToKm, required double fare})
      : km = TextEditingController(text: _format(upToKm)),
        amount = TextEditingController(text: _format(fare));
  final TextEditingController km;
  final TextEditingController amount;

  static String _format(double n) => n == n.roundToDouble()
      ? n.toStringAsFixed(0)
      : n.toStringAsFixed(2);

  void dispose() {
    km.dispose();
    amount.dispose();
  }
}

class _AdminDistanceFaresEditorState extends State<AdminDistanceFaresEditor> {
  AdminEnvironmentStore get _environment => AdminEnvironmentStore(widget.channel);

  String _qaRecordKey(String zoneId, String serviceKey) =>
      '$zoneId::$serviceKey';

  final List<_Step> _steps = <_Step>[];
  String? _service;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  int _revision = 0;

  List<String> get _services {
    final keys = widget.services
        .map((s) => (s['service_key'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()..sort();
    return keys;
  }

  @override
  void initState() {
    super.initState();
    _service = _services.isNotEmpty ? _services.first : null;
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminDistanceFaresEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.zone['id']?.toString() != oldWidget.zone['id']?.toString()
        || widget.channel != oldWidget.channel) {
      _load();
    } else if (!_services.contains(_service)) {
      _service = _services.isNotEmpty ? _services.first : null;
      _load();
    }
  }

  void _replaceSteps(List<_Step> next) {
    for (final step in _steps) {
      step.dispose();
    }
    _steps..clear()..addAll(next);
  }

  Future<void> _load() async {
    final revision = ++_revision;
    final service = _service;
    final zone = widget.zone['id']?.toString();
    setState(() {
      _loading = true;
      _error = null;
    });
    if (service == null || zone == null) {
      if (mounted && revision == _revision) {
        setState(() {
          _replaceSteps([]);
          _loading = false;
        });
      }
      return;
    }
    try {
      final raw = _environment.isPreview
          ? await _environment.previewGet(
              'zone_distance_fare_steps',
              recordKey: _qaRecordKey(zone, service),
            )
          : await supabase.rpc(
              'admin_distance_fare_steps_get',
              params: {
                'p_channel': widget.channel,
                'p_zone_id': zone,
                'p_service_key': service,
              },
            );
      if (!mounted || revision != _revision) return;
      if (raw is! Map) throw StateError('Respuesta de tarifas no válida');
      final data = Map<String, dynamic>.from(raw);
      final rows = (data['steps'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _replaceSteps(rows.map((row) => _Step(
          upToKm: (row['up_to_km'] as num).toDouble(),
          fare: (row['fare'] as num).toDouble(),
        )).toList());
        _loading = false;
      });
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() {
          _loading = false;
          _error = 'No se pudieron cargar las tarifas: $error';
        });
      }
    }
  }

  Future<void> _save() async {
    final zone = widget.zone['id']?.toString();
    final service = _service;
    if (zone == null || service == null || _saving) return;
    final steps = <Map<String, num>>[];
    double previousKm = 0;
    double previousFare = 0;
    for (final step in _steps) {
      final km = double.tryParse(step.km.text.trim().replaceAll(',', '.'));
      final fare =
          double.tryParse(step.amount.text.trim().replaceAll(',', '.'));
      if (km == null || fare == null || !km.isFinite || !fare.isFinite
          || km <= previousKm || fare <= 0 || fare < previousFare) {
        setState(() => _error =
            'Ordena las distancias de menor a mayor y no disminuyas el precio.');
        return;
      }
      steps.add({'up_to_km': km, 'fare': fare});
      previousKm = km;
      previousFare = fare;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_environment.isPreview) {
        await _environment.previewUpsert(
          'zone_distance_fare_steps',
          _qaRecordKey(zone, service),
          <String, dynamic>{
            'zone_id': zone,
            'service_key': service,
            'steps': steps,
          },
        );
      } else {
        await supabase.rpc('admin_distance_fare_steps_replace', params: {
          'p_channel': widget.channel,
          'p_zone_id': zone,
          'p_service_key': service,
          'p_steps': steps,
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            _environment.isPreview
                ? 'Tarifas de prueba guardadas solo en Preview.'
                : 'Tarifas escalonadas de Producción guardadas.')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    ++_revision;
    _replaceSteps([]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = (widget.zone['currency_code'] ?? 'BOB').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.stacked_line_chart_rounded,
                    color: AdminColors.blue),
                SizedBox(width: 10),
                Expanded(child: Text('Tarifa escalonada por distancia',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
              ],
            ),
            if (_environment.isPreview) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.warnSoft,
                  border: Border.all(color: const Color(0xFFF5D58A)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PREVIEW · Simulación QA: estos escalones no modifican '
                  'las tarifas de pasajeros ni los precios de Producción.',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text('Configura cuánto cuesta cada tramo en $currency. '
                'Los límites son inclusivos: 3 km = primer tramo, '
                'más de 3 km = siguiente tramo. '
                'Para distancias superiores al último escalón se prolonga '
                'el incremento final. Sin escalones se conserva la tarifa actual.',
              style: const TextStyle(color: AdminColors.muted)),
            const SizedBox(height: 12),
            if (_services.isEmpty)
              const Text('No hay servicios configurados en esta zona.')
            else
              DropdownButtonFormField<String>(
                key: ValueKey('step-service-${widget.zone['id']}-$_service'),
                initialValue: _services.contains(_service) ? _service : null,
                decoration: const InputDecoration(
                  labelText: 'Servicio', border: OutlineInputBorder()),
                items: _services.map((service) => DropdownMenuItem(
                  value: service, child: Text(service))).toList(),
                onChanged: _saving ? null : (service) {
                  if (service == null) return;
                  _service = service;
                  _load();
                },
              ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else ...[
              if (_steps.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('No hay escalones: se conserva la tarifa existente.'),
                ),
              for (var index = 0; index < _steps.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _steps[index].km,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Hasta km', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _steps[index].amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Precio ($currency)',
                            border: const OutlineInputBorder()),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Eliminar escalón',
                        onPressed: _saving ? null : () => setState(() {
                          _steps.removeAt(index).dispose();
                        }),
                        icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.red),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar escalón'),
                    onPressed: _saving || _service == null ? null : () {
                      final last = _steps.isEmpty ? null : _steps.last;
                      final previousKm = double.tryParse(
                          last?.km.text.replaceAll(',', '.') ?? '') ?? 2;
                      final previousFare = double.tryParse(
                          last?.amount.text.replaceAll(',', '.') ?? '') ?? 4;
                      setState(() => _steps.add(_Step(
                        upToKm: previousKm + 1,
                        fare: previousFare + 1)));
                    },
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar escalones'),
                    onPressed: _saving || _service == null ? null : _save,
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
