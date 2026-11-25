import 'package:flutter/material.dart';

import 'core/admin_dropdown_field.dart';
import 'core/admin_friendly_error.dart';
import 'core/admin_friendly_labels.dart';
import 'core/supabase_client.dart';

/// Registro de despachos: solicitudes que terminaron sin conductor y cómo respondió cada conductor.
const Color _blue = Color(0xFF2563EB);
const Color _muted = Color(0xFF64748B);
const Color _line = Color(0xFFE7ECF3);
const Color _red = Color(0xFFB42318);
const Color _green = Color(0xFF15803D);
const Color _amber = Color(0xFFB45309);

class AdminDispatchRpc {
  static const unserved = 'admin_dispatch_unserved_v1';
  static const drivers = 'admin_dispatch_request_drivers_v1';
  static const stats = 'admin_dispatch_driver_stats_v1';
  static const summary = 'admin_dispatch_summary_v1';

  /// Porcentaje entero de [part] sobre [total]; «—» si no hay total.
  static String percent(num part, num total) =>
      total <= 0 ? '—' : '${(part * 100 / total).round()}%';

  /// Inicio del periodo elegido (hora local): hoy, últimos 7 o 30 días.
  static DateTime periodStart(String period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      'today' => today,
      '30d' => today.subtract(const Duration(days: 29)),
      _ => today.subtract(const Duration(days: 6)),
    };
  }

  static String outcomeLabel(String? outcome) => switch (outcome) {
        'acepto' => 'Aceptó',
        'oferto' => 'Ofertó',
        'rechazo' => 'Rechazó',
        'vio_y_no_respondio' => 'La vio y no respondió',
        'no_la_abrio' => 'No la abrió',
        _ => '—',
      };

  static Color outcomeColor(String? outcome) => switch (outcome) {
        'acepto' || 'oferto' => _green,
        'rechazo' => _amber,
        'vio_y_no_respondio' => _red,
        _ => _muted,
      };
}

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : const [];

