import 'dart:io';

import 'package:adminexpress/admin_trip_ranking_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('escapa punto y coma, comillas y saltos de línea', () {
    expect(adminCsvCell('Ana; Pérez'), '"Ana; Pérez"');
    expect(adminCsvCell('dice "hola"'), '"dice ""hola"""');
    expect(adminCsvCell('línea\nnueva'), '"línea\nnueva"');
    expect(adminCsvCell(null), '');
    expect(adminCsvCell(12), '12');
  });

  test('neutraliza celdas que una hoja de cálculo tomaría como fórmula', () {
    expect(adminCsvCell('=HYPERLINK(1)'), "'=HYPERLINK(1)");
    expect(adminCsvCell('+1 555'), "'+1 555");
    expect(adminCsvCell('@usuario'), "'@usuario");
    expect(adminCsvCell('Juan'), 'Juan');
  });

  test('CSV con BOM, encabezados y una fila por conductor en orden recibido', () {
    final csv = adminTripRankingCsv([
      {
        'user_id': 'd1',
        'full_name': 'Carlos Mamani',
        'completed_trips': 44,
        'first_completed_at': '2026-10-02T14:05:00Z',
        'last_completed_at': '2026-11-14T22:30:00Z',
      },
      {
        'user_id': 'd2',
        'full_name': '',
        'completed_trips': 3,
        'first_completed_at': null,
        'last_completed_at': null,
      },
    ]);

    expect(csv.startsWith('﻿'), isTrue);
    final lines = csv.substring(1).split('\r\n');
    expect(lines[0], 'Posición;Nombre;ID;Viajes completados;'
        'Primer viaje completado;Último viaje completado');
    expect(lines[1].startsWith('1;Carlos Mamani;d1;44;'), isTrue);
    expect(lines[2], '2;Sin nombre;d2;3;;');
    expect(csv.endsWith('\r\n'), isTrue);
  });

  test('CSV vacío sigue teniendo encabezados', () {
    final csv = adminTripRankingCsv(const []);
    expect(csv.substring(1).split('\r\n').first,
        startsWith('Posición;Nombre;ID;'));
  });

  test('nombre de archivo distinto para conductores y usuarios', () {
    final day = DateTime(2026, 11, 5);
    expect(adminTripRankingFileName(drivers: true, day: day),
        'ranking-conductores-2026-11-05.csv');
    expect(adminTripRankingFileName(drivers: false, day: day),
        'ranking-usuarios-2026-11-05.csv');
  });

  test('el botón Exportar de conductores y usuarios exporta todos los datos', () {
    final source = File('lib/admin_panel.dart').readAsStringSync();
    expect(source, contains("'admin_completed_trip_ranking_v1'"));
    expect(source, contains("'admin_driver_export_v1'"));
    expect(source, contains('onExport: _exportDrivers,'));
    expect(source, contains('onExport: _exportUsers,'));
    expect(source, contains("'p_role': 'passenger'"));
    expect(source, contains("'p_role': 'driver'"));
  });

  test('la migración solo lee y no se expone a anónimos', () {
    final sql = File(
      'supabase/migrations/20261115100000_admin_completed_trip_ranking_v1.sql',
    ).readAsStringSync();
    expect(sql, contains('security definer'));
    expect(sql, contains("admin_operator_assert_module("));
    expect(sql, contains('admin_assert_environment(v_channel)'));
    expect(sql, contains('revoke all on function public.admin_completed_trip_ranking_v1(text, uuid, text) from public, anon;'));
    expect(sql, isNot(contains('insert into')));
    expect(sql, isNot(contains('update public.')));
    expect(sql, isNot(contains('delete from')));
  });

  test('CSV de viajes: encabezados, BOM y sin teléfonos ni correos', () {
    final csv = adminTripsCsv([
      {
        'created_at': '2026-11-15T22:35:00Z',
        'status': 'completed',
        'category': 'economy',
        'passenger_name': 'Berecita Vaca',
        'driver_name': 'Raúl Guaji',
        'pickup_address': 'Trinidad, Centro',
        'destination_address': 'Aeropuerto; Terminal',
        'final_fare': 15.5,
        'currency': 'BOB',
        'payment_status': 'paid',
        'completed_at': '2026-11-15T22:50:00Z',
        'passenger_phone': '+59170000000',
      },
    ]);
    expect(csv.startsWith('\uFEFF'), isTrue);
    final lines = csv.substring(1).split('\r\n');
    expect(lines[0], 'Fecha;Estado;Categoría;Pasajero;Conductor;Origen;'
        'Destino;Tarifa final;Moneda;Pago;Completado');
    expect(lines[1], contains('completed;economy;Berecita Vaca;Raúl Guaji;'));
    expect(lines[1], contains('"Aeropuerto; Terminal"'));
    expect(lines[1], contains('15.5;BOB;paid;'));
    expect(csv, isNot(contains('+59170000000')));
  });

  test('nombre de archivo de viajes según el periodo', () {
    final day = DateTime(2026, 11, 16);
    expect(adminTripsFileName(period: 'month', day: day), 'viajes-todos-mes-2026-11-16.csv');
    expect(adminTripsFileName(period: 'today', day: day), 'viajes-todos-hoy-2026-11-16.csv');
    expect(adminTripsFileName(period: 'custom', day: day), 'viajes-todos-rango-2026-11-16.csv');
    expect(adminTripsFileName(period: 'month', status: 'completed', day: day),
        'viajes-completados-mes-2026-11-16.csv');
    expect(adminTripsFileName(period: 'month', status: 'cancelled', day: day),
        'viajes-cancelados-mes-2026-11-16.csv');
  });

  test('la lista de viajes exporta todas las páginas del servidor', () {
    final source = File('lib/admin_panel.dart').readAsStringSync();
    expect(source, contains('onExport: _exportTrips,'));
    expect(source, contains('const pageSize = 500;'));
    // Lista, conteo y exportación usan el mismo estado seleccionado.
    expect(source, contains("'p_status': tripStatus,"));
    expect(source, contains('Widget _tripStatusFilter()'));
    expect(source, contains("label: 'Completados'"));
    expect(source, contains("label: 'Cancelados'"));
    expect(source, contains("'admin_trip_list_v4'"));
  });

  group('exportación completa de conductores y usuarios', () {
    final driver = <String, dynamic>{
      'user_id': '8e6c652c-3fb3-4a24-9809-a2cc500bbe5a',
      'full_name': 'Jorge Luis',
      'email': 'jorge@correo.cl',
      'phone': '+56982807639',
      'phone_verified_at': '2026-10-01T12:00:00Z',
      'account_status': 'active',
      'approval_status': 'approved',
      'online_status': 'offline',
      'created_at': '2026-10-01T12:00:00Z',
      'license_number': 'B-123',
      'vehicle_type': 'moto',
      'vehicle_brand': 'Honda',
      'vehicle_model': 'CB',
      'vehicle_color': 'Rojo',
      'vehicle_plate': 'ABCD12',
      'vehicle_year': 2022,
      'vehicle_summary': 'Honda CB rojo',
      'city': 'Iquique',
      'zone_name': 'Iquique',
      'country': 'Chile',
      'currency_code': 'CLP',
      'rating': 4.9,
      'completed_trips': 19,
      'cancelled_trips': 2,
      'first_completed_at': '2026-10-05T10:00:00Z',
      'last_completed_at': '2026-11-23T20:00:00Z',
      'accepted_payment_methods': 'cash, qr',
      'subscription_status': 'active',
      'integrity_warnings': 1,
      'integrity_suspensions': 0,
      'user_id_dummy': null,
    };

    test('conductores: una columna por dato y una fila por conductor', () {
      final csv = adminDriversExportCsv([driver, {'user_id': 'x', 'full_name': ''}]);
      final lines = csv.trim().split('\r\n');
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(lines.length, 3);
      for (final line in lines) {
        expect(line.split(';').length, adminDriversExportHeaders.length);
      }
      expect(lines.first, contains('Placa'));
      expect(lines.first, contains('Correo'));
      expect(lines[1], contains('Jorge Luis;jorge@correo.cl; +56982807639;Sí;Activa;Aprobado;Desconectado'));
      expect(lines[1], contains('ABCD12'));
      expect(lines[1], contains('Honda'));
      expect(lines[1], contains('4.9;19;2;'));
      expect(lines[1], contains('Activa;'));
      expect(lines[2], startsWith('Sin nombre;'));
    });

    test('las fechas salen como texto para que Excel no muestre ##########', () {
      final text = adminCsvDateText('2026-11-23T20:00:00Z');
      expect(text.endsWith(' '), isTrue);
      expect(text.trim(), matches(RegExp(r'^\d{2}/\d{2}/\d{4} \d{2}:\d{2}$')));
      expect(adminCsvDateText(null), '');
      expect(adminCsvDateText('no es fecha'), '');
    });

    test('usuarios: viajes como pasajero y como conductor desde los rankings', () {
      final users = <Map<String, dynamic>>[
        {
          'user_id': 'u1',
          'full_name': 'Ana',
          'email': 'ana@x.cl',
          'phone': '+56911111111',
          'active_mode': 'passenger',
          'account_status': 'active',
          'zone_name': 'Iquique',
          'created_at': '2026-11-01T10:00:00Z',
        },
        {'user_id': 'u2', 'full_name': 'Luis', 'driver_status': 'approved'},
      ];
      final csv = adminUsersExportCsv(
        users,
        passengerRanking: adminRankingById([
          {'user_id': 'u1', 'completed_trips': 7, 'first_completed_at': '2026-11-02T10:00:00Z', 'last_completed_at': '2026-11-20T10:00:00Z'},
        ]),
        driverRanking: adminRankingById([
          {'user_id': 'u2', 'completed_trips': 12},
        ]),
      );
      final lines = csv.trim().split('\r\n');
      expect(lines.length, 3);
      for (final line in lines) {
        expect(line.split(';').length, adminUsersExportHeaders.length);
      }
      expect(lines[1], contains('Ana;ana@x.cl; +56911111111;Pasajero;Activa'));
      expect(lines[1], contains(';7;'));
      expect(lines[2], contains('Luis;'));
      expect(lines[2], contains('Aprobado'));
      expect(lines[2], contains(';0;;;12;u2'));
    });

    test('un nombre que parece fórmula se neutraliza', () {
      final csv = adminDriversExportCsv([{'user_id': 'x', 'full_name': '=HYPERLINK("x")'}]);
      expect(csv.split('\r\n')[1], startsWith("\"'=HYPERLINK(\"\"x\"\")\""));
    });

    test('nombres de archivo', () {
      final day = DateTime(2026, 11, 24);
      expect(adminDriversFileName(day: day), 'conductores-todos-2026-11-24.csv');
      expect(adminDriversFileName(status: 'approved', day: day), 'conductores-aprobados-2026-11-24.csv');
      expect(adminUsersFileName(day: day), 'usuarios-2026-11-24.csv');
    });

    test('un teléfono válido conserva el + como texto y otros valores se neutralizan', () {
      final csv = adminDriversExportCsv([
        {'user_id': 'x', 'full_name': 'A', 'phone': '+56 9 8280 7639'},
        {'user_id': 'y', 'full_name': 'B', 'phone': '=1+1'},
      ]);
      final lines = csv.split('\r\n');
      expect(lines[1], contains('; +56 9 8280 7639;'));
      expect(lines[2], contains(";'=1+1;"));
    });

    test('el panel exporta todo, no solo la página ni el filtro', () {
      final source = File('lib/admin_panel.dart').readAsStringSync();
      expect(source, contains("'admin_driver_export_v1'"));
      expect(source, contains('onExport: _exportDrivers,'));
      expect(source, contains('onExport: _exportUsers,'));
      expect(source, contains("'admin_completed_trip_ranking_v1'"));
    });
  });
}
