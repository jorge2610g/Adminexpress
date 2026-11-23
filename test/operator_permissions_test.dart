import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adminexpress/admin_operator_permissions.dart';

const _catalog = [
  OperatorPermission(key: 'drivers.view', moduleKey: 'drivers', group: 'Conductores', label: 'Ver conductores'),
  OperatorPermission(key: 'drivers.approve', moduleKey: 'drivers', group: 'Conductores', label: 'Aprobar conductores'),
  OperatorPermission(key: 'drivers.view_documents', moduleKey: 'drivers', group: 'Conductores', label: 'Ver cédula', sensitive: true),
  OperatorPermission(key: 'trips.view', moduleKey: 'trips', group: 'Viajes', label: 'Ver viajes'),
  OperatorPermission(key: 'trips.cancel', moduleKey: 'trips', group: 'Viajes', label: 'Cancelar viajes'),
  OperatorPermission(key: 'dashboard.view', moduleKey: 'dashboard', group: 'Dashboard', label: 'Ver dashboard'),
  OperatorPermission(key: 'live_operations.view', moduleKey: 'live_operations', group: 'Operación en vivo', label: 'Ver operación en vivo'),
  OperatorPermission(key: 'users.view', moduleKey: 'users', group: 'Usuarios', label: 'Ver usuarios'),
];

void main() {
  test('marcar una acción completa el Ver de su módulo', () {
    final r = operatorPermissionsToggled({}, 'drivers.approve', true);
    expect(r, containsAll(['drivers.approve', 'drivers.view']));
  });

  test('quitar el Ver quita todo el módulo', () {
    final r = operatorPermissionsToggled(
        {'drivers.view', 'drivers.approve', 'trips.view'}, 'drivers.view', false);
    expect(r, {'trips.view'});
  });

  test('operación en vivo pide dashboard y conductores', () {
    final r = operatorPermissionsToggled({}, 'live_operations.view', true);
    expect(r, containsAll(['live_operations.view', 'dashboard.view', 'drivers.view']));
    final back = operatorPermissionsToggled(r, 'drivers.view', false);
    expect(back.contains('live_operations.view'), isFalse);
  });

  test('derivar el Ver de los módulos antiguos', () {
    expect(operatorViewPermissionsFor(['drivers', 'trips', 'delivery'], _catalog),
        {'drivers.view', 'trips.view'});
  });

  test('marcar y desmarcar un módulo completo', () {
    final on = operatorPermissionsSetModule({}, _catalog, 'trips', true);
    expect(on, {'trips.view', 'trips.cancel'});
    expect(operatorPermissionsSetModule(on, _catalog, 'trips', false), isEmpty);
  });

  testWidgets('el selector muestra contador, grupos y Seleccionar/Quitar todos',
      (tester) async {
    var selected = <String>{'trips.view'};
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => OperatorPermissionPicker(
              catalog: _catalog,
              selected: selected,
              onChanged: (v) => setState(() => selected = v),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('1 de 8 permisos seleccionados'), findsOneWidget);
    expect(find.text('Viajes (1/2)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('operator-permission-all')));
    await tester.pump();
    expect(find.text('8 de 8 permisos seleccionados'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('operator-permission-none')));
    await tester.pump();
    expect(find.text('0 de 8 permisos seleccionados'), findsOneWidget);
    // Abrir un grupo y marcar una acción completa el Ver.
    await tester.tap(find.text('Conductores (0/3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('operator-permission-drivers.approve')));
    await tester.pump();
    expect(selected, containsAll(['drivers.approve', 'drivers.view']));
  });
}
