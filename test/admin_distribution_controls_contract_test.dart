import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  setUpAll(() {
    source = File('lib/admin_single_app_release.dart').readAsStringSync();
  });

  test('Admin has build history, version/critical switches, notes and store URL',
      () {
    expect(source, contains('Historial de Builds · Distribución'));
    expect(source, contains('Distribución del Build'));
    expect(source, contains('Versión actual'));
    expect(source, contains('Actualización crítica'));
    expect(source, contains('Notas de la versión'));
    expect(source, contains('URL de Play Store (opcional)'));
    expect(source, contains('Guardar distribución'));
    expect(source, contains('Anterior'));
    expect(source, contains('Siguiente'));
  });

  test('Server authenticated RPC controls all distribution writes', () {
    expect(source, contains("admin_android_update_distributions"));
    expect(source, contains("admin_save_android_update_distribution"));
    expect(source, contains("'p_build_id': jobId"));
    expect(source, contains("'p_channel': values['channel']"));
    expect(source, contains("'p_confirmed_in_play': values['confirmed_play']"));
    expect(source, contains("'p_confirmed_critical': values['confirmed_critical']"));
    expect(source, contains('if (!canManage || busy'));
    expect(source, isNot(contains("supabase.from('app_releases').update")));
  });

  test('Internal builds never appear as already-available Production releases',
      () {
    expect(source, contains("build['artifact_type'] == 'aab'"));
    expect(source, contains("channel == 'production' && isCurrent"));
    expect(source, contains('Las pruebas internas no activan avisos en Producción'));
    expect(source, contains('Pruebas internas: esta configuración se guarda'));
    expect(source, contains('productionEligible'));
    expect(source, contains('confirmedPlay'));
    expect(source, contains('confirmedCritical'));
  });

  test('Existing signed release and app-build queue are retained', () {
    expect(source, contains('Future<void> _queueInternalAab() async'));
    expect(source, contains('admin_publish_build'));
    expect(source, contains('latest_app_release'));
    expect(source, contains('Avisar actualización a pasajeros y conductores'));
  });
}
