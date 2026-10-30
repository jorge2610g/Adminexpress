import 'package:flutter/material.dart';

import 'core/admin_friendly_error.dart';
import 'core/supabase_client.dart';

const _benefitTypes = <String, String>{
  'coupon': 'Cupones para viajes',
  'activation': 'Recompensas automáticas',
  'loyalty': 'Fidelidad',
  'referral': 'Referidos directos',
  'referral_commission': 'Comisión recurrente de referidos',
  'driver_challenge': 'Retos para conductores',
};

String _stateLabel(String state) => switch (state) {
      'draft' => 'Borrador',
      'active' => 'Activo',
      'paused' => 'Pausado',
      'closed' => 'Cerrado',
      _ => state,
    };

class AdminBenefitsPage extends StatefulWidget {
  const AdminBenefitsPage({super.key, required this.channel, required this.zoneId});
  final String channel;
  final String? zoneId;

  @override
  State<AdminBenefitsPage> createState() => _AdminBenefitsPageState();
}

class _AdminBenefitsPageState extends State<AdminBenefitsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _type = 'coupon';
  String? _id;
  String _discount = 'fixed';
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _maxDiscount = TextEditingController();
  final _minFare = TextEditingController();
  final _threshold = TextEditingController();
  bool _firstRide = false;
  bool _saving = false;

  @override
  void initState() { super.initState(); _reload(); }

  @override
  void didUpdateWidget(covariant AdminBenefitsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel || oldWidget.zoneId != widget.zoneId) {
      _clear();
      _reload();
    }
  }

  @override
  void dispose() {
    _name.dispose(); _description.dispose(); _code.dispose(); _value.dispose();
    _maxDiscount.dispose(); _minFare.dispose(); _threshold.dispose(); super.dispose();
  }

  void _reload() {
    _future = () async {
      if (widget.zoneId == null) return <Map<String, dynamic>>[];
      final raw = await supabase.rpc('admin_benefit_program_list', params: {
        'p_zone_id': widget.zoneId,
        'p_channel': widget.channel,
        'p_type': _type,
      });
      return raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    }();
  }

  void _clear() {
    _id = null; _name.clear(); _description.clear(); _code.clear(); _value.clear();
    _maxDiscount.clear(); _minFare.clear(); _threshold.clear();
    _discount = 'fixed'; _firstRide = false;
  }

  void _open(Map<String, dynamic> item) {
    final config = item['config'] is Map ? Map<String, dynamic>.from(item['config'] as Map) : <String, dynamic>{};
    setState(() {
      _id = item['id']?.toString();
      _name.text = item['name']?.toString() ?? '';
      _description.text = item['description']?.toString() ?? '';
      _code.text = config['code']?.toString() ?? '';
      _value.text = config['value']?.toString() ?? '';
      _maxDiscount.text = config['max_discount']?.toString() ?? '';
      _minFare.text = config['min_fare']?.toString() ?? '';
      _threshold.text = config['trip_threshold']?.toString() ?? '';
      _discount = config['discount_type']?.toString() ?? 'fixed';
      _firstRide = config['first_ride_only'] == true;
    });
  }

  Future<void> _save() async {
    if (_saving || widget.zoneId == null || _name.text.trim().length < 2) return;
    if (_type == 'coupon' && (double.tryParse(_value.text.trim()) ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indica un valor de descuento válido.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final config = <String, dynamic>{
        'code': _code.text.trim().toUpperCase(),
        'discount_type': _discount,
        'value': double.tryParse(_value.text.trim()),
        'max_discount': double.tryParse(_maxDiscount.text.trim()),
        'min_fare': double.tryParse(_minFare.text.trim()),
        'first_ride_only': _firstRide,
        'trip_threshold': int.tryParse(_threshold.text.trim()),
        'service_mode': 'transport',
        'reward_policy_pending': true,
      }..removeWhere((key, value) => value == null || value == '');
      await supabase.rpc('admin_benefit_program_save', params: {
        'p_id': _id,
        'p_zone_id': widget.zoneId,
        'p_channel': widget.channel,
        'p_type': _type,
        'p_name': _name.text.trim(),
        'p_description': _description.text.trim(),
        'p_config': config,
        'p_state': 'draft',
      });
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado como borrador. Los beneficios aún no afectan viajes ni pagos.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: ${friendlyError(error)}')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Widget _field(String label, TextEditingController controller, {String? hint, TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: controller, keyboardType: keyboard, decoration: InputDecoration(labelText: label, hintText: hint)),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.zoneId == null) return const Center(child: Text('Selecciona una zona para administrar beneficios.'));
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('No se pudieron cargar los programas: ${friendlyError(snapshot.error)}'));
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return ListView(padding: const EdgeInsets.all(22), children: [
          Row(children: [
            const Icon(Icons.card_giftcard_outlined, color: Color(0xFF2563EB), size: 30),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Beneficios Express', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              Text('Configura cupones, fidelidad, referidos y retos por zona.', style: TextStyle(color: Color(0xFF667085))),
            ])),
            FilledButton.icon(onPressed: () => setState(_clear), icon: const Icon(Icons.add), label: const Text('Nuevo borrador')),
          ]),
          const SizedBox(height: 14),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(
            'Los importes de premio, quién financia descuentos y qué viajes califican todavía deben definirse. Los programas se guardan como borradores y no mueven dinero.',
            style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w700),
          ))),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: _benefitTypes.entries.map((entry) => ChoiceChip(
            label: Text(entry.value), selected: _type == entry.key,
            onSelected: (_) => setState(() { _type = entry.key; _clear(); _reload(); }),
          )).toList()),
          const SizedBox(height: 14),
          Row(children: [
            Text('Programas · ${widget.channel == 'preview' ? 'PRUEBA' : 'PRODUCCIÓN'}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const Spacer(), Text('${rows.length}'),
          ]),
          Card(child: Column(children: [
            if (rows.isEmpty) const ListTile(title: Text('Aún no hay programas en esta categoría.')),
            ...rows.map((row) => ListTile(
              leading: const Icon(Icons.card_giftcard_outlined),
              title: Text(row['name']?.toString() ?? ''),
              subtitle: Text('${_stateLabel(row['state']?.toString() ?? 'draft')} · ${row['description'] ?? ''}'),
              trailing: const Icon(Icons.edit_outlined), onTap: () => _open(row),
            )),
          ])),
          const SizedBox(height: 14),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_id == null ? 'Crear ${_benefitTypes[_type]}' : 'Editar borrador', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _field('Nombre del programa', _name),
            _field('Descripción y reglas visibles', _description, hint: 'Explica elegibilidad, vigencia y condiciones'),
            if (_type == 'coupon') ...[
              _field('Código del cupón', _code, hint: 'BIENVENIDA'),
              DropdownButtonFormField<String>(initialValue: _discount, decoration: const InputDecoration(labelText: 'Tipo de descuento'), items: const [
                DropdownMenuItem(value: 'fixed', child: Text('Monto fijo')),
                DropdownMenuItem(value: 'percent', child: Text('Porcentaje')),
              ], onChanged: (value) => setState(() => _discount = value ?? 'fixed')),
              const SizedBox(height: 12),
              _field(_discount == 'percent' ? 'Porcentaje' : 'Monto (moneda de la zona)', _value, keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _field('Descuento máximo (opcional)', _maxDiscount, keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _field('Monto mínimo de viaje (opcional)', _minFare, keyboard: const TextInputType.numberWithOptions(decimal: true)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Solo primer viaje'), value: _firstRide, onChanged: (value) => setState(() => _firstRide = value)),
            ],
            if (_type == 'loyalty' || _type == 'referral' || _type == 'activation' || _type == 'driver_challenge')
              _field(_type == 'driver_challenge' ? 'Meta de viajes' : 'Viajes pagados requeridos', _threshold, keyboard: TextInputType.number),
            const SizedBox(height: 8),
            const Text('Estado: BORRADOR · Guardar conserva los datos en este entorno y zona.', style: TextStyle(color: Color(0xFF667085))),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Guardando…' : 'Guardar borrador'))),
          ]))),
        ]);
      },
    );
  }
}
