import 'dart:io';

import 'package:adminexpress/admin_notification_schedules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firmas de las RPC según la migración de Expressdelivery
/// `supabase/migrations/20261106120000_scheduled_push_notifications.sql`.
const Map<String, List<String>> expectedRpcParams = {
  'admin_notification_schedule_save_v1': [
    'p_channel', 'p_zone_id', 'p_id', 'p_label', 'p_title', 'p_body',
    'p_audience', 'p_partner_id', 'p_kind', 'p_run_on', 'p_time_of_day',
    'p_days_of_week', 'p_timezone', 'p_starts_on', 'p_ends_on', 'p_active',
  ],
  'admin_notification_schedule_list_v1': ['p_channel', 'p_zone_id'],
  'admin_notification_schedule_set_active_v1': [
    'p_channel', 'p_zone_id', 'p_id', 'p_active',
  ],
  'admin_notification_schedule_delete_v1': ['p_channel', 'p_zone_id', 'p_id'],
  'admin_notification_schedule_preview_v1': [
    'p_channel', 'p_zone_id', 'p_kind', 'p_run_on', 'p_time_of_day',
    'p_days_of_week', 'p_timezone', 'p_starts_on', 'p_ends_on', 'p_count',
  ],
};

const _migrationName = '20261106120000_scheduled_push_notifications.sql';

/// Busca la migración en el repositorio hermano (local) o en
/// EXPRESSDELIVERY_DIR. En CI de Adminexpress puede no estar disponible.
File? _findMigration() {
  final roots = [
    Platform.environment['EXPRESSDELIVERY_DIR'],
    '../Expressdelivery',
  ].whereType<String>();
  for (final root in roots) {
    final file = File('$root/supabase/migrations/$_migrationName');
    if (file.existsSync()) return file;
  }
  return null;
}

/// Extrae los nombres de parámetros de `create or replace function public.X(...)`.
Map<String, List<String>> _parseSignatures(String sql) {
  final result = <String, List<String>>{};
  final header = RegExp(
    r'create\s+or\s+replace\s+function\s+public\.(\w+)\s*\(([\s\S]*?)\)\s*returns',
    caseSensitive: false,
  );
  for (final match in header.allMatches(sql)) {
    final params = match
        .group(2)!
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map((part) => part.split(RegExp(r'\s+')).first)
        .toList();
    result[match.group(1)!] = params;
  }
  return result;
}

