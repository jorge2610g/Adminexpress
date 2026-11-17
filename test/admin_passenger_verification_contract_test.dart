import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Interruptores de verificación de pasajeros en la página de Usuarios.
void main() {
  late String widgetSource;
  late String panel;

  setUpAll(() {
    widgetSource = File('lib/admin_passenger_verification.dart').readAsStringSync();
    panel = File('lib/admin_panel.dart').readAsStringSync();
  });

  test('la tarjeta lee y guarda con las RPC de configuración', () {
    expect(widgetSource, contains("'admin_passenger_verification_settings_get'"));
    expect(widgetSource, contains("'admin_passenger_verification_settings_update'"));
    expect(widgetSource, contains("'p_profile_photo_required': _profilePhoto"));
    expect(widgetSource, contains("'p_identity_document_required': _identity"));
    expect(widgetSource, contains("'p_face_selfie_required': _selfie"));
  });

  test('los tres interruptores existen y carnet y selfie arrancan apagados', () {
    expect(widgetSource, contains('bool _profilePhoto = true;'));
    expect(widgetSource, contains('bool _identity = false;'));
    expect(widgetSource, contains('bool _selfie = false;'));
    expect(widgetSource, contains('Pedir foto de perfil'));
    expect(widgetSource, contains('Pedir carnet de identidad'));
    expect(widgetSource, contains('Pedir selfie para reconocimiento facial'));
  });

  test('el panel no escribe en Storage desde la tarjeta', () {
    expect(widgetSource, isNot(contains('storage.from(')));
    expect(widgetSource, isNot(contains('uploadBinary')));
  });

  test('la tarjeta solo aparece para super_admin, igual que la base', () {
    expect(
      panel,
      contains(
        "if (adminAccess['role'] == 'super_admin')\n"
        "              const Padding(\n"
        "                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),\n"
        "                child: AdminPassengerVerificationSettings(),",
      ),
    );
    expect(panel, contains("import 'admin_passenger_verification.dart';"));
  });
}
