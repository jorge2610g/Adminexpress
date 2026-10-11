import 'package:supabase_flutter/supabase_flutter.dart';

/// One immutable environment per compiled site, with independent projects.
/// Both frontend keys are publishable (never service_role). Server-side RPCs
/// must still enforce authenticated admin roles and permissions.
const adminDeployment = String.fromEnvironment(
  'ADMIN_ENV',
  defaultValue: 'production',
);
const bool adminIsPreview = adminDeployment == 'preview';

const _productionUrl = 'https://zgpijrznvaskgcmauwxx.supabase.co';
const _productionPublishableKey =
    'sb_publishable_MALGs-X8KdmJSq-QQzeazQ_p5xsfrZP';
const _previewUrl = 'https://xbphilqezmwfjfpdbwad.supabase.co';
const _previewPublishableKey = 'sb_publishable_Gj9wcPPgkBhypbL8xIx2-w_guLesRNY';
// A Preview build must never initialize a Supabase client for Production.
const supabaseUrl = adminIsPreview ? _previewUrl : _productionUrl;
const supabasePublishableKey =
    adminIsPreview ? _previewPublishableKey : _productionPublishableKey;
const adminRuntimeChannel = adminIsPreview ? 'preview' : 'production';

/// Canonical Google OAuth return destination of the published Preview panel.
/// Supabase Auth must explicitly allowlist this URL under Authentication >
/// URL Configuration > Redirect URLs. NEVER change the global Site URL to
/// solve Preview sign-in; that would alter unrelated passenger redirects.
const adminPreviewGoogleOAuthRedirectUrl =
    'https://admin.expressviajes.online/preview/';


/// A separate web LocalStorage session bound to the dedicated Preview project.
/// Production deliberately keeps the original/default storage key so no
/// existing Production administrator is unexpectedly signed out.
const adminPreviewAuthSessionStorageKey =
    'express-admin-preview-xbphilqezmwfjfpdbwad-session-v1';


/// Reject misspelled flags instead of silently using Production.
void validateAdminDeployment() {
  if (adminDeployment != 'production' && adminDeployment != 'preview') {
    throw StateError(
      'ADMIN_ENV inválido. Debe ser production o preview.',
    );
  }
  if (_previewUrl == _productionUrl ||
      _previewPublishableKey == _productionPublishableKey) {
    throw StateError('Las credenciales de Preview no están aisladas.');
  }
  if (adminIsPreview) {
    if (supabaseUrl != _previewUrl ||
        supabasePublishableKey != _previewPublishableKey) {
      throw StateError('Preview debe usar exclusivamente Express Preview.');
    }
  } else if (supabaseUrl != _productionUrl ||
      supabasePublishableKey != _productionPublishableKey) {
    throw StateError('Producción debe usar exclusivamente Express Production.');
  }
  if (adminRuntimeChannel != (adminIsPreview ? 'preview' : 'production')) {
    throw StateError('Canal del panel no coincide con ADMIN_ENV.');
  }
}

SupabaseClient get supabase => Supabase.instance.client;
