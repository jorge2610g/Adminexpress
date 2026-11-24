import 'package:flutter/material.dart';

import 'core/admin_friendly_error.dart';
import 'core/supabase_client.dart';

/// Solicitudes de los conductores: cambio de foto, nombre, teléfono y servicios.
/// El conductor aprobado ya no edita estos datos directamente; aquí se aprueban o rechazan.
const Color _blue = Color(0xFF2563EB);
const Color _muted = Color(0xFF64748B);
const Color _line = Color(0xFFE7ECF3);

class AdminDriverRequestsRpc {
  static const list = 'admin_driver_requests_v1';
  static const review = 'admin_driver_profile_change_review_v1';
  static const setPermission = 'admin_set_driver_work_permission';

  static const serviceLabels = <String, String>{
    'ride': 'Taxi y pasajeros',
    'parcel': 'Paquetería y documentos',
    'market': 'Pedidos de restaurantes',
  };

  static String title(Map<String, dynamic> row) {
    switch (row['request_kind']) {
      case 'photo':
        return 'Quiere cambiar su foto de perfil';
      case 'name':
        return 'Quiere cambiar su nombre';
      case 'phone':
        return 'Quiere cambiar su teléfono';
      case 'service':
        final key = row['service_key']?.toString() ?? '';
        return 'Pide autorización para ${serviceLabels[key] ?? key}';
      default:
        return 'Solicitud';
    }
  }
}

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList()
    : const [];

String _fmt(Object? raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (date == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

class AdminDriverRequestsPage extends StatefulWidget {
  final String channel;
  final String? zoneId;
  final bool canEdit;

  const AdminDriverRequestsPage({
    super.key,
    required this.channel,
    required this.zoneId,
    required this.canEdit,
  });

  @override
  State<AdminDriverRequestsPage> createState() =>
      _AdminDriverRequestsPageState();
}

class _AdminDriverRequestsPageState extends State<AdminDriverRequestsPage> {
  int revision = 0;
  String tab = 'pending';
  String? busyId;

  Future<List<Map<String, dynamic>>> _load() async {
    final zone = widget.zoneId;
    if (zone == null || zone.isEmpty) return const [];
    final value = await supabase.rpc(
      AdminDriverRequestsRpc.list,
      params: {
        'p_channel': widget.channel,
        'p_zone_id': zone,
        'p_status': tab,
      },
    );
    return _rows(value);
  }

  void _toast(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message is String ? message : friendlyError(message)),
      ),
    );
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: controller,
          maxLength: 300,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Motivo (el conductor lo verá)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (ok != true) return null;
    if (text.isEmpty) {
      _toast('Escribe el motivo del rechazo.');
      return null;
    }
    return text;
  }

  Future<void> _decide(Map<String, dynamic> row, bool approve) async {
    if (busyId != null) return;
    String? reason;
    if (!approve && row['request_kind'] != 'service') {
      reason = await _askReason();
      if (reason == null) return;
    }
    final id = row['id'].toString();
    setState(() => busyId = id);
    try {
      if (row['request_kind'] == 'service') {
        await supabase.rpc(
          AdminDriverRequestsRpc.setPermission,
          params: {
            'p_driver_id': row['driver_id'],
            'p_service_key': row['service_key'],
            'p_status': approve ? 'approved' : 'rejected',
            'p_channel': widget.channel,
          },
        );
      } else {
        await supabase.rpc(
          AdminDriverRequestsRpc.review,
          params: {
            'p_channel': widget.channel,
            'p_id': id,
            'p_approve': approve,
            'p_reason': reason,
          },
        );
      }
      if (!mounted) return;
      setState(() => revision++);
      _toast(approve ? 'Solicitud aprobada.' : 'Solicitud rechazada.');
    } catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'Solicitudes de conductores',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Los conductores aprobados no cambian su foto, nombre, teléfono ni servicios por su cuenta: lo piden aquí y tú decides.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'pending', label: Text('Pendientes')),
            ButtonSegment(value: 'history', label: Text('Historial')),
          ],
          selected: {tab},
          onSelectionChanged: (value) => setState(() => tab = value.first),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey('driver-requests-$tab-$revision'),
          future: _load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return Text(friendlyError(snapshot.error));
            }
            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    tab == 'pending'
                        ? 'No hay solicitudes pendientes.'
                        : 'Todavía no hay solicitudes resueltas.',
                    style: const TextStyle(color: _muted),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final row in rows)
                  _RequestCard(
                    key: ValueKey(row['id']),
                    row: row,
                    pending: tab == 'pending',
                    canEdit: widget.canEdit,
                    busy: busyId == row['id'].toString(),
                    onApprove: () => _decide(row, true),
                    onReject: () => _decide(row, false),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool pending;
  final bool canEdit;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    super.key,
    required this.row,
    required this.pending,
    required this.canEdit,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final kind = row['request_kind']?.toString();
    final status = row['status']?.toString() ?? '';
    final approved = status == 'approved';
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
          Row(
            children: [
              Expanded(
                child: Text(
                  row['driver_name']?.toString() ?? 'Conductor',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                _fmt(row['created_at']),
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
          Text(
            row['driver_phone']?.toString() ?? '',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            AdminDriverRequestsRpc.title(row),
            style: const TextStyle(color: _blue, fontWeight: FontWeight.w800),
          ),
          if (kind == 'name' || kind == 'phone') ...[
            const SizedBox(height: 6),
            Text(
              'Antes: ${row['old_value'] ?? '—'}',
              style: const TextStyle(color: _muted),
            ),
            Text(
              'Ahora: ${row['new_value'] ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          if (kind == 'photo')
            _RequestPhoto(path: row['new_photo_path']?.toString() ?? ''),
          if (!pending) ...[
            const SizedBox(height: 8),
            Text(
              '${approved ? 'Aprobada' : 'Rechazada'} ${_fmt(row['reviewed_at'])}'
              '${(row['reviewed_by_name'] ?? '').toString().isEmpty ? '' : ' por ${row['reviewed_by_name']}'}'
              '${(row['reject_reason'] ?? '').toString().isEmpty ? '' : '\nMotivo: ${row['reject_reason']}'}',
              style: TextStyle(
                color: approved
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB42318),
                fontSize: 12,
              ),
            ),
          ],
          if (pending && canEdit) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Aprobar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Rechazar'),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// La foto nueva vive en el bucket privado de documentos: se muestra con URL firmada.
class _RequestPhoto extends StatelessWidget {
  final String path;
  const _RequestPhoto({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<String>(
      future:
          supabase.storage.from('driver-onboarding').createSignedUrl(path, 600),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              snapshot.data!,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Text('Foto no disponible'),
            ),
          ),
        );
      },
    );
  }
}
