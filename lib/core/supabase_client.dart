import 'package:supabase_flutter/supabase_flutter.dart';

/// Compile-time website identity. Both sites share the MAIN Supabase project,
/// but all Preview administrative actions MUST be scoped to QA data via RPC
/// p_channel='preview' or the server-side admin_environment_config shadow.
/// Do not confuse a distinct URL with a distinct database. No service_role here.
const adminDeployment = String.fromEnvironment(
  'ADMIN_ENV',
  defaultValue: 'production',
);
const bool adminIsPreview = adminDeployment == 'preview';

const _productionUrl = 'https://zgpijrznvaskgcmauwxx.supabase.co';
const _productionPublishableKey =
    'sb_publishable_MALGs-X8KdmJSq-QQzeazQ_p5xsfrZP';
// Same authentication and storage host for both websites.
// ADMIN_ENV distinguishes the admin data channel, never the database.
const supabaseUrl = _productionUrl;
const supabasePublishableKey = _productionPublishableKey;
const adminRuntimeChannel = adminIsPreview ? 'preview' : 'production';

/// Reject misspelled flags instead of silently using Production.
void validateAdminDeployment() {
  if (adminDeployment != 'production' && adminDeployment != 'preview') {
    throw StateError(
      'ADMIN_ENV inválido. Debe ser production o preview.',
    );
  }
  if (supabaseUrl != _productionUrl ||
      supabasePublishableKey != _productionPublishableKey) {
    throw StateError('Ambas páginas deben usar Supabase principal.');
  }
  if (adminRuntimeChannel != (adminIsPreview ? 'preview' : 'production')) {
    throw StateError('Canal del panel no coincide con ADMIN_ENV.');
  }
}

SupabaseClient get supabase => Supabase.instance.client;
