import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const _bg = Color(0xFFF1F5F9);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

/// One chronological audit trail for Express. Entries retain their origin
/// so QA actions are never mistaken for real Production operations.
class AdminEnvironmentAuditPage extends StatefulWidget {
  const AdminEnvironmentAuditPage({
    super.key,
    required this.includePreview,
    required this.includeProduction,
  });

  final bool includePreview;
  final bool includeProduction;

  @override
  State<AdminEnvironmentAuditPage> createState() =>
      _AdminEnvironmentAuditPageState();
}

class _AdminEnvironmentAuditPageState extends State<AdminEnvironmentAuditPage> {
  int revision = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final channels = <String>[
      if (widget.includeProduction) 'production',
      if (widget.includePreview) 'preview',
    ];
    if (channels.isEmpty) return const [];
    // Both streams are read only. The DB checks access for each environment.
    // Fetch in parallel and merge only for display, retaining origin.
    final results = await Future.wait(channels.map((channel) =>
        supabase.rpc('admin_audit_list_v2', params: {
          'p_channel': channel,
          'p_limit': 200,
        })));
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < channels.length; i++) {
      final result = results[i];
      if (result is! List) {
        throw StateError('Respuesta de auditoría no válida');
      }
      for (final raw in result.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        rows.add({...row, 'source_channel': channels[i]});
      }
    }
    rows.sort((a, b) => (DateTime.tryParse(
          b['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0)));
    return rows.take(300).toList(growable: false);
  }

  String _date(Object? raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (value == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return two(value.day) + '/' + two(value.month) + '/' +
        value.year.toString() + ' · ' +
        two(value.hour) + ':' + two(value.minute);
  }

  String _label(Map<String, dynamic> row) {
    final action = row['action']?.toString() ?? 'acción';
    final entity = row['entity_type']?.toString() ?? 'registro';
    if (entity == 'environment_config') {
      return 'Configuración de pruebas internas actualizada';
    }
    return action.replaceAll('_', ' ') + ' · ' + entity.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(revision),
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => setState(() => revision++),
                icon: const Icon(Icons.refresh_rounded),
                label: Text('Reintentar: ' + snapshot.error.toString()),
              ),
            );
          }

          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auditoría',
                        style: TextStyle(color: _ink, fontSize: 24,
                            fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text('Historial general de Express, ordenado por fecha. '
                           'Las acciones reales y de pruebas están identificadas '
                           'en una misma pantalla.',
                        style: TextStyle(color: _muted)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => revision++),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar'),
                ),
              ]),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hay acciones para los entornos autorizados.',
                      style: TextStyle(color: _muted)),
                  ),
                )
              else
                for (final row in rows)
                  Builder(builder: (context) {
                    final isTest = row['source_channel'] == 'preview';
                    final color = isTest
                        ? const Color(0xFFB54708)
                        : const Color(0xFF14804A);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isTest
                              ? const Color(0xFFFFF1D6)
                              : const Color(0xFFE8F8EF),
                          child: Icon(
                            isTest ? Icons.science_rounded
                                   : Icons.history_rounded,
                            color: color,
                          ),
                        ),
                        title: Text(_label(row),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          (row['admin_name'] ?? 'Administrador').toString() +
                          ' · ' + _date(row['created_at']) + '\n' +
                          (row['entity_id'] ?? '—').toString(),
                        ),
                        isThreeLine: true,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: isTest ? const Color(0xFFFFF7E6)
                                          : const Color(0xFFE8F8EF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            isTest ? 'QA' : 'REAL',
                            style: TextStyle(color: color, fontSize: 10,
                              fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    );
                  }),
            ],
          );
        },
      ),
    );
  }
}
