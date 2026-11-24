import 'package:flutter/material.dart';

import 'core/admin_friendly_error.dart';
import 'core/supabase_client.dart';

/// Resumen de Restaurantes y Delivery: pedidos de restaurantes, envíos, envíos directos y
/// liquidaciones de un periodo (semana, 30 días o el mes actual).
class AdminDeliveryDashboard extends StatefulWidget {
  const AdminDeliveryDashboard({
    super.key,
    required this.channel,
    required this.zoneId,
    this.onOpenTab,
  });

  final String channel;
  final String? zoneId;

  /// Para saltar al detalle (Pedidos, Envíos directos, Liquidaciones).
  final void Function(int tab)? onOpenTab;

  @override
  State<AdminDeliveryDashboard> createState() => _AdminDeliveryDashboardState();
}

class _AdminDeliveryDashboardState extends State<AdminDeliveryDashboard> {
  static const _blue = Color(0xFF0B57D0);
  static const _ink = Color(0xFF1D2433);
  static const _muted = Color(0xFF667085);
  static const _line = Color(0xFFE4E7EC);

  String _period = '7';
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant AdminDeliveryDashboard old) {
    super.didUpdateWidget(old);
    if (old.channel != widget.channel || old.zoneId != widget.zoneId) {
      _future = _load();
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _load() async {
    final zone = widget.zoneId;
    if (zone == null || zone.isEmpty) return {};
    final now = DateTime.now();
    final from = _period == 'month'
        ? DateTime(now.year, now.month, 1)
        : now.subtract(Duration(days: int.parse(_period) - 1));
    final raw = await supabase.rpc('admin_delivery_dashboard', params: {
      'p_zone_id': zone,
      'p_channel': widget.channel,
      'p_from': _iso(from),
      'p_to': _iso(now),
    });
    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  void _setPeriod(String value) {
    setState(() {
      _period = value;
      _future = _load();
    });
  }

  Map<String, dynamic> _m(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  List<Map<String, dynamic>> _l(Object? v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
  double _n(Object? v) => double.tryParse(v?.toString() ?? '') ?? 0;

  String _money(Object? v, String currency) {
    final n = _n(v);
    final text = n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
    return currency == 'BOB' ? 'Bs $text' : '$currency $text';
  }

  Widget _kpi(String label, String value, {IconData? icon, Color color = _blue}) =>
      Container(
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          if (icon != null)
            Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _muted)),
            ]),
          ),
        ]),
      );

  Widget _panel(String title, Widget child, {String? action, int? tab}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: _ink))),
            if (action != null && tab != null && widget.onOpenTab != null)
              TextButton(
                  onPressed: () => widget.onOpenTab!(tab), child: Text(action)),
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      );

  Widget _bars(List<({String label, double value, String text})> items,
      {Color color = _blue}) {
    if (items.isEmpty) {
      return const Text('Sin datos en este periodo.',
          style: TextStyle(color: _muted));
    }
    final max = items.map((e) => e.value).fold<double>(0, (a, b) => b > a ? b : a);
    return Column(children: [
      for (final i in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(
                width: 92,
                child: Text(i.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12))),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 14,
                    width: max <= 0 ? 2 : (c.maxWidth * (i.value / max)).clamp(2, c.maxWidth),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
            ),
            SizedBox(
                width: 96,
                child: Text(i.text,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
        ),
    ]);
  }

  String _settlementLabel(String status) => switch (status) {
        'pending' => 'Pendientes de pago',
        'reported' => 'Pago reportado',
        'paid' => 'Pagadas',
        'approved' => 'Aprobadas',
        'rejected' => 'Rechazadas',
        _ => status.replaceAll('_', ' '),
      };

  @override
  Widget build(BuildContext context) {
    if ((widget.zoneId ?? '').isEmpty) {
      return const Center(child: Text('Selecciona una zona para ver el resumen.'));
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('No se pudo cargar el resumen: ${friendlyError(snapshot.error)}'),
              const SizedBox(height: 10),
              FilledButton(
                  onPressed: () => setState(() => _future = _load()),
                  child: const Text('Reintentar')),
            ]),
          );
        }
        final d = snapshot.data ?? {};
        final currency = d['currency']?.toString() ?? 'BOB';
        final o = _m(d['orders']);
        final s = _m(d['shipments']);
        final direct = _m(d['direct']);
        final cuts = _l(_m(d['settlements'])['by_status']);
        final series = _l(o['series']);
        final top = _l(o['top_merchants']);
        final shipSeries = _l(s['series']);
        return ListView(padding: const EdgeInsets.all(14), children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final (key, label) in [
              ('7', 'Últimos 7 días'),
              ('30', 'Últimos 30 días'),
              ('month', 'Este mes'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _period == key,
                onSelected: (_) => _setPeriod(key),
              ),
          ]),
          const SizedBox(height: 14),
          _panel(
            'Pedidos de restaurantes',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                _kpi('Pedidos', '${o['total'] ?? 0}', icon: Icons.receipt_long_outlined),
                _kpi('Entregados', '${o['delivered'] ?? 0}',
                    icon: Icons.check_circle_outline, color: const Color(0xFF15803D)),
                _kpi('Cancelados', '${o['cancelled'] ?? 0}',
                    icon: Icons.cancel_outlined, color: const Color(0xFFC2413B)),
                _kpi('En curso', '${o['active'] ?? 0}',
                    icon: Icons.local_fire_department_outlined,
                    color: const Color(0xFFB7791F)),
                _kpi('Ventas de productos', _money(o['sales'], currency),
                    icon: Icons.payments_outlined),
                _kpi('Ticket promedio', _money(o['average_ticket'], currency),
                    icon: Icons.shopping_bag_outlined),
              ]),
              const SizedBox(height: 14),
              const Text('Ventas por día',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _bars([
                for (final x in series)
                  (
                    label: x['day']?.toString() ?? '',
                    value: _n(x['sales']),
                    text: '${_money(x['sales'], currency)} · ${x['orders']}'
                  ),
              ]),
              const SizedBox(height: 14),
              const Text('Restaurantes con más pedidos',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _bars([
                for (final x in top)
                  (
                    label: x['name']?.toString() ?? '',
                    value: _n(x['orders']),
                    text: '${x['orders']} pedidos'
                  ),
              ], color: const Color(0xFF15803D)),
            ]),
            action: 'Ver pedidos',
            tab: 4,
          ),
          _panel(
            'Envíos',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                _kpi('Solicitudes de envío', '${s['total'] ?? 0}',
                    icon: Icons.inventory_2_outlined),
                _kpi('Con repartidor', '${s['with_driver'] ?? 0}',
                    icon: Icons.delivery_dining_outlined,
                    color: const Color(0xFF15803D)),
                _kpi('Buscando', '${s['searching'] ?? 0}',
                    icon: Icons.search, color: const Color(0xFFB7791F)),
                _kpi('Cancelados', '${s['cancelled'] ?? 0}',
                    icon: Icons.cancel_outlined, color: const Color(0xFFC2413B)),
                _kpi('Pedidos por restaurantes', '${s['from_restaurants'] ?? 0}',
                    icon: Icons.storefront_outlined),
                _kpi('Tarifas de envíos aceptados', _money(s['fares'], currency),
                    icon: Icons.payments_outlined),
              ]),
              const SizedBox(height: 14),
              _bars([
                for (final x in shipSeries)
                  (
                    label: x['day']?.toString() ?? '',
                    value: _n(x['shipments']),
                    text: '${x['shipments']}'
                  ),
              ], color: const Color(0xFF7C3AED)),
            ]),
          ),
          _panel(
            'Envíos directos',
            Wrap(spacing: 10, runSpacing: 10, children: [
              _kpi('Total', '${direct['total'] ?? 0}', icon: Icons.local_shipping_outlined),
              _kpi('Entregados', '${direct['delivered'] ?? 0}',
                  icon: Icons.check_circle_outline, color: const Color(0xFF15803D)),
              _kpi('Cancelados', '${direct['cancelled'] ?? 0}',
                  icon: Icons.cancel_outlined, color: const Color(0xFFC2413B)),
              _kpi('En curso', '${direct['active'] ?? 0}',
                  icon: Icons.local_fire_department_outlined,
                  color: const Color(0xFFB7791F)),
            ]),
            action: 'Ver envíos directos',
            tab: 5,
          ),
          _panel(
            'Liquidaciones de restaurantes',
            cuts.isEmpty
                ? const Text('Todavía no hay liquidaciones en esta zona.',
                    style: TextStyle(color: _muted))
                : Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final c in cuts)
                      _kpi(
                          _settlementLabel(c['status']?.toString() ?? ''),
                          '${c['count']} · ${_money(c['amount'], currency)}',
                          icon: Icons.account_balance_wallet_outlined),
                  ]),
            action: 'Ver liquidaciones',
            tab: 6,
          ),
        ]);
      },
    );
  }
}
