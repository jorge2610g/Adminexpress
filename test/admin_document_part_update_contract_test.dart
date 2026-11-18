import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El administrador actualiza cada documento ya cargado desde la ficha del conductor.
void main() {
  late String dialogs;

  setUpAll(() {
    dialogs = File('lib/admin_detail_dialogs.dart').readAsStringSync();
  });

  test('la RPC de reemplazo de parte se llama con el documento, la ranura y la ruta', () {
    expect(dialogs, contains("'admin_driver_document_part_replace_v1'"));
    expect(dialogs, contains("'p_document_id': documentId"));
    expect(dialogs, contains("'p_slot': slot"));
    expect(dialogs, contains("'p_path': path"));
    expect(dialogs, contains("'p_channel': widget.channel"));
  });

  test('la subida va a la carpeta documents del documento, sin sobrescribir', () {
    expect(
      dialogs,
      contains(r"'${widget.userId}/documents/$documentId/$slot-${DateTime.now().millisecondsSinceEpoch}.$ext'"),
    );
  });

  test('las tarjetas de carné y licencia tienen el botón Actualizar junto a Ver', () {
    final identity = dialogs.indexOf('Widget _identityPartReviewCard(');
    final license = dialogs.indexOf('Widget _licensePartReviewCard(');
    expect(identity, greaterThan(0));
    expect(license, greaterThan(identity));

    final identityBody = dialogs.substring(identity, license);
    final licenseBody = dialogs.substring(license, dialogs.indexOf('\n  Widget ', license + 10));
    for (final body in [identityBody, licenseBody]) {
      final ver = body.indexOf("label: const Text('Ver')");
      final actualizar = body.indexOf("label: const Text('Actualizar')");
      expect(ver, greaterThan(0));
      expect(actualizar, greaterThan(ver));
      expect(body, contains('_updateDocumentPart(document, slot)'));
    }
  });

  test('la foto de perfil se llama Actualizar y usa la RPC de foto de perfil', () {
    expect(dialogs, contains("'Actualizar foto de perfil'"));
    expect(dialogs, contains("'admin_driver_set_profile_photo_v1'"));
    expect(dialogs, contains("if (slot == 'profile') {\n      await _changeProfilePhoto();"));
  });
}
