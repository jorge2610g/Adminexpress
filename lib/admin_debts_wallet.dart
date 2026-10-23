import 'package:flutter/material.dart';

import 'core/admin_money.dart';
import 'core/supabase_client.dart';

const _blue = Color(0xFF2563EB);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);

/// Zone-scoped central view for passenger/driver cancellation debts and wallet
/// adjustments. All reads and writes are performed by guarded database RPCs.
class AdminDebtWalletPage extends StatefulWidget {
  const AdminDebtWalletPage({
    super.key,
    required this.channel,
    required this.zoneId,
    required this.zoneName,
    required this.readOnly,
  });

  final String channel;
  final String zoneId;
  final String zoneName;
  final bool readOnly;

  @override
  State<AdminDebtWalletPage> createState() => _AdminDebtWalletPageState();
}

class _AdminDebtWalletPageState extends State<AdminDebtWalletPage> {
  final searchController = TextEditingController();
  String role = 'all';
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> users = const [];

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

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
      : const [];

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final result = await supabase.rpc(
        'admin_debt_wallet_list_v1',
        params: {
          'p_channel': widget.channel,
          'p_zone_id': widget.zoneId,
          'p_search': searchController.text.trim().isEmpty
              ? null
              : searchController.text.trim(),
          'p_target_role': role == 'all' ? null : role,
          'p_limit': 150,
          'p_offset': 0,
        },
      );
      if (!mounted) return;
      setState(() {
        users = _maps(result is Map ? result['users'] : null);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  String _money(Object? value, Object? currency) =>
      adminMoney(value, currency?.toString() ?? '');

  Future<void> _showDetail(Map<String, dynamic> row) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _AdminDebtWalletDetailDialog(
        channel: widget.channel,
        zoneId: widget.zoneId,
        readOnly: widget.readOnly,
        initial: row,
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text(
            'Deudas y ajustes',
            style: TextStyle(
              color: _ink,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${widget.zoneName} · ${widget.channel == 'preview' ? 'Prueba' : 'Producción'}',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 8),
          const Text(
            'Consulta deudas por cancelación, saldo y movimientos de pasajeros y conductores. Cada operación conserva motivo y responsable.',
            style: TextStyle(color: _muted),
          ),
          if (widget.readOnly) ...[
            const SizedBox(height: 10),
            const _InfoBanner(
              text: 'Acceso de solo lectura para este usuario.',
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar por nombre o teléfono',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _load,
                tooltip: 'Buscar',
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _roleChip('all', 'Todos'),
              _roleChip('passenger', 'Pasajeros'),
              _roleChip('driver', 'Conductores'),
            ],
          ),
          const SizedBox(height: 16),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            ),
          if (error != null)
            _InfoBanner(
              text: 'No se pudo cargar la información: $error',
              isError: true,
            ),
          if (!loading && error == null && users.isEmpty)
            const _InfoBanner(
              text:
                  'No hay cuentas que coincidan con la búsqueda en esta zona.',
            ),
          if (!loading && error == null)
            ...users.map((row) {
              final currency = row['currency_code'];
              final debtCount =
                  int.tryParse('${row['open_debt_count'] ?? 0}') ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEFF4FF),
                    child: Icon(
                      row['target_role'] == 'driver'
                          ? Icons.drive_eta_outlined
                          : Icons.person_outline,
                      color: _blue,
                    ),
                  ),
                  title: Text(
                    row['full_name']?.toString().trim().isNotEmpty == true
                        ? row['full_name'].toString()
                        : 'Cuenta ${row['user_id']}',
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 5,
                      children: [
                        Text(
                          row['target_role'] == 'driver'
                              ? 'Conductor'
                              : 'Pasajero',
                        ),
                        if ((row['phone']?.toString() ?? '').isNotEmpty)
                          Text(row['phone'].toString()),
                        Text('Saldo: ${_money(row['balance'], currency)}'),
                        Text(
                          'Deuda pendiente: ${_money(row['open_debt_total'], currency)} · $debtCount',
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showDetail(row),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _roleChip(String value, String label) => ChoiceChip(
        label: Text(label),
        selected: role == value,
        onSelected: (_) {
          setState(() => role = value);
          _load();
        },
      );
}

class _AdminDebtWalletDetailDialog extends StatefulWidget {
  const _AdminDebtWalletDetailDialog({
    required this.channel,
    required this.zoneId,
    required this.readOnly,
    required this.initial,
  });
  final String channel;
  final String zoneId;
  final bool readOnly;
  final Map<String, dynamic> initial;

  @override
  State<_AdminDebtWalletDetailDialog> createState() =>
      _AdminDebtWalletDetailDialogState();
}

class _AdminDebtWalletDetailDialogState
    extends State<_AdminDebtWalletDetailDialog> {
  bool loading = true;
  bool saving = false;
  String? error;
  Map<String, dynamic> detail = {};
  final Set<String> selectedDebtIds = {};

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
      : const [];

  String get userId => widget.initial['user_id'].toString();
  String get targetRole => widget.initial['target_role'].toString();
  String get currency =>
      detail['currency_code']?.toString() ??
      widget.initial['currency_code']?.toString() ??
      '';
  String money(Object? amount) => adminMoney(amount, currency);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final value = await supabase.rpc(
        'admin_debt_wallet_detail_v1',
        params: {
          'p_channel': widget.channel,
          'p_zone_id': widget.zoneId,
          'p_user_id': userId,
          'p_target_role': targetRole,
        },
      );
      if (!mounted) return;
      setState(() {
        detail = value is Map ? Map<String, dynamic>.from(value) : {};
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _settleManually() async {
    final unpaid =
        _maps(detail['debts']).where((d) => d['paid_at'] == null).toList();
    final ids = selectedDebtIds
        .where((id) => unpaid.any((d) => d['id']?.toString() == id))
        .toList();
    if (ids.isEmpty) return;
    final selectedTotal = unpaid
        .where((d) => ids.contains(d['id']?.toString()))
        .fold<num>(0,
            (total, debt) => total + (num.tryParse('${debt['amount']}') ?? 0));
    final reason = TextEditingController();
    final reference = TextEditingController();
    String method = 'cash';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registrar pago manual recibido'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Se liquidarán ${money(selectedTotal)} de deudas seleccionadas. Esto registra un pago recibido fuera de la app.',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                    DropdownMenuItem(
                      value: 'bank_transfer',
                      child: Text('Transferencia'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Otro')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => method = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'Referencia (opcional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reason,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Motivo / comprobante de recepción',
                    hintText:
                        'Describe quién recibió el pago y cómo se verificó.',
                  ),
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
              child: const Text('Registrar pago'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) {
      reason.dispose();
      reference.dispose();
      return;
    }
    if (reason.text.trim().length < 5) {
      reason.dispose();
      reference.dispose();
      _message('Escribe un motivo de al menos 5 caracteres.');
      return;
    }
    await _mutate(
        'admin_settle_cancellation_debts_manual_v1',
        {
          'p_channel': widget.channel,
          'p_zone_id': widget.zoneId,
          'p_user_id': userId,
          'p_target_role': targetRole,
          'p_debt_ids': ids,
          'p_payment_method': method,
          'p_payment_reference':
              reference.text.trim().isEmpty ? null : reference.text.trim(),
          'p_reason': reason.text.trim(),
        },
        'Pago manual registrado; deudas liquidadas.');
    reason.dispose();
    reference.dispose();
  }

  Future<void> _adjustWallet() async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajustar saldo'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Usa un monto positivo para acreditar y uno negativo para descontar. Moneda: $currency.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Ajuste (por ejemplo, 250 o -50)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reason,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Motivo obligatorio',
                ),
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
            child: const Text('Aplicar ajuste'),
          ),
        ],
      ),
    );
    if (accepted != true) {
      amount.dispose();
      reason.dispose();
      return;
    }
    final delta = num.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (delta == null || delta == 0 || reason.text.trim().length < 5) {
      amount.dispose();
      reason.dispose();
      _message(
        'Indica un monto distinto de cero y un motivo de al menos 5 caracteres.',
      );
      return;
    }
    await _mutate(
        'admin_adjust_wallet_balance_v1',
        {
          'p_channel': widget.channel,
          'p_zone_id': widget.zoneId,
          'p_user_id': userId,
          'p_target_role': targetRole,
          'p_delta': delta,
          'p_reason': reason.text.trim(),
        },
        'Ajuste de saldo aplicado y auditado.');
    amount.dispose();
    reason.dispose();
  }

  Future<void> _mutate(
    String rpc,
    Map<String, dynamic> params,
    String success,
  ) async {
    if (mounted) setState(() => saving = true);
    try {
      await supabase.rpc(rpc, params: params);
      selectedDebtIds.clear();
      await _load();
      if (mounted) _message(success);
    } catch (e) {
      if (mounted) _message('No se pudo completar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final debts = _maps(detail['debts']);
    final movements = _maps(detail['wallet_movements']);
    final audit = _maps(detail['audit']);
    final unpaid = debts.where((d) => d['paid_at'] == null).toList();
    final title = detail['full_name']?.toString().trim().isNotEmpty == true
        ? detail['full_name'].toString()
        : 'Cuenta';
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${targetRole == 'driver' ? 'Conductor' : 'Pasajero'} · ${detail['phone'] ?? ''}',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: loading || saving ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      content: SizedBox(
        width: 760,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? _InfoBanner(text: error!, isError: true)
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          color: const Color(0xFFEFF4FF),
                          child: ListTile(
                            title: const Text('Saldo disponible'),
                            trailing: Text(
                              money(detail['balance']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _blue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Deudas por cancelación (${unpaid.length} pendientes)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (!widget.readOnly && unpaid.isNotEmpty)
                              TextButton.icon(
                                onPressed: _settleManually,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Registrar pago manual'),
                              ),
                          ],
                        ),
                        if (debts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No hay deudas de cancelación.'),
                          ),
                        for (final debt in debts) ...[
                          CheckboxListTile(
                            value: selectedDebtIds
                                .contains(debt['id']?.toString()),
                            onChanged: widget.readOnly ||
                                    debt['paid_at'] != null ||
                                    saving
                                ? null
                                : (value) {
                                    setState(() {
                                      final id = debt['id']?.toString() ?? '';
                                      if (value == true) {
                                        selectedDebtIds.add(id);
                                      } else {
                                        selectedDebtIds.remove(id);
                                      }
                                    });
                                  },
                            title: Text(
                              '${money(debt['amount'])} · ${debt['paid_at'] == null ? 'Pendiente' : 'Pagada'}',
                            ),
                            subtitle: Text(
                              '${debt['reason'] ?? 'Cancelación'} · ${debt['created_at'] ?? ''}',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                        ],
                        if (!widget.readOnly) ...[
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: saving ? null : _adjustWallet,
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text('Ajustar saldo con motivo'),
                          ),
                        ],
                        const Divider(height: 28),
                        const Text(
                          'Movimientos de billetera',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (movements.isEmpty) const Text('Sin movimientos.'),
                        for (final tx in movements.take(10))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.receipt_long_outlined,
                              color: _muted,
                            ),
                            title: Text(
                              '${money(tx['amount'])} · ${tx['type'] ?? 'Movimiento'}',
                            ),
                            subtitle: Text(
                              '${tx['reference'] ?? ''} · ${tx['created_at'] ?? ''}',
                            ),
                          ),
                        const Divider(height: 28),
                        const Text(
                          'Historial de acciones administrativas',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (audit.isEmpty)
                          const Text('Sin ajustes administrativos anteriores.'),
                        for (final item in audit.take(10))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.verified_user_outlined,
                              color: _muted,
                            ),
                            title: Text(
                              item['action_type'] == 'wallet_adjustment'
                                  ? 'Ajuste ${money(item['amount'])}'
                                  : 'Liquidación manual ${money(item['amount'])}',
                            ),
                            subtitle: Text(
                              '${item['reason'] ?? ''} · ${item['created_at'] ?? ''} · Operador ${item['actor_id'] ?? ''}',
                            ),
                          ),
                        if (saving) const LinearProgressIndicator(),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, true),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, this.isError = false});
  final String text;
  final bool isError;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFEF3F2) : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(color: isError ? const Color(0xFFB42318) : _muted),
        ),
      );
}
