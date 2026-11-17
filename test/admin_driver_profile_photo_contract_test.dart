import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El administrador cambia la foto de perfil del conductor desde el panel.
void main() {
  late String dialogs;
  late String migration;

  setUpAll(() {
    dialogs = File('lib/admin_detail_dialogs.dart').readAsStringSync();
    migration = File(
      'supabase/migrations/20261117190000_admin_driver_set_profile_photo_v1.sql',
    ).readAsStringSync();
  });

  test('el botón cambia la foto y usa la RPC de administrador', () {
    expect(dialogs, contains("'admin_driver_set_profile_photo_v1'"));
    expect(dialogs, contains("'p_driver_id': widget.userId"));
    expect(dialogs, contains("'p_channel': widget.channel"));
    expect(dialogs, contains('Cambiar foto de perfil'));
    expect(dialogs, contains('Agregar foto de perfil'));
  });

  test('la subida va solo a la carpeta profile/ del conductor, sin sobrescribir', () {
    expect(
      dialogs,
      contains("'\${widget.userId}/profile/profile-\${DateTime.now().millisecondsSinceEpoch}.\$ext'"),
    );
    expect(dialogs, contains("storage.from('driver-onboarding').uploadBinary("));
    expect(dialogs, contains('upsert: false'));
  });

  test('solo se aceptan JPG, PNG y WebP', () {
    expect(dialogs, contains("if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';"));
    expect(dialogs, contains("if (lower.endsWith('.png')) return 'png';"));
    expect(dialogs, contains("if (lower.endsWith('.webp')) return 'webp';"));
  });

  test('la base limita la ruta a profile/ y deja registro', () {
    expect(migration, contains("split_part(v_path, '/', 2) <> 'profile'"));
    expect(migration, contains("split_part(v_path, '/', 1) <> p_driver_id::text"));
    expect(migration, contains('admin_assert_target_environment(p_driver_id, p_channel)'));
    expect(migration, contains("'driver_profile_photo_replaced'"));
    expect(migration, contains('revoke execute on function public.admin_driver_set_profile_photo_v1(uuid, text, text) from public, anon;'));
    expect(migration, isNot(contains('drop table')));
  });
}
