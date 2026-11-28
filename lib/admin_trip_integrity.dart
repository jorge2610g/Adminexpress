import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'core/admin_friendly_error.dart';
import 'core/admin_friendly_labels.dart';
import 'admin_detail_dialogs.dart' show showAdminTripDetail;
import 'core/supabase_client.dart';

/// Motivos de una irregularidad, en español claro para quien revisa.
const Map<String, String> _reasonLabels = {
  'termino_antes_de_lo_previsto': 'Terminó antes de lo previsto',
  'inicio_lejos_del_origen': 'Empezó lejos del punto de origen',
  'fin_lejos_del_destino': 'Terminó lejos del destino',
  'recorrido_mucho_menor_a_la_ruta': 'Recorrió mucho menos que la ruta',
  'velocidad_imposible': 'Velocidad imposible (salto de ubicación)',
  'origen_y_destino_casi_iguales': 'Origen y destino casi iguales',
  'misma_pareja_repetida': 'Mismo pasajero repetido muchas veces',
  'muchos_viajes_cortos_seguidos': 'Muchos viajes cortos seguidos',
  'en_curso_muy_corto':
      'Viaje en curso de menos de 90 segundos con una ruta de más de 500 m',
  'sin_movimiento_gps':
      'El conductor casi no se movió (menos de 100 m) en un viaje de más de 500 m',
  'viaje_historico_muy_corto':
      'Terminó en menos de 5 minutos con una distancia larga (revisión del historial)',
};

String _reasonLabel(String key) {
  final known = _reasonLabels[key];
  if (known != null) return known;
  // Un código nuevo sin traducir no debe verse crudo: se muestra legible.
  final text = key.replaceAll('_', ' ').trim();
  return text.isEmpty ? key : text[0].toUpperCase() + text.substring(1);
}

String _statusLabel(String status) => switch (status) {
      'open' => 'Por revisar',
      'cleared' => 'Descartado',
      'confirmed' => 'Confirmado',
      _ => status,
    };

/// Viajes marcados por el sistema al completarse (recorrido, tiempo y patrones).
/// Los viajes «por revisar» y «confirmados» no suman al Campeonato Express.
class AdminTripIntegrityPage extends StatefulWidget {
  const AdminTripIntegrityPage({
    super.key,
    required this.channel,
    required this.zoneId,
    this.canEdit = true,
  });

  final String channel;
  final String? zoneId;
  final bool canEdit;

  @override
  State<AdminTripIntegrityPage> createState() => _AdminTripIntegrityPageState();
}

