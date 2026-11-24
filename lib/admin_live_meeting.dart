import 'package:flutter/material.dart';

import 'core/admin_dropdown_field.dart';
import 'core/admin_friendly_error.dart';
import 'core/supabase_client.dart';

/// «En directo»: activa una reunión de Google Meet. A los conductores les aparece un
/// círculo parpadeante en su pantalla con el botón para entrar.
const Color _live = Color(0xFFE5252A);
const Color _muted = Color(0xFF64748B);
const Color _line = Color(0xFFE7ECF3);

class AdminLiveMeetingRpc {
  static const get = 'admin_live_meeting_get_v1';
  static const save = 'admin_live_meeting_save_v1';
  static const end = 'admin_live_meeting_end_v1';

  static bool isMeetUrl(String url) => RegExp(
        r'^https://meet\.google\.com/[A-Za-z0-9_?=&./-]+$',
        caseSensitive: false,
      ).hasMatch(url.trim());

  /// Hora de apagado de hoy (o de mañana si ya pasó). `null` si no se indicó hora.
  static DateTime? endsAt(TimeOfDay? time, DateTime now) {
    if (time == null) return null;
    var at = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }
}

class AdminLiveMeetingTab extends StatefulWidget {
  final String channel;
  final String? zoneId;
  final String? zoneName;
  final bool operatorOnly;

  const AdminLiveMeetingTab({
    super.key,
    required this.channel,
    required this.zoneId,
    this.zoneName,
    this.operatorOnly = false,
  });

  @override
  State<AdminLiveMeetingTab> createState() => _AdminLiveMeetingTabState();
}

class _AdminLiveMeetingTabState extends State<AdminLiveMeetingTab> {
  final title = TextEditingController(text: 'Reunión con conductores');
  final message = TextEditingController(
    text:
        'Estamos reunidos por Google Meet. Entra para escuchar las novedades y hacer tus preguntas.',
  );
  final link = TextEditingController();
  String audience = 'drivers';
  bool allZones = false;
  bool sendPush = true;
  TimeOfDay? endTime;
  bool busy = false;
  bool loading = true;
  Map<String, dynamic>? current;

  bool get active => current?['active'] == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminLiveMeetingTab old) {
    super.didUpdateWidget(old);
    if (old.zoneId != widget.zoneId || old.channel != widget.channel) _load();
  }

  @override
  void dispose() {
    title.dispose();
    message.dispose();
    link.dispose();
    super.dispose();
  }

  String? get _scopeZone => allZones ? null : widget.zoneId;

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final value = await supabase.rpc(
        AdminLiveMeetingRpc.get,
        params: {'p_channel': widget.channel, 'p_zone_id': _scopeZone},
      );
      if (!mounted) return;
      setState(() {
        current = value is Map ? Map<String, dynamic>.from(value) : null;
        final m = current;
        if (m != null && m['active'] == true) {
          title.text = m['title']?.toString() ?? title.text;
          message.text = m['message']?.toString() ?? message.text;
          link.text = m['meet_url']?.toString() ?? link.text;
          audience = m['audience']?.toString() ?? audience;
        }
      });
    } catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toast(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message is String ? message : friendlyError(message)),
      ),
    );
  }

  Future<void> _start() async {
    if (busy) return;
    if (title.text.trim().isEmpty) {
      _toast('Escribe un título.');
      return;
    }
    if (!AdminLiveMeetingRpc.isMeetUrl(link.text)) {
      _toast(
          'El enlace debe ser de Google Meet (https://meet.google.com/...).');
      return;
    }
    setState(() => busy = true);
    try {
      await supabase.rpc(
        AdminLiveMeetingRpc.save,
        params: {
          'p_channel': widget.channel,
          'p_zone_id': _scopeZone,
          'p_title': title.text.trim(),
          'p_message': message.text.trim(),
          'p_meet_url': link.text.trim(),
          'p_audience': audience,
          'p_ends_at': AdminLiveMeetingRpc.endsAt(endTime, DateTime.now())
              ?.toUtc()
              .toIso8601String(),
          'p_send_push': sendPush,
        },
      );
      await _load();
      _toast('En directo activado. Los conductores ya ven el círculo.');
    } catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _end() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await supabase.rpc(
        AdminLiveMeetingRpc.end,
        params: {'p_channel': widget.channel, 'p_zone_id': _scopeZone},
      );
      await _load();
      _toast('Reunión terminada. El círculo desapareció.');
    } catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final joins = (current?['joins'] as num?)?.toInt() ?? 0;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            const Text(
              'En directo',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 10),
            _StatePill(active: active),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Al activarlo, a los conductores les aparece un círculo parpadeante en su pantalla. '
          'Al tocarlo ven de qué trata y entran a Google Meet con un botón.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mostrar el círculo a los conductores',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Al apagarlo desaparece de inmediato.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: active,
                activeThumbColor: _live,
                onChanged: busy ? null : (on) => on ? _start() : _end(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: title,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        TextField(
          controller: message,
          maxLength: 300,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Mensaje corto'),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: link,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Enlace de Google Meet',
            hintText: 'https://meet.google.com/abc-defg-hij',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AdminDropdownField<String>(
                initialValue: audience,
                decoration: const InputDecoration(labelText: 'Quién lo ve'),
                items: const [
                  DropdownMenuItem(
                      value: 'drivers', child: Text('Conductores')),
                  DropdownMenuItem(
                      value: 'passengers', child: Text('Pasajeros')),
                  DropdownMenuItem(value: 'all', child: Text('Todos')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => audience = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AdminDropdownField<bool>(
                initialValue: allZones,
                decoration: const InputDecoration(labelText: 'Zona'),
                items: [
                  DropdownMenuItem(
                    value: false,
                    child: Text(widget.zoneName ?? 'Zona seleccionada'),
                  ),
                  if (!widget.operatorOnly)
                    const DropdownMenuItem(
                      value: true,
                      child: Text('Todas las zonas'),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => allZones = v);
                  _load();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                endTime == null
                    ? 'Se apaga solo: sin hora (lo terminas tú)'
                    : 'Se apaga solo a las ${endTime!.format(context)}',
              ),
            ),
            TextButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: endTime ?? const TimeOfDay(hour: 21, minute: 0),
                );
                if (picked != null) setState(() => endTime = picked);
              },
              child: const Text('Elegir hora'),
            ),
            if (endTime != null)
              IconButton(
                tooltip: 'Quitar hora',
                onPressed: () => setState(() => endTime = null),
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: sendPush,
          onChanged: (v) => setState(() => sendPush = v ?? false),
          title: const Text('Avisar también con una notificación push'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : _start,
              icon: const Icon(Icons.sensors_rounded),
              label: Text(active ? 'Guardar cambios' : 'Guardar y activar'),
            ),
            OutlinedButton(
              onPressed: busy || !active ? null : _end,
              child: const Text('Terminar reunión'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          active
              ? 'Han entrado $joins ${joins == 1 ? 'persona' : 'personas'} a la reunión.'
              : 'Cada vez que alguien entra queda registrado para que veas cuántos asistieron.',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatePill extends StatelessWidget {
  final bool active;
  const _StatePill({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? _live : _muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? '● Activo' : 'Apagado',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
