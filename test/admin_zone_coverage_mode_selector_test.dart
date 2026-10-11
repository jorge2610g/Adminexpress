import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/admin_zone_coverage_mode_selector.dart';

void main() {
  for (final width in <double>[390, 900]) {
    testWidgets('E7 coverage switches exclusively at ${width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      String mode = 'radius';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.all(20),
            child: AdminZoneCoverageModeSelector(
              mode: mode,
              onChanged: (value) => setState(() => mode = value),
            ),
          ),
        )),
      ));
      expect(find.text('Radio'), findsOneWidget);
      expect(find.text('Polígono'), findsOneWidget);
      expect(mode, 'radius');
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      await tester.tap(find.text('Polígono'));
      await tester.pump();
      expect(mode, 'polygon');
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      await tester.tap(find.text('Radio'));
      await tester.pump();
      expect(mode, 'radius');
      expect(tester.takeException(), isNull);
    });
  }
}
