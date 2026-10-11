import 'package:flutter_test/flutter_test.dart';
import '../lib/core/supabase_client.dart';

void main() {
  test('Both websites use ONE Supabase project with different data channels', () {
    validateAdminDeployment();
    const expected = 'https://zgpijrznvaskgcmauwxx.supabase.co';
    expect(supabaseUrl, expected);
    expect(supabasePublishableKey, startsWith('sb_publishable_'));
    expect(adminDeployment, anyOf('preview', 'production'));
    expect(adminIsPreview, adminDeployment == 'preview');
    expect(adminRuntimeChannel, adminDeployment);
  });

  test('Preview Auth session remains separate from the Production session', () {
    expect(adminPreviewAuthSessionStorageKey, contains('zgpijrznvaskgcmauwxx'));
    expect(adminPreviewAuthSessionStorageKey, contains('preview'));
    expect(adminPreviewGoogleOAuthRedirectUrl,
        'https://admin.expressviajes.online/preview/');
  });
}
