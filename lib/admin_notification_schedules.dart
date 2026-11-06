import 'package:flutter/material.dart';

import 'core/admin_dropdown_field.dart';
import 'core/admin_friendly_error.dart';
import 'core/supabase_client.dart';

/// Avisos push programados (desayuno, almuerzo, cena...).
///
/// La base de datos guarda la hora local y la zona horaria de cada
/// programación; pg_cron despacha el aviso a la hora indicada con la misma
/// audiencia que el envío manual (admin_send_announcement_v4).
const Color _blue = Color(0xFF2563EB);
const Color _dark = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);

/// Nombres y parámetros de las RPC. La prueba de contrato los compara con la
/// migración `20261106120000_scheduled_push_notifications.sql`.
class AdminNotificationScheduleRpc {
  static const save = 'admin_notification_schedule_save_v1';
  static const list = 'admin_notification_schedule_list_v1';
  static const setActive = 'admin_notification_schedule_set_active_v1';
  static const delete = 'admin_notification_schedule_delete_v1';
  static const preview = 'admin_notification_schedule_preview_v1';
  static const estimate = 'admin_push_audience_estimate_v2';

  static Map<String, dynamic> listParams({
    required String channel,
    required String? zoneId,
  }) =>
      {'p_channel': channel, 'p_zone_id': zoneId};

  static Map<String, dynamic> saveParams({
    required String channel,
    required String? zoneId,
    required String? id,
    required String label,
    required String title,
    required String body,
    required String audience,
    required String? partnerId,
    required NotificationScheduleDefinition definition,
    required bool active,
  }) =>
      {
        'p_channel': channel,
        'p_zone_id': zoneId,
        'p_id': id,
        'p_label': label,
        'p_title': title,
        'p_body': body,
        'p_audience': audience,
        'p_partner_id': partnerId,
        ...definition.toParams(),
        'p_active': active,
      };

  static Map<String, dynamic> setActiveParams({
    required String channel,
    required String? zoneId,
    required String id,
    required bool active,
  }) =>
      {
        'p_channel': channel,
        'p_zone_id': zoneId,
        'p_id': id,
        'p_active': active,
      };

  static Map<String, dynamic> deleteParams({
    required String channel,
    required String? zoneId,
    required String id,
  }) =>
      {'p_channel': channel, 'p_zone_id': zoneId, 'p_id': id};

  static Map<String, dynamic> previewParams({
    required String channel,
    required String? zoneId,
    required NotificationScheduleDefinition definition,
  }) =>
      {
        'p_channel': channel,
        'p_zone_id': zoneId,
        ...definition.toParams(),
        'p_count': 5,
      };
}

/// Cuándo se envía: una vez, todos los días o días de la semana.
class NotificationScheduleDefinition {
  const NotificationScheduleDefinition({
    required this.kind,
    required this.time,
    required this.timezone,
    this.runOn,
    this.daysOfWeek = const [],
    this.startsOn,
    this.endsOn,
  });

  /// 'once' | 'daily' | 'weekly'
  final String kind;
  final TimeOfDay time;
  final String timezone;
  final DateTime? runOn;

  /// ISO: 1 = lunes … 7 = domingo.
  final List<int> daysOfWeek;
  final DateTime? startsOn;
  final DateTime? endsOn;

  bool get isComplete {
    if (kind == 'once') return runOn != null;
    if (kind == 'weekly') return daysOfWeek.isNotEmpty;
    return kind == 'daily';
  }

  Map<String, dynamic> toParams() {
    final once = kind == 'once';
    final days = [...daysOfWeek]..sort();
    return {
      'p_kind': kind,
      'p_run_on': once ? scheduleDate(runOn) : null,
      'p_time_of_day': scheduleTime(time),
      'p_days_of_week': kind == 'weekly' ? days : null,
      'p_timezone': timezone,
      'p_starts_on': once ? null : scheduleDate(startsOn),
      'p_ends_on': once ? null : scheduleDate(endsOn),
    };
  }

  /// Clave estable para no repetir la vista previa en cada redibujo.
  String get cacheKey => toParams().toString();
}

