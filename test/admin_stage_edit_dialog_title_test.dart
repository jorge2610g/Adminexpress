import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/core/admin_stage_edit_dialog_title.dart';

void main() {
  for (final width in <double>[390, 960]) {
    testWidgets('E4 modal heading is responsive at ${width.toInt()} px',
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
              builder: (context) => FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const AdminStageEditDialogTitle(
                      title: 'Configuración de Express Market',
                      subtitle: 'Preview · Bolivia · Trinidad',
                      icon: Icons.settings_outlined,
                    ),
                    content: const SizedBox(
                      width: 550,
                      child: Text('Ajustes del módulo'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Configuración de Express Market'), findsOneWidget);
      expect(find.text('Preview · Bolivia · Trinidad'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
