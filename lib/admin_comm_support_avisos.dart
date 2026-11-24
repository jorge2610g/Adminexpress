import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import 'core/admin_dropdown_field.dart';
import 'core/admin_friendly_error.dart';
import 'core/supabase_client.dart';

/// Soporte con conversaciones (abiertas / cerradas) y Avisos de la empresa.
///
/// Las RPC viven en `20261124150000_support_tickets_and_announcements.sql`.
/// Un aviso es un mensaje editorial que el usuario puede reabrir desde su menú
/// «Avisos»; la notificación push es solo el timbre que apunta a él.
const Color _blue = Color(0xFF2563EB);
const Color _muted = Color(0xFF64748B);
const Color _line = Color(0xFFE7ECF3);

class AdminCommRpc {
  static const tickets = 'admin_support_tickets_v1';
  static const ticketMessages = 'admin_support_ticket_messages_v1';
  static const ticketReply = 'admin_support_ticket_reply_v1';
  static const ticketClose = 'admin_support_ticket_close_v1';
  static const ticketReopen = 'admin_support_ticket_reopen_v1';
  static const announcementSave = 'admin_announcement_save_v1';
  static const announcementList = 'admin_announcement_list_v1';
  static const announcementSetStatus = 'admin_announcement_set_status_v1';
  static const announcementDelete = 'admin_announcement_delete_v1';
  static const sendPush = 'admin_send_push_v1';

  static const announcementCategories = <String, String>{
    'aviso': 'Aviso',
    'evento': 'Evento',
    'importante': 'Importante',
    'novedad': 'Novedad',
  };

  static const audienceLabels = <String, String>{
    'drivers': 'Conductores',
    'passengers': 'Pasajeros',
    'all': 'Todos',
  };

  /// Texto corto de la push a partir del cuerpo del aviso.
  static String pushBodyFrom(String body) {
    final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= 140 ? flat : '${flat.substring(0, 137)}...';
  }

  static String pushTitleFrom(String title) =>
      title.length <= 90 ? title : title.substring(0, 90);
}

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  return const [];
}

Map<String, dynamic> _row(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _fmt(Object? raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (date == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

void _toast(BuildContext context, Object message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message is String ? message : friendlyError(message)),
    ),
  );
}

// ───────────────────────────── SOPORTE ─────────────────────────────

class AdminSupportTicketsTab extends StatefulWidget {
  final String channel;
  final String? zoneId;

  const AdminSupportTicketsTab({
    super.key,
    required this.channel,
    required this.zoneId,
  });

  @override
  State<AdminSupportTicketsTab> createState() => _AdminSupportTicketsTabState();
}

