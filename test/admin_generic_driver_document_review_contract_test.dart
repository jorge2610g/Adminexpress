import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin generic driver photos use authorized versioned review RPC', () {
    final source = File('lib/admin_detail_dialogs.dart').readAsStringSync();
    expect(source, contains("'admin_driver_document_review_part_v2'"));
    expect(source, contains("generic: generic"));
    expect(source, contains("'p_expected_version': version"));
    expect(source, contains("'p_channel': widget.channel"));
    expect(source, contains("containsKey('front')"));
    expect(source, contains("containsKey(slot)"));
    expect(source, contains("'selfie_object_path'"));
    expect(source, contains("if (rejecting && reason.length < 5)"));
    expect(source, contains("'admin_driver_license_review_part'"));
  });
}