void main() {
  const definition = NotificationScheduleDefinition(
    kind: 'weekly',
    time: TimeOfDay(hour: 12, minute: 30),
    timezone: 'America/La_Paz',
    daysOfWeek: [5, 1, 3],
  );

  test('los parámetros que envía el panel coinciden con las RPC', () {
    final sent = <String, Map<String, dynamic>>{
      AdminNotificationScheduleRpc.save: AdminNotificationScheduleRpc.saveParams(
        channel: 'preview',
        zoneId: 'z',
        id: null,
        label: 'Almuerzo',
        title: 't',
        body: 'b',
        audience: 'drivers',
        partnerId: null,
        definition: definition,
        active: true,
      ),
      AdminNotificationScheduleRpc.list: AdminNotificationScheduleRpc.listParams(
        channel: 'preview',
        zoneId: 'z',
      ),
      AdminNotificationScheduleRpc.setActive:
          AdminNotificationScheduleRpc.setActiveParams(
        channel: 'preview',
        zoneId: 'z',
        id: 'i',
        active: false,
      ),
      AdminNotificationScheduleRpc.delete:
          AdminNotificationScheduleRpc.deleteParams(
        channel: 'preview',
        zoneId: 'z',
        id: 'i',
      ),
      AdminNotificationScheduleRpc.preview:
          AdminNotificationScheduleRpc.previewParams(
        channel: 'preview',
        zoneId: 'z',
        definition: definition,
      ),
    };
    expect(sent.keys.toSet(), expectedRpcParams.keys.toSet());
    for (final entry in expectedRpcParams.entries) {
      expect(
        sent[entry.key]!.keys.toSet(),
        entry.value.toSet(),
        reason: entry.key,
      );
    }
  });

  final migration = _findMigration();
  test(
    'las firmas coinciden con la migración de Expressdelivery',
    () {
      final sql = migration!.readAsStringSync();
      final signatures = _parseSignatures(sql);
      for (final entry in expectedRpcParams.entries) {
        expect(signatures[entry.key], entry.value, reason: entry.key);
        expect(
          sql,
          contains('grant execute on function public.${entry.key}('),
          reason: '${entry.key} debe concederse a authenticated',
        );
      }
      // Las funciones internas no se conceden a clientes.
      for (final internal in [
        'notification_schedules_run_due',
        'notification_campaign_dispatch_internal',
        'notification_schedule_next_run',
      ]) {
        expect(sql, isNot(contains('grant execute on function public.$internal(')));
        expect(sql, contains('revoke all on function public.$internal('));
      }
      expect(sql, contains("'notification-schedules-every-minute'"));
    },
    skip: migration == null
        ? 'Migración de Expressdelivery no disponible (define EXPRESSDELIVERY_DIR).'
        : false,
  );

  test('la definición normaliza fecha, hora y días', () {
    final weekly = definition.toParams();
    expect(weekly['p_kind'], 'weekly');
    expect(weekly['p_time_of_day'], '12:30:00');
    expect(weekly['p_days_of_week'], [1, 3, 5]);
    expect(weekly['p_run_on'], isNull);

    final once = NotificationScheduleDefinition(
      kind: 'once',
      time: const TimeOfDay(hour: 8, minute: 5),
      timezone: 'America/Santiago',
      runOn: DateTime(2026, 11, 7),
      daysOfWeek: const [1],
      startsOn: DateTime(2026, 11, 1),
    ).toParams();
    expect(once['p_run_on'], '2026-11-07');
    expect(once['p_time_of_day'], '08:05:00');
    expect(once['p_days_of_week'], isNull);
    expect(once['p_starts_on'], isNull);

    expect(
      const NotificationScheduleDefinition(
        kind: 'weekly',
        time: TimeOfDay(hour: 8, minute: 0),
        timezone: 'America/La_Paz',
      ).isComplete,
      isFalse,
    );
  });

  test('zona horaria por país y textos en hora local', () {
    expect(scheduleDefaultTimezone('CL'), 'America/Santiago');
    expect(scheduleDefaultTimezone('BO'), 'America/La_Paz');
    expect(scheduleDefaultTimezone(null), 'America/La_Paz');
    expect(formatScheduleLocal('2026-11-07 08:00'), 'sáb 07/11 08:00');
    expect(
      describeScheduleWhen({
        'kind': 'weekly',
        'days_of_week': [5, 1, 3],
        'time_of_day': '12:30',
      }),
      'lun, mié, vie · 12:30',
    );
    expect(
      describeScheduleWhen({'kind': 'daily', 'time_of_day': '19:30'}),
      'Todos los días · 19:30',
    );
  });

  test('la pestaña de avisos muestra «Programados» con el canal de la página',
      () {
    final page = File('lib/admin_control_sections.dart').readAsStringSync();
    final section = File('lib/admin_notification_schedules.dart').readAsStringSync();
    expect(page, contains('AdminNotificationSchedulesSection('));
    expect(page, contains('channel: widget.channel,'));
    expect(page, contains('operatorOnly: widget.operatorOnly,'));
    expect(section, contains("'Programados'"));
    expect(section, contains('StatefulBuilder('));
    expect(section, contains('AdminDropdownField<String>('));
    for (final preset in ["'Desayuno'", "'Almuerzo'", "'Cena'"]) {
      expect(section, contains(preset));
    }
    expect(section, contains('admin_push_audience_estimate_v2'));
  });

  testWidgets('el diálogo de nueva programación se dibuja y cambia de tipo',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminNotificationSchedulesSection(
              channel: 'preview',
              zoneId: 'zona-prueba',
              zoneName: 'Montero',
              countryCode: 'CL',
              partners: [],
              operatorOnly: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Programados'), findsOneWidget);

    await tester.tap(find.text('Nueva programación'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Prueba'), findsWidgets);
    expect(find.text('Chile (America/Santiago)'), findsOneWidget);

    await tester.tap(find.text('Cena 19:30'));
    await tester.pump();
    expect(find.text('Hora 19:30'), findsOneWidget);

    await tester.tap(find.text('Días de la semana'));
    await tester.pump();
    expect(find.byType(FilterChip), findsNWidgets(7));

    await tester.tap(find.text('Una sola vez'));
    await tester.pump();
    expect(find.text('Elegir fecha'), findsOneWidget);

    // Sin fecha no se guarda y avisa en el diálogo.
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Cena');
    await tester.enterText(find.widgetWithText(TextField, 'Mensaje'), 'Pide ya');
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Elige la fecha del aviso.'), findsOneWidget);
  });
}
