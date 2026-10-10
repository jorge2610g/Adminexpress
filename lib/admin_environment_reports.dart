import 'package:flutter/material.dart';

import 'core/admin_design_tokens.dart';

import 'core/supabase_client.dart';

const _bg = AdminColors.bg;
const _ink = AdminColors.ink;
const _muted = AdminColors.muted;
const _blue = AdminColors.blue;

/// One reports destination for Express. Production and QA metrics remain
/// separate, clearly labeled datasets; never sum test figures into real KPIs.
class AdminEnvironmentReportsPage extends StatefulWidget {
  const AdminEnvironmentReportsPage({
    super.key,
    required this.includePreview,
    required this.includeProduction,
  });

  final bool includePreview;
  final bool includeProduction;

  @override
  State<AdminEnvironmentReportsPage> createState() =>
      _AdminEnvironmentReportsPageState();
}

class _AdminEnvironmentReportsPageState
    extends State<AdminEnvironmentReportsPage> {
  DateTime from = DateTime.now().subtract(const Duration(days: 30));
  DateTime to = DateTime.now().add(const Duration(days: 1));
  int revision = 0;
  late Future<Map<String, Map<String, dynamic>>> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _load();
  }

  @override
  void didUpdateWidget(covariant AdminEnvironmentReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.includePreview != widget.includePreview ||
        oldWidget.includeProduction != widget.includeProduction) {
      _reportFuture = _load();
    }
  }

  void _refresh() {
    setState(() {
      revision++;
      _reportFuture = _load();
    });
  }

  Future<Map<String, Map<String, dynamic>>> _load() async {
    final channels = <String>[
      if (widget.includeProduction) 'production',
      if (widget.includePreview) 'preview',
    ];
    if (channels.isEmpty) return const {};
    // Exactly one query per accessible environment, concurrently; data for
    // production and test must never be merged or presented as one total.
    final responses = await Future.wait(channels.map((channel) =>
        supabase.rpc('admin_report_summary_v2', params: {
          'p_channel': channel,
          'p_from': from.toUtc().toIso8601String(),
          'p_to': to.toUtc().toIso8601String(),
        })));
    return {
      for (var i = 0; i < channels.length; i++)
        channels[i]: responses[i] is Map
            ? Map<String, dynamic>.from(responses[i] as Map)
            : <String, dynamic>{},
    };
  }

  Future<void> _pickFrom() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: from,
    );
    if (date != null && mounted) {
      setState(() {
        from = date;
        revision++;
        _reportFuture = _load();
      });
    }
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now.add(const Duration(days: 1)),
      initialDate: to.isAfter(now) ? now : to,
    );
    if (date != null && mounted) {
      setState(() {
        to = date.add(const Duration(days: 1));
        revision++;
        _reportFuture = _load();
      });
    }
  }

  String _date(DateTime value) => value.day.toString().padLeft(2, '0') +
      '/' + value.month.toString().padLeft(2, '0') + '/' + value.year.toString();

  Widget _metrics(Map<String, dynamic> data) {
    final entries = <(String, Object?, IconData)>[
      ('Viajes', data['trips_total'], Icons.local_taxi_rounded),
      ('Completados', data['trips_completed'], Icons.task_alt_rounded),
      ('Cancelados', data['trips_cancelled'], Icons.cancel_outlined),
      ('Delivery', data['delivery_total'], Icons.local_shipping_rounded),
      ('Delivery completados', data['delivery_completed'], Icons.inventory_2_outlined),
      ('Delivery cancelados', data['delivery_cancelled'], Icons.remove_shopping_cart_outlined),
      ('Cobrado', data['paid_volume'], Icons.payments_outlined),
      ('Usuarios nuevos', data['new_users'], Icons.person_add_alt_1_rounded),
      ('Emergencias', data['emergencies'], Icons.sos_rounded),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width < 650
            ? width
            : width < 1000
                ? (width - 12) / 2
                : (width - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: entries.map((item) => SizedBox(
            width: cardWidth,
            child: Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AdminColors.blueSoft,
                      child: Icon(item.$3, color: _blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((item.$2 ?? 0).toString(),
                              style: const TextStyle(
                                color: _ink, fontSize: 20,
                                fontWeight: FontWeight.w900)),
                          Text(item.$1, style: const TextStyle(color: _muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _channelReport(String channel, Map<String, dynamic> data) {
    final isTest = channel == 'preview';
    final accent = isTest ? AdminColors.warn : AdminColors.ok;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isTest ? AdminColors.warnSoft : AdminColors.okSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(isTest ? Icons.science_rounded : Icons.verified_rounded,
                color: accent),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isTest ? 'Actividad de pruebas internas'
                              : 'Actividad real de Express',
                      style: TextStyle(color: accent,
                          fontSize: 15, fontWeight: FontWeight.w900)),
                  Text(
                    isTest
                        ? 'Datos QA separados: no se suman a los resultados reales.'
                        : 'Datos reales de clientes y operaciones.',
                    style: const TextStyle(color: _ink, fontSize: 12),
                  ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _metrics(data),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: FutureBuilder<Map<String, Map<String, dynamic>>>(
        key: ValueKey(revision),
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('Reintentar: ' + snapshot.error.toString()),
              ),
            );
          }
          final reports = snapshot.data ?? const <String, Map<String, dynamic>>{};
          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const Text('Reportes', style: TextStyle(
                color: _ink, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text(
                'Resumen general de Express. Una sola pantalla, sin cambiar '
                'el modo del panel ni seleccionar país o zona.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickFrom,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text('Desde ' + _date(from)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickTo,
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: Text('Hasta ' + _date(to.subtract(const Duration(days: 1)))),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (reports.isEmpty)
                const Card(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No hay entornos autorizados para consultar reportes.'),
                )),
              for (final item in reports.entries)
                _channelReport(item.key, item.value),
            ],
          );
        },
      ),
    );
  }
}
