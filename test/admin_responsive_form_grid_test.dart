import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/admin_responsive_form_grid.dart';

void main() {
  for (final width in <double>[320, 390, 760]) {
    testWidgets('E7 dense editor has no overflow at ${width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AdminResponsiveFormGrid(
              children: [
                for (var index = 1; index <= 4; index++)
                  TextFormField(
                    initialValue: '$index',
                    decoration: InputDecoration(labelText: 'Dato $index'),
                  ),
              ],
            ),
          ),
        ),
      ));
      for (var i = 1; i <= 4; i++) {
        expect(find.text('Dato $i'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
