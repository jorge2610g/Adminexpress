import 'package:supabase_flutter/supabase_flutter.dart';

/// Compile-time deployment identity: one Supabase project per deployed site.
/// The publishable keys below are *public client keys*, never service_role.
/// Preview must be compiled using --dart-define=ADMIN_ENV=preview.
const adminDeployment = String.fromEnvironment(
  'ADMIN_ENV',
  defaultValue: 'production',
);
const bool adminIsPreview = adminDeployment == 'preview';

const _productionUrl = 'https://zgpijrznvaskgcmauwxx.supabase.co';
const _previewUrl = 'https://xbphilqezmwfjfpdbwad.supabase.co';

const _productionPublishableKey =
    'sb_publishable_MALGs-X8KdmJSq-QQzeazQ_p5xsfrZP';
const _previewPublishableKey =
    'sb_publishable_Gj9wcPPgkBhypbL8xIx2-w_guLesRNY';

const supabaseUrl = adminIsPreview ? _previewUrl : _productionUrl;
const supabasePublishableKey = adminIsPreview
    ? _previewPublishableKey
    : _productionPublishableKey;

/// Reject misspelled flags instead of silently using Production.
void validateAdminDeployment() {
  if (adminDeployment != 'production' && adminDeployment != 'preview') {
    throw StateError(
      'ADMIN_ENV inválido. Debe ser production o preview.',
    );
  }
  if (adminIsPreview && supabaseUrl != _previewUrl) {
    throw StateError('El panel de prueba no apunta a Supabase Preview.');
  }
  if (!adminIsPreview && supabaseUrl != _productionUrl) {
    throw StateError('El panel de producción no apunta a Supabase Production.');
  }
}

SupabaseClient get supabase => Supabase.instance.client;
