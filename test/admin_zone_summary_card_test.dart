import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/admin_zone_summary_card.dart';

void main() {
  for (final width in <double>[390, 1280]) {
    testWidgets('E7 zone actions and polygon summary at ${width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = Size(width, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var partners = 0;
      var payments = 0;
      var edits = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: AdminZoneSummaryCard(
              zone: const {
                'name':'Trinidad',
                'city':'Trinidad',
                'country':'Bolivia',
                'currency_code':'BOB',
                'coverage_mode':'polygon',
                'radius_km':500,
                'active':true,
                'zone_key':'trinidad',
              },
              onPartners: () => partners++,
              onPayments: () => payments++,
              onEdit: () => edits++,
            ),
          ),
        ),
      ));
      expect(find.text('Trinidad'), findsWidgets);
      expect(find.textContaining('Polígono'), findsOneWidget);
      expect(find.textContaining('Radio 500 km'), findsNothing);
      await tester.tap(find.text('Aliados'));
      await tester.tap(find.text('Pagos'));
      await tester.tap(find.text('Editar'));
      expect((partners, payments, edits), (1, 1, 1));
      expect(tester.takeException(), isNull);
    });
  }
}
