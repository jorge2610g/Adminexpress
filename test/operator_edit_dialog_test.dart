import 'package:adminexpress/admin_operators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Abre la ventana «Editar operador» desde un botón, como hace la lista de accesos.
Future<void> _openDialog(
  WidgetTester tester, {
  required bool initialActive,
  required Set<String> initialModules,
  void Function(OperatorEditResult?)? onClosed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showDialog<OperatorEditResult>(
                  context: context,
                  builder: (_) => OperatorEditDialog(
                    userLabel: 'Ana Operadora · ana@ejemplo.com',
                    zoneLabel: 'Iquique · Iquique',
                    initialActive: initialActive,
                    initialModules: initialModules,
                  ),
                );
                onClosed?.call(result);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  expect(find.text('Editar operador'), findsOneWidget);
}

String _label(String key) => operatorSelectorModules.firstWhere((m) => m.key == key).label;

void main() {
  testWidgets('Editar operador: desactivar el acceso y añadir un módulo devuelve el cambio',
      (tester) async {
    OperatorEditResult? result;
    await _openDialog(
      tester,
      initialActive: true,
      initialModules: const {'trips'},
      onClosed: (value) => result = value,
    );

    final driversTile = find.widgetWithText(CheckboxListTile, _label('drivers'));
    await tester.ensureVisible(driversTile);
    await tester.tap(driversTile);
    await tester.pumpAndSettle();

    final accessSwitch = find.widgetWithText(SwitchListTile, 'Acceso activo');
    await tester.ensureVisible(accessSwitch);
    await tester.tap(accessSwitch);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.active, isFalse);
    expect(result!.modules, containsAll(['users', 'trips', 'drivers']));
  });

  testWidgets('Usuarios siempre va incluido y no se puede quitar', (tester) async {
    await _openDialog(tester, initialActive: true, initialModules: const {'trips'});

    final usersTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, _label('users')),
    );
    expect(usersTile.value, isTrue);
    expect(usersTile.onChanged, isNull);
  });
}
