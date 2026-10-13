import 'package:supabase_flutter/supabase_flutter.dart';

/// Adminexpress uses one canonical web application and one Supabase project.
/// Preview vs Production is resolved server-side from the authenticated
/// administrator identity. The browser build never chooses the data channel.
const _productionUrl = 'https://zgpijrznvaskgcmauwxx.supabase.co';
const _productionPublishableKey =
    'sb_publishable_MALGs-X8KdmJSq-QQzeazQ_p5xsfrZP';

const supabaseUrl = _productionUrl;
const supabasePublishableKey = _productionPublishableKey;

/// Startup guard: Adminexpress must always use the primary Express project.
/// Environment authorization is intentionally NOT decided at build time.
void validateAdminDeployment() {
  if (supabaseUrl != _productionUrl ||
      supabasePublishableKey != _productionPublishableKey) {
    throw StateError('Adminexpress debe usar Supabase principal.');
  }
}

SupabaseClient get supabase => Supabase.instance.client;