String _fmt(Object? raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

String _km(Object? v) {
  final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
  if (n == null) return '—';
  return n < 1 ? '${(n * 1000).round()} m' : '${n.toStringAsFixed(1)} km';
}

/// Pestañas del despacho: el despacho manual de siempre y los dos registros nuevos.
class AdminDispatchHub extends StatelessWidget {
  final String channel;
  final String? zoneId;
  final Widget manual;

  const AdminDispatchHub({
    super.key,
    required this.channel,
    required this.zoneId,
    required this.manual,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const Material(
            color: Colors.white,
            child: TabBar(
              tabs: [
                Tab(text: 'Despacho manual'),
                Tab(text: 'Resumen'),
                Tab(text: 'No concretadas'),
                Tab(text: 'Por conductor'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                manual,
                _SummaryTab(channel: channel, zoneId: zoneId),
                _UnservedTab(channel: channel, zoneId: zoneId),
                _DriversTab(channel: channel, zoneId: zoneId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodBar extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;
  const _PeriodBar({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 'today', label: Text('Hoy')),
        ButtonSegment(value: '7d', label: Text('7 días')),
        ButtonSegment(value: '30d', label: Text('30 días')),
      ],
      selected: {period},
      onSelectionChanged: (v) => onChanged(v.first),
    );
  }
}

class _SummaryTab extends StatefulWidget {
  final String channel;
  final String? zoneId;
  const _SummaryTab({required this.channel, required this.zoneId});

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  String period = 'today';
  int revision = 0;

  Future<Map<String, dynamic>> _load() async {
    final zone = widget.zoneId;
    if (zone == null || zone.isEmpty) return const {};
    final value = await supabase.rpc(
      AdminDispatchRpc.summary,
      params: {
        'p_channel': widget.channel,
        'p_zone_id': zone,
        'p_from': AdminDispatchRpc.periodStart(period, DateTime.now())
            .toUtc()
            .toIso8601String(),
        'p_to': null,
      },
    );
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text('Resumen de despachos',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text(
          'Cuántas solicitudes entran, cuántas se concretan y qué hacen los conductores con ellas. '
          'Sirve para saber si los usuarios piden y los conductores no aceptan.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _PeriodBar(
          period: period,
          onChanged: (v) => setState(() {
            period = v;
            revision++;
          }),
        ),
        const SizedBox(height: 14),
        FutureBuilder<Map<String, dynamic>>(
          key: ValueKey('summary-$period-$revision'),
          future: _load(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const LinearProgressIndicator();
            }
            if (snap.hasError) return Text(friendlyError(snap.error));
            final data = snap.data ?? const <String, dynamic>{};
            final t = data['totals'] is Map
                ? Map<String, dynamic>.from(data['totals'] as Map)
                : <String, dynamic>{};
            int n(String k) => (t[k] as num?)?.toInt() ?? 0;
            final requests = n('requests');
            if (requests == 0) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('No hubo solicitudes en este periodo.',
                        style: TextStyle(color: _muted))),
              );
            }
            final notifs = n('notificaciones');
            final days = _rows(data['days']);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _Kpi('Solicitudes', '$requests', _blue),
                  _Kpi(
                      'Concretadas',
                      '${n('concretadas')} · ${AdminDispatchRpc.percent(n('concretadas'), requests)}',
                      _green),
                  _Kpi(
                      'Sin concretar',
                      '${n('sin_concretar') + n('buscando')} · ${AdminDispatchRpc.percent(n('sin_concretar') + n('buscando'), requests)}',
                      _red),
                  _Kpi(
                      'Sin ningún conductor notificado',
                      '${n('sin_notificados')}',
                      n('sin_notificados') > 0 ? _red : _muted),
                  _Kpi('Conductores notificados',
                      '${n('conductores_notificados')}', _blue),
                  _Kpi('Conductores en línea ahora',
                      '${data['online_now'] ?? '—'}', _green),
                  _Kpi('Notificaciones enviadas', '$notifs', _blue),
                  _Kpi(
                      'Vistas',
                      '${n('vistas')} · ${AdminDispatchRpc.percent(n('vistas'), notifs)}',
                      _muted),
                  _Kpi(
                      'Respondieron',
                      '${n('respuestas')} · ${AdminDispatchRpc.percent(n('respuestas'), notifs)}',
                      _green),
                  _Kpi(
                      'La vieron y no respondieron',
                      '${n('ignoradas')} · ${AdminDispatchRpc.percent(n('ignoradas'), notifs)}',
                      _red),
                  _Kpi('No la abrieron', '${n('sin_abrir')}', _muted),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'De cada 100 notificaciones, ${AdminDispatchRpc.percent(n('vistas'), notifs)} fueron vistas y '
                    '${AdminDispatchRpc.percent(n('respuestas'), notifs)} recibieron respuesta. '
                    '${AdminDispatchRpc.percent(n('concretadas'), requests)} de las solicitudes terminó en viaje.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Por día',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    headingRowHeight: 38,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 40,
                    columns: const [
                      DataColumn(label: Text('Día')),
                      DataColumn(label: Text('Solicitudes'), numeric: true),
                      DataColumn(label: Text('Concretadas'), numeric: true),
                      DataColumn(label: Text('Sin concretar'), numeric: true),
                      DataColumn(label: Text('Sin notificados'), numeric: true),
                      DataColumn(label: Text('Conductores'), numeric: true),
                      DataColumn(label: Text('Notificaciones'), numeric: true),
                      DataColumn(label: Text('Vistas'), numeric: true),
                      DataColumn(label: Text('Respondieron'), numeric: true),
                      DataColumn(label: Text('No respondieron'), numeric: true),
                    ],
                    rows: [
                      for (final d in days)
                        DataRow(cells: [
                          DataCell(Text(_day(d['day']))),
                          DataCell(Text('${d['requests']}')),
                          DataCell(Text('${d['concretadas']}')),
                          DataCell(Text(
                              '${(d['sin_concretar'] as num? ?? 0) + (d['buscando'] as num? ?? 0)}')),
                          DataCell(Text('${d['sin_notificados']}')),
                          DataCell(Text('${d['conductores_notificados']}')),
                          DataCell(Text('${d['notificaciones']}')),
                          DataCell(Text('${d['vistas']}')),
                          DataCell(Text('${d['respuestas']}')),
                          DataCell(Text('${d['ignoradas']}')),
                        ]),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

String _day(Object? raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '');
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}';
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Kpi(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: 190,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      );
}

class _UnservedTab extends StatefulWidget {
  final String channel;
  final String? zoneId;
  const _UnservedTab({required this.channel, required this.zoneId});

  @override
  State<_UnservedTab> createState() => _UnservedTabState();
}

class _UnservedTabState extends State<_UnservedTab> {
  String period = '7d';
  int revision = 0;

  Future<Map<String, dynamic>> _load() async {
    final zone = widget.zoneId;
    if (zone == null || zone.isEmpty) return const {};
    final value = await supabase.rpc(
      AdminDispatchRpc.unserved,
      params: {
        'p_channel': widget.channel,
        'p_zone_id': zone,
        'p_from': AdminDispatchRpc.periodStart(period, DateTime.now())
            .toUtc()
            .toIso8601String(),
        'p_to': null,
        'p_limit': 150,
      },
    );
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  Future<void> _open(Map<String, dynamic> row) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _RequestDriversDialog(channel: widget.channel, request: row),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text('Solicitudes no concretadas',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text(
          'Todo lo que se pidió y no llegó a ser un viaje: cancelado, vencido o todavía buscando conductor. Toca uno para ver quién fue '
          'notificado, quién la vio, quién respondió y a qué distancia estaba.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _PeriodBar(
          period: period,
          onChanged: (v) => setState(() {
            period = v;
            revision++;
          }),
        ),
        const SizedBox(height: 14),
        FutureBuilder<Map<String, dynamic>>(
          key: ValueKey('unserved-$period-$revision'),
          future: _load(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const LinearProgressIndicator();
            }
            if (snap.hasError) return Text(friendlyError(snap.error));
            final data = snap.data ?? const <String, dynamic>{};
            final rows = _rows(data['rows']);
            final total = (data['total'] as num?)?.toInt() ?? 0;
            final none = (data['without_notified'] as num?)?.toInt() ?? 0;
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                      'No hubo solicitudes sin concretar en este periodo.',
                      style: TextStyle(color: _muted)),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _Pill('$total no concretadas', _blue),
                  _Pill('$none sin ningún conductor notificado',
                      none > 0 ? _red : _muted),
                ]),
                const SizedBox(height: 12),
                for (final r in rows)
                  _UnservedCard(row: r, onTap: () => _open(r)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

class _UnservedCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  const _UnservedCard({required this.row, required this.onTap});

  int _n(String k) => (row[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final notified = _n('notified');
    final ignored = _n('ignored');
    final fare = row['proposed_fare'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(_fmt(row['created_at']),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                _Pill(
                    friendlyService(row['category']?.toString() ?? ''), _blue),
                const SizedBox(width: 6),
                _Pill(friendlyStatus(row['status']?.toString() ?? ''), _muted),
                const Spacer(),
                Text('${row['currency'] ?? ''} ${fare ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 6),
              Text(friendlyAddress(row['pickup_address']?.toString() ?? ''),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              Text('Pasajero: ${row['passenger_name'] ?? '—'}',
                  style: const TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _Pill(
                    notified == 0
                        ? 'Ningún conductor notificado'
                        : '$notified notificados',
                    notified == 0 ? _red : _blue),
                _Pill('${_n('viewed')} la vieron', _muted),
                _Pill('${_n('responded')} respondieron', _green),
                if (ignored > 0)
                  _Pill('$ignored la vieron y no respondieron', _red),
                if (_n('unopened') > 0)
                  _Pill('${_n('unopened')} no la abrieron', _muted),
                if (row['min_km'] != null)
                  _Pill('El más cercano: ${_km(row['min_km'])}', _amber),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestDriversDialog extends StatelessWidget {
  final String channel;
  final Map<String, dynamic> request;
  const _RequestDriversDialog({required this.channel, required this.request});

  Future<Map<String, dynamic>> _load() async {
    final value = await supabase.rpc(
      AdminDispatchRpc.drivers,
      params: {'p_channel': channel, 'p_request_id': request['id']},
    );
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conductores de esta solicitud'),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _load(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) return Text(friendlyError(snap.error));
            final drivers = _rows(snap.data?['drivers']);
            if (drivers.isEmpty) {
              return const Text(
                  'A ningún conductor se le notificó esta solicitud: no había conductores disponibles que cumplieran las condiciones.');
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${friendlyAddress(request['pickup_address']?.toString() ?? '')} · '
                    '${_fmt(request['created_at'])}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  for (final d in drivers) _DriverRow(d: d),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar')),
      ],
    );
  }
}

class _DriverRow extends StatelessWidget {
  final Map<String, dynamic> d;
  const _DriverRow({required this.d});

  @override
  Widget build(BuildContext context) {
    final outcome = d['outcome']?.toString();
    final color = AdminDispatchRpc.outcomeColor(outcome);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(d['name']?.toString() ?? 'Conductor',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            _Pill(AdminDispatchRpc.outcomeLabel(outcome), color),
          ]),
          SelectableText(d['phone']?.toString() ?? '',
              style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            'Distancia: ${_km(d['distance_km'])} · Notificado: ${_fmt(d['notified_at'])}'
            '${d['delivered'] == true ? ' (entregada)' : ''} · Vista: ${_fmt(d['viewed_at'])}'
            '${d['offer_fare'] != null ? ' · Ofertó ${d['offer_fare']}' : ''}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DriversTab extends StatefulWidget {
  final String channel;
  final String? zoneId;
  const _DriversTab({required this.channel, required this.zoneId});

  @override
  State<_DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<_DriversTab> {
  String period = '7d';
  int revision = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final zone = widget.zoneId;
    if (zone == null || zone.isEmpty) return const [];
    final value = await supabase.rpc(
      AdminDispatchRpc.stats,
      params: {
        'p_channel': widget.channel,
        'p_zone_id': zone,
        'p_from': AdminDispatchRpc.periodStart(period, DateTime.now())
            .toUtc()
            .toIso8601String(),
        'p_to': null,
        'p_limit': 150,
      },
    );
    return _rows(value);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text('Respuesta de los conductores',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text(
          'Quién recibe, ve y responde las solicitudes. Ordenado por los que más veces la vieron y no respondieron.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _PeriodBar(
          period: period,
          onChanged: (v) => setState(() {
            period = v;
            revision++;
          }),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey('stats-$period-$revision'),
          future: _load(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const LinearProgressIndicator();
            }
            if (snap.hasError) return Text(friendlyError(snap.error));
            final rows = snap.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('Sin datos en este periodo.',
                        style: TextStyle(color: _muted))),
              );
            }
            return Column(
                children: [for (final r in rows) _DriverStatCard(row: r)]);
          },
        ),
      ],
    );
  }
}

class _DriverStatCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _DriverStatCard({required this.row});

  int _n(String k) => (row[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final online = row['online'] == 'online';
    final rate = row['response_rate'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.circle, size: 10, color: online ? _green : _muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(row['name']?.toString() ?? 'Conductor',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15)),
            ),
            Text(rate == null ? '' : '$rate% responde',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          SelectableText(row['phone']?.toString() ?? '',
              style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _Pill('${_n('notified')} notificado', _blue),
            _Pill('${_n('viewed')} la vio', _muted),
            _Pill('${_n('took')} tomó', _green),
            if (_n('declined') > 0) _Pill('${_n('declined')} rechazó', _amber),
            if (_n('ignored') > 0)
              _Pill('${_n('ignored')} la vio y no respondió', _red),
            if (_n('unopened') > 0)
              _Pill('${_n('unopened')} no la abrió', _muted),
            if (row['avg_km'] != null)
              _Pill('Distancia media ${_km(row['avg_km'])}', _amber),
          ]),
        ],
      ),
    );
  }
}