const List<String> scheduleWeekdayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const List<String> _weekdayShort = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

String? scheduleDate(DateTime? value) {
  if (value == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-${two(value.day)}';
}

String scheduleTime(TimeOfDay value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:00';
}

String scheduleTimeLabel(TimeOfDay value) => scheduleTime(value).substring(0, 5);

/// Zona horaria por defecto según el país de la zona.
String scheduleDefaultTimezone(String? countryCode) =>
    (countryCode ?? '').toUpperCase() == 'CL'
        ? 'America/Santiago'
        : 'America/La_Paz';

TimeOfDay? parseScheduleTime(Object? raw) {
  final parts = (raw ?? '').toString().split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

DateTime? parseScheduleDate(Object? raw) {
  final text = (raw ?? '').toString();
  if (text.length < 10) return null;
  return DateTime.tryParse(text.substring(0, 10));
}

/// "2026-11-07 08:00" → "sáb 07/11 08:00" (hora local de la zona).
String formatScheduleLocal(Object? raw) {
  final text = (raw ?? '').toString();
  final date = parseScheduleDate(text);
  if (date == null) return '—';
  final time = text.length >= 16 ? text.substring(11, 16) : '';
  final day = _weekdayShort[date.weekday - 1];
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  return '$day $dd/$mm${time.isEmpty ? '' : ' $time'}';
}

String describeScheduleWhen(Map<String, dynamic> row) {
  final time = (row['time_of_day'] ?? '').toString();
  switch (row['kind']?.toString()) {
    case 'once':
      return 'Una sola vez · ${formatScheduleLocal('${row['run_on'] ?? ''} $time')}';
    case 'daily':
      return 'Todos los días · $time';
    case 'weekly':
      final days = ((row['days_of_week'] as List?) ?? const [])
          .map((d) => int.tryParse(d.toString()) ?? 0)
          .where((d) => d >= 1 && d <= 7)
          .toList()
        ..sort();
      final names = days.map((d) => _weekdayShort[d - 1]).join(', ');
      return '${names.isEmpty ? 'Días' : names} · $time';
  }
  return time;
}

String scheduleAudienceLabel(Object? audience) => switch (audience?.toString()) {
      'drivers' => 'Conductores',
      'passengers' => 'Pasajeros',
      _ => 'Todos',
    };

String scheduleRunStatusLabel(Object? status) => switch (status?.toString()) {
      'sent' => 'Enviado',
      'skipped_late' => 'Omitido por atraso',
      _ => 'Error',
    };

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

Map<String, dynamic> _object(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

/// Sección «Programados» dentro de la pestaña de avisos.
class AdminNotificationSchedulesSection extends StatefulWidget {
  const AdminNotificationSchedulesSection({
    super.key,
    required this.channel,
    required this.zoneId,
    required this.zoneName,
    required this.countryCode,
    required this.partners,
    required this.operatorOnly,
  });

  final String channel;
  final String? zoneId;
  final String? zoneName;
  final String? countryCode;
  final List<Map<String, dynamic>> partners;
  final bool operatorOnly;

  @override
  State<AdminNotificationSchedulesSection> createState() =>
      _AdminNotificationSchedulesSectionState();
}

class _AdminNotificationSchedulesSectionState
    extends State<AdminNotificationSchedulesSection> {
  late Future<List<Map<String, dynamic>>> future;
  final Set<String> busy = <String>{};

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void didUpdateWidget(covariant AdminNotificationSchedulesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel ||
        oldWidget.zoneId != widget.zoneId) {
      future = _load();
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final zoneId = widget.zoneId;
    if (zoneId == null || zoneId.isEmpty) return const [];
    final value = await supabase.rpc(
      AdminNotificationScheduleRpc.list,
      params: AdminNotificationScheduleRpc.listParams(
        channel: widget.channel,
        zoneId: zoneId,
      ),
    );
    return _rows(value);
  }

  void _refresh() => setState(() => future = _load());

  void _snack(Object value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value is String ? value : friendlyError(value)),
      ),
    );
  }

  List<Map<String, dynamic>> get _zonePartners => widget.partners
      .where((partner) =>
          widget.zoneId == null ||
          partner['zone_id']?.toString() == widget.zoneId)
      .toList();

  Future<void> _toggle(Map<String, dynamic> row, bool active) async {
    final id = row['id']?.toString();
    if (id == null || busy.contains(id)) return;
    setState(() => busy.add(id));
    try {
      await supabase.rpc(
        AdminNotificationScheduleRpc.setActive,
        params: AdminNotificationScheduleRpc.setActiveParams(
          channel: widget.channel,
          zoneId: widget.zoneId,
          id: id,
          active: active,
        ),
      );
      if (!mounted) return;
      _snack(active ? 'Programación activada.' : 'Programación pausada.');
      _refresh();
    } catch (e) {
      _snack(e);
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null || busy.contains(id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar programación'),
        content: Text(
          'Se eliminará “${row['label']?.toString().isNotEmpty == true ? row['label'] : row['title']}”. '
          'Los avisos ya enviados se mantienen en el historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy.add(id));
    try {
      await supabase.rpc(
        AdminNotificationScheduleRpc.delete,
        params: AdminNotificationScheduleRpc.deleteParams(
          channel: widget.channel,
          zoneId: widget.zoneId,
          id: id,
        ),
      );
      if (!mounted) return;
      _snack('Programación eliminada.');
      _refresh();
    } catch (e) {
      _snack(e);
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final zoneId = widget.zoneId;
    if (zoneId == null || zoneId.isEmpty) {
      _snack('Selecciona país y zona antes de programar avisos.');
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScheduleEditorDialog(
        channel: widget.channel,
        zoneId: zoneId,
        zoneName: widget.zoneName,
        countryCode: widget.countryCode,
        partners: widget.operatorOnly ? const [] : _zonePartners,
        initial: row,
      ),
    );
    if (saved == true && mounted) {
      _snack(row == null ? 'Programación creada.' : 'Programación guardada.');
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7ECF3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Programados',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: _dark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Se envían solos a la hora indicada (hora local de la zona).',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add_alarm_rounded),
                label: const Text('Nueva programación'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text(
                  'No se pudieron cargar las programaciones: ${friendlyError(snapshot.error)}',
                  style: const TextStyle(color: Color(0xFFB42318), fontSize: 12),
                );
              }
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const Text(
                  'Todavía no hay avisos programados. Usa «Nueva programación» para crear, por ejemplo, el aviso del almuerzo.',
                  style: TextStyle(color: _muted, fontSize: 12),
                );
              }
              return Column(
                children: [for (final row in rows) _scheduleCard(row)],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final active = row['active'] == true;
    final label = row['label']?.toString() ?? '';
    final runs = _rows(row['recent_runs']);
    final target = [
      scheduleAudienceLabel(row['audience']),
      if ((row['zone_name'] ?? '').toString().isNotEmpty) row['zone_name'],
      if ((row['partner_name'] ?? '').toString().isNotEmpty) row['partner_name'],
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE7ECF3)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (label.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: _blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        Text(
                          row['title']?.toString() ?? 'Aviso',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${describeScheduleWhen(row)} · $target',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      active
                          ? 'Próximo envío: ${formatScheduleLocal(row['next_run_local'])} (${row['timezone'] ?? ''})'
                          : 'Pausada · sin próximo envío',
                      style: TextStyle(
                        color: active ? const Color(0xFF027A48) : _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: active,
                onChanged: busy.contains(id) ? null : (value) => _toggle(row, value),
              ),
              IconButton(
                tooltip: 'Editar',
                onPressed: busy.contains(id) ? null : () => _edit(row),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: busy.contains(id) ? null : () => _delete(row),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          if (runs.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Últimas ejecuciones',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            for (final run in runs)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${formatScheduleLocal(run['scheduled_local'])} · '
                  '${scheduleRunStatusLabel(run['status'])}'
                  '${run['status'] == 'sent' ? ' · ${run['recipients'] ?? 0} destinatarios (${run['push_enabled'] ?? 0} con push)' : ''}'
                  '${run['status'] == 'error' && (run['error'] ?? '').toString().isNotEmpty ? ' · ${run['error']}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: run['status'] == 'error'
                        ? const Color(0xFFB42318)
                        : _muted,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleEditorDialog extends StatefulWidget {
  const _ScheduleEditorDialog({
    required this.channel,
    required this.zoneId,
    required this.zoneName,
    required this.countryCode,
    required this.partners,
    required this.initial,
  });

  final String channel;
  final String zoneId;
  final String? zoneName;
  final String? countryCode;
  final List<Map<String, dynamic>> partners;
  final Map<String, dynamic>? initial;

  @override
  State<_ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<_ScheduleEditorDialog> {
  static const presets = [
    ('Desayuno', TimeOfDay(hour: 8, minute: 0)),
    ('Almuerzo', TimeOfDay(hour: 12, minute: 30)),
    ('Cena', TimeOfDay(hour: 19, minute: 30)),
  ];

  late final TextEditingController label;
  late final TextEditingController title;
  late final TextEditingController body;
  late String audience;
  String? partnerId;
  late String kind;
  late TimeOfDay time;
  late String timezone;
  DateTime? runOn;
  late Set<int> days;
  DateTime? startsOn;
  DateTime? endsOn;
  late bool active;
  bool saving = false;
  String? error;

  String? previewKey;
  Future<Map<String, dynamic>>? previewFuture;
  String? estimateKey;
  Future<Map<String, dynamic>>? estimateFuture;

  @override
  void initState() {
    super.initState();
    final row = widget.initial;
    label = TextEditingController(text: row?['label']?.toString() ?? '');
    title = TextEditingController(text: row?['title']?.toString() ?? '');
    body = TextEditingController(text: row?['body']?.toString() ?? '');
    audience = row?['audience']?.toString() ?? 'passengers';
    partnerId = row?['partner_id']?.toString();
    if (partnerId != null &&
        !widget.partners.any((p) => p['id']?.toString() == partnerId)) {
      partnerId = null;
    }
    kind = row?['kind']?.toString() ?? 'daily';
    time = parseScheduleTime(row?['time_of_day']) ??
        const TimeOfDay(hour: 12, minute: 30);
    timezone = row?['timezone']?.toString() ??
        scheduleDefaultTimezone(widget.countryCode);
    runOn = parseScheduleDate(row?['run_on']);
    days = {
      ...((row?['days_of_week'] as List?) ?? const [])
          .map((d) => int.tryParse(d.toString()) ?? 0)
          .where((d) => d >= 1 && d <= 7),
    };
    if (days.isEmpty) days = {1, 2, 3, 4, 5};
    startsOn = parseScheduleDate(row?['starts_on']);
    endsOn = parseScheduleDate(row?['ends_on']);
    active = row == null ? true : row['active'] == true;
  }

  @override
  void dispose() {
    label.dispose();
    title.dispose();
    body.dispose();
    super.dispose();
  }

  NotificationScheduleDefinition get definition =>
      NotificationScheduleDefinition(
        kind: kind,
        time: time,
        timezone: timezone,
        runOn: runOn,
        daysOfWeek: days.toList(),
        startsOn: startsOn,
        endsOn: endsOn,
      );

  /// Solo vuelve a consultar cuando cambia la definición.
  Future<Map<String, dynamic>>? _preview() {
    final current = definition;
    if (!current.isComplete) return null;
    final key = current.cacheKey;
    if (key != previewKey) {
      previewKey = key;
      previewFuture = Future.sync(
        () => supabase.rpc(
          AdminNotificationScheduleRpc.preview,
          params: AdminNotificationScheduleRpc.previewParams(
            channel: widget.channel,
            zoneId: widget.zoneId,
            definition: current,
          ),
        ),
      ).then(_object);
    }
    return previewFuture;
  }

  Future<Map<String, dynamic>> _estimate() {
    final key = '$audience-${partnerId ?? 'all'}';
    if (key != estimateKey || estimateFuture == null) {
      estimateKey = key;
      estimateFuture = Future.sync(
        () => supabase.rpc(
          AdminNotificationScheduleRpc.estimate,
          params: {
            'p_channel': widget.channel,
            'p_audience': audience,
            'p_zone_id': widget.zoneId,
            'p_partner_id': partnerId,
          },
        ),
      ).then(_object);
    }
    return estimateFuture!;
  }

  Future<void> _pickTime(StateSetter update) async {
    final picked = await showTimePicker(context: context, initialTime: time);
    if (picked != null) update(() => time = picked);
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return showDatePicker(
      context: context,
      initialDate: initial != null && !initial.isBefore(today) ? initial : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );
  }

  Future<void> _save(StateSetter update) async {
    if (saving) return;
    final current = definition;
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      update(() => error = 'Escribe el título y el mensaje.');
      return;
    }
    if (!current.isComplete) {
      update(() => error = kind == 'once'
          ? 'Elige la fecha del aviso.'
          : 'Elige al menos un día de la semana.');
      return;
    }
    update(() {
      saving = true;
      error = null;
    });
    try {
      await supabase.rpc(
        AdminNotificationScheduleRpc.save,
        params: AdminNotificationScheduleRpc.saveParams(
          channel: widget.channel,
          zoneId: widget.zoneId,
          id: widget.initial?['id']?.toString(),
          label: label.text.trim(),
          title: title.text.trim(),
          body: body.text.trim(),
          audience: audience,
          partnerId: audience == 'drivers' ? partnerId : null,
          definition: current,
          active: active,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        update(() {
          saving = false;
          error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // StatefulBuilder: cada cambio del formulario redibuja el diálogo.
    return StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(
          '${widget.initial == null ? 'Nueva programación' : 'Editar programación'}'
          ' · ${widget.channel == 'preview' ? 'Prueba' : 'Producción'}',
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Atajos',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final preset in presets)
                      ActionChip(
                        avatar: const Icon(Icons.schedule_rounded, size: 16),
                        label: Text('${preset.$1} ${scheduleTimeLabel(preset.$2)}'),
                        onPressed: () => update(() {
                          label.text = preset.$1;
                          time = preset.$2;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: label,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Etiqueta',
                    hintText: 'Ej. Almuerzo',
                  ),
                ),
                TextField(
                  controller: title,
                  maxLength: 90,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Ej. ¿Ya almorzaste?',
                  ),
                ),
                TextField(
                  controller: body,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Mensaje'),
                ),
                const SizedBox(height: 8),
                AdminDropdownField<String>(
                  initialValue: audience,
                  decoration: const InputDecoration(labelText: 'Destinatarios'),
                  items: const [
                    DropdownMenuItem(value: 'drivers', child: Text('Conductores')),
                    DropdownMenuItem(value: 'passengers', child: Text('Pasajeros')),
                    DropdownMenuItem(value: 'all', child: Text('Todos')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    update(() {
                      audience = value;
                      if (value != 'drivers') partnerId = null;
                    });
                  },
                ),
                if (audience == 'drivers' && widget.partners.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AdminDropdownField<String?>(
                    initialValue: partnerId,
                    decoration: const InputDecoration(
                      labelText: 'Empresa / sindicato / cooperativa',
                      helperText: 'Opcional: limita el aviso a los conductores afiliados.',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas las organizaciones'),
                      ),
                      ...widget.partners.map(
                        (partner) => DropdownMenuItem<String?>(
                          value: partner['id']?.toString(),
                          child: Text((partner['name'] ?? 'Organización').toString()),
                        ),
                      ),
                    ],
                    onChanged: (value) => update(() => partnerId = value),
                  ),
                ],
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Zona',
                    helperText: 'La zona seleccionada en la barra superior.',
                  ),
                  child: Text(widget.zoneName ?? 'Zona actual'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Cuándo se envía',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final option in const [
                      ('once', 'Una sola vez'),
                      ('daily', 'Todos los días'),
                      ('weekly', 'Días de la semana'),
                    ])
                      ChoiceChip(
                        label: Text(option.$2),
                        selected: kind == option.$1,
                        onSelected: (_) => update(() => kind = option.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (kind == 'weekly') ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(scheduleWeekdayLetters[day - 1]),
                          tooltip: _weekdayShort[day - 1],
                          selected: days.contains(day),
                          onSelected: (selected) => update(() {
                            if (selected) {
                              days.add(day);
                            } else {
                              days.remove(day);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (kind == 'once')
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickDate(runOn);
                          if (picked != null) update(() => runOn = picked);
                        },
                        icon: const Icon(Icons.event_rounded),
                        label: Text(runOn == null
                            ? 'Elegir fecha'
                            : formatScheduleLocal(scheduleDate(runOn))),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _pickTime(update),
                      icon: const Icon(Icons.access_time_rounded),
                      label: Text('Hora ${scheduleTimeLabel(time)}'),
                    ),
                  ],
                ),
                if (kind != 'once') ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _dateButton(
                        update,
                        text: startsOn == null
                            ? 'Desde: hoy'
                            : 'Desde: ${formatScheduleLocal(scheduleDate(startsOn))}',
                        onPick: (value) => startsOn = value,
                        current: startsOn,
                      ),
                      _dateButton(
                        update,
                        text: endsOn == null
                            ? 'Hasta: sin fecha final'
                            : 'Hasta: ${formatScheduleLocal(scheduleDate(endsOn))}',
                        onPick: (value) => endsOn = value,
                        current: endsOn,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                AdminDropdownField<String>(
                  initialValue: timezone,
                  decoration: const InputDecoration(labelText: 'Zona horaria'),
                  items: const [
                    DropdownMenuItem(
                      value: 'America/La_Paz',
                      child: Text('Bolivia (America/La_Paz)'),
                    ),
                    DropdownMenuItem(
                      value: 'America/Santiago',
                      child: Text('Chile (America/Santiago)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) update(() => timezone = value);
                  },
                ),
                const SizedBox(height: 12),
                _previewBox(),
                const SizedBox(height: 10),
                _estimateBox(),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activa'),
                  subtitle: const Text('Si la pausas, no se envía hasta reactivarla.'),
                  value: active,
                  onChanged: (value) => update(() => active = value),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFB42318),
                        fontWeight: FontWeight.w700,
                      ),
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
          FilledButton.icon(
            onPressed: saving ? null : () => _save(update),
            icon: saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _dateButton(
    StateSetter update, {
    required String text,
    required DateTime? current,
    required void Function(DateTime?) onPick,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await _pickDate(current);
            if (picked != null) update(() => onPick(picked));
          },
          icon: const Icon(Icons.date_range_rounded),
          label: Text(text),
        ),
        if (current != null)
          IconButton(
            tooltip: 'Quitar fecha',
            onPressed: () => update(() => onPick(null)),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
      ],
    );
  }

  Widget _previewBox() {
    final future = _preview();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD5E3FF)),
      ),
      child: future == null
          ? const Text(
              'Completa la fecha o los días para ver los próximos envíos.',
              style: TextStyle(color: _muted, fontSize: 11),
            )
          : FutureBuilder<Map<String, dynamic>>(
              key: ValueKey(previewKey),
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text(
                    friendlyError(snapshot.error),
                    style: const TextStyle(color: Color(0xFFB42318), fontSize: 11),
                  );
                }
                final runs = _rows(snapshot.data?['runs']);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Próximos envíos',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    if (runs.isEmpty)
                      const Text(
                        'No hay fechas futuras con esta configuración.',
                        style: TextStyle(color: Color(0xFFB42318), fontSize: 11),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final run in runs)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                formatScheduleLocal(run['local']),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _estimateBox() {
    final future = _estimate();
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(estimateKey),
      future: future,
      builder: (context, snapshot) {
        final estimate = snapshot.data ?? const <String, dynamic>{};
        final text = snapshot.hasError
            ? 'No se pudo estimar el alcance.'
            : 'Alcance hoy: ${estimate['recipients'] ?? '…'} destinatarios · '
                '${estimate['push_enabled'] ?? '…'} con push activo';
        return Text(
          text,
          style: const TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }
}
