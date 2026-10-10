import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/admin_widgets.dart';

void main() {
  for (final width in <double>[390, 960]) {
    testWidgets('The shared mockup hero keeps actions usable at ${width.toInt()} px',
        (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: AdminPageHero(
                  title: 'Conductores',
                  subtitle: 'Requisitos, aprobaciones e identidad',
                  icon: Icons.drive_eta_rounded,
                  trailing: FilledButton(
                    onPressed: () => pressed = true,
                    child: const Text('Ajuste de requisitos'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Conductores'), findsOneWidget);
      expect(find.text('Ajuste de requisitos'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ajuste de requisitos'));
      expect(pressed, isTrue);
    });
  }

  testWidgets('The shared card retains its content on a compact screen',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: AdminCard(
              child: Text('Documentos del conductor'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Documentos del conductor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
