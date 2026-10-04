import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const _blue = Color(0xFF2563EB);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _bg = Color(0xFFF1F5F9);

class AdminMarketplacePhase2Page extends StatefulWidget {
  final bool ordersOnly;
  final String channel;

  const AdminMarketplacePhase2Page({
    super.key,
    this.ordersOnly = false,
    this.channel = 'preview',
  });

  @override
  State<AdminMarketplacePhase2Page> createState() =>
      _AdminMarketplacePhase2PageState();
}

class _AdminMarketplacePhase2PageState
    extends State<AdminMarketplacePhase2Page> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final value = await supabase.rpc('admin_marketplace_phase2_state');
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  void _refresh() {
    setState(() => future = _load());
  }

  List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(Object? value, String currency) {
    final amount = _number(value);
    if (currency == 'CLP') {
      final raw = amount.round().toString();
      final grouped = raw.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      );
      return 'CLP ' + grouped;
    }
    return currency + ' ' + amount.toStringAsFixed(2);
  }

  Future<void> _editZone(Map<String, dynamic> row) async {
    final customerBase =
        TextEditingController(text: row['customer_base_fee']?.toString() ?? '0');
    final customerKm =
        TextEditingController(text: row['customer_per_km']?.toString() ?? '0');
    final customerMin =
        TextEditingController(text: row['customer_min_fee']?.toString() ?? '0');
    final driverBase = TextEditingController(
      text: row['driver_base_payout']?.toString() ?? '0',
    );
    final driverKm =
        TextEditingController(text: row['driver_per_km']?.toString() ?? '0');
    final driverMin = TextEditingController(
      text: row['driver_min_payout']?.toString() ?? '0',
    );
    final priorityFee = TextEditingController(
      text: row['priority_customer_fee']?.toString() ?? '0',
    );
    final priorityBonus = TextEditingController(
      text: row['priority_driver_bonus']?.toString() ?? '0',
    );

    var preview = row['preview_enabled'] == true;
    var production = row['production_enabled'] == true;
    var priority = row['priority_enabled'] == true;
    var tips = row['tips_enabled'] == true;
    var cash = row['cash_enabled'] == true;
    var transfer = row['transfer_enabled'] == true;
    var online = row['online_enabled'] == true;
    var plus = row['plus_enabled'] == true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            'Delivery · ' + (row['zone_name']?.toString() ?? 'Zona'),
          ),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tarifa que paga el cliente',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customerBase,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Base cliente',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: customerKm,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Por km cliente',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: customerMin,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Mínimo cliente',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Pago independiente al repartidor',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: driverBase,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Base repartidor',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: driverKm,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Por km repartidor',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: driverMin,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Mínimo repartidor',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Envío Plus · prioridad',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priorityFee,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Recargo al cliente',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: priorityBonus,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Bono al repartidor',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: priority,
                    onChanged: (v) => setLocal(() => priority = v),
                    title: const Text('Habilitar Envío Plus prioritario'),
                  ),
                  SwitchListTile.adaptive(
                    value: tips,
                    onChanged: (v) => setLocal(() => tips = v),
                    title: const Text('Permitir propinas'),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    value: cash,
                    onChanged: (v) => setLocal(() => cash = v),
                    title: const Text('Efectivo'),
                  ),
                  SwitchListTile.adaptive(
                    value: transfer,
                    onChanged: (v) => setLocal(() => transfer = v),
                    title: const Text('Transferencia al comercio'),
                    subtitle: const Text(
                      'Requiere comprobante y aprobación del comercio.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    value: online,
                    onChanged: (v) => setLocal(() => online = v),
                    title: const Text('Tarjeta / Mercado Pago'),
                  ),
                  SwitchListTile.adaptive(
                    value: plus,
                    onChanged: (v) => setLocal(() => plus = v),
                    title: const Text('Suscripción Express Plus clientes'),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    value: preview,
                    onChanged: (v) => setLocal(() => preview = v),
                    title: const Text('Delivery Fase 2 en Preview'),
                  ),
                  SwitchListTile.adaptive(
                    value: production,
                    onChanged: (v) => setLocal(() => production = v),
                    title: const Text('Delivery Fase 2 en Producción'),
                    subtitle: const Text(
                      'Mantener apagado hasta aprobación final.',
                    ),
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

    if (save == true) {
      await supabase.rpc(
        'admin_marketplace_update_zone_phase2',
        params: {
          'p_zone_id': row['zone_id'],
          'p_preview_enabled': preview,
          'p_production_enabled': production,
          'p_customer_base_fee':
              double.tryParse(customerBase.text.trim()) ?? 0,
          'p_customer_per_km':
              double.tryParse(customerKm.text.trim()) ?? 0,
          'p_customer_min_fee':
              double.tryParse(customerMin.text.trim()) ?? 0,
          'p_driver_base_payout':
              double.tryParse(driverBase.text.trim()) ?? 0,
          'p_driver_per_km':
              double.tryParse(driverKm.text.trim()) ?? 0,
          'p_driver_min_payout':
              double.tryParse(driverMin.text.trim()) ?? 0,
          'p_priority_enabled': priority,
          'p_priority_customer_fee':
              double.tryParse(priorityFee.text.trim()) ?? 0,
          'p_priority_driver_bonus':
              double.tryParse(priorityBonus.text.trim()) ?? 0,
          'p_tips_enabled': tips,
          'p_cash_enabled': cash,
          'p_transfer_enabled': transfer,
          'p_online_enabled': online,
          'p_plus_enabled': plus,
        },
      );
      if (mounted) _refresh();
    }

    customerBase.dispose();
    customerKm.dispose();
    customerMin.dispose();
    driverBase.dispose();
    driverKm.dispose();
    driverMin.dispose();
    priorityFee.dispose();
    priorityBonus.dispose();
  }

  Future<void> _editPlan(Map<String, dynamic> row) async {
    final name = TextEditingController(
      text: row['name']?.toString() ?? 'Express Plus',
    );
    final price = TextEditingController(
      text: row['monthly_price']?.toString() ?? '0',
    );
    final discount = TextEditingController(
      text: row['default_discount_percent']?.toString() ?? '0',
    );
    final priority = TextEditingController(
      text: row['included_priority_deliveries']?.toString() ?? '0',
    );
    final description = TextEditingController(
      text: row['description']?.toString() ?? '',
    );

    var active = row['active'] == true;
    var preview = row['preview_visible'] != false;
    var production = row['production_visible'] == true;
    var freeDelivery = row['free_delivery'] == true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            'Express Plus · ' + (row['zone_name']?.toString() ?? ''),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio mensual',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: discount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Descuento general %',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priority,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Envíos prioritarios incluidos / mes',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    value: freeDelivery,
                    onChanged: (v) => setLocal(() => freeDelivery = v),
                    title: const Text('Envío gratis'),
                  ),
                  SwitchListTile.adaptive(
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                    title: const Text('Plan activo'),
                  ),
                  SwitchListTile.adaptive(
                    value: preview,
                    onChanged: (v) => setLocal(() => preview = v),
                    title: const Text('Visible Preview'),
                  ),
                  SwitchListTile.adaptive(
                    value: production,
                    onChanged: (v) => setLocal(() => production = v),
                    title: const Text('Visible Producción'),
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

    if (save == true) {
      final monthlyPrice = double.tryParse(price.text.trim()) ?? 0;
      if (active && monthlyPrice <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Define un precio mensual mayor a 0 antes de activar Express Plus.',
              ),
            ),
          );
        }
        name.dispose();
        price.dispose();
        discount.dispose();
        priority.dispose();
        description.dispose();
        return;
      }

      await supabase.rpc(
        'admin_marketplace_upsert_plus_plan',
        params: {
          'p_id': row['id'],
          'p_zone_id': row['zone_id'],
          'p_name': name.text.trim(),
          'p_monthly_price': monthlyPrice,
          'p_active': active,
          'p_preview_visible': preview,
          'p_production_visible': production,
          'p_free_delivery': freeDelivery,
          'p_included_priority_deliveries':
              int.tryParse(priority.text.trim()) ?? 0,
          'p_default_discount_percent':
              double.tryParse(discount.text.trim()) ?? 0,
          'p_description': description.text.trim(),
        },
      );
      if (mounted) _refresh();
    }

    name.dispose();
    price.dispose();
    discount.dispose();
    priority.dispose();
    description.dispose();
  }

  Future<void> _editBenefit(
    Map<String, dynamic> merchant,
    Map<String, dynamic>? current,
  ) async {
    final discount = TextEditingController(
      text: current?['discount_percent']?.toString() ?? '0',
    );
    var enabled = current?['enabled'] == true;
    var freeDelivery = current?['free_delivery'] == true;
    var exclusive = current?['exclusive_promo'] == true;
    var fundedBy = current?['funded_by']?.toString() ?? 'express';

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            'Plus · ' + (merchant['name']?.toString() ?? 'Comercio'),
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: discount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Descuento exclusivo %',
                  ),
                ),
                SwitchListTile.adaptive(
                  value: freeDelivery,
                  onChanged: (v) => setLocal(() => freeDelivery = v),
                  title: const Text('Envío gratis para Plus'),
                ),
                SwitchListTile.adaptive(
                  value: exclusive,
                  onChanged: (v) => setLocal(() => exclusive = v),
                  title: const Text('Promoción exclusiva Plus'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: fundedBy,
                  decoration: const InputDecoration(
                    labelText: 'Quién financia el descuento',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'express',
                      child: Text('Express'),
                    ),
                    DropdownMenuItem(
                      value: 'merchant',
                      child: Text('Comercio'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => fundedBy = v);
                  },
                ),
                SwitchListTile.adaptive(
                  value: enabled,
                  onChanged: (v) => setLocal(() => enabled = v),
                  title: const Text('Beneficio activo'),
                ),
              ],
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

    if (save == true) {
      await supabase.rpc(
        'admin_marketplace_set_plus_merchant_benefit',
        params: {
          'p_merchant_id': merchant['id'],
          'p_enabled': enabled,
          'p_discount_percent':
              double.tryParse(discount.text.trim()) ?? 0,
          'p_free_delivery': freeDelivery,
          'p_exclusive_promo': exclusive,
          'p_funded_by': fundedBy,
        },
      );
      if (mounted) _refresh();
    }

    discount.dispose();
  }

  Future<void> _editMerchantLogistics(
    Map<String, dynamic> merchant,
  ) async {
    final detail = await supabase.rpc(
      'admin_marketplace_merchant_detail',
      params: {'p_merchant_id': merchant['id']},
    );
    final map = detail is Map
        ? Map<String, dynamic>.from(detail)
        : <String, dynamic>{};
    final row = map['merchant'] is Map
        ? Map<String, dynamic>.from(map['merchant'] as Map)
        : merchant;

    if (!mounted) return;

    final address = TextEditingController(
      text: row['address']?.toString() ?? '',
    );
    final latitude = TextEditingController(
      text: row['latitude']?.toString() ?? '',
    );
    final longitude = TextEditingController(
      text: row['longitude']?.toString() ?? '',
    );
    final transfer = TextEditingController(
      text: row['transfer_instructions']?.toString() ?? '',
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Logística · ' + (merchant['name']?.toString() ?? ''),
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: address,
                  decoration: const InputDecoration(
                    labelText: 'Dirección del comercio',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latitude,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Latitud',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: longitude,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Longitud',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: transfer,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Datos/instrucciones de transferencia',
                    hintText:
                        'Banco, tipo de cuenta, titular, RUT/CI, correo, etc.',
                  ),
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
    );

    if (save == true) {
      await supabase.rpc(
        'admin_marketplace_update_merchant_logistics',
        params: {
          'p_merchant_id': merchant['id'],
          'p_address': address.text.trim(),
          'p_latitude': double.tryParse(latitude.text.trim()),
          'p_longitude': double.tryParse(longitude.text.trim()),
          'p_transfer_instructions': transfer.text.trim(),
        },
      );
      if (mounted) _refresh();
    }

    address.dispose();
    latitude.dispose();
    longitude.dispose();
    transfer.dispose();
  }

  Future<void> _manageMerchantUsers(
    Map<String, dynamic> merchant,
  ) async {
    final email = TextEditingController();

    Future<List<Map<String, dynamic>>> loadUsers() async {
      final value = await supabase.rpc(
        'admin_marketplace_merchant_users',
        params: {'p_merchant_id': merchant['id']},
      );
      return _rows(value);
    }

    var users = await loadUsers();
    if (!mounted) {
      email.dispose();
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> assign() async {
            final value = email.text.trim();
            if (value.isEmpty) return;
            await supabase.rpc(
              'admin_marketplace_assign_merchant_user',
              params: {
                'p_merchant_id': merchant['id'],
                'p_email': value,
                'p_role': 'manager',
              },
            );
            email.clear();
            users = await loadUsers();
            setLocal(() {});
          }

          Future<void> toggle(
            Map<String, dynamic> row,
            bool active,
          ) async {
            await supabase.rpc(
              'admin_marketplace_set_merchant_user_active',
              params: {
                'p_merchant_id': merchant['id'],
                'p_user_id': row['user_id'],
                'p_active': active,
              },
            );
            users = await loadUsers();
            setLocal(() {});
          }

          return AlertDialog(
            title: Text(
              'Accesos · ' +
                  (merchant['name']?.toString() ?? 'Comercio'),
            ),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText:
                            'Correo de la cuenta Express del comercio',
                        suffixIcon: IconButton(
                          tooltip: 'Vincular',
                          onPressed: assign,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (users.isEmpty)
                      const ListTile(
                        leading: Icon(Icons.info_outline_rounded),
                        title: Text(
                          'Todavía no hay cuentas vinculadas.',
                        ),
                        subtitle: Text(
                          'La persona debe tener una cuenta Express con ese correo.',
                        ),
                      )
                    else
                      ...users.map(
                        (row) => SwitchListTile.adaptive(
                          value: row['active'] == true,
                          onChanged: (value) => toggle(row, value),
                          title: Text(
                            row['full_name']?.toString().trim().isNotEmpty ==
                                    true
                                ? row['full_name'].toString()
                                : row['email']?.toString() ?? 'Usuario',
                          ),
                          subtitle: Text(
                            (row['email']?.toString() ?? '') +
                                ' · ' +
                                (row['role']?.toString() ?? 'manager'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );

    email.dispose();
  }

  Future<void> _openOrder(Map<String, dynamic> order) async {
    var detail = await supabase.rpc(
      'marketplace_order_detail',
      params: {'p_order_id': order['id']},
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          final map = detail is Map
              ? Map<String, dynamic>.from(detail)
              : <String, dynamic>{};
          final orderRow = map['order'] is Map
              ? Map<String, dynamic>.from(map['order'] as Map)
              : order;
          final financials = map['financials'] is Map
              ? Map<String, dynamic>.from(map['financials'] as Map)
              : <String, dynamic>{};
          final messages = _rows(map['messages']);
          final currency =
              orderRow['currency_code']?.toString() ?? 'CLP';
          final canReview = orderRow['payment_method'] == 'transfer' &&
              orderRow['payment_status'] == 'under_review';

          Future<void> review(bool approve) async {
            detail = await supabase.rpc(
              'marketplace_review_transfer',
              params: {
                'p_order_id': orderRow['id'],
                'p_approve': approve,
                'p_note': approve
                    ? 'Transferencia aprobada por el comercio/administración.'
                    : 'Comprobante rechazado. Envía uno nuevo.',
              },
            );
            setLocal(() {});
            _refresh();
          }

          Future<void> setOrderStatus(String status) async {
            detail = await supabase.rpc(
              'marketplace_order_set_status',
              params: {
                'p_order_id': orderRow['id'],
                'p_status': status,
              },
            );
            setLocal(() {});
            _refresh();
          }

          Future<void> markDriverPaid() async {
            detail = await supabase.rpc(
              'marketplace_mark_driver_paid',
              params: {
                'p_order_id': orderRow['id'],
                'p_note':
                    'Comercio confirmó que entregó la tarifa y propina al repartidor.',
              },
            );
            setLocal(() {});
            _refresh();
          }

          Future<void> settle(
            String balanceKey,
            String label,
          ) async {
            detail = await supabase.rpc(
              'marketplace_settle_balance',
              params: {
                'p_order_id': orderRow['id'],
                'p_balance_key': balanceKey,
                'p_note': 'Liquidación confirmada: ' + label + '.',
              },
            );
            setLocal(() {});
            _refresh();
          }

          return AlertDialog(
            title: Text(
              'Pedido · ' +
                  (orderRow['id']?.toString().substring(0, 8) ?? ''),
            ),
            content: SizedBox(
              width: 720,
              height: 620,
              child: ListView(
                children: [
                  Text(
                    'Estado: ' +
                        (orderRow['status']?.toString() ?? '') +
                        ' · Pago: ' +
                        (orderRow['payment_status']?.toString() ?? ''),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          _financialRow(
                            'Total cliente',
                            financials['customer_total'],
                            currency,
                          ),
                          _financialRow(
                            'Productos comercio',
                            financials['merchant_products_amount'],
                            currency,
                          ),
                          _financialRow(
                            'Pago repartidor',
                            financials['driver_payout'],
                            currency,
                          ),
                          _financialRow(
                            'Propina',
                            financials['driver_tip'],
                            currency,
                          ),
                          _financialRow(
                            'Margen Express',
                            financials['express_margin'],
                            currency,
                          ),
                          const Divider(),
                          _financialRow(
                            'Comercio debe al repartidor',
                            financials['merchant_owes_driver'],
                            currency,
                          ),
                          _financialRow(
                            'Comercio debe a Express',
                            financials['merchant_owes_express'],
                            currency,
                          ),
                          _financialRow(
                            'Repartidor debe al comercio',
                            financials['driver_owes_merchant'],
                            currency,
                          ),
                          _financialRow(
                            'Repartidor debe a Express',
                            financials['driver_owes_express'],
                            currency,
                          ),
                          _financialRow(
                            'Express debe al comercio',
                            financials['express_owes_merchant'],
                            currency,
                          ),
                          _financialRow(
                            'Express debe al repartidor',
                            financials['express_owes_driver'],
                            currency,
                          ),
                          const Divider(),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Liquidación: ' +
                                  (financials['settlement_status']?.toString() ??
                                      'pending'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_number(financials['merchant_owes_express']) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => settle(
                          'merchant_owes_express',
                          'Comercio → Express',
                        ),
                        icon: const Icon(Icons.account_balance_rounded),
                        label: const Text(
                          'Cerrar saldo Comercio → Express',
                        ),
                      ),
                    ),
                  if (_number(financials['driver_owes_merchant']) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => settle(
                          'driver_owes_merchant',
                          'Repartidor → comercio',
                        ),
                        icon: const Icon(Icons.storefront_rounded),
                        label: const Text(
                          'Cerrar saldo Repartidor → comercio',
                        ),
                      ),
                    ),
                  if (_number(financials['driver_owes_express']) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => settle(
                          'driver_owes_express',
                          'Repartidor → Express',
                        ),
                        icon: const Icon(Icons.account_balance_wallet_rounded),
                        label: const Text(
                          'Cerrar saldo Repartidor → Express',
                        ),
                      ),
                    ),
                  if (_number(financials['express_owes_merchant']) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => settle(
                          'express_owes_merchant',
                          'Express → comercio',
                        ),
                        icon: const Icon(Icons.store_mall_directory_rounded),
                        label: const Text(
                          'Cerrar saldo Express → comercio',
                        ),
                      ),
                    ),
                  if (_number(financials['express_owes_driver']) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => settle(
                          'express_owes_driver',
                          'Express → repartidor',
                        ),
                        icon: const Icon(Icons.delivery_dining_rounded),
                        label: const Text(
                          'Cerrar saldo Express → repartidor',
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chat / comprobantes',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  ...messages.map(
                    (message) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(
                        message['body']?.toString() ??
                            message['attachment_url']?.toString() ??
                            '',
                      ),
                      subtitle: Text(
                        (message['sender_role']?.toString() ?? '') +
                            ' · ' +
                            (message['message_type']?.toString() ?? ''),
                      ),
                    ),
                  ),
                  if (canReview) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => review(false),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Rechazar comprobante'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => review(true),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Aprobar transferencia'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (orderRow['status'] == 'pending' &&
                      orderRow['payment_method'] == 'cash') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => setOrderStatus('confirmed'),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Confirmar pedido en efectivo'),
                      ),
                    ),
                  ],
                  if (orderRow['status'] == 'confirmed') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => setOrderStatus('preparing'),
                        icon: const Icon(Icons.soup_kitchen_outlined),
                        label: const Text('Pasar a preparación'),
                      ),
                    ),
                  ],
                  if (orderRow['status'] == 'preparing') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => setOrderStatus('ready'),
                        icon: const Icon(Icons.delivery_dining_rounded),
                        label: const Text(
                          'Listo · buscar repartidor',
                        ),
                      ),
                    ),
                  ],
                  if (_number(financials['merchant_owes_driver']) > 0 &&
                      orderRow['assigned_driver_id'] != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: markDriverPaid,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text(
                          'Confirmar pago al repartidor',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _financialRow(
    String label,
    Object? value,
    String currency,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            _money(value, currency),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFE8F8EF)
            : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFF14804A) : _muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _moduleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String countLabel,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFEAF2FF),
                child: Icon(icon, color: _blue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    countLabel,
                    style: const TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Icon(Icons.open_in_new_rounded, size: 18, color: _muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showZonesModule(
    List<Map<String, dynamic>> zones,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tarifas Delivery por zona'),
        content: SizedBox(
          width: 820,
          height: 560,
          child: zones.isEmpty
              ? const Center(child: Text('Todavía no hay zonas configuradas.'))
              : ListView.separated(
                  itemCount: zones.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = zones[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.delivery_dining_rounded),
                        ),
                        title: Text(
                          row['zone_name']?.toString() ?? 'Zona',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          'Cliente: ' +
                              _money(
                                row['customer_base_fee'],
                                row['currency_code']?.toString() ?? '',
                              ) +
                              ' base · Repartidor: ' +
                              _money(
                                row['driver_base_payout'],
                                row['currency_code']?.toString() ?? '',
                              ) +
                              ' base',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editZone(row),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPlansModule(
    List<Map<String, dynamic>> plans,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Express Plus · planes'),
        content: SizedBox(
          width: 760,
          height: 520,
          child: plans.isEmpty
              ? const Center(child: Text('Todavía no hay planes configurados.'))
              : ListView.separated(
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = plans[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.bolt_rounded),
                        ),
                        title: Text(
                          (row['name']?.toString() ?? 'Express Plus') +
                              ' · ' +
                              (row['zone_name']?.toString() ?? ''),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          _money(
                                row['monthly_price'],
                                row['currency_code']?.toString() ?? '',
                              ) +
                              ' / mes',
                        ),
                        trailing: _badge('Activo', row['active'] == true),
                        onTap: () => _editPlan(row),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMerchantsModule(
    List<Map<String, dynamic>> merchants,
    Map<String, Map<String, dynamic>> benefitsByMerchant,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Locales · beneficios y logística'),
        content: SizedBox(
          width: 840,
          height: 560,
          child: merchants.isEmpty
              ? const Center(child: Text('Todavía no hay locales configurados.'))
              : ListView.separated(
                  itemCount: merchants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final merchant = merchants[index];
                    final benefit =
                        benefitsByMerchant[merchant['id'].toString()];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.storefront_rounded),
                        ),
                        title: Text(
                          merchant['name']?.toString() ?? 'Comercio',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          merchant['zone_key']?.toString() ?? '',
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Administrar local',
                          onSelected: (value) {
                            if (value == 'plus') {
                              _editBenefit(merchant, benefit);
                            } else if (value == 'access') {
                              _manageMerchantUsers(merchant);
                            } else {
                              _editMerchantLogistics(merchant);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'plus',
                              child: Text('Beneficios Express Plus'),
                            ),
                            PopupMenuItem(
                              value: 'logistics',
                              child: Text('Ubicación / transferencia'),
                            ),
                            PopupMenuItem(
                              value: 'access',
                              child: Text('Usuarios del local'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _ordersView(List<Map<String, dynamic>> orders) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.channel == 'preview'
                        ? 'Pedidos Delivery · Prueba'
                        : 'Pedidos Delivery · Producción',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Pedidos recientes, estados, pagos, comisiones y liquidaciones.',
                    style: TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualizar'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (orders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Todavía no hay pedidos Delivery.'),
            ),
          )
        else
          ...orders.map(
            (row) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  row['payment_method'] == 'transfer'
                      ? Icons.account_balance_rounded
                      : row['payment_method'] == 'cash'
                          ? Icons.payments_outlined
                          : Icons.credit_card_rounded,
                ),
                title: Text(
                  row['merchant_name']?.toString() ?? 'Pedido',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  (row['zone_key']?.toString() ?? '') +
                      ' · ' +
                      (row['status']?.toString() ?? '') +
                      ' · ' +
                      (row['payment_status']?.toString() ?? ''),
                ),
                trailing: Text(
                  _money(
                    row['total_amount'],
                    row['currency_code']?.toString() ?? '',
                  ),
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                onTap: () => _openOrder(row),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(snapshot.error.toString()),
              ),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final zones = _rows(data['zones']);
          final plans = _rows(data['plus_plans']);
          final benefits = _rows(data['benefits']);
          final merchants = _rows(data['merchants']);
          final orders = _rows(data['recent_orders'])
              .where(
                (row) =>
                    (row['channel']?.toString() ?? 'production') ==
                    widget.channel,
              )
              .toList();

          final benefitsByMerchant = <String, Map<String, dynamic>>{
            for (final row in benefits)
              row['merchant_id'].toString(): row,
          };

          if (widget.ordersOnly) {
            return _ordersView(orders);
          }

          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery · Configuración',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Cada bloque abre su propia administración para mantener el panel compacto.',
                          style: TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1050
                      ? 3
                      : constraints.maxWidth >= 680
                          ? 2
                          : 1;
                  final gap = 12.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;

                  final cards = [
                    SizedBox(
                      width: width,
                      child: _moduleCard(
                        icon: Icons.delivery_dining_rounded,
                        title: 'Tarifas por zona',
                        subtitle:
                            'Tarifa cliente, pago repartidor, métodos y activación por ciudad.',
                        countLabel: zones.length.toString() + ' zonas',
                        onTap: () => _showZonesModule(zones),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _moduleCard(
                        icon: Icons.bolt_rounded,
                        title: 'Express Plus',
                        subtitle:
                            'Planes mensuales, precio, descuentos y beneficios incluidos.',
                        countLabel: plans.length.toString() + ' planes',
                        onTap: () => _showPlansModule(plans),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _moduleCard(
                        icon: Icons.storefront_rounded,
                        title: 'Locales y beneficios',
                        subtitle:
                            'Logística, beneficios Plus y usuarios autorizados por comercio.',
                        countLabel: merchants.length.toString() + ' locales',
                        onTap: () =>
                            _showMerchantsModule(merchants, benefitsByMerchant),
                      ),
                    ),
                  ];

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: cards,
                  );
                },
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFEAF2FF),
                        child: Icon(Icons.receipt_long_rounded, color: _blue),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pedidos fuera de esta pantalla',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Los pedidos ahora tienen acceso propio debajo de Delivery en el menú lateral.',
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      _badge(
                        orders.length.toString() + ' recientes',
                        orders.isNotEmpty,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
