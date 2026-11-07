import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final settings = File('lib/admin_control_sections.dart').readAsStringSync();
  final panel = File('lib/admin_panel.dart').readAsStringSync();

  test('Configuración tiene la pestaña Redes sociales con su tarjeta', () {
    expect(settings, contains("'Redes sociales',\n    ];"));
    expect(settings, contains('case 8:\n        content = AdminSocialLinksSettingsCard('));
    expect(settings, contains("settingsTab == 7 || settingsTab == 8"));
    expect(settings, contains("title: 'Redes sociales'"));
  });

  test('la tarjeta usa las RPC de lectura pública, lista y guardado', () {
    expect(settings, contains("supabase.rpc('admin_app_social_links_list_v1')"));
    expect(settings, contains("supabase.rpc('app_social_links_public_v1')"));
    expect(settings, contains("supabase.rpc(\n        'admin_app_social_links_save_v1'"));
    expect(settings, contains("'p_audience': audience"));
    expect(settings, contains("'p_network': network"));
    expect(settings, contains("'p_url': url"));
  });

  test('solo el super admin edita; el resto ve los campos en solo lectura', () {
    expect(panel, contains("canEditSocialLinks:\n              adminAccess['role'] == 'super_admin' && !_readOnly"));
    expect(settings, contains('enabled: widget.canEdit'));
    expect(settings, contains('!widget.canEdit || saving'));
  });

  test('valida que el enlace sea https y no supere 300 caracteres', () {
    expect(settings, contains("url.startsWith('https://')"));
    expect(settings, contains('url.length > 300'));
  });
}
