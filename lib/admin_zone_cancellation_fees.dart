import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

/// Zone-scoped cancellation fees, separated by the authenticated runtime.
/// The database defaults every unseen zone to disabled.
class AdminZoneCancellationFeesEditor extends StatefulWidget {
  const AdminZoneCancellationFeesEditor({
    super.key,
    required this.channel,
    required this.zone,
  });

  final String channel;
  final Map<String, dynamic> zone;

  @override
  State<AdminZoneCancellationFeesEditor> createState() =>
      _AdminZoneCancellationFeesEditorState();
}

class _AdminZoneCancellationFeesEditorState
    extends State<AdminZoneCancellationFeesEditor> {
  final _passenger = TextEditingController();
  final _driver = TextEditingController();
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _currency = 'BOB';
  int _revision = 0;

  String get _zoneId => widget.zone['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminZoneCancellationFeesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel ||
        oldWidget.zone['id'] != widget.zone['id']) {
      _load();
    }
  }

  @override
  void dispose() {
    _revision++;
    _passenger.dispose();
    _driver.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
      _enabled = false;
      _passenger.clear();
      _driver.clear();
    });
    try {
      final value = await supabase.rpc(
        'admin_zone_cancellation_fee_get',
        params: {'p_zone_id': _zoneId, 'p_channel': widget.channel},
      );
      if (!mounted || revision != _revision) return;
      if (value is! Map) {
        throw StateError('Respuesta de configuración inválida');
      }
      setState(() {
        _enabled = value['enabled'] == true;
        _passenger.text = _format(value['passenger_fee']);
        _driver.text = _format(value['driver_fee']);
        _currency = value['currency']?.toString() ?? 'BOB';
        _loading = false;
      });
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() {
          _loading = false;
          _error = 'No se pudo cargar la configuración: $error';
        });
      }
    }
  }

  String _format(Object? value) {
    final amount = double.tryParse(value?.toString() ?? '');
    if (amount == null) return '0';
    return amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    final passenger = double.tryParse(
      _passenger.text.trim().replaceAll(',', '.'),
    );
    final driver = double.tryParse(_driver.text.trim().replaceAll(',', '.'));
    if (passenger == null ||
        driver == null ||
        !passenger.isFinite ||
        !driver.isFinite ||
        passenger < 0 ||
        driver < 0 ||
        passenger > 5000 ||
        driver > 5000 ||
        (_currency.toUpperCase() == 'CLP' &&
            (passenger != passenger.roundToDouble() ||
                driver != driver.roundToDouble())) ||
        (_enabled && ((passenger > 0 && passenger < 1) || (driver > 0 && driver < 1)))) {
      setState(() => _error =
          'Usa montos entre 1 y 5.000 (o cero para no cobrar).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await supabase.rpc(
        'admin_zone_cancellation_fee_set',
        params: {
          'p_zone_id': _zoneId,
          'p_enabled': _enabled,
          'p_passenger_fee': passenger,
          'p_driver_fee': driver,
          'p_channel': widget.channel,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _enabled
                ? 'Cobros guardados para nuevas cancelaciones en esta zona.'
                : 'Cobros de cancelación apagados en esta zona.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudo guardar: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _amountField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        enabled: !_loading && !_saving && _error == null,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: _currency),
      );

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone['name']?.toString() ?? 'Zona';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.money_off_csred_outlined, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cobro por cancelación',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Zona: $zone · Entorno: ${widget.channel == 'preview' ? 'Prueba' : 'Producción'}. '
              'La tarifa se aplica solo al cancelar un viaje aceptado dentro del plazo de espera.',
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                title: const Text('Activar cobros en esta zona'),
                subtitle: const Text(
                  'Todas las zonas nuevas comienzan apagadas.',
                ),
                onChanged: _saving || _error != null
                    ? null
                    : (value) => setState(() => _enabled = value),
              ),
              Row(
                children: [
                  Expanded(child: _amountField(_passenger, 'Pasajero')),
                  const SizedBox(width: 12),
                  Expanded(child: _amountField(_driver, 'Conductor')),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Pasajero: se cobra si cancela antes de que el conductor llegue dentro de 5 minutos. '
                'Conductor: se cobra si cancela antes de esperar 5 minutos desde “Ya llegué”.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving || _loading || _error != null ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar cobros'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