class _AdminTripIntegrityPageState extends State<AdminTripIntegrityPage> {
  String _status = 'open';
  String _section = 'trips';
  String _notificationFilter = 'all';
  late Future<List<Map<String, dynamic>>> _future;
  late Future<List<Map<String, dynamic>>> _driversFuture;
  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant AdminTripIntegrityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel ||
        oldWidget.zoneId != widget.zoneId) {
      setState(_reload);
    }
  }

  void _reload() {
    _driversFuture = () async {
      if (widget.zoneId == null) return <Map<String, dynamic>>[];
      final raw = await supabase.rpc('admin_driver_integrity_list', params: {
        'p_zone_id': widget.zoneId,
        'p_channel': widget.channel,
      });
      return raw is List
          ? raw.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList()
          : <Map<String, dynamic>>[];
    }();
    _future = () async {
      if (widget.zoneId == null) return <Map<String, dynamic>>[];
      final raw = await supabase.rpc('admin_trip_integrity_list', params: {
        'p_zone_id': widget.zoneId,
        'p_channel': widget.channel,
        'p_status': _status,
      });
      return raw is List
          ? raw
              .whereType<Map>()
              .map((x) => Map<String, dynamic>.from(x))
              .toList()
          : <Map<String, dynamic>>[];
    }();
    _notificationsFuture = () async {
      if (widget.zoneId == null) return <Map<String, dynamic>>[];
      final raw = await supabase.rpc('admin_trip_integrity_notifications', params: {
        'p_zone_id': widget.zoneId,
        'p_channel': widget.channel,
      });
      return raw is List
          ? raw.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList()
          : <Map<String, dynamic>>[];
    }();
  }

  Future<List<Map<String, dynamic>>>? _umbrellaFuture;

  Future<List<Map<String, dynamic>>> _loadUmbrella() async {
    final raw = await supabase.rpc('admin_moto_comfort_reports_v1', params: {
      'p_zone_id': widget.zoneId,
      'p_channel': widget.channel,
    });
    return raw is List
        ? raw.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList()
        : <Map<String, dynamic>>[];
  }

  Future<void> _dismissUmbrella(String reportId, bool dismissed) async {
    try {
      await supabase.rpc('admin_moto_umbrella_dismiss_v1',
          params: {'p_report_id': reportId, 'p_dismissed': dismissed});
      if (!mounted) return;
      setState(() => _umbrellaFuture = _loadUmbrella());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(dismissed
              ? 'Reporte descartado: no cuenta como oportunidad.'
              : 'Reporte restaurado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: ${friendlyError(e)}')));
    }
  }

  static String _reportDate(Object? raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _setComfortBlocked(String driverId, bool blocked) async {
    try {
      await supabase.rpc('admin_moto_comfort_set_blocked_v1',
          params: {'p_driver_id': driverId, 'p_blocked': blocked});
      if (!mounted) return;
      setState(() => _umbrellaFuture = _loadUmbrella());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(blocked
              ? 'Moto Confort quitado al conductor.'
              : 'Moto Confort habilitado de nuevo.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: ${friendlyError(e)}')));
    }
  }

  Widget _umbrellaPage() {
    _umbrellaFuture ??= _loadUmbrella();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _umbrellaFuture,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Row(children: [
              const Icon(Icons.beach_access_outlined,
                  color: Color(0xFF2563EB), size: 30),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reportes de sombrilla',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w900)),
                      Text(
                          'Moto Confort: conductores que lo usan y reportes de pasajeros que dijeron que no había sombrilla. Cada día con reporte gasta una oportunidad (3); con el cuarto queda inhabilitado hasta que soporte lo habilite.',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF667085))),
                    ]),
              ),
              IconButton(
                  tooltip: 'Actualizar',
                  onPressed: () =>
                      setState(() => _umbrellaFuture = _loadUmbrella()),
                  icon: const Icon(Icons.refresh)),
            ]),
            _sectionPicker(),
            if (snapshot.connectionState != ConnectionState.done)
              const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()))
            else if (snapshot.hasError)
              Text('No se pudo cargar: ${friendlyError(snapshot.error)}')
            else if (rows.isEmpty)
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                          'Todavía no hay conductores en Moto Confort ni reportes.')))
            else
              for (final row in rows)
                Card(
                  child: ExpansionTile(
                    leading: Icon(
                        row['blocked'] == true
                            ? Icons.block
                            : Icons.beach_access_outlined,
                        color: row['blocked'] == true
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF2563EB)),
                    title: Text(row['name']?.toString() ?? 'Conductor'),
                    subtitle: Text(
                        'Viajes Confort: ${row['comfort_trips'] ?? 0} · '
                        'Oportunidades usadas: ${row['strikes'] ?? 0} de 3 · '
                        '${row['blocked'] == true ? 'Inhabilitado: debe contactar a soporte' : row['suspended_until'] != null ? 'Suspendido hasta mañana 6:00' : row['mode'] == 'comfort' ? 'Conectado como Confort' : 'Económico'}'),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      if ((row['reports'] as List? ?? const []).isEmpty)
                        const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Sin reportes de «sin sombrilla».'))
                      else
                        for (final rep in (row['reports'] as List))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                'Reporte del ${_reportDate((rep as Map)['created_at'])}'
                                '${rep['dismissed'] == true ? ' · descartado' : ''}',
                                style: TextStyle(
                                    decoration: rep['dismissed'] == true
                                        ? TextDecoration.lineThrough
                                        : null)),
                            trailing: widget.canEdit
                                ? TextButton(
                                    onPressed: () => _dismissUmbrella(
                                        rep['id'].toString(),
                                        rep['dismissed'] != true),
                                    child: Text(rep['dismissed'] == true
                                        ? 'Restaurar'
                                        : 'Descartar reporte'))
                                : null,
                          ),
                      if (widget.canEdit)
                        Align(
                          alignment: Alignment.centerRight,
                          child: row['blocked'] == true
                              ? OutlinedButton(
                                  onPressed: () => _setComfortBlocked(
                                      row['driver_id'].toString(), false),
                                  child: const Text('Habilitar de nuevo'))
                              : FilledButton(
                                  onPressed: () => _setComfortBlocked(
                                      row['driver_id'].toString(), true),
                                  child: const Text('Quitar Confort')),
                        ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _sectionPicker() => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 12),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'trips',
                icon: Icon(Icons.policy_outlined),
                label: Text('Viajes sospechosos')),
            ButtonSegment(
                value: 'notifications',
                icon: Icon(Icons.notifications_active_outlined),
                label: Text('Notificaciones')),
            ButtonSegment(
                value: 'umbrella',
                icon: Icon(Icons.beach_access_outlined),
                label: Text('Sombrillas (Moto Confort)')),
          ],
          selected: {_section},
          onSelectionChanged: (selection) =>
              setState(() => _section = selection.first),
        ),
      );

  static String _alertLabel(Object? raw) => switch (raw?.toString()) {
        'trip_integrity_warning' => 'Aviso por irregularidad',
        'trip_integrity_suspension' => 'Suspensión',
        'trip_integrity_review' => 'Cuenta en revisión',
        'trip_integrity_cleared' => 'Aviso actualizado',
        _ => 'Alerta automática',
      };

  Widget _notificationsPage() => FutureBuilder<List<Map<String, dynamic>>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          final allRows = snapshot.data ?? const <Map<String, dynamic>>[];
          final rows = allRows.where((row) {
            if (_notificationFilter == 'unread') return row['is_read'] != true;
            if (_notificationFilter == 'read') return row['is_read'] == true;
            return true;
          }).toList();
          final unread = allRows.where((row) => row['is_read'] != true).length;
          final notifiedDrivers = allRows
              .map((row) => row['driver_id']?.toString())
              .whereType<String>()
              .toSet()
              .length;
          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(children: [
                const Icon(Icons.policy_outlined,
                    color: Color(0xFF2563EB), size: 30),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Viajes sospechosos',
                        style: TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w900)),
                    Text(
                        'Revisa las alertas personales que recibieron los conductores y si ya las leyeron.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF667085))),
                  ]),
                ),
                IconButton(
                    tooltip: 'Actualizar',
                    onPressed: () => setState(_reload),
                    icon: const Icon(Icons.refresh_rounded)),
              ]),
              _sectionPicker(),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator()))
              else if (snapshot.hasError)
                Text('No se pudieron cargar las notificaciones: ${friendlyError(snapshot.error)}')
              else ...[
                Wrap(spacing: 10, runSpacing: 8, children: [
                  _notificationMetric('Conductores avisados', '$notifiedDrivers',
                      Icons.person_outline_rounded),
                  _notificationMetric('Alertas registradas', '${allRows.length}',
                      Icons.notifications_active_outlined),
                  _notificationMetric('Pendientes de lectura', '$unread',
                      Icons.mark_email_unread_outlined),
                  _notificationMetric('Leídas', '${allRows.length - unread}',
                      Icons.mark_email_read_outlined),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  for (final item in const [
                    ('all', 'Todas'),
                    ('unread', 'No leídas'),
                    ('read', 'Leídas'),
                  ])
                    ChoiceChip(
                      label: Text(item.$2),
                      selected: _notificationFilter == item.$1,
                      onSelected: (_) =>
                          setState(() => _notificationFilter = item.$1),
                    ),
                ]),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(allRows.isEmpty
                          ? 'Todavía no hay alertas personales para conductores en esta zona y entorno.'
                          : 'No hay notificaciones en este filtro.'),
                    ),
                  )
                else
                  for (final row in rows) _notificationCard(row),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                      'El registro confirma que la alerta quedó en la app. El estado indica si el conductor la leyó; no representa una confirmación de entrega push.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
                ),
              ],
            ],
          );
        },
      );

  Widget _notificationMetric(String label, String value, IconData icon) =>
      SizedBox(
        width: 190,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icon, color: const Color(0xFF2563EB)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF667085))),
                Text(value,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w900)),
              ])),
            ]),
          ),
        ),
      );

  Widget _notificationCard(Map<String, dynamic> row) {
    final read = row['is_read'] == true;
    final tripId = row['trip_id']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(row['driver_name']?.toString() ?? 'Conductor',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            Chip(
              label: Text(read ? 'Leída' : 'Pendiente de lectura'),
              avatar: Icon(read ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                  size: 16),
              visualDensity: VisualDensity.compact,
            ),
            Chip(
              label: Text(_alertLabel(row['alert_kind'])),
              visualDensity: VisualDensity.compact,
            ),
            Text(_when(row['created_at']),
                style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
          ]),
          const SizedBox(height: 4),
          Text(row['title']?.toString() ?? 'Alerta de viaje',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if ((row['body']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(row['body'].toString()),
            ),
          if (tripId != null && tripId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Viaje: $tripId',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF667085))),
            ),
        ]),
      ),
    );
  }

  static String _when(Object? raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  static String _money(Object? amount, Object? currency) {
    final n = amount is num ? amount : num.tryParse(amount?.toString() ?? '');
    if (n == null) return '—';
    final c = (currency?.toString() ?? '').toUpperCase();
    final text = n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
    return (c == 'CLP' ? '\$ ' : c == 'BOB' ? 'Bs ' : '') + text;
  }

  Future<void> _driverAction(Map<String, dynamic> d, String action) async {
    final controller = TextEditingController();
    final days = TextEditingController(text: '7');
    final title = switch (action) {
      'suspend_days' => 'Suspender conductor',
      'reset' => 'Reiniciar avisos',
      'lift' => 'Levantar suspensión',
      'disable' => 'Inhabilitar permanentemente',
      _ => 'Acción',
    };
    final text = switch (action) {
      'suspend_days' => 'El conductor no podrá conectarse durante los días que indiques y recibirá un aviso.',
      'reset' => 'Los avisos vuelven a cero y empieza de nuevo el ciclo de 3 avisos.',
      'lift' => 'El conductor podrá conectarse de inmediato.',
      'disable' => 'La cuenta queda suspendida de forma permanente (estado «suspendido»). Puedes revertirlo desde la ficha del conductor.',
      _ => '',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$title · ${d['driver_name']}'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text),
            if (action == 'suspend_days') ...[
              const SizedBox(height: 12),
              TextField(
                controller: days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Días de suspensión'),
              ),
            ],
            if (action == 'suspend_days') ...[
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Mensaje para el conductor (opcional)'),
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action == 'disable' ? 'Inhabilitar' : 'Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      if (action == 'disable') {
        await supabase.rpc('admin_set_driver_approval_v2', params: {
          'p_user_id': d['driver_id'],
          'p_status': 'suspended',
          'p_channel': widget.channel,
        });
      } else {
        await supabase.rpc('admin_driver_integrity_action', params: {
          'p_driver_id': d['driver_id'],
          'p_action': action,
          'p_days': action == 'suspend_days' ? int.tryParse(days.text.trim()) : null,
          'p_note': controller.text.trim(),
        });
      }
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listo.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo aplicar: ${friendlyError(e)}')));
      }
    }
  }

  Widget _driversSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _driversFuture,
      builder: (context, snap) {
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        if (snap.connectionState != ConnectionState.done || rows.isEmpty) {
          return const SizedBox.shrink();
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.person_off_outlined, color: Color(0xFFB42318)),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Conductores con avisos y sanciones',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 4),
              const Text(
                  'Ciclo 1: 3 avisos y luego 1 día de suspensión. Ciclo 2: 3 avisos más y luego revisión tuya. '
                  'Los de «En revisión» esperan tu decisión.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
              const SizedBox(height: 8),
              for (final d in rows) _driverTile(d),
            ]),
          ),
        );
      },
    );
  }

  Widget _driverTile(Map<String, dynamic> d) {
    final cycle = (d['cycle'] as num?)?.toInt() ?? 1;
    final suspended = d['suspended'] == true;
    final under = cycle >= 3;
    final until = _when(d['suspended_until']);
    final status = under
        ? 'En revisión: espera tu decisión'
        : suspended
            ? 'Suspendido hasta $until'
            : 'Ciclo $cycle · ${d['warnings']} de 3 avisos';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: under ? const Color(0xFFFDA29B) : const Color(0xFFE4E7EC)),
        color: under ? const Color(0xFFFEF3F2) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(d['driver_name']?.toString() ?? 'Conductor',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          Text(status,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: under ? const Color(0xFFB42318) : const Color(0xFF475467))),
        ]),
        if (d['approval_status'] == 'suspended')
          const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Cuenta inhabilitada', style: TextStyle(color: Color(0xFFB42318)))),
        if (widget.canEdit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              OutlinedButton(
                  onPressed: () => _driverAction(d, 'suspend_days'), child: const Text('Suspender días')),
              if (suspended)
                OutlinedButton(
                    onPressed: () => _driverAction(d, 'lift'), child: const Text('Levantar suspensión')),
              OutlinedButton(
                  onPressed: () => _driverAction(d, 'reset'), child: const Text('Reiniciar avisos')),
              if (d['approval_status'] != 'suspended')
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
                    onPressed: () => _driverAction(d, 'disable'),
                    child: const Text('Inhabilitar permanentemente')),
            ]),
          ),
      ]),
    );
  }

  Future<void> _review(Map<String, dynamic> flag, String decision) async {
    final controller = TextEditingController();
    final confirm = decision == 'confirmed';
    final undo = !confirm && flag['review_status'] == 'confirmed';
    // Volver a confirmar una irregularidad que se había descartado.
    final redo = confirm && flag['review_status'] == 'cleared';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(confirm
            ? (redo ? 'Volver a confirmar la irregularidad' : 'Confirmar irregularidad')
            : undo
                ? 'Corregir: el viaje sí fue normal'
                : 'Descartar aviso'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(confirm
                  ? (redo
                      ? 'El viaje vuelve a quedar confirmado como irregular y no suma al campeonato. Si al descartarlo se había levantado una advertencia, vuelve a contarse. Una suspensión no se reaplica sola: si corresponde, aplícala desde las acciones del conductor.'
                      : 'El viaje queda confirmado como irregular y no suma al campeonato.')
                  : undo
                      ? 'Se deshace la confirmación: el viaje queda como normal, vuelve a sumar al campeonato y se revierte el aviso o la sanción que generó (si se suspendió al conductor, se levanta y se le avisa).'
                      : 'El viaje queda como normal y vuelve a sumar al campeonato.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirm
                  ? (redo ? 'Sí, confirmar' : 'Confirmar')
                  : undo
                      ? 'Sí, descartar'
                      : 'Descartar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await supabase.rpc('admin_trip_integrity_review', params: {
        'p_flag_id': flag['id'],
        'p_decision': decision,
        'p_note': controller.text.trim(),
      });
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(confirm
              ? (redo ? 'Irregularidad confirmada de nuevo.' : 'Irregularidad confirmada.')
              : undo
                  ? 'Confirmación deshecha: el viaje quedó como normal.'
                  : 'Aviso descartado.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo guardar: ${friendlyError(e)}')));
      }
    }
  }

  Future<void> _showTrail(Map<String, dynamic> flag) async {
    final future = () async {
      final raw = await supabase.rpc('admin_trip_integrity_trail',
          params: {'p_flag_id': flag['id']});
      return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    }();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Recorrido de ${flag['driver_name'] ?? 'conductor'}'),
        content: SizedBox(
          width: 640,
          height: 460,
          child: FutureBuilder<Map<String, dynamic>>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Text('No se pudo cargar el recorrido: ${friendlyError(snap.error)}');
              }
              return _TrailMap(data: snap.data ?? const {});
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  /// Redondea a 2 decimales y quita ceros sobrantes (3.1290999999 → 3.13).
  static String _n(Object? v) {
    final d = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    if (d == null) return v?.toString() ?? '—';
    return d.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Widget _metricLine(Map<String, dynamic> m) {
    final parts = <String>[];
    if (m['minutos_reales'] != null) {
      parts.add('Duró ${_n(m['minutos_reales'])} min (estimado ${m['minutos_estimados'] ?? '—'} min)');
    }
    if (m['km_recorridos'] != null && m['sin_recorrido'] != true) {
      parts.add('Recorrió ${_n(m['km_recorridos'])} km (ruta ${_n(m['km_ruta'])} km)');
    }
    if (m['metros_fin_vs_destino'] != null && m['sin_recorrido'] != true) {
      parts.add('Terminó a ${m['metros_fin_vs_destino']} m del destino');
    }
    if (m['velocidad_maxima_kmh'] != null && (m['velocidad_maxima_kmh'] as num) > 0) {
      parts.add('Velocidad máx. ${_n(m['velocidad_maxima_kmh'])} km/h');
    }
    if (m['velocidad_implicita_kmh'] != null) {
      parts.add('Velocidad implícita ${_n(m['velocidad_implicita_kmh'])} km/h '
          '(${_n(m['km_ruta'])} km en ${_n(m['minutos_reales'])} min)');
    }
    if (m['sin_recorrido'] == true) {
      parts.add('Sin recorrido GPS guardado');
    }
    return Text(parts.join(' · '),
        style: const TextStyle(fontSize: 12, color: Color(0xFF667085)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.zoneId == null) {
      return const Center(child: Text('Selecciona una ciudad para continuar.'));
    }
    if (_section == 'notifications') return _notificationsPage();
    if (_section == 'umbrella') return _umbrellaPage();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Row(children: [
              const Icon(Icons.policy_outlined, color: Color(0xFF2563EB), size: 30),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Viajes sospechosos',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  Text(
                      'Viajes que terminaron antes de lo previsto, fuera de ruta o con patrones repetidos. '
                      'Mientras no se revisen, no suman al Campeonato Express.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
                ]),
              ),
              IconButton(
                  tooltip: 'Actualizar',
                  onPressed: () => setState(_reload),
                  icon: const Icon(Icons.refresh_rounded)),
            ]),
            _sectionPicker(),
            const SizedBox(height: 12),
            _driversSection(),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final s in const ['open', 'confirmed', 'cleared', 'all'])
                ChoiceChip(
                  label: Text(s == 'all' ? 'Todos' : _statusLabel(s)),
                  selected: _status == s,
                  onSelected: (_) => setState(() {
                    _status = s;
                    _reload();
                  }),
                ),
            ]),
            const SizedBox(height: 14),
            if (snapshot.connectionState != ConnectionState.done)
              const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()))
            else if (snapshot.hasError)
              Text('No se pudieron cargar los viajes: ${friendlyError(snapshot.error)}')
            else if (rows.isEmpty)
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No hay viajes en esta lista.')))
            else
              for (final f in rows) _flagCard(f),
          ],
        );
      },
    );
  }

  Widget _flagCard(Map<String, dynamic> f) {
    final high = f['severity'] == 'high';
    final reasons = (f['reasons'] is List)
        ? (f['reasons'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final metrics = f['metrics'] is Map
        ? Map<String, dynamic>.from(f['metrics'] as Map)
        : <String, dynamic>{};
    final open = f['review_status'] == 'open';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Chip(
              label: Text(high ? 'Prioridad alta' : 'Prioridad media',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: high ? const Color(0xFFB42318) : const Color(0xFFB54708))),
              backgroundColor:
                  high ? const Color(0xFFFEE4E2) : const Color(0xFFFEF0C7),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(_statusLabel(f['review_status']?.toString() ?? '')),
              visualDensity: VisualDensity.compact,
            ),
            const Spacer(),
            Text(_when(f['completed_at']),
                style: const TextStyle(color: Color(0xFF667085), fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          Text('${f['driver_name'] ?? 'Conductor'} · ${friendlyService(f['service_key']?.toString() ?? '')}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          Text('Pasajero: ${f['passenger_name'] ?? '—'} · ${_money(f['fare'], f['currency'])}',
              style: const TextStyle(color: Color(0xFF475467))),
          const SizedBox(height: 4),
          Text('${f['pickup'] ?? '—'}  →  ${f['destination'] ?? '—'}',
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in reasons)
              Chip(
                avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                label: Text(_reasonLabel(r), style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
              ),
          ]),
          const SizedBox(height: 6),
          _metricLine(metrics),
          if ((f['open_flags_driver'] as num? ?? 0) > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  'Este conductor tiene ${f['open_flags_driver']} viajes por revisar.',
                  style: const TextStyle(
                      color: Color(0xFFB42318), fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          if ((f['review_note']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Nota: ${f['review_note']}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475467))),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            OutlinedButton.icon(
                onPressed: f['trip_id'] == null
                    ? null
                    : () => showAdminTripDetail(
                        context, f['trip_id'].toString(),
                        channel: widget.channel),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver viaje completo')),
            OutlinedButton.icon(
                onPressed: () => _showTrail(f),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver recorrido')),
            if (widget.canEdit && open) ...[
              OutlinedButton.icon(
                  onPressed: () => _review(f, 'cleared'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Descartar')),
              FilledButton.icon(
                  onPressed: () => _review(f, 'confirmed'),
                  icon: const Icon(Icons.gpp_bad_outlined),
                  label: const Text('Confirmar irregularidad')),
            ],
            if (widget.canEdit && f['review_status'] == 'confirmed')
              OutlinedButton.icon(
                  onPressed: () => _review(f, 'cleared'),
                  icon: const Icon(Icons.undo),
                  label: const Text('Descartar (fue un error)')),
            if (widget.canEdit && f['review_status'] == 'cleared')
              FilledButton.icon(
                  onPressed: () => _review(f, 'confirmed'),
                  icon: const Icon(Icons.gpp_bad_outlined),
                  label: const Text('Volver a confirmar')),
          ]),
        ]),
      ),
    );
  }
}

