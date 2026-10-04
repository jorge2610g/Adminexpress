import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const _bg = Color(0xFFF1F5F9);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

class AdminEnvironmentAuditPage extends StatefulWidget {
  final String channel;

  const AdminEnvironmentAuditPage({
    super.key,
    required this.channel,
  });

  @override
  State<AdminEnvironmentAuditPage> createState() =>
      _AdminEnvironmentAuditPageState();
}

class _AdminEnvironmentAuditPageState extends State<AdminEnvironmentAuditPage> {
  int revision = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final value = await supabase.rpc(
      'admin_audit_list_v2',
      params: {
        'p_channel': widget.channel,
        'p_limit': 300,
      },
    );
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  String _date(Object? raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (value == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} · '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String _label(Map<String, dynamic> row) {
    final action = row['action']?.toString() ?? 'acción';
    final entity = row['entity_type']?.toString() ?? 'registro';
    if (entity == 'environment_config') {
      return 'Configuración Preview actualizada';
    }
    return '${action.replaceAll('_', ' ')} · ${entity.replaceAll('_', ' ')}';
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.channel == 'preview';
    return ColoredBox(
      color: _bg,
      child: FutureBuilder<List<Map<String, dynamic>>>(
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

          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Auditoría',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preview
                              ? 'Solo acciones registradas en Preview / QA.'
                              : 'Acciones de Producción y registros históricos sin marca Preview.',
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => revision++),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay acciones para este entorno.',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                )
              else
                ...rows.map(
                  (row) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: preview
                            ? const Color(0xFFFFF1D6)
                            : const Color(0xFFE8F8EF),
                        child: Icon(
                          preview ? Icons.science_rounded : Icons.history_rounded,
                          color: preview
                              ? const Color(0xFFB54708)
                              : const Color(0xFF14804A),
                        ),
                      ),
                      title: Text(
                        _label(row),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${row['admin_name'] ?? 'Administrador'} · '
                        '${_date(row['created_at'])}\n'
                        '${row['entity_id'] ?? '—'}',
                      ),
                      isThreeLine: true,
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
