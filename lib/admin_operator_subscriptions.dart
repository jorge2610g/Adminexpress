import 'package:flutter/material.dart';
import 'core/supabase_client.dart';

/// Planes, montos y recibos de suscripción de una sola zona.
class AdminOperatorSubscriptionsPage extends StatefulWidget {
  const AdminOperatorSubscriptionsPage({super.key, required this.zoneId, required this.zoneName, this.readOnly = false});
  final String zoneId;
  final String zoneName;
  final bool readOnly;
  @override
  State<AdminOperatorSubscriptionsPage> createState() => _AdminOperatorSubscriptionsPageState();
}

class _AdminOperatorSubscriptionsPageState extends State<AdminOperatorSubscriptionsPage> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList()
      : [];

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final value = await supabase.rpc(
        'admin_operator_subscription_overview',
        params: {'p_zone_id': widget.zoneId},
      );
      if (!mounted) return;
      setState(() {
        data = value is Map ? Map<String, dynamic>.from(value) : {};
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> _edit([Map<String, dynamic>? plan]) async {
    if (widget.readOnly) return;
    final code = TextEditingController(text: plan?['code']?.toString() ?? '');
    final name = TextEditingController(text: plan?['name']?.toString() ?? '');
    final price = TextEditingController(text: plan?['amount']?.toString() ?? '0');
    final days = TextEditingController(text: plan?['days']?.toString() ?? '30');
    bool active = plan?['active'] != false;
    bool saving = false;
    try {
      final success = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(plan == null ? 'Nuevo plan de ${widget.zoneName}' : 'Editar plan de ${widget.zoneName}'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Solo cambia el plan de tu zona. La moneda proviene de su configuración.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: code, decoration: const InputDecoration(labelText: 'Código del plan'),
                    enabled: !saving,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: name, decoration: const InputDecoration(labelText: 'Nombre'),
                    enabled: !saving,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: price,
                    decoration: InputDecoration(labelText: 'Monto (${data['currency_code'] ?? ''})'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !saving,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: days, decoration: const InputDecoration(labelText: 'Duración en días'),
                    keyboardType: TextInputType.number, enabled: !saving,
                  ),
                  SwitchListTile(
                    title: const Text('Plan activo'),value: active,
                    onChanged: saving ? null : (value) => update(() => active = value),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
              FilledButton(
                onPressed: saving ? null : () async {
                  final amount = double.tryParse(price.text.trim().replaceAll(',', '.'));
                  final duration = int.tryParse(days.text.trim());
                  if (amount == null || amount < 0 || duration == null || duration < 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Revisa el monto y la duración.')));
                    return;
                  }
                  update(() => saving = true);
                  try {
                    await supabase.rpc('admin_operator_upsert_subscription_plan', params: {
                      'p_id': plan?['id'], 'p_zone_id': widget.zoneId,
                      'p_code': code.text.trim(), 'p_name': name.text.trim(),
                      'p_amount': amount, 'p_days': duration,
                      'p_benefits': plan?['benefits'] is List ? plan!['benefits'] : [],
                      'p_active': active, 'p_sort_order': plan?['sort_order'] ?? 100,
                    });
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al guardar el plan: $e')));
                      update(() => saving = false);
                    }
                  }
                },
                child: Text(saving ? 'Guardando…' : 'Guardar plan'),
              ),
            ],
          ),
        ),
      );
      if (success == true) await _load();
    } finally {
      code.dispose(); name.dispose(); price.dispose(); days.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _rows(data['plans']);
    final payments = _rows(data['payments']);
    final currency = data['currency_code']?.toString() ?? '';
    return ListView(padding: const EdgeInsets.all(18), children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
          const Text('Suscripciones de mi zona', style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
          Text(widget.zoneName),
        ])),
        IconButton(onPressed: _load,icon: const Icon(Icons.refresh),tooltip: 'Actualizar'),
      ]),
      const SizedBox(height: 16),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (error != null) Text('No se pudieron cargar las suscripciones: $error'),
      if (!loading && error == null) ...[
        FilledButton.icon(onPressed: widget.readOnly ? null : () => _edit(),
          icon: const Icon(Icons.add), label: const Text('Crear plan de mi zona')),
        const SizedBox(height: 12),
        Text('Planes y montos', style: Theme.of(context).textTheme.titleMedium),
        if (plans.isEmpty) const Text('No hay planes locales configurados.'),
        for (final plan in plans) Card(
          child: ListTile(
            title: Text(plan['name']?.toString() ?? 'Plan'),
            subtitle: Text('${plan['amount']} $currency · ${plan['days']} días · ${plan['active'] == false ? 'Inactivo' : 'Activo'}'),
            trailing: IconButton(icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar plan de zona', onPressed: widget.readOnly ? null : () => _edit(plan)),
          ),
        ),
        const SizedBox(height: 20),
        Text('Últimos pagos de suscripción',style: Theme.of(context).textTheme.titleMedium),
        const Text('Consulta únicamente. Las credenciales y los fondos globales se administran por separado.'),
        if (payments.isEmpty) const Text('No hay movimientos de suscripción en la zona.'),
        for (final payment in payments) Card(
          child: ListTile(
            title: Text('${payment['amount']} ${payment['currency_code'] ?? currency}'),
            subtitle: Text('Estado: ${payment['status']} · ${payment['created_at']}'),
            leading: const Icon(Icons.receipt_long_outlined),
          ),
        ),
      ],
    ]);
  }
}
