import 'package:flutter/material.dart';
import 'core/supabase_client.dart';

/// Consulta de movimientos con zona comprobable; nunca muestra claves de pasarela.
class AdminOperatorPaymentsPage extends StatefulWidget {
  const AdminOperatorPaymentsPage({super.key,required this.zoneId,required this.zoneName});
  final String zoneId;
  final String zoneName;
  @override
  State<AdminOperatorPaymentsPage> createState() => _AdminOperatorPaymentsPageState();
}

class _AdminOperatorPaymentsPageState extends State<AdminOperatorPaymentsPage> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() {loading = true;error = null;});
    try {
      final result = await supabase.rpc('admin_operator_payment_overview',
        params: {'p_zone_id':widget.zoneId,'p_limit':100});
      if (!mounted) return;
      setState(() {
        data = result is Map ? Map<String,dynamic>.from(result) : {};
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {error = e.toString();loading = false;});
    }
  }

  List<Map<String,dynamic>> get transactions {
    final raw = data['recent'];
    return raw is List
      ? raw.whereType<Map>().map((r) => Map<String,dynamic>.from(r)).toList()
      : [];
  }

  @override
  Widget build(BuildContext context) {
    final totals = data['paid_by_currency'];
    return ListView(padding: const EdgeInsets.all(18),children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
          const Text('Pagos de mi zona',style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
          Text(widget.zoneName),
        ])),
        IconButton(onPressed: _load,icon: const Icon(Icons.refresh),tooltip: 'Actualizar'),
      ]),
      const SizedBox(height: 10),
      const Text('Se muestran pagos vinculados a viajes o pedidos de esta zona. '
        'Los pagos globales o sin zona verificable permanecen con la administración central.'),
      const SizedBox(height: 16),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (error != null) Text('No pudimos cargar los pagos: $error'),
      if (!loading && error == null) ...[
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
            Text('Pagos completados: ${data['paid_count'] ?? 0}',
              style: Theme.of(context).textTheme.titleMedium),
            Text('Pagos pendientes: ${data['pending_count'] ?? 0}'),
            if (totals is Map) ...[
              const SizedBox(height: 8),
              for (final entry in totals.entries) Text('Total ${entry.key}: ${entry.value}'),
            ],
          ]),
        )),
        const SizedBox(height: 16),
        Text('Últimos movimientos',style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (transactions.isEmpty) const Text('No hay movimientos con zona verificable.'),
        for (final tx in transactions) Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text('${tx['amount']} ${tx['currency']}'),
            subtitle: Text('Estado: ${tx['status']} · ${tx['created_at']}'),
            trailing: Text(tx['method']?.toString() ?? 'Pago'),
          ),
        ),
      ],
    ]);
  }
}
