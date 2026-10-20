import 'package:flutter/material.dart';

import 'core/supabase_client.dart';
import 'core/admin_dropdown_field.dart';

/// Admin settings are per runtime, city (zone) and service. The server returns
/// the same increments with the driver's existing dispatch RPC response.
class AdminDriverQuickOffersEditor extends StatefulWidget {
  const AdminDriverQuickOffersEditor({
    super.key,
    required this.channel,
    required this.zone,
    required this.services,
  });

  final String channel;
  final Map<String, dynamic> zone;
  final List<Map<String, dynamic>> services;

  @override
  State<AdminDriverQuickOffersEditor> createState() =>
      _AdminDriverQuickOffersEditorState();
}

class _AdminDriverQuickOffersEditorState
    extends State<AdminDriverQuickOffersEditor> {
  String _service = '*';
  String _currency = 'BOB';
  bool _configured = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _loadRevision = 0;

  final _first = TextEditingController();
  final _second = TextEditingController();
  final _third = TextEditingController();

  String get _zoneId => widget.zone['id']?.toString() ?? '';

  List<DropdownMenuItem<String>> get _serviceOptions {
    final list = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '*', child: Text('Todos los servicios de la ciudad')),
    ];
    final seen = <String>{};
    for (final service in widget.services) {
      final key = service['service_key']?.toString() ?? '';
      if (key.isEmpty || !seen.add(key)) continue;
      list.add(DropdownMenuItem(
        value: key, child: Text((service['name'] ?? key).toString()),
      ));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminDriverQuickOffersEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zone['id'] != widget.zone['id'] ||
        oldWidget.channel != widget.channel) {
      _service = '*';
      _load();
    }
  }

  @override
  void dispose() {
    _loadRevision++;
    _first.dispose();
    _second.dispose();
    _third.dispose();
    super.dispose();
  }

  static String _formatted(Object? value) {
    final number = num.tryParse(value?.toString() ?? '');
    if (number == null) return '';
    return number == number.roundToDouble()
        ? number.toStringAsFixed(0)
        : number.toStringAsFixed(2);
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await supabase.rpc('admin_driver_quick_offer_get', params: {
        'p_zone_id': _zoneId,
        'p_service_key': _service,
        'p_channel': widget.channel,
      });
      if (!mounted || revision != _loadRevision) return;
      if (raw is! Map || raw['steps'] is! List ||
          (raw['steps'] as List).length != 3) {
        throw StateError('El servidor no devolvió los tres aumentos');
      }
      final steps = raw['steps'] as List;
      setState(() {
        _first.text = _formatted(steps[0]);
        _second.text = _formatted(steps[1]);
        _third.text = _formatted(steps[2]);
        _currency = raw['currency']?.toString() ?? 'BOB';
        _configured = raw['configured'] == true;
        _loading = false;
      });
    } catch (e) {
      if (mounted && revision == _loadRevision) {
        setState(() {
          _loading = false;
          _error = 'No se pudieron cargar los aumentos: $e';
        });
      }
    }
  }

  static double? _number(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (_saving || _loading) return;
    final amounts = [_first, _second, _third]
        .map((c) => _number(c.text)).toList();
    if (amounts.any((n) => n == null || !n.isFinite) ||
        amounts[0]! <= 0 ||
        amounts[1]! <= amounts[0]! ||
        amounts[2]! <= amounts[1]!) {
      setState(() => _error =
          'Ingresa tres aumentos positivos en orden creciente.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await supabase.rpc('admin_driver_quick_offer_set', params: {
        'p_zone_id': _zoneId,
        'p_service_key': _service,
        'p_step_1': amounts[0],
        'p_step_2': amounts[1],
        'p_step_3': amounts[2],
        'p_channel': widget.channel,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Aumentos guardados. Se aplicarán a nuevas ofertas.')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudieron guardar los aumentos: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label, prefixText: '+ ',
          suffixText: _currency,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final zoneName = widget.zone['name']?.toString() ?? 'Ciudad';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_offer_outlined, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Expanded(child: Text('Aumentos rápidos del conductor',
                  style: TextStyle(fontWeight: FontWeight.w900,fontSize: 15))),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Ciudad: $zoneName · Entorno: ${widget.channel == 'preview' ? 'Prueba' : 'Producción'}. '
              'Elige una configuración para todos los servicios o selecciona '
              'uno en particular. El servicio específico tiene prioridad.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            AdminDropdownField<String>(
              key: ValueKey('quick-offer-$_zoneId-$_service-${widget.channel}'),
              isExpanded: true,
              initialValue: _service,
              decoration: const InputDecoration(labelText: 'Aplicar a'),
              items: _serviceOptions,
              onChanged: _saving ? null : (value) {
                if (value == null || value == _service) return;
                _service = value;
                _load();
              },
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else ...[
              LayoutBuilder(builder: (context, constraints) {
                final fields = [
                  _field(_first, 'Botón 1'),
                  _field(_second, 'Botón 2'),
                  _field(_third, 'Botón 3'),
                ];
                if (constraints.maxWidth < 580) {
                  return Column(children: [
                    for (final field in fields) ...[
                      field, const SizedBox(height: 9),
                    ],
                  ]);
                }
                return Row(children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(width: 9),
                    Expanded(child: fields[i]),
                  ],
                ]);
              }),
              const SizedBox(height: 9),
              Text(
                _configured
                    ? 'Configuración guardada para esta selección.'
                    : 'Valores heredados. Guárdalos para definirlos expresamente.',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Guardando…' : 'Guardar aumentos'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 9),
              Text(_error!, style: const TextStyle(
                color: Color(0xFFB42318),fontSize: 12)),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Volver a intentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
