import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/admin_demand_stats_grid.dart';

void main() {
  for (final width in <double>[390, 1280]) {
    testWidgets('E7 demand retains 7 values at ${width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: AdminDemandStatsGrid(
              items: [
                ('Estado','Activo'),
                ('Demanda baja','0 %'),
                ('Elevada','10 %'),
                ('Alta','15 %'),
                ('Crítica','20 %'),
                ('Radio','5 km'),
                ('Ventana','10 min'),
              ],
            ),
          ),
        ),
      ));
      for (final label in const [
        'Estado','Demanda baja','Elevada','Alta','Crítica','Radio','Ventana',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
