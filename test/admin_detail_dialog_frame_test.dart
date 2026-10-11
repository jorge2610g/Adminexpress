import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/admin_detail_dialog_frame.dart';
import 'package:adminexpress/core/admin_widgets.dart';

void main() {
  for (final width in <double>[390, 1280]) {
    testWidgets(
      'E3 detail overlay stays readable and closable at ${width.toInt()} px',
      (tester) async {
        tester.view.physicalSize = Size(width, 920);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AdminDetailDialogFrame(
                        title: 'Ficha del conductor',
                        subtitle: 'conductor@example.com',
                        icon: Icons.badge_outlined,
                        status: 'Pendiente',
                        statusTone: AdminStatusTone.warning,
                        child: const SingleChildScrollView(
                          child: Column(
                            children: [
                              Text('Fotos para aprobación'),
                              Text('Datos personales y operación'),
                              Text('Documentos e identidad'),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text('Abrir ficha'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir ficha'));
        await tester.pumpAndSettle();

        expect(find.text('Ficha del conductor'), findsOneWidget);
        expect(find.text('conductor@example.com'), findsOneWidget);
        expect(find.text('Pendiente'), findsOneWidget);
        expect(find.text('Documentos e identidad'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Cerrar'));
        await tester.pumpAndSettle();
        expect(find.text('Abrir ficha'), findsOneWidget);
        expect(find.text('Ficha del conductor'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
