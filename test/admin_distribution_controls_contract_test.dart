import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/admin_single_app_release.dart').readAsStringSync();
  });

  test('Distribution is only for Google Play Production', () {
    expect(source, contains('Distribución de actualizaciones · Producción'));
    expect(source, contains('Distribución · Google Play Producción'));
    expect(source, contains('Destino: Google Play · Producción'));
    expect(source, contains('Versión actual'));
    expect(source, contains('Actualización crítica'));
    expect(source, contains('Notas de la versión'));
    expect(source, contains('Enlace oficial de Play Store'));
    expect(source, contains('Guardar distribución'));
    expect(source, isNot(contains('Configura cómo se distribuye este build:')));
    expect(source, isNot(contains('Pruebas internas: esta configuración se guarda')));
  });

  test('Only the Google Play verified signed Build can appear in history', () {
    expect(source, contains("rawStatus['production_verified_build_job_id']"));
    expect(source, contains("row['id']?.toString() == verifiedJobId"));
    expect(source, contains("row['signing_mode'] == 'production'"));
    expect(source, contains('jobId != verifiedId'));
    expect(source, contains('build != storeBuild'));
    expect(source, contains("_savedDistribution(jobId, 'production')"));
  });

  test('Changes use the server authorized RPC and the Production channel', () {
    expect(source, contains('admin_android_update_distributions'));
    expect(source, contains('admin_save_android_update_distribution'));
    expect(source, contains("'p_channel': 'production'"));
    expect(source, contains("'p_build_id': jobId"));
    expect(source, contains("'p_confirmed_in_play': values['confirmed_play']"));
    expect(source, contains("'p_confirmed_critical': values['confirmed_critical']"));
    expect(source, contains('if (!canManage || busy'));
    expect(source, isNot(contains("supabase.from('app_releases').update")));
  });

  test('Critical update is opt-in and the unified candidate flow is retained', () {
    expect(source, contains('bool isCritical = saved?'));
    expect(source, contains('confirmedPlay = false'));
    expect(source, contains('confirmedCritical = false'));
    expect(source, contains('mustConfirm = isCurrent && !confirmedPlay'));
    expect(source, contains('mustConfirmCritical = isCritical && !confirmedCritical'));
    expect(source, contains("'admin_queue_single_app_candidate'"));
    expect(source, contains('admin_publish_build'));
    expect(source, contains('latest_app_release'));
    expect(source, isNot(contains('Future<void> _queueInternalAab() async')));
  });
}
