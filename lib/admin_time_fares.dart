import 'package:flutter/material.dart';

import 'core/admin_dropdown_field.dart';
import 'core/admin_friendly_error.dart';
import 'core/admin_friendly_labels.dart';
import 'core/supabase_client.dart';

const List<String> _kDayLabels = [
  'Lun',
  'Mar',
  'Mié',
  'Jue',
  'Vie',
  'Sáb',
  'Dom',
];

/// Resume los días de una tarifa por horario: «Todos los días», «Lun a Vie»
/// o la lista de días.
String timeFareDaysLabel(List<int> days) {
  final sorted = days.toSet().toList()..sort();
  if (sorted.length == 7) return 'Todos los días';
  if (sorted.length >= 3) {
    var consecutive = true;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] != sorted[i - 1] + 1) consecutive = false;
    }
    if (consecutive) {
      return '${_kDayLabels[sorted.first - 1]} a ${_kDayLabels[sorted.last - 1]}';
    }
  }
  return sorted.map((d) => _kDayLabels[d - 1]).join(', ');
}

/// Tarifas por horario de una zona (tarifa nocturna, de madrugada, etc.).
///
/// Cada tarifa tiene nombre, franja de horas, días y precios. Dentro de la
/// franja reemplaza a la tarifa normal de la zona y el servicio; fuera de toda
/// franja se usa la tarifa normal. Solo se guarda en Producción.
class AdminTimeFaresEditor extends StatefulWidget {
  const AdminTimeFaresEditor({
    super.key,
    required this.channel,
    required this.zone,
    required this.services,
  });

  final String channel;
  final Map<String, dynamic> zone;
  final List<Map<String, dynamic>> services;

  @override
  State<AdminTimeFaresEditor> createState() => _AdminTimeFaresEditorState();
}

class _AdminTimeFaresEditorState extends State<AdminTimeFaresEditor> {
  final List<Map<String, dynamic>> _rules = <Map<String, dynamic>>[];
  String? _service;
  String? _error;
  String _timezone = 'America/La_Paz';
  bool _loading = true;
  int _revision = 0;

  bool get _isPreview => widget.channel == 'preview';