/// Mapa con el origen, el destino y el recorrido real del conductor.
class _TrailMap extends StatelessWidget {
  const _TrailMap({required this.data});
  final Map<String, dynamic> data;

  static double? _d(Object? v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  @override
  Widget build(BuildContext context) {
    final points = (data['points'] is List)
        ? (data['points'] as List).whereType<Map>().toList()
        : <Map>[];
    final trip = <LatLng>[];
    final approach = <LatLng>[];
    for (final p in points) {
      final lat = _d(p['lat']);
      final lng = _d(p['lng']);
      if (lat == null || lng == null) continue;
      (p['status'] == 'in_progress' ? trip : approach).add(LatLng(lat, lng));
    }
    final pickup = data['pickup'] is Map ? Map<String, dynamic>.from(data['pickup'] as Map) : <String, dynamic>{};
    final dest = data['destination'] is Map ? Map<String, dynamic>.from(data['destination'] as Map) : <String, dynamic>{};
    final pickupPoint = (_d(pickup['lat']) != null && _d(pickup['lng']) != null)
        ? LatLng(_d(pickup['lat'])!, _d(pickup['lng'])!)
        : null;
    final destPoint = (_d(dest['lat']) != null && _d(dest['lng']) != null)
        ? LatLng(_d(dest['lat'])!, _d(dest['lng'])!)
        : null;
    final all = [...approach, ...trip, if (pickupPoint != null) pickupPoint, if (destPoint != null) destPoint];
    if (all.isEmpty) {
      return const Center(child: Text('Este viaje no tiene recorrido guardado.'));
    }
    final options = all.length >= 2
        ? MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(all),
              padding: const EdgeInsets.all(48),
              maxZoom: 17,
            ),
          )
        : MapOptions(initialCenter: all.first, initialZoom: 15);
    return Column(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FlutterMap(
            options: options,
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.express.admin',
              ),
              PolylineLayer(polylines: [
                if (approach.length >= 2)
                  Polyline(points: approach, strokeWidth: 3, color: const Color(0xFF98A2B3)),
                if (trip.length >= 2)
                  Polyline(points: trip, strokeWidth: 5, color: const Color(0xFF2563EB)),
                if (pickupPoint != null && destPoint != null)
                  Polyline(
                      points: [pickupPoint, destPoint],
                      strokeWidth: 2,
                      color: const Color(0x66D92D20)),
              ]),
              MarkerLayer(markers: [
                if (pickupPoint != null)
                  Marker(
                      point: pickupPoint,
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.trip_origin_rounded,
                          color: Color(0xFF16A34A), size: 30)),
                if (destPoint != null)
                  Marker(
                      point: destPoint,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on_rounded,
                          color: Color(0xFFD92D20), size: 36)),
                if (trip.isNotEmpty)
                  Marker(
                      point: trip.last,
                      width: 28,
                      height: 28,
                      child: const Icon(Icons.flag_rounded,
                          color: Color(0xFF101828), size: 24)),
              ]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
          'Verde: origen · Rojo: destino · Azul: recorrido real con pasajero · Gris: camino hacia el origen · '
          'Línea roja tenue: recta origen–destino · Bandera: dónde terminó',
          style: TextStyle(fontSize: 11, color: Color(0xFF667085))),
    ]);
  }
}
