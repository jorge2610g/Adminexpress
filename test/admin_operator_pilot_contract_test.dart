import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('operadores solo visibles a superadmin y zona fija para operadores', () {
    final panel = File('lib/admin_panel.dart').readAsStringSync();
    expect(panel, contains("adminAccess['role'] != 'super_admin'"));
    expect(panel, contains("32: 'operators'"));
    expect(panel, contains('return const AdminOperatorsPage();'));
    expect(panel, contains("if (_zoneScoped)"));
  });

  test('alta protegida y limpieza de cuentas ante error', () {
    final source = File('supabase/functions/admin-create-operator/index.ts').readAsStringSync();
    expect(source, contains('getUser(token)'));
    expect(source, contains("supported = new Set(['users', 'dashboard', 'trips', 'drivers'])"));
    expect(source, contains('deleteUser(userId)'));
    expect(source, contains("zone?.active !== true"));
  });
}
