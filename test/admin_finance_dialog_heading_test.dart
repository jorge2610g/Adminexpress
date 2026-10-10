import 'package:adminexpress/core/admin_stage_edit_dialog_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in <double>[390, 1280]) {
    testWidgets('E5 finance dialog heading is usable at ${width.toInt()} px',
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
            body: AlertDialog(
              title: AdminStageEditDialogTitle(
                title: 'Mercado Pago · Trinidad',
                subtitle: 'Credenciales por zona y verificación protegida.',
                icon: Icons.account_balance_wallet_rounded,
              ),
              content: SizedBox(width: 520, child: Text('Public Key')),
            ),
          ),
        ),
      );

      expect(find.text('Mercado Pago · Trinidad'), findsOneWidget);
      expect(
        find.text('Credenciales por zona y verificación protegida.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