  List<String> get _services => widget.services
      .map((s) => (s['service_key'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  String get _currency => (widget.zone['currency_code'] ?? 'BOB').toString();

  @override
  void initState() {
    super.initState();
    _service = _services.isNotEmpty ? _services.first : null;
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminTimeFaresEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.zone['id']?.toString() != oldWidget.zone['id']?.toString() ||
        widget.channel != oldWidget.channel) {
      _service = _services.isNotEmpty ? _services.first : null;
      _load();
    } else if (!_services.contains(_service)) {
      _service = _services.isNotEmpty ? _services.first : null;
      _load();
    }
  }

  @override
  void dispose() {
    ++_revision;
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    final zone = widget.zone['id']?.toString();
    final service = _service;
    if (_isPreview || zone == null || service == null) {
      if (mounted) {
        setState(() {
          _rules.clear();
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await supabase.rpc('admin_fare_time_rules_list', params: {
        'p_zone_id': zone,
        'p_service_key': service,
        'p_channel': widget.channel,
      });
      if (!mounted || revision != _revision) return;
      if (raw is! Map) throw StateError('Respuesta de tarifas no válida');
      final data = Map<String, dynamic>.from(raw);
      setState(() {
        _timezone = (data['timezone'] ?? 'America/La_Paz').toString();
        _rules
          ..clear()
          ..addAll((data['rules'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e)));
        _loading = false;
      });
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() {
          _loading = false;
          _error = 'No se pudieron cargar las tarifas: ${friendlyError(error)}';
        });
      }
    }
  }

  static String _fmt(num n) =>
      n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);

  static double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  static TimeOfDay _timeOf(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final zone = widget.zone['id']?.toString();
    final service = _service;
    if (zone == null || service == null) return;

    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final base = TextEditingController(
        text: row == null ? '' : _fmt((row['base_fare'] as num?) ?? 0));
    final perKm = TextEditingController(
        text: row == null ? '' : _fmt((row['per_km'] as num?) ?? 0));
    final perMinute = TextEditingController(
        text: row == null ? '' : _fmt((row['per_minute'] as num?) ?? 0));
    final minimum = TextEditingController(
        text: row == null ? '' : _fmt((row['minimum_fare'] as num?) ?? 0));
    var start = row?['start_time']?.toString() ?? '22:00';
    var end = row?['end_time']?.toString() ?? '05:00';
    final days = <int>{
      ...((row?['days_of_week'] as List?)?.map((e) => (e as num).toInt()) ??
          [1, 2, 3, 4, 5, 6, 7]),
    };
    var active = row?['active'] != false;
    var saving = false;
    String? dialogError;

    Future<void> pickTime(
      BuildContext context,
      String current,
      void Function(String) apply,
    ) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: _timeOf(current),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        ),
      );
      if (picked != null) apply(_hhmm(picked));
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null
              ? 'Nueva tarifa por horario'
              : 'Editar tarifa por horario'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Servicio: ${friendlyService(service)} · Zona horaria: $_timezone',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Nombre (por ejemplo, Tarifa nocturna)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.nightlight_round),
                          label: Text('Desde $start'),
                          onPressed: saving
                              ? null
                              : () => pickTime(context, start,
                                  (v) => setLocal(() => start = v)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.wb_twilight_rounded),
                          label: Text('Hasta $end'),
                          onPressed: saving
                              ? null
                              : () => pickTime(
                                  context, end, (v) => setLocal(() => end = v)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Si «Hasta» es menor que «Desde», la tarifa cruza la '
                    'medianoche (por ejemplo, 22:00 a 05:00).',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(_kDayLabels[d - 1]),
                          selected: days.contains(d),
                          onSelected: saving
                              ? null
                              : (value) => setLocal(() {
                                    if (value) {
                                      days.add(d);
                                    } else {
                                      days.remove(d);
                                    }
                                  }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(base, 'Tarifa base ($_currency)')),
                      const SizedBox(width: 10),
                      Expanded(child: _field(perKm, 'Por km ($_currency)')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _field(perMinute, 'Por minuto ($_currency)')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _field(minimum, 'Tarifa mínima ($_currency)')),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged:
                        saving ? null : (v) => setLocal(() => active = v),
                    title: const Text('Tarifa activa'),
                  ),
                  if (dialogError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(dialogError!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty) {
                        setLocal(() => dialogError = 'Escribe un nombre.');
                        return;
                      }
                      if (days.isEmpty) {
                        setLocal(() =>
                            dialogError = 'Elige al menos un día de la semana.');
                        return;
                      }
                      setLocal(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        await supabase
                            .rpc('admin_fare_time_rule_upsert', params: {
                          'p_id': row?['id'],
                          'p_zone_id': zone,
                          'p_service_key': service,
                          'p_name': name.text.trim(),
                          'p_start_time': start,
                          'p_end_time': end,
                          'p_days': (days.toList()..sort()),
                          'p_base_fare': _parse(base.text) ?? 0,
                          'p_per_km': _parse(perKm.text) ?? 0,
                          'p_per_minute': _parse(perMinute.text) ?? 0,
                          'p_minimum_fare': _parse(minimum.text) ?? 0,
                          'p_active': active,
                          'p_channel': widget.channel,
                        });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        setLocal(() {
                          saving = false;
                          dialogError = friendlyError(error);
                        });
                      }
                    },
              child: Text(saving ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    base.dispose();
    perKm.dispose();
    perMinute.dispose();
    minimum.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarifa por horario guardada.')),
      );
      await _load();
    }
  }

  Widget _field(TextEditingController controller, String label) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar tarifa por horario'),
        content: Text(
            '¿Borrar «${row['name']}»? Fuera de sus horarios no cambia nada; '
            'en esos horarios se usará la tarifa normal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await supabase.rpc('admin_fare_time_rule_delete', params: {
        'p_id': row['id'],
        'p_channel': widget.channel,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarifa por horario borrada.')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo borrar: ${friendlyError(error)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.schedule_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tarifas por horario',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea tarifas con nombre para ciertas horas (por ejemplo, '
              'Tarifa nocturna o de madrugada). Dentro de su horario reemplazan '
              'a la tarifa normal de la zona; fuera de todo horario se usa la '
              'tarifa normal. La hora es la local de la zona.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            if (_isPreview)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  border: Border.all(color: const Color(0xFFF5D58A)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Las tarifas por horario se administran con una cuenta de '
                  'Producción. Preview no las modifica.',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              )
            else if (_services.isEmpty)
              const Text('No hay servicios configurados en esta zona.')
            else ...[
              AdminDropdownField<String>(
                key: ValueKey('time-fare-service-${widget.zone['id']}-$_service'),
                initialValue: _services.contains(_service) ? _service : null,
                decoration: const InputDecoration(
                  labelText: 'Servicio',
                  border: OutlineInputBorder(),
                ),
                items: _services
                    .map((service) => DropdownMenuItem(
                          value: service,
                          child: Text(friendlyService(service)),
                        ))
                    .toList(),
                onChanged: (service) {
                  if (service == null) return;
                  _service = service;
                  _load();
                },
              ),
              const SizedBox(height: 12),
              if (_loading)
                const LinearProgressIndicator()
              else ...[
                if (_rules.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                        'No hay tarifas por horario: siempre se usa la tarifa normal.'),
                  ),
                for (final rule in _rules)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE7ECF3)),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: rule['active'] == true
                            ? const Color(0xFFEAF2FF)
                            : const Color(0xFFF1F5F9),
                        child: Icon(Icons.schedule_rounded,
                            color: rule['active'] == true
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF94A3B8)),
                      ),
                      title: Text(
                        '${rule['name']}'
                        '${rule['active'] == true ? '' : ' (inactiva)'}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${rule['start_time']} a ${rule['end_time']} · '
                        '${timeFareDaysLabel((rule['days_of_week'] as List? ?? const []).map((e) => (e as num).toInt()).toList())}\n'
                        'Base ${_fmt(rule['base_fare'] as num)} · '
                        'km ${_fmt(rule['per_km'] as num)} · '
                        'min ${_fmt(rule['per_minute'] as num)} · '
                        'mínimo ${_fmt(rule['minimum_fare'] as num)} $_currency',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(rule),
                          ),
                          IconButton(
                            tooltip: 'Borrar',
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red),
                            onPressed: () => _delete(rule),
                          ),
                        ],
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nueva tarifa por horario'),
                    onPressed: _service == null ? null : () => _edit(),
                  ),
                ),
              ],
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
