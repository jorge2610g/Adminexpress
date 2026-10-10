import 'package:adminexpress/core/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in <double>[390, 1032]) {
    testWidgets('PDF plain heading fits width $width and keeps controls active',
        (tester) async {
      var clicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: AdminPlainPageHeading(
                title: 'Prioridad de conductores',
                subtitle: 'Ranking y repartición de solicitudes.',
                trailing: FilledButton(
                  onPressed: () => clicked = true,
                  child: const Text('Configurar'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Prioridad de conductores'), findsOneWidget);
      expect(find.text('Ranking y repartición de solicitudes.'), findsOneWidget);
      await tester.tap(find.text('Configurar'));
      expect(clicked, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
