import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const _bg = Color(0xFFF1F5F9);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _blue = Color(0xFF2563EB);

class AdminEnvironmentReportsPage extends StatefulWidget {
  final String channel;

  const AdminEnvironmentReportsPage({
    super.key,
    required this.channel,
  });

  @override
  State<AdminEnvironmentReportsPage> createState() =>
      _AdminEnvironmentReportsPageState();
}

class _AdminEnvironmentReportsPageState
    extends State<AdminEnvironmentReportsPage> {
  DateTime from = DateTime.now().subtract(const Duration(days: 30));
  DateTime to = DateTime.now().add(const Duration(days: 1));
  int revision = 0;

  Future<Map<String, dynamic>> _load() async {
    final value = await supabase.rpc(
      'admin_report_summary_v2',
      params: {
        'p_channel': widget.channel,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      },
    );
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  Future<void> _pickFrom() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: from,
    );
    if (value != null) {
      setState(() {
        from = value;
        revision++;
      });
    }
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now.add(const Duration(days: 1)),
      initialDate: to.isAfter(now) ? now : to,
    );
    if (value != null) {
      setState(() {
        to = value.add(const Duration(days: 1));
        revision++;
      });
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';

  @override
  Widget build(BuildContext context) {
    final preview = widget.channel == 'preview';
    return ColoredBox(
      color: _bg,
      child: FutureBuilder<Map<String, dynamic>>(
        key: ValueKey('${widget.channel}-$revision'),
        future: _load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => setState(() => revision++),
                icon: const Icon(Icons.refresh_rounded),
                label: Text('Reintentar: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reportes',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preview
                              ? 'Solo métricas Preview / QA.'
                              : 'Solo métricas reales de Producción.',
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: preview
                          ? const Color(0xFFFFF7E6)
                          : const Color(0xFFE8F8EF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      preview ? 'PRUEBA' : 'PRODUCCIÓN',
                      style: TextStyle(
                        color: preview
                            ? const Color(0xFFB54708)
                            : const Color(0xFF14804A),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickFrom,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text('Desde ${_date(from)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickTo,
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: Text('Hasta ${_date(to.subtract(const Duration(days: 1)))}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => revision++),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final cardWidth = width < 650
                      ? width
                      : width < 1000
                          ? (width - 12) / 2
                          : (width - 36) / 4;
                  final cards = <(String, Object?, IconData)>[
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
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards
                        .map(
                          (item) => SizedBox(
                            width: cardWidth,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          const Color(0xFFEAF2FF),
                                      child: Icon(item.$3, color: _blue),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (item.$2 ?? 0).toString(),
                                            style: const TextStyle(
                                              color: _ink,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            item.$1,
                                            style:
                                                const TextStyle(color: _muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
