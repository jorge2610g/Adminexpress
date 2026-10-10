import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/admin_priority_metrics.dart';

void main() {
  test('priority indicators clamp backend values to 0..100', () {
    expect(AdminPriorityMetrics.value(-3), 0);
    expect(AdminPriorityMetrics.value('42.5'), 42.5);
    expect(AdminPriorityMetrics.value(170), 100);
    expect(AdminPriorityMetrics.value(null), 0);
  });

  for (final width in <double>[320, 390, 900]) {
    testWidgets('E4 ranking renders all metrics at ${width.toInt()} px', (tester) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(12),
              child: AdminPriorityMetrics(
                metrics: {
                  'rating': 90,
                  'reviews': 62,
                  'experience': 48,
                  'frequency': 75,
                },
              ),
            ),
          ),
        ),
      );
      for (final label in <String>['Reputación','Reseñas','Experiencia','Frecuencia']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  }
}
