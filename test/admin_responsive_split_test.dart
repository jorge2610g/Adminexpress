import 'package:adminexpress/core/admin_responsive_split.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in <double>[390, 1280]) {
    testWidgets('E6 split keeps both Avisos panels at ${width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminResponsiveSplit(
              primary: [Text('Enviar avisos')],
              secondary: [Text('Historial y telemetría push')],
            ),
          ),
        ),
      );

      expect(find.text('Enviar avisos'), findsOneWidget);
      expect(find.text('Historial y telemetría push'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        find.byType(Row),
        width >= 960 ? findsOneWidget : findsNothing,
      );
    });
  }
}
