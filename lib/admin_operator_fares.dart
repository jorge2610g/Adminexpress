import 'package:flutter/material.dart';
import 'core/supabase_client.dart';

/// Tarifas editables solo dentro de la zona asignada al operador.
class AdminOperatorFaresPage extends StatefulWidget {
  const AdminOperatorFaresPage({super.key, required this.zoneId, required this.zoneName});
  final String zoneId;
  final String zoneName;
  @override
  State<AdminOperatorFaresPage> createState() => _AdminOperatorFaresPageState();
}

class _AdminOperatorFaresPageState extends State<AdminOperatorFaresPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> fares = [];
  List<Map<String, dynamic>> services = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
      : [];

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final values = await Future.wait([
        supabase.rpc('admin_operator_fare_list', params: {'p_zone_id': widget.zoneId}),
        supabase.rpc('admin_operator_service_list'),
      ]);
      if (!mounted) return;
      setState(() {
        fares = _rows(values[0]);
        services = _rows(values[1]);
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = e.toString(); });
    }
  }

  String _name(String? key) {
    for (final row in services) {
      if (row['service_key']?.toString() == key) {
        return row['name']?.toString() ?? (key ?? 'Servicio');
      }
    }
    return key ?? 'Servicio';
  }

  Future<void> _edit([Map<String, dynamic>? fare]) async {
    if (services.isEmpty) return;
    String selected = fare?['service_key']?.toString() ??
        services.first['service_key'].toString();
    bool enabled = fare?['active'] != false;
    final fields = <String, TextEditingController>{
      'p_base_fare': TextEditingController(text: '${fare?['base_fare'] ?? 0}'),
      'p_per_km': TextEditingController(text: '${fare?['per_km'] ?? 0}'),
      'p_per_minute': TextEditingController(text: '${fare?['per_minute'] ?? 0}'),
      'p_minimum_fare': TextEditingController(text: '${fare?['minimum_fare'] ?? 0}'),
      'p_surge_multiplier': TextEditingController(text: '${fare?['surge_multiplier'] ?? 1}'),
      'p_commission_percent': TextEditingController(text: '${fare?['commission_percent'] ?? 0}'),
    };
    bool saving = false;
    final labels = <String, String>{
      'p_base_fare': 'Tarifa base',
      'p_per_km': 'Precio por kilómetro',
      'p_per_minute': 'Precio por minuto',
      'p_minimum_fare': 'Tarifa mínima',
      'p_surge_multiplier': 'Multiplicador de demanda',
      'p_commission_percent': 'Comisión (%)',
    };
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(fare == null ? 'Nueva tarifa de ${widget.zoneName}' : 'Editar tarifa de ${widget.zoneName}'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Los cambios se aplican solo a esta zona. No modifican tarifas generales.'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selected,
                    decoration: const InputDecoration(labelText: 'Servicio'),
                    items: services.map((s) => DropdownMenuItem(
                      value: s['service_key'].toString(),
                      child: Text(s['name']?.toString() ?? s['service_key'].toString()),
                    )).toList(),
                    onChanged: saving ? null : (v) { if (v != null) update(() => selected = v); },
                  ),
                  for (final entry in fields.entries) Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: entry.value,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: labels[entry.key]),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Tarifa activa'),
                    value: enabled,
                    onChanged: saving ? null : (v) => update(() => enabled = v),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
              FilledButton(
                onPressed: saving ? null : () async {
                  final numbers = <String, double>{};
                  for (final entry in fields.entries) {
                    final parsed = double.tryParse(entry.value.text.trim().replaceAll(',', '.'));
                    if (parsed == null || parsed < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Revisa ${labels[entry.key]}')));
                      return;
                    }
                    numbers[entry.key] = parsed;
                  }
                  update(() => saving = true);
                  try {
                    await supabase.rpc('admin_operator_upsert_fare_rule', params: {
                      'p_id': fare?['id'],
                      'p_zone_id': widget.zoneId,
                      'p_service_key': selected,
                      'p_active': enabled,
                      ...numbers,
                    });
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No se pudo guardar: $'+'e')));
                      update(() => saving = false);
                    }
                  }
                },
                child: Text(saving ? 'Guardando…' : 'Guardar tarifa'),
              ),
            ],
          ),
        ),
      );
      if (saved == true) await _load();
    } finally {
      for (final field in fields.values) { field.dispose(); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(18), children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tarifas de mi zona', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(widget.zoneName),
        ])),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Actualizar'),
      ]),
      const SizedBox(height: 14),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (error != null) Text('No se pudieron cargar las tarifas: $'+'error'),
      if (!loading && error == null) ...[
        FilledButton.icon(
          onPressed: services.isEmpty ? null : () => _edit(),
          icon: const Icon(Icons.add), label: const Text('Crear tarifa de zona')),
        const SizedBox(height: 12),
        if (fares.isEmpty) const Text('Todavía no hay tarifas específicas para esta zona.'),
        for (final fare in fares) Card(
          child: ListTile(
            title: Text(_name(fare['service_key']?.toString())),
            subtitle: Text('Base: ${fare['base_fare']} · Km: ${fare['per_km']} · Mínima: ${fare['minimum_fare']}'),
            trailing: IconButton(
              onPressed: () => _edit(fare),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar tarifa local'),
          ),
        ),
      ],
    ]);
  }
}