class _AdminSupportTicketsTabState extends State<AdminSupportTicketsTab> {
  int revision = 0;
  String status = 'open';
  String? selectedTicketId;
  bool busy = false;
  final reply = TextEditingController();

  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final zone = widget.zoneId;
    if (zone == null || zone.isEmpty) return const {};
    final value = await supabase.rpc(
      AdminCommRpc.tickets,
      params: {
        'p_channel': widget.channel,
        'p_zone_id': zone,
        'p_status': status,
      },
    );
    return _row(value);
  }

  Future<Map<String, dynamic>> _conversation(String ticketId) async {
    final value = await supabase.rpc(
      AdminCommRpc.ticketMessages,
      params: {'p_channel': widget.channel, 'p_ticket_id': ticketId},
    );
    return _row(value);
  }

  Future<void> _send(String ticketId) async {
    final text = reply.text.trim();
    if (text.isEmpty || busy) return;
    setState(() => busy = true);
    try {
      await supabase.rpc(
        AdminCommRpc.ticketReply,
        params: {
          'p_channel': widget.channel,
          'p_ticket_id': ticketId,
          'p_body': text,
        },
      );
      reply.clear();
      if (mounted) setState(() => revision++);
    } catch (e) {
      if (mounted) _toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _close(String ticketId, String name) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar conversación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La conversación con $name quedará guardada como cerrada. '
              'Si el usuario vuelve a escribir, se abre una conversación nueva.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Nota interna (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar conversación'),
          ),
        ],
      ),
    );
    final noteText = note.text.trim();
    note.dispose();
    if (ok != true || !mounted) return;
    await _act(
      AdminCommRpc.ticketClose,
      {
        'p_channel': widget.channel,
        'p_ticket_id': ticketId,
        'p_note': noteText.isEmpty ? null : noteText,
      },
      'Conversación cerrada.',
    );
  }

  Future<void> _reopen(String ticketId) => _act(
        AdminCommRpc.ticketReopen,
        {'p_channel': widget.channel, 'p_ticket_id': ticketId},
        'Conversación reabierta.',
        switchTo: 'open',
      );

  Future<void> _act(
    String rpc,
    Map<String, dynamic> params,
    String done, {
    String? switchTo,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await supabase.rpc(rpc, params: params);
      if (!mounted) return;
      setState(() {
        if (switchTo != null) status = switchTo;
        selectedTicketId = null;
        revision++;
      });
      _toast(context, done);
    } catch (e) {
      if (mounted) _toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('tickets-$status-$revision'),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(friendlyError(snapshot.error)),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => setState(() => revision++),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final tickets = _rows(data['tickets']);
        final openCount = (data['open_count'] as num?)?.toInt() ?? 0;
        final closedCount = (data['closed_count'] as num?)?.toInt() ?? 0;
        final current = tickets.isEmpty
            ? null
            : tickets.firstWhere(
                (t) => t['ticket_id']?.toString() == selectedTicketId,
                orElse: () => tickets.first,
              );

        final header = Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 'open',
                label: Text('Abiertas ($openCount)'),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
              ),
              ButtonSegment(
                value: 'closed',
                label: Text('Cerradas ($closedCount)'),
                icon: const Icon(Icons.inventory_2_outlined),
              ),
            ],
            selected: {status},
            onSelectionChanged: (value) => setState(() {
              status = value.first;
              selectedTicketId = null;
            }),
          ),
        );

        if (tickets.isEmpty) {
          return Column(
            children: [
              header,
              Expanded(
                child: Center(
                  child: Text(
                    status == 'open'
                        ? 'No hay conversaciones abiertas.'
                        : 'No hay conversaciones cerradas.',
                    style: const TextStyle(color: _muted),
                  ),
                ),
              ),
            ],
          );
        }

        final list = ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          children: [
            for (final t in tickets)
              _TicketTile(
                ticket: t,
                selected: t['ticket_id'] == current?['ticket_id'],
                onTap: () => setState(() {
                  selectedTicketId = t['ticket_id']?.toString();
                }),
              ),
          ],
        );

        final chat = current == null
            ? const SizedBox.shrink()
            : _TicketChat(
                key: ValueKey('chat-${current['ticket_id']}-$revision'),
                ticket: current,
                load: () => _conversation(current['ticket_id'].toString()),
                reply: reply,
                busy: busy,
                onSend: () => _send(current['ticket_id'].toString()),
                onClose: () => _close(
                  current['ticket_id'].toString(),
                  current['full_name']?.toString() ?? 'el usuario',
                ),
                onReopen: () => _reopen(current['ticket_id'].toString()),
              );

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 850) {
              return Column(
                children: [
                  header,
                  SizedBox(height: 200, child: list),
                  const Divider(height: 1),
                  Expanded(child: chat),
                ],
              );
            }
            return Column(
              children: [
                header,
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(width: 330, child: list),
                      const VerticalDivider(width: 1),
                      Expanded(child: chat),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TicketTile extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final bool selected;
  final VoidCallback onTap;

  const _TicketTile({
    required this.ticket,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = (ticket['unread_count'] as num?)?.toInt() ?? 0;
    final driver = ticket['role'] == 'driver';
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF4F8FF) : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: selected ? const Color(0xFFCFE0FF) : _line,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            child: Icon(
              driver ? Icons.local_taxi_outlined : Icons.person_outline_rounded,
            ),
          ),
          title: Text(
            ticket['full_name']?.toString() ?? 'Usuario Express',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '${driver ? 'Conductor' : 'Pasajero'} · '
            '${ticket['last_message'] ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: unread > 0
              ? CircleAvatar(
                  radius: 12,
                  backgroundColor: _blue,
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _TicketChat extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final Future<Map<String, dynamic>> Function() load;
  final TextEditingController reply;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onClose;
  final VoidCallback onReopen;

  const _TicketChat({
    super.key,
    required this.ticket,
    required this.load,
    required this.reply,
    required this.busy,
    required this.onSend,
    required this.onClose,
    required this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    final closed = ticket['status'] == 'closed';
    return FutureBuilder<Map<String, dynamic>>(
      future: load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(friendlyError(snapshot.error)));
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final messages = _rows(data['messages']);
        final info = _row(data['ticket']);
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket['full_name']?.toString() ?? 'Usuario Express',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Abierta ${_fmt(ticket['opened_at'])}',
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  if (closed)
                    OutlinedButton.icon(
                      onPressed: busy ? null : onReopen,
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text('Reabrir'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: busy ? null : onClose,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Cerrar conversación'),
                    ),
                ],
              ),
            ),
            if (closed)
              Container(
                width: double.infinity,
                color: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.all(10),
                child: Text(
                  'Cerrada ${_fmt(info['closed_at'])}'
                  '${(info['closed_by_name'] ?? '').toString().isEmpty ? '' : ' por ${info['closed_by_name']}'}'
                  '${(info['close_note'] ?? '').toString().isEmpty ? '' : '\nNota: ${info['close_note']}'}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Text('Sin mensajes.',
                          style: TextStyle(color: _muted)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final row = messages[index];
                        final admin = row['sender_role'] == 'admin';
                        return Align(
                          alignment: admin
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 430),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: admin
                                  ? const Color(0xFFEAF2FF)
                                  : const Color(0xFFF2F4F7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row['body']?.toString() ?? ''),
                                const SizedBox(height: 3),
                                Text(
                                  _fmt(row['created_at']),
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (!closed)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: reply,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Responder desde soporte...',
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: busy ? null : onSend,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ───────────────────────────── AVISOS ─────────────────────────────

class AdminAvisosTab extends StatefulWidget {
  final String channel;
  final String? zoneId;
  final String? zoneName;
  final List<Map<String, dynamic>> partners;

  const AdminAvisosTab({
    super.key,
    required this.channel,
    required this.zoneId,
    this.zoneName,
    this.partners = const [],
  });

  @override
  State<AdminAvisosTab> createState() => _AdminAvisosTabState();
}

class _AdminAvisosTabState extends State<AdminAvisosTab> {
  int revision = 0;
  bool busy = false;

  Future<List<Map<String, dynamic>>> _load() async {
    final zone = widget.zoneId;
    if (zone == null || zone.isEmpty) return const [];
    final value = await supabase.rpc(
      AdminCommRpc.announcementList,
      params: {'p_channel': widget.channel, 'p_zone_id': zone, 'p_limit': 100},
    );
    return _rows(value);
  }

  Future<void> _edit([Map<String, dynamic>? aviso]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AvisoEditorDialog(
        channel: widget.channel,
        zoneId: widget.zoneId,
        zoneName: widget.zoneName,
        partners: widget.partners,
        aviso: aviso,
      ),
    );
    if (saved == true && mounted) setState(() => revision++);
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (!mounted) return;
      setState(() => revision++);
      _toast(context, done);
    } catch (e) {
      if (mounted) _toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sendPush(Map<String, dynamic> aviso) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enviar notificación push'),
        content: Text(
          'Se avisará por push a '
          '${AdminCommRpc.audienceLabels[aviso['audience']] ?? 'todos'}'
          ' y al tocarla se abrirá el aviso “${aviso['title']}”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () async {
        await supabase.rpc(
          AdminCommRpc.sendPush,
          params: {
            'p_channel': widget.channel,
            'p_mode': 'with_announcement',
            'p_title': AdminCommRpc.pushTitleFrom(aviso['title'].toString()),
            'p_body': AdminCommRpc.pushBodyFrom(aviso['body'].toString()),
            'p_audience': aviso['audience'],
            'p_zone_id': widget.zoneId,
            'p_partner_id': aviso['partner_id'],
            'p_announcement_id': aviso['id'],
          },
        );
      },
      'Notificación push enviada.',
    );
  }

  Future<void> _delete(Map<String, dynamic> aviso) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar aviso'),
        content: Text(
          '“${aviso['title']}” dejará de aparecer a los usuarios. '
          'Para conservarlo sin mostrarlo, usa Archivar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => supabase.rpc(
        AdminCommRpc.announcementDelete,
        params: {'p_channel': widget.channel, 'p_id': aviso['id']},
      ),
      'Aviso eliminado.',
    );
  }

  Future<void> _setStatus(Map<String, dynamic> aviso, String status) => _run(
        () => supabase.rpc(
          AdminCommRpc.announcementSetStatus,
          params: {
            'p_channel': widget.channel,
            'p_id': aviso['id'],
            'p_status': status,
          },
        ),
        status == 'archived' ? 'Aviso archivado.' : 'Aviso publicado.',
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Avisos de la empresa',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo aviso'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Invitaciones, novedades o comunicados. Los usuarios los ven en el menú '
          '“Avisos” de la app y pueden abrirlos cuando quieran, aunque la '
          'notificación push ya haya pasado.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey('avisos-$revision'),
          future: _load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return Text(friendlyError(snapshot.error));
            }
            final avisos = snapshot.data ?? const <Map<String, dynamic>>[];
            if (avisos.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Todavía no hay avisos. Crea el primero con “Nuevo aviso”.',
                    style: TextStyle(color: _muted),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final aviso in avisos)
                  _AvisoCard(
                    aviso: aviso,
                    busy: busy,
                    onEdit: () => _edit(aviso),
                    onPush: () => _sendPush(aviso),
                    onDelete: () => _delete(aviso),
                    onArchive: () => _setStatus(aviso, 'archived'),
                    onPublish: () => _setStatus(aviso, 'published'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AvisoCard extends StatelessWidget {
  final Map<String, dynamic> aviso;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onPush;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback onPublish;

  const _AvisoCard({
    required this.aviso,
    required this.busy,
    required this.onEdit,
    required this.onPush,
    required this.onDelete,
    required this.onArchive,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final state = aviso['state']?.toString() ?? '';
    final withPush = aviso['with_push'] == true;
    final stateLabel = switch (state) {
      'visible' => 'Visible',
      'programado' => 'Programado',
      'vencido' => 'Vencido',
      'draft' => 'Borrador',
      'archived' => 'Archivado',
      _ => state,
    };
    final expires = aviso['expires_at'];
    final published = aviso['status'] == 'published';
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
              _Chip(
                AdminCommRpc.announcementCategories[aviso['category']] ??
                    'Aviso',
                color: _blue,
              ),
              const SizedBox(width: 6),
              _Chip(
                stateLabel,
                color: state == 'visible' ? const Color(0xFF15803D) : _muted,
              ),
              if (withPush) ...[
                const SizedBox(width: 6),
                const _Chip('Con push', color: Color(0xFF7C3AED)),
              ],
              const Spacer(),
              Text(
                _fmt(aviso['created_at']),
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            aviso['title']?.toString() ?? '',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            aviso['body']?.toString() ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            '${AdminCommRpc.audienceLabels[aviso['audience']] ?? 'Todos'}'
            ' · ${aviso['zone_name'] ?? 'Todas las zonas'}'
            ' · Leído por ${aviso['read_count'] ?? 0} de ${aviso['audience_size'] ?? 0}'
            '${expires == null ? ' · No caduca' : ' · Se borra ${_fmt(expires)}'}',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Editar'),
              ),
              if (published && !withPush)
                TextButton.icon(
                  onPressed: busy ? null : onPush,
                  icon:
                      const Icon(Icons.notifications_active_outlined, size: 17),
                  label: const Text('Enviar push'),
                ),
              if (published)
                TextButton.icon(
                  onPressed: busy ? null : onArchive,
                  icon: const Icon(Icons.inventory_2_outlined, size: 17),
                  label: const Text('Archivar'),
                )
              else
                TextButton.icon(
                  onPressed: busy ? null : onPublish,
                  icon: const Icon(Icons.publish_rounded, size: 17),
                  label: const Text('Publicar'),
                ),
              TextButton.icon(
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Eliminar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;

  const _Chip(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AvisoEditorDialog extends StatefulWidget {
  final String channel;
  final String? zoneId;
  final String? zoneName;
  final List<Map<String, dynamic>> partners;
  final Map<String, dynamic>? aviso;

  const _AvisoEditorDialog({
    required this.channel,
    required this.zoneId,
    required this.zoneName,
    required this.partners,
    required this.aviso,
  });

  @override
  State<_AvisoEditorDialog> createState() => _AvisoEditorDialogState();
}

class _AvisoEditorDialogState extends State<_AvisoEditorDialog> {
  late final TextEditingController title;
  late final TextEditingController body;
  String imageUrl = '';
  final List<(TextEditingController, TextEditingController)> buttons = [];
  Uint8List? pickedBytes;
  String pickedName = '';
  late final TextEditingController days;
  late String category;
  late String audience;
  String? partnerId;
  late bool sendPush;
  bool saving = false;

  bool get editing => widget.aviso != null;

  @override
  void initState() {
    super.initState();
    final a = widget.aviso;
    title = TextEditingController(text: a?['title']?.toString() ?? '');
    body = TextEditingController(text: a?['body']?.toString() ?? '');
    imageUrl = a?['image_url']?.toString() ?? '';
    category = a?['category']?.toString() ?? 'aviso';
    audience = a?['audience']?.toString() ?? 'drivers';
    partnerId = a?['partner_id']?.toString();
    // Por defecto: borrado a los 30 días. Al editar se calculan los días que faltan.
    String initialDays = '30';
    if (a != null) {
      final expires = DateTime.tryParse(a['expires_at']?.toString() ?? '');
      initialDays = expires == null
          ? '0'
          : expires.difference(DateTime.now()).inDays.clamp(1, 3650).toString();
    }
    final saved = a?['buttons'];
    if (saved is List) {
      for (final b in saved.whereType<Map>()) {
        buttons.add((
          TextEditingController(text: b['label']?.toString() ?? ''),
          TextEditingController(text: b['url']?.toString() ?? ''),
        ));
      }
    }
    days = TextEditingController(text: initialDays);
    sendPush = !editing;
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    days.dispose();
    for (final b in buttons) {
      b.$1.dispose();
      b.$2.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 86,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) _toast(context, 'La imagen debe pesar menos de 5 MB.');
      return;
    }
    setState(() {
      pickedBytes = bytes;
      pickedName = file.name;
    });
  }

  Future<String> _uploadImage() async {
    final name = pickedName.toLowerCase();
    final ext = name.endsWith('.png')
        ? 'png'
        : name.endsWith('.webp')
            ? 'webp'
            : 'jpg';
    final type = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    final path = '${widget.channel}/${widget.zoneId ?? 'global'}/'
        '${DateTime.now().microsecondsSinceEpoch}.$ext';
    final bucket = supabase.storage.from('express-announcements');
    await bucket.uploadBinary(
      path,
      pickedBytes!,
      fileOptions: FileOptions(contentType: type, upsert: false),
    );
    return bucket.getPublicUrl(path);
  }

  Future<void> _save() async {
    final t = title.text.trim();
    final b = body.text.trim();
    if (t.isEmpty || b.isEmpty) {
      _toast(context, 'Escribe el título y el mensaje.');
      return;
    }
    final d = int.tryParse(days.text.trim()) ?? 30;
    final expires = d <= 0
        ? null
        : DateTime.now().toUtc().add(Duration(days: d)).toIso8601String();
    setState(() => saving = true);
    try {
      if (pickedBytes != null) imageUrl = await _uploadImage();
      final result = await supabase.rpc(
        AdminCommRpc.announcementSave,
        params: {
          'p_channel': widget.channel,
          'p_id': widget.aviso?['id'],
          'p_category': category,
          'p_title': t,
          'p_body': b,
          'p_image_url': imageUrl.isEmpty ? null : imageUrl,
          'p_audience': audience,
          'p_zone_id': widget.zoneId,
          'p_partner_id': audience == 'passengers' ? null : partnerId,
          'p_publish_at': null,
          'p_expires_at': expires,
          'p_status': widget.aviso?['status'] ?? 'published',
          'p_buttons': [
            for (final b in buttons)
              if (b.$1.text.trim().isNotEmpty || b.$2.text.trim().isNotEmpty)
                {'label': b.$1.text.trim(), 'url': b.$2.text.trim()},
          ],
        },
      );
      final id = _row(result)['id'];
      var pushError = '';
      if (sendPush && id != null) {
        try {
          await supabase.rpc(
            AdminCommRpc.sendPush,
            params: {
              'p_channel': widget.channel,
              'p_mode': 'with_announcement',
              'p_title': AdminCommRpc.pushTitleFrom(t),
              'p_body': AdminCommRpc.pushBodyFrom(b),
              'p_audience': audience,
              'p_zone_id': widget.zoneId,
              'p_partner_id': audience == 'passengers' ? null : partnerId,
              'p_announcement_id': id,
            },
          );
        } catch (e) {
          pushError = friendlyError(e);
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      if (pushError.isNotEmpty) {
        _toast(
          context,
          'Aviso guardado, pero la push no salió: $pushError',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        _toast(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final zonePartners = widget.partners
        .where((p) =>
            widget.zoneId == null || p['zone_id']?.toString() == widget.zoneId)
        .toList();
    final alreadyPushed = widget.aviso?['with_push'] == true;
    return AlertDialog(
      title: Text(editing ? 'Editar aviso' : 'Nuevo aviso'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminDropdownField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  for (final e in AdminCommRpc.announcementCategories.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => category = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: title,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ej. Invitación a la fiesta de aniversario',
                ),
              ),
              TextField(
                controller: body,
                minLines: 5,
                maxLines: 12,
                maxLength: 8000,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 6),
              if (pickedBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(pickedBytes!,
                      height: 150, fit: BoxFit.cover),
                )
              else if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Text('Imagen no disponible'),
                  ),
                ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: saving ? null : _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      pickedBytes != null || imageUrl.isNotEmpty
                          ? 'Cambiar imagen'
                          : 'Subir imagen desde la galería',
                    ),
                  ),
                  if (pickedBytes != null || imageUrl.isNotEmpty)
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => setState(() {
                                pickedBytes = null;
                                pickedName = '';
                                imageUrl = '';
                              }),
                      child: const Text('Quitar'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Botones con enlace (opcional, máximo 3)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              for (var i = 0; i < buttons.length; i++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: buttons[i].$1,
                        maxLength: 30,
                        decoration: const InputDecoration(
                          labelText: 'Texto',
                          hintText: 'Ver ubicación',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: buttons[i].$2,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Enlace https://',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar botón',
                      onPressed: () => setState(() {
                        final b = buttons.removeAt(i);
                        b.$1.dispose();
                        b.$2.dispose();
                      }),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              if (buttons.length < 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => buttons.add((
                          TextEditingController(),
                          TextEditingController(),
                        ))),
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text('Añadir botón'),
                  ),
                ),
              const SizedBox(height: 10),
              AdminDropdownField<String>(
                initialValue: audience,
                decoration: const InputDecoration(labelText: 'Destinatarios'),
                items: [
                  for (final e in AdminCommRpc.audienceLabels.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      audience = v;
                      if (v == 'passengers') partnerId = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Zona: ${widget.zoneName ?? 'la zona seleccionada'}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              if (audience != 'passengers' && zonePartners.isNotEmpty) ...[
                const SizedBox(height: 10),
                AdminDropdownField<String?>(
                  initialValue: partnerId,
                  decoration: const InputDecoration(
                    labelText: 'Empresa / sindicato (opcional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todas las organizaciones'),
                    ),
                    for (final p in zonePartners)
                      DropdownMenuItem<String?>(
                        value: p['id']?.toString(),
                        child: Text((p['name'] ?? 'Organización').toString()),
                      ),
                  ],
                  onChanged: (v) => setState(() => partnerId = v),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Se borra solo a los (días)',
                  helperText: '0 = no caduca nunca. Por defecto 30 días.',
                ),
              ),
              const SizedBox(height: 6),
              if (alreadyPushed)
                const Text(
                  'Este aviso ya tiene su notificación push enviada.',
                  style: TextStyle(color: _muted, fontSize: 12),
                )
              else
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sendPush,
                  onChanged: (v) => setState(() => sendPush = v ?? false),
                  title: const Text('Enviar también notificación push'),
                  subtitle: const Text(
                    'Al tocarla, la app abre este aviso.',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(editing ? 'Guardar' : 'Publicar'),
        ),
      ],
    );
  }
}
