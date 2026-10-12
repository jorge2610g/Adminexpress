import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

/// Updates authoritative server-side fare increments, never presentation-only prices.
class AdminFareRoundingEditor extends StatefulWidget {
  const AdminFareRoundingEditor({
    super.key,
    required this.channel,
    required this.currencyCode,
  });

  final String channel;
  final String currencyCode;

  @override
  State<AdminFareRoundingEditor> createState() =>
      _AdminFareRoundingEditorState();
}

class _AdminFareRoundingEditorState extends State<AdminFareRoundingEditor> {
  bool _loading = true;
  bool _saving = false;
  String _increment = '0.01';
  String? _error;
  int _revision = 0;

  static const Map<String, String> _increments = {
    '0.01': 'Con centavos (0,01)',
    '0.5': 'Cada 0,50',
    '1': 'Solo enteros (1,00)',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminFareRoundingEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channel != oldWidget.channel ||
        widget.currencyCode != oldWidget.currencyCode) {
      _load();
    }
  }

  String get _currency => widget.currencyCode.toUpperCase();

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await supabase.rpc('admin_fare_rounding_get', params: {
        'p_currency': _currency,
        'p_channel': widget.channel,
      });
      if (!mounted || revision != _revision) return;
      if (raw is! Map) throw StateError('Respuesta inválida del servidor');
      final value = double.tryParse(raw['increment'].toString()) ?? 0.01;
      setState(() {
        _increment = value == 1 ? '1' : value == 0.5 ? '0.5' : '0.01';
        _loading = false;
      });
    } catch (e) {
      if (mounted && revision == _revision) {
        setState(() {
          _loading = false;
          _error = 'No se pudo cargar la configuración: $e';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await supabase.rpc('admin_fare_rounding_set', params: {
        'p_currency': _currency,
        'p_increment': double.parse(_increment),
        'p_channel': widget.channel,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Redondeo guardado para viajes nuevos.'),
      ));
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = double.tryParse(_increment) ?? 0.01;
    final sample = (8.59 / step).round() * step;
    final example =
        step >= 1 ? sample.toStringAsFixed(0) : sample.toStringAsFixed(2);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.price_check_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Redondeo real de tarifas',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Moneda $_currency · ${widget.channel == 'preview' ? 'Prueba' : 'Producción'}. '
              'Se aplica al monto guardado y las ganancias, no solo a la pantalla.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final dropdown = DropdownButtonFormField<String>(
                    key: ValueKey('fare-round-$_currency-${widget.channel}'),
                    initialValue: _increment,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Incremento permitido',
                    ),
                    items: _increments.entries
                        .map((entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _increment = value);
                          },
                  );
                  final save = FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Guardando...' : 'Guardar redondeo'),
                  );
                  if (constraints.maxWidth < 480) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [dropdown, const SizedBox(height: 10), save],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: dropdown),
                      const SizedBox(width: 12),
                      save,
                    ],
                  );
                },
              ),
            const SizedBox(height: 10),
            Text(
              'Ejemplo: 8,59 $_currency → $example $_currency. '
              'Los viajes anteriores mantienen su tarifa.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            if (_error != null) ...[
              const SizedBox(height: 9),
              Text(_error!, style: const TextStyle(
                color: Color(0xFFB42318),
                fontSize: 12,
              )),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
