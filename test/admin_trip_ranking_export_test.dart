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

  test('el botón Exportar de conductores y usuarios llama a la RPC del ranking', () {
    final source = File('lib/admin_panel.dart').readAsStringSync();
    expect(source, contains("'admin_completed_trip_ranking_v1'"));
    expect(source, contains("onExport: () => _exportCompletedTripRanking(drivers: true)"));
    expect(source, contains("onExport: () => _exportCompletedTripRanking(drivers: false)"));
    expect(source, contains("'p_role': drivers ? 'driver' : 'passenger'"));
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
    expect(adminTripsFileName(period: 'month', day: day), 'viajes-mes-2026-11-16.csv');
    expect(adminTripsFileName(period: 'today', day: day), 'viajes-hoy-2026-11-16.csv');
    expect(adminTripsFileName(period: 'custom', day: day), 'viajes-rango-2026-11-16.csv');
  });

  test('la lista de viajes exporta todas las páginas del servidor', () {
    final source = File('lib/admin_panel.dart').readAsStringSync();
    expect(source, contains('onExport: _exportTrips,'));
    expect(source, contains('const pageSize = 500;'));
    expect(source, contains("'admin_trip_list_v4'"));
  });
}
