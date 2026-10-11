import 'package:adminexpress/core/admin_records_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sample = <Map<String, dynamic>>[
    {
      'id': 'qa-trip-01',
      'pickup_address': 'Terminal de buses',
      'destination_address': 'Plaza Principal',
      'status': 'in_progress',
      'category': 'Auto',
      'final_fare': 35,
      'country_code': 'BO',
      'passenger_name': 'Pasajero QA',
      'driver_name': 'Conductor QA',
      'payment_status': 'pending',
      'created_at': '2026-10-10',
    },
  ];

  testWidgets('Mobile records open full details without losing actions',
      (tester) async {
    var openings = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: SingleChildScrollView(
            child: AdminRecordsTable(
              kind: AdminRecordsKind.trips,
              rows: sample,
              tryOpen: (_) {
                openings++;
                return true;
              },
              detailBuilder: (_) => const Text('Ficha completa'),
            ),
          ),
        ),
      ),
    ));

    expect(find.text('Terminal de buses'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
    expect(find.text('35 Bs'), findsOneWidget);
    await tester.tap(find.text('Terminal de buses'));
    expect(openings, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Desktop renders mockup table headings and keeps inline actions',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 900)),
          child: SingleChildScrollView(
            child: AdminRecordsTable(
              kind: AdminRecordsKind.drivers,
              rows: const [
                {
                  'user_id': 'qa-driver-01',
                  'full_name': 'Conductor QA',
                  'email': 'qa@example.invalid',
                  'city': 'Trinidad',
                  'vehicle_summary': 'Motocicleta',
                  'approval_status': 'pending',
                  'online_status': 'offline',
                }
              ],
              detailBuilder: (_) => const Text('Acciones de revisión'),
            ),
          ),
        ),
      ),
    ));

    expect(find.text('CONDUCTOR'), findsOneWidget);
    expect(find.text('VEHÍCULO'), findsOneWidget);
    expect(find.text('APROBACIÓN'), findsOneWidget);
    // The last action column is horizontally scrollable at 800 px.
    // Bring it on screen before interacting, just as the user would.
    await tester.ensureVisible(find.byTooltip('Ver detalle y acciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ver detalle y acciones'));
    await tester.pump();
    expect(find.text('Acciones de revisión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
