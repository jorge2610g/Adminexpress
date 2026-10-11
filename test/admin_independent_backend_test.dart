import 'package:flutter_test/flutter_test.dart';
import '../lib/core/supabase_client.dart';

void main() {
  test('Admin deployment is pinned to one physical Supabase project', () {
    validateAdminDeployment();
    expect(adminIsPreview, adminDeployment == 'preview');
    expect(adminRuntimeChannel, adminDeployment);

    final preview = 'https://xbphilqezmwfjfpdbwad.supabase.co';
    final production = 'https://zgpijrznvaskgcmauwxx.supabase.co';
    expect(preview, isNot(production));
    expect(supabasePublishableKey, startsWith('sb_publishable_'));

    if (adminIsPreview) {
      expect(supabaseUrl, preview);
      expect(supabaseUrl, isNot(production));
      expect(adminPreviewAuthSessionStorageKey, contains('xbphilqezmwfjfpdbwad'));
    } else {
      expect(supabaseUrl, production);
      expect(supabaseUrl, isNot(preview));
    }
  });
}
