import 'dart:math';

import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

/// Gestión financiera zonal. Lecturas y escrituras se autorizan en RPC.
class AdminDebtManagementPage extends StatefulWidget {
  const AdminDebtManagementPage({
    super.key,
    required this.zoneId,
    required this.zoneName,
  });

  final String zoneId;
  final String zoneName;

  @override
  State<AdminDebtManagementPage> createState() =>
      _AdminDebtManagementPageState();
}

class _AdminDebtManagementPageState extends State<AdminDebtManagementPage> {
  bool loading = true;
  String? error;
  String status = 'pending';
  String role = 'all';
  String currency = '';
  final searchController = TextEditingController();
  List<Map<String, dynamic>> debts = [];
  List<Map<String, dynamic>> adjustments = [];
  List<Map<String, dynamic>> targets = [];
  final Set<String> busyIds = {};
  final Map<String, String> pendingOperationKeys = {};
  final Map<String, String> pendingSettlementReasons = {};
  final Map<String, Map<String, dynamic>> pendingAdjustments = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
      : <Map<String, dynamic>>[];

  Future<void> _load() async {
    if (widget.zoneId.isEmpty) {
      setState(() {
        loading = false;
        error = 'Selecciona una zona para ver sus registros financieros.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await supabase.rpc(
        'admin_finance_debts_v1',
        params: {
          'p_zone_id': widget.zoneId,
          'p_status': status,
          'p_role': role,
          'p_search': searchController.text.trim().isEmpty
              ? null
              : searchController.text.trim(),
          'p_limit': 200,
        },
      );
      final data = result is Map ? Map<String, dynamic>.from(result) : {};
      if (!mounted) return;
      setState(() {
        currency = (data['currency_code'] ?? '').toString();
        debts = _rows(data['debts']);
        adjustments = _rows(data['adjustments']);
        targets = _rows(data['targets']);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = _friendlyError(e);
        loading = false;
      });
    }
  }

  String _friendlyError(Object error) {
    final value = error.toString();
    if (value.contains('Modulo sin autorizacion') ||
        value.contains('Modulo no autorizado')) {
      return 'Tu cuenta no tiene habilitado el módulo de pagos para esta zona.';
    }
    if (value.contains('No autorizado') || value.contains('fuera de la zona')) {
      return 'No tienes permiso para consultar o modificar registros de esta zona.';
    }
    return value.replaceFirst(RegExp(r'^Exception: '), '');
  }

  String _idempotencyKey() {
    final random = Random.secure();
    String part(int length) => List.generate(
          length,
          (_) => random.nextInt(16).toRadixString(16),
        ).join();
    return '${part(8)}-${part(4)}-4${part(3)}-${(8 + random.nextInt(4)).toRadixString(16)}${part(3)}-${part(12)}';
  }

  String _money(dynamic amount, [String? code]) {
    final number = amount is num ? amount : num.tryParse('$amount') ?? 0;
    final decimals = (code ?? currency) == 'CLP' ? 0 : 2;
    return '${code ?? currency} ${number.toStringAsFixed(decimals)}';
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Fecha desconocida';
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Future<String?> _askReason({
    required String title,
    required String action,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(action),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Motivo obligatorio',
                hintText: 'Describe por qué se realiza esta acción',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length < 3) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _settle(Map<String, dynamic> debt) async {
    final id = debt['debt_id']?.toString();
    if (id == null || id.isEmpty || busyIds.contains(id)) return;
    final reason = await _askReason(
      title: 'Liquidar deuda',
      action:
          'Se marcará como liquidada la deuda de ${debt['full_name'] ?? 'este usuario'} por ${_money(debt['amount'], debt['currency_code']?.toString())}. Esta acción quedará auditada.',
      initialValue: pendingSettlementReasons[id] ?? '',
    );
    if (reason == null || !mounted) return;
    pendingSettlementReasons[id] = reason;
    setState(() => busyIds.add(id));
    try {
      await supabase.rpc(
        'admin_finance_settle_debt_v1',
        params: {
          'p_zone_id': widget.zoneId,
          'p_debt_id': id,
          'p_reason': reason,
          'p_idempotency_key': pendingOperationKeys.putIfAbsent(
            id,
            _idempotencyKey,
          ),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deuda liquidada y acción registrada.')),
      );
      pendingOperationKeys.remove(id);
      pendingSettlementReasons.remove(id);
      await _load();
    } catch (e) {
      if (mounted) _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => busyIds.remove(id));
    }
  }

  Future<void> _adjust(Map<String, dynamic> target) async {
    final userId = target['user_id']?.toString();
    if (userId == null || userId.isEmpty || busyIds.contains(userId)) return;
    final formKey = GlobalKey<FormState>();
    final pending = pendingAdjustments[userId];
    final amountController = TextEditingController(
      text: pending?['amount']?.toString() ?? '',
    );
    final reasonController = TextEditingController(
      text: pending?['reason']?.toString() ?? '',
    );
    var direction = pending?['direction']?.toString() ?? 'credit';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Ajuste manual de billetera'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${target['full_name'] ?? 'Usuario'} · ${target['role'] == 'driver' ? 'Conductor' : 'Pasajero'}',
                  ),
                  Text(
                    'Saldo actual: ${_money(target['balance'], target['currency_code']?.toString())}',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: direction,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de ajuste',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'credit',
                        child: Text('Asignar saldo'),
                      ),
                      DropdownMenuItem(
                        value: 'debit',
                        child: Text('Descontar saldo'),
                      ),
                    ],
                    onChanged: (value) =>
                        updateDialog(() => direction = value ?? 'credit'),
                  ),
                  if (direction == 'debit') ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Si el descuento supera el saldo, la diferencia quedará como deuda administrativa en negativo.',
                      style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          'Importe (${target['currency_code'] ?? currency})',
                    ),
                    validator: (value) {
                      final amount = num.tryParse(
                        (value ?? '').trim().replaceAll(',', '.'),
                      );
                      if (amount == null || amount <= 0) {
                        return 'Ingresa un importe mayor que cero';
                      }
                      if ((target['currency_code'] ?? currency) == 'CLP' &&
                          amount != amount.truncateToDouble()) {
                        return 'CLP no admite decimales';
                      }
                      if (amount > 10000000) {
                        return 'El importe supera el máximo permitido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: reasonController,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Motivo obligatorio',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value ?? '').trim().length < 3
                        ? 'Explica el motivo (mínimo 3 caracteres)'
                        : null,
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
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Aplicar ajuste'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      amountController.dispose();
      reasonController.dispose();
      return;
    }
    final amount = num.parse(amountController.text.trim().replaceAll(',', '.'));
    final reason = reasonController.text.trim();
    pendingAdjustments[userId] = {
      'direction': direction,
      'amount': amount,
      'reason': reason,
    };
    amountController.dispose();
    reasonController.dispose();
    setState(() => busyIds.add(userId));
    try {
      final result = await supabase.rpc(
        'admin_finance_adjust_wallet_v1',
        params: {
          'p_zone_id': widget.zoneId,
          'p_user_id': userId,
          'p_direction': direction,
          'p_amount': amount,
          'p_reason': reason,
          'p_idempotency_key': pendingOperationKeys.putIfAbsent(
            userId,
            _idempotencyKey,
          ),
        },
      );
      final response = result is Map ? Map<String, dynamic>.from(result) : {};
      if (!mounted) return;
      final balanceAfter = (response['balance_after'] as num?)?.toDouble();
      final balanceMessage = balanceAfter != null && balanceAfter < 0
          ? 'Deuda registrada. Saldo deudor: ${_money(balanceAfter)}.'
          : 'Ajuste aplicado. Saldo nuevo: ${_money(balanceAfter)}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(balanceMessage),
        ),
      );
      pendingOperationKeys.remove(userId);
      pendingAdjustments.remove(userId);
      await _load();
    } catch (e) {
      if (mounted) _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => busyIds.remove(userId));
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Widget _debtCard(Map<String, dynamic> debt) {
    final isOpen = debt['status'] == 'pending';
    final id = debt['debt_id']?.toString() ?? '';
    final roleLabel = debt['role'] == 'driver' ? 'Conductor' : 'Pasajero';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF2458C6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt['full_name']?.toString().trim().isNotEmpty == true
                            ? debt['full_name'].toString()
                            : roleLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        [
                          roleLabel,
                          if ((debt['email'] ?? '').toString().isNotEmpty)
                            debt['email'].toString(),
                          if ((debt['phone'] ?? '').toString().isNotEmpty)
                            debt['phone'].toString(),
                        ].join(' · '),
                      ),
                    ],
                  ),
                ),
                Text(
                  _money(debt['amount'], debt['currency_code']?.toString()),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${debt['reason'] ?? 'Deuda por cancelación'} · ${_date(debt['created_at'])}',
            ),
            Text(
              'Viaje: ${debt['trip_id'] ?? '—'} · ${isOpen ? 'Pendiente' : 'Liquidada'}',
            ),
            if (!isOpen &&
                (debt['resolution_reason'] ?? '').toString().isNotEmpty)
              Text('Motivo de liquidación: ${debt['resolution_reason']}'),
            if (!isOpen && debt['resolved_by_name'] != null)
              Text(
                'Liquidada por ${debt['resolved_by_name']} · ${_date(debt['resolved_at'])}',
              ),
            if (isOpen) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: busyIds.contains(id) ? null : () => _settle(debt),
                  icon: busyIds.contains(id)
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Liquidar manualmente'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _targetCard(Map<String, dynamic> target) {
    final id = target['user_id']?.toString() ?? '';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            target['role'] == 'driver'
                ? Icons.local_taxi
                : Icons.person_outline,
          ),
        ),
        title: Text(
          target['full_name']?.toString().trim().isNotEmpty == true
              ? target['full_name'].toString()
              : 'Usuario',
        ),
        subtitle: Text(
          '${target['role'] == 'driver' ? 'Conductor' : 'Pasajero'} · ${(target['email'] ?? 'Sin correo').toString()} · ${(target['phone'] ?? 'Sin teléfono').toString()}\nSaldo: ${_money(target['balance'], target['currency_code']?.toString())}',
        ),
        isThreeLine: true,
        trailing: FilledButton.tonal(
          onPressed: busyIds.contains(id) ? null : () => _adjust(target),
          child: const Text('Ajustar'),
        ),
      ),
    );
  }

  Widget _adjustmentCard(Map<String, dynamic> row) {
    final before = (row['balance_before'] as num? ?? 0).toDouble();
    final after = (row['balance_after'] as num? ?? 0).toDouble();
    final added = after >= before;
    final label = after < 0
        ? (added ? 'Deuda reducida' : 'Saldo deudor')
        : (before < 0
            ? 'Deuda saldada'
            : (added ? 'Saldo asignado' : 'Saldo descontado'));
    return Card(
      child: ListTile(
        leading: Icon(
          added ? Icons.add_circle_outline : Icons.remove_circle_outline,
          color: added ? Colors.green : Colors.deepOrange,
        ),
        title: Text(
          '${row['full_name'] ?? 'Usuario'} · $label',
        ),
        subtitle: Text(
          [
            if ((row['email'] ?? '').toString().isNotEmpty)
              row['email'].toString(),
            _date(row['created_at']),
            (row['reason'] ?? '').toString(),
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money(row['amount'], row['currency_code']?.toString()),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              '${_money(row['balance_before'], row['currency_code']?.toString())} → ${_money(row['balance_after'], row['currency_code']?.toString())}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deudas y ajustes',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.zoneName} · Deudas de pasajeros y conductores',
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: loading ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Las liquidaciones y ajustes requieren motivo y quedan registrados con el operador, zona y saldo anterior y nuevo.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              labelText: 'Buscar usuario, teléfono o viaje',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.arrow_forward),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              DropdownButton<String>(
                value: status,
                items: const [
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('Deudas pendientes'),
                  ),
                  DropdownMenuItem(
                    value: 'settled',
                    child: Text('Deudas liquidadas'),
                  ),
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Todas las deudas'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      status = value;
                      _load();
                    });
                  }
                },
              ),
              DropdownButton<String>(
                value: role,
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Pasajeros y conductores'),
                  ),
                  DropdownMenuItem(
                    value: 'passenger',
                    child: Text('Pasajeros'),
                  ),
                  DropdownMenuItem(value: 'driver', child: Text('Conductores')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      role = value;
                      _load();
                    });
                  }
                },
              ),
            ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            ),
          if (!loading && error == null) ...[
            const SizedBox(height: 8),
            Text(
              'Deudas (${debts.length}) · $currency',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (debts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('No hay deudas para estos filtros.'),
              ),
            for (final debt in debts) _debtCard(debt),
            const SizedBox(height: 18),
            Text(
              'Ajustes de saldo de la zona (${targets.length} coincidencias)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Busca una cuenta de pasajero o conductor para asignar o descontar saldo.',
            ),
            if (targets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No encontramos usuarios activos con ese filtro en la zona.',
                ),
              ),
            for (final target in targets) _targetCard(target),
            const SizedBox(height: 18),
            Text(
              'Historial de ajustes manuales',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (adjustments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Todavía no hay ajustes manuales en esta zona.'),
              ),
            for (final row in adjustments) _adjustmentCard(row),
          ],
        ],
      ),
    );
  }
}
