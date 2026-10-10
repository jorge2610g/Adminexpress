import 'package:adminexpress/core/admin_sos_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SOS mockup card shows severity and keeps Resolve working',
      (tester) async {
    var resolved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSosRow(
            row: const {
              'id': 'sos-qa-1',
              'user_name': 'Pasajero QA',
              'status': 'open',
              'created_at': '2026-10-10T14:00:00Z',
            },
            onResolve: () => resolved = true,
          ),
        ),
      ),
    );
    expect(find.text('Pasajero QA'), findsOneWidget);
    expect(find.textContaining('Abierta'), findsOneWidget);
    await tester.tap(find.text('Resolver'));
    expect(resolved, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Read-only monitor cannot resolve emergencies', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminSosRow(
            row: {
              'user_name': 'Usuario Express',
              'status': 'acknowledged',
            },
          ),
        ),
      ),
    );
    expect(find.text('Usuario Express'), findsOneWidget);
    expect(find.textContaining('Atendida'), findsOneWidget);
    expect(find.text('Resolver'), findsNothing);
  });
}
