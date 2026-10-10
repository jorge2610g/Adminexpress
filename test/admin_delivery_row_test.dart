import 'package:adminexpress/core/admin_delivery_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Delivery artboard uses its accordion, not the Viajes table',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminDeliveryRow(
              row: const {
                'id': 'qa-delivery',
                'pickup_address': 'Farmacia Central',
                'dropoff_address': 'Calle Nicolas Suarez',
                'status': 'picked_up',
                'package_type': 'Medicamentos',
                'proposed_fare': 12,
                'country_code': 'BO',
                'customer_name': 'Cliente QA',
                'courier_name': 'Repartidor QA',
                'payment_method': 'cash',
                'created_at': '2026-10-10T10:00:00Z',
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Recogido'), findsOneWidget);
    expect(find.text('Medicamentos'), findsOneWidget);
    expect(find.text('Bs 12.00'), findsOneWidget);
    expect(find.textContaining('Cliente QA', findRichText: true), findsNothing);

    await tester.tap(find.text('Recogido'));
    await tester.pump();
    expect(find.textContaining('Cliente QA', findRichText: true), findsOneWidget);
    expect(find.textContaining('Repartidor QA', findRichText: true), findsOneWidget);
    expect(find.textContaining('Efectivo', findRichText: true), findsOneWidget);
    expect(find.text('Ver detalle del pedido'), findsOneWidget);
    await tester.tap(find.text('Ver detalle del pedido'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Detalle del pedido'), findsOneWidget);
    expect(find.text('Ruta y participantes'), findsOneWidget);
    expect(find.text('Operación y pago'), findsOneWidget);
    expect(find.text('Cliente QA'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Detalle del pedido'), findsNothing);
  });

  testWidgets('Chile delivery correctly shows CLP', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminDeliveryRow(
            row: {
              'pickup_address': 'Iquique',
              'dropoff_address': 'Centro',
              'status': 'delivered',
              'proposed_fare': 2500,
              'country_code': 'CL',
              'payment_method': 'transfer',
            },
          ),
        ),
      ),
    );
    expect(find.text('CLP 2500.00'), findsOneWidget);
    expect(find.text('Entregado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
