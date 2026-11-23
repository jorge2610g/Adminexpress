import 'dart:math';

import 'package:flutter/material.dart';

import 'admin_csv_download.dart';
import 'admin_wallets_helpers.dart';
import 'core/admin_friendly_error.dart';
import 'core/supabase_client.dart';

/// Billeteras, retiros y recargas de la zona. Todo se autoriza en las RPC.
class AdminWalletsPage extends StatefulWidget {
  const AdminWalletsPage({
    super.key,
    required this.zoneId,
    required this.zoneName,
    this.canEdit = true,
  });

  final String zoneId;
  final String zoneName;
  final bool canEdit;

  @override
  State<AdminWalletsPage> createState() => _AdminWalletsPageState();
}

class _AdminWalletsPageState extends State<AdminWalletsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final searchController = TextEditingController();
  Map<String, dynamic> overview = {};
  List<Map<String, dynamic>> wallets = [];
  List<Map<String, dynamic>> withdrawals = [];
  List<Map<String, dynamic>> topups = [];
  String currency = '';
  String role = 'all';
  String balanceFilter = 'all';
  String withdrawalStatus = 'pending';
  String topupStatus = 'pending';
  int totalWallets = 0;
  bool loading = true;
  bool loadingMore = false;
  String? error;
  final Set<String> busyIds = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant AdminWalletsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoneId != widget.zoneId) _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList()
      : <Map<String, dynamic>>[];

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String? get _search {
    final text = searchController.text.trim();
    return text.isEmpty ? null : text;
  }

  String _money(dynamic amount, [String? code]) =>
      adminWalletMoney(amount, code ?? currency);

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String _dateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _idempotencyKey() {
    final random = Random.secure();
    String part(int length) => List.generate(
          length,
          (_) => random.nextInt(16).toRadixString(16),
        ).join();
    return '${part(8)}-${part(4)}-4${part(3)}-'
        '${(8 + random.nextInt(4)).toRadixString(16)}${part(3)}-${part(12)}';
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _loadAll() async {
    if (widget.zoneId.isEmpty) {
      setState(() {
        loading = false;
        error = 'Selecciona una zona para ver sus billeteras.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        supabase.rpc('admin_wallets_overview_v1',
            params: {'p_zone_id': widget.zoneId}),
        _fetchWallets(0),
        _fetchWithdrawals(),
        _fetchTopups(),
      ]);
      if (!mounted) return;
      final list = _map(results[1]);
      setState(() {
        overview = _map(results[0]);
        currency = (overview['currency_code'] ?? list['currency_code'] ?? '')
            .toString();
        wallets = _rows(list['rows']);
        totalWallets = (list['total'] as num?)?.toInt() ?? wallets.length;
        withdrawals = _rows(_map(results[2])['rows']);
        topups = _rows(results[3]);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = friendlyError(e);
        loading = false;
      });
    }
  }

  Future<dynamic> _fetchWallets(int offset) => supabase.rpc(
        'admin_wallets_list_v1',
        params: {
          'p_zone_id': widget.zoneId,
          'p_role': role,
          'p_filter': balanceFilter,
          'p_search': _search,
          'p_limit': 50,
          'p_offset': offset,
        },
      );

  Future<dynamic> _fetchWithdrawals() => supabase.rpc(
        'admin_wallet_withdrawals_v1',
        params: {
          'p_zone_id': widget.zoneId,
          'p_status': withdrawalStatus,
          'p_search': null,
          'p_limit': 100,
        },
      );

  Future<dynamic> _fetchTopups() => supabase.rpc(
        'admin_topup_requests',
        params: {'p_status': topupStatus == 'all' ? null : topupStatus},
      );

  Future<void> _reloadWallets() async {
    try {
      final list = _map(await _fetchWallets(0));
      if (!mounted) return;
      setState(() {
        wallets = _rows(list['rows']);
        totalWallets = (list['total'] as num?)?.toInt() ?? wallets.length;
      });
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    }
  }

  Future<void> _loadMore() async {
    if (loadingMore || wallets.length >= totalWallets) return;
    setState(() => loadingMore = true);
    try {
      final list = _map(await _fetchWallets(wallets.length));
      if (!mounted) return;
      setState(() => wallets = [...wallets, ..._rows(list['rows'])]);
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> _reloadWithdrawals() async {
    try {
      final data = _map(await _fetchWithdrawals());
      if (mounted) setState(() => withdrawals = _rows(data['rows']));
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    }
  }

  Future<void> _reloadTopups() async {
    try {
      final data = await _fetchTopups();
      if (mounted) setState(() => topups = _rows(data));
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    }
  }

  Future<void> _refreshOverview() async {
    try {
      final data = await supabase.rpc('admin_wallets_overview_v1',
          params: {'p_zone_id': widget.zoneId});
      if (mounted) setState(() => overview = _map(data));
    } catch (_) {}
  }

  void _exportCsv() {
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    adminDownloadTextFile('billeteras-$stamp.csv', adminWalletsCsv(wallets));
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _loadAll, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(child: _header()),
              SliverToBoxAdapter(child: _summaryCards()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabs,
                    tabs: [
                      const Tab(text: 'Billeteras'),
                      Tab(
                        text: 'Retiros'
                        '${_pendingCount('pending_withdrawals') > 0 ? ' (${_pendingCount('pending_withdrawals')})' : ''}',
                      ),
                      Tab(
                        text: 'Recargas'
                        '${_pendingCount('pending_topups') > 0 ? ' (${_pendingCount('pending_topups')})' : ''}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [_walletsTab(), _withdrawalsTab(), _topupsTab()],
            ),
          ),
        ),
      ],
    );
  }

  int _pendingCount(String key) =>
      (_map(overview[key])['count'] as num?)?.toInt() ?? 0;

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Billeteras',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(
                    'Conductores y clientes de ${widget.zoneName}: saldos, '
                    'ganancias, retiros y recargas.',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      );

  Widget _summaryCards() {
    final withdrawalsInfo = _map(overview['pending_withdrawals']);
    final topupsInfo = _map(overview['pending_topups']);
    final cards = <(IconData, String, String, String?)>[
      (
        Icons.account_balance_wallet_outlined,
        'Balance total',
        _money(overview['total_balance']),
        'Por pagar a conductores: ${_money(overview['driver_payable'])}',
      ),
      (
        Icons.warning_amber_rounded,
        'Deuda de saldos',
        _money(overview['debt_total']),
        'Suma de saldos negativos',
      ),
      (
        Icons.history_toggle_off_rounded,
        'Retiros pendientes',
        '${withdrawalsInfo['count'] ?? 0}',
        _money(withdrawalsInfo['amount']),
      ),
      (
        Icons.add_card_rounded,
        'Recargas pendientes',
        '${topupsInfo['count'] ?? 0}',
        _money(topupsInfo['amount']),
      ),
      (
        Icons.check_circle_outline_rounded,
        'Procesados hoy',
        '${overview['processed_today'] ?? 0}',
        null,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final c in cards)
            SizedBox(
              width: 230,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(c.$1, size: 20, color: const Color(0xFF2458C6)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.$2)),
                      ]),
                      const SizedBox(height: 8),
                      Text(c.$3,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      if (c.$4 != null)
                        Text(c.$4!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _walletsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(
                    labelText: 'Usuarios', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Todos')),
                  DropdownMenuItem(value: 'driver', child: Text('Conductores')),
                  DropdownMenuItem(value: 'passenger', child: Text('Clientes')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => role = v);
                  _reloadWallets();
                },
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                initialValue: balanceFilter,
                decoration: const InputDecoration(
                    labelText: 'Saldo', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Todas')),
                  DropdownMenuItem(value: 'debt', child: Text('Solo en deuda')),
                  DropdownMenuItem(
                      value: 'balance', child: Text('Solo con saldo')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => balanceFilter = v);
                  _reloadWallets();
                },
              ),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre, correo o teléfono',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _reloadWallets(),
              ),
            ),
            FilledButton.icon(
              onPressed: _reloadWallets,
              icon: const Icon(Icons.search),
              label: const Text('Buscar'),
            ),
            OutlinedButton.icon(
              onPressed: wallets.isEmpty ? null : _exportCsv,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Exportar CSV'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Todas las billeteras · $totalWallets',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (wallets.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No hay billeteras con esos filtros.')),
          ),
        for (final wallet in wallets) _walletCard(wallet),
        if (wallets.length < totalWallets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: OutlinedButton(
                onPressed: loadingMore ? null : _loadMore,
                child: Text(loadingMore ? 'Cargando…' : 'Cargar más'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _walletCard(Map<String, dynamic> wallet) {
    final balance = (wallet['balance'] as num?) ?? 0;
    final isDriver = wallet['role'] == 'driver';
    final name = (wallet['full_name']?.toString().trim().isEmpty ?? true)
        ? 'Sin nombre'
        : wallet['full_name'].toString();
    final pending = (wallet['pending_withdrawals'] as num?)?.toInt() ?? 0;
    return Card(
      child: ListTile(
        onTap: () => _openDetail(wallet['user_id'].toString()),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE3EDFD),
          child: Icon(
              isDriver ? Icons.drive_eta_rounded : Icons.person_outline_rounded,
              color: const Color(0xFF2458C6)),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${isDriver ? 'Conductor' : 'Cliente'} · '
          '${wallet['email'] ?? wallet['phone'] ?? ''}\n'
          'Transacciones: ${wallet['tx_count'] ?? 0}'
          '${pending > 0 ? ' · Retiros pendientes: $pending' : ''}'
          ' · Última actividad: ${_date(wallet['last_activity'])}',
        ),
        isThreeLine: true,
        trailing: Text(
          _money(balance, wallet['currency_code']?.toString()),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: balance < 0 ? const Color(0xFFB3261E) : null,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- detalle

  Future<void> _openDetail(String userId) async {
    Map<String, dynamic> data;
    try {
      data = _map(await supabase.rpc('admin_wallet_detail_v1',
          params: {'p_zone_id': widget.zoneId, 'p_user_id': userId}));
    } catch (e) {
      _toast(friendlyError(e));
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _WalletDetailDialog(
        data: data,
        canEdit: widget.canEdit,
        money: _money,
        dateTime: _dateTime,
        onAdjust: () async {
          Navigator.of(dialogContext).pop();
          await _adjust(data);
        },
      ),
    );
  }

  Future<void> _adjust(Map<String, dynamic> data) async {
    final user = _map(data['user']);
    final userId = user['id']?.toString() ?? '';
    final code = (data['currency_code'] ?? currency).toString();
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var direction = 'credit';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Ajustar saldo manualmente'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${user['full_name'] ?? 'Usuario'} · saldo actual '
                      '${_money(data['balance'], code)}'),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'credit',
                          icon: Icon(Icons.add),
                          label: Text('Abonar')),
                      ButtonSegment(
                          value: 'debit',
                          icon: Icon(Icons.remove),
                          label: Text('Descontar')),
                    ],
                    selected: {direction},
                    onSelectionChanged: (v) => update(() => direction = v.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Monto ($code)',
                        border: const OutlineInputBorder()),
                    validator: (raw) {
                      final v = double.tryParse(
                          (raw ?? '').trim().replaceAll(',', '.'));
                      if (v == null || v <= 0) return 'Ingresa un monto mayor a 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Comentario / justificación (requerido)',
                        border: OutlineInputBorder()),
                    validator: (raw) => (raw ?? '').trim().length < 3
                        ? 'Escribe al menos 3 caracteres'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar')),
            FilledButton(
              style: direction == 'debit'
                  ? FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB3261E))
                  : null,
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(direction == 'credit' ? 'Abonar' : 'Descontar'),
            ),
          ],
        ),
      ),
    );
    final amount =
        double.tryParse(amountController.text.trim().replaceAll(',', '.'));
    final reason = reasonController.text.trim();
    amountController.dispose();
    reasonController.dispose();
    if (confirmed != true || amount == null || userId.isEmpty) return;
    setState(() => busyIds.add(userId));
    try {
      final result = await supabase.rpc('admin_finance_adjust_wallet_v1',
          params: {
            'p_zone_id': widget.zoneId,
            'p_user_id': userId,
            'p_direction': direction,
            'p_amount': amount,
            'p_reason': reason,
            'p_idempotency_key': _idempotencyKey(),
          });
      final response = _map(result);
      if (!mounted) return;
      _toast('Ajuste aplicado. Saldo nuevo: '
          '${_money(response['balance_after'], code)}.');
      await _loadAll();
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => busyIds.remove(userId));
    }
  }

  // ---------------------------------------------------------------- retiros

  Widget _withdrawalsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const Text('Estado:  '),
          DropdownButton<String>(
            value: withdrawalStatus,
            items: const [
              DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
              DropdownMenuItem(value: 'paid', child: Text('Pagados')),
              DropdownMenuItem(value: 'rejected', child: Text('Rechazados')),
              DropdownMenuItem(value: 'all', child: Text('Todos')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => withdrawalStatus = v);
              _reloadWithdrawals();
            },
          ),
        ]),
        const SizedBox(height: 8),
        if (withdrawals.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Column(children: [
              Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.black38),
              SizedBox(height: 8),
              Text('No hay solicitudes de retiro',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text('No se encontraron solicitudes con los filtros actuales.',
                  textAlign: TextAlign.center),
            ]),
          ),
        for (final w in withdrawals) _withdrawalCard(w),
      ],
    );
  }

  Widget _withdrawalCard(Map<String, dynamic> w) {
    final id = w['id'].toString();
    final pending = w['status'] == 'pending';
    final busy = busyIds.contains(id);
    final statusText = switch (w['status']) {
      'paid' => 'Pagado',
      'rejected' => 'Rechazado',
      _ => 'Pendiente',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(w['full_name']?.toString() ?? 'Usuario',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text(_money(w['amount'], w['currency']?.toString()),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            Text('$statusText · ${_dateTime(w['created_at'])}'),
            Text('Saldo actual: ${_money(w['balance'], w['currency']?.toString())}'),
            if ((w['method'] ?? '').toString().isNotEmpty)
              Text('Método: ${w['method']}'),
            if ((w['destination'] ?? '').toString().isNotEmpty)
              Text('Destino: ${w['destination']}'),
            if ((w['resolution_note'] ?? '').toString().isNotEmpty)
              Text('Nota: ${w['resolution_note']}'),
            if (pending && widget.canEdit) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                FilledButton.icon(
                  onPressed: busy ? null : () => _resolveWithdrawal(w, 'pay'),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Marcar como pagado'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _resolveWithdrawal(w, 'reject'),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Rechazar'),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<String?> _askNote({required String title, required bool required}) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: required ? 'Motivo (requerido)' : 'Nota (opcional)',
              border: const OutlineInputBorder(),
            ),
            validator: (raw) => required && (raw ?? '').trim().length < 3
                ? 'Escribe al menos 3 caracteres'
                : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _resolveWithdrawal(Map<String, dynamic> w, String action) async {
    final id = w['id'].toString();
    final note = await _askNote(
      title: action == 'pay'
          ? 'Marcar retiro como pagado'
          : 'Rechazar retiro',
      required: action == 'reject',
    );
    if (note == null) return;
    setState(() => busyIds.add(id));
    try {
      await supabase.rpc('admin_resolve_wallet_withdrawal_v1', params: {
        'p_zone_id': widget.zoneId,
        'p_request_id': id,
        'p_action': action,
        'p_note': note.isEmpty ? null : note,
      });
      if (!mounted) return;
      _toast(action == 'pay'
          ? 'Retiro pagado. Se descontó de la billetera.'
          : 'Retiro rechazado.');
      await Future.wait([_reloadWithdrawals(), _reloadWallets(), _refreshOverview()]);
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => busyIds.remove(id));
    }
  }

  // --------------------------------------------------------------- recargas

  Widget _topupsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const Text('Estado:  '),
          DropdownButton<String>(
            value: topupStatus,
            items: const [
              DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
              DropdownMenuItem(value: 'approved', child: Text('Aprobadas')),
              DropdownMenuItem(value: 'rejected', child: Text('Rechazadas')),
              DropdownMenuItem(value: 'all', child: Text('Todas')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => topupStatus = v);
              _reloadTopups();
            },
          ),
        ]),
        const SizedBox(height: 8),
        if (topups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No hay solicitudes de recarga.')),
          ),
        for (final t in topups) _topupCard(t),
      ],
    );
  }

  Widget _topupCard(Map<String, dynamic> t) {
    final id = t['id'].toString();
    final pending = t['status'] == 'pending';
    final busy = busyIds.contains(id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(t['full_name']?.toString() ?? 'Usuario',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text(_money(t['amount'], t['currency']?.toString()),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            Text('${t['status']} · ${_dateTime(t['created_at'])}'),
            if ((t['method'] ?? '').toString().isNotEmpty)
              Text('Método: ${t['method']}'),
            if ((t['provider_reference'] ?? '').toString().isNotEmpty)
              Text('Referencia: ${t['provider_reference']}'),
            if (pending && widget.canEdit) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                FilledButton(
                  onPressed: busy ? null : () => _resolveTopup(id, 'approved'),
                  child: const Text('Aprobar'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => _resolveTopup(id, 'rejected'),
                  child: const Text('Rechazar'),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _resolveTopup(String id, String status) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(status == 'approved' ? 'Aprobar recarga' : 'Rechazar recarga'),
        content: Text(status == 'approved'
            ? 'Se acreditará el monto a la billetera del usuario.'
            : 'La solicitud se marcará como rechazada.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busyIds.add(id));
    try {
      await supabase.rpc('admin_resolve_wallet_topup',
          params: {'p_request_id': id, 'p_status': status});
      if (!mounted) return;
      _toast(status == 'approved' ? 'Recarga aprobada.' : 'Recarga rechazada.');
      await Future.wait([_reloadTopups(), _reloadWallets(), _refreshOverview()]);
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => busyIds.remove(id));
    }
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Material(color: Theme.of(context).colorScheme.surface, child: tabBar);

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}

class _WalletDetailDialog extends StatelessWidget {
  const _WalletDetailDialog({
    required this.data,
    required this.canEdit,
    required this.money,
    required this.dateTime,
    required this.onAdjust,
  });

  final Map<String, dynamic> data;
  final bool canEdit;
  final String Function(dynamic, [String?]) money;
  final String Function(dynamic) dateTime;
  final VoidCallback onAdjust;

  Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  Widget _stat(String label, String value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final user = _map(data['user']);
    final code = (data['currency_code'] ?? '').toString();
    final isDriver = user['role'] == 'driver';
    final earnings = _map(data['earnings']);
    final pending = _map(data['pending_withdrawals']);
    final settle = _map(data['settle']);
    final transactions = data['recent_transactions'] is List
        ? (data['recent_transactions'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    Widget earningsRow(String label, Map<String, dynamic> e) {
      final trips = (e['trips'] as num?)?.toInt() ?? 0;
      final deliveries = (e['deliveries'] as num?)?.toInt() ?? 0;
      final total = ((e['trips_total'] as num?) ?? 0) +
          ((e['deliveries_total'] as num?) ?? 0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 70, child: Text(label)),
          Expanded(
            child: Text(
                '$trips viajes${deliveries > 0 ? ' · $deliveries entregas' : ''}'),
          ),
          Text(money(total, code),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
    }

    return AlertDialog(
      title: Text('Detalle de billetera (${isDriver ? 'Conductor' : 'Cliente'})'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user['full_name']?.toString() ?? 'Usuario',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              Text('${user['email'] ?? ''}  ${user['phone'] ?? ''}'),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _stat('Balance actual', money(data['balance'], code)),
                _stat('Moneda', code),
                _stat('Transacciones', '${data['tx_count'] ?? 0}'),
                if (isDriver)
                  _stat('Estado',
                      (user['online_status'] ?? 'offline').toString().toUpperCase()),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Neto a liquidar',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(
                      adminWalletSettleText(settle['net'], code),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ],
                ),
              ),
              if (isDriver) ...[
                const SizedBox(height: 14),
                const Text('Ganancias',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                earningsRow('Hoy', _map(earnings['today'])),
                earningsRow('7 días', _map(earnings['week'])),
                earningsRow('Este mes', _map(earnings['month'])),
              ],
              const SizedBox(height: 12),
              Text('Retiros pendientes: ${pending['count'] ?? 0}'
                  '${(pending['count'] as num? ?? 0) > 0 ? ' (${money(pending['amount'], code)})' : ''}'),
              Text('Creada: ${dateTime(data['created_at'])}'),
              Text('Última actividad: ${dateTime(data['last_activity'])}'),
              const SizedBox(height: 14),
              const Text('Últimos movimientos',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              if (transactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sin movimientos.'),
                ),
              for (final t in transactions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        '${dateTime(t['created_at'])} · ${t['reference'] ?? t['type']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    Text(
                      money(t['amount'], code),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ((t['amount'] as num?) ?? 0) < 0
                            ? const Color(0xFFB3261E)
                            : const Color(0xFF0A6B49),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        if (canEdit)
          FilledButton.icon(
            onPressed: onAdjust,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Ajustar saldo'),
          ),
      ],
    );
  }
}
