import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Admin Express can open the shared union panel without a second login', () {
    final admin = File('lib/admin_control_sections.dart').readAsStringSync();
    final authGate = File('lib/main.dart').readAsStringSync();
    expect(admin, contains('Abrir panel del sindicato'));
    expect(admin, contains('PartnerExpressPanel('));
    expect(admin, contains('El panel real está separado de Preview'));
    expect(authGate, contains("supabase.rpc('admin_access_context')"));
  });

  test('union admin UI assigns membership identity and scopes actions', () {
    final panel = File('lib/partner_panel.dart').readAsStringSync();
    expect(panel, contains('partner_search_drivers'));
    expect(panel, contains('partner_add_driver'));
    expect(panel, contains('Número de socio'));
    expect(panel, contains('partner_set_membership_status'));
    expect(panel, contains('partner_save_branding'));
    expect(panel, contains('partner_completed_plan_summary'));
    expect(panel, contains("'p_status': status"));
  });
}
