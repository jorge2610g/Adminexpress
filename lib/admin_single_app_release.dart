import 'dart:convert';

import 'package:flutter/material.dart';
import 'core/admin_friendly_error.dart';
import 'core/admin_friendly_labels.dart';
import 'core/admin_dropdown_field.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'core/supabase_client.dart';

/// One Express Android package. The signed Production candidate itself is
/// tested/certified; no permanent Preview APK is involved.
class AdminSingleAppReleasePage extends StatefulWidget {
  const AdminSingleAppReleasePage({
    super.key,
    required this.productionAccess,
    this.zoneId,
  });
  // Capability from server-side admin_access_context; never a Preview/Production UI mode.
  final bool productionAccess;
  // Optional scoped zone from the canonical admin selector.
  // The release itself is always global, while notices may target one zone.
  final String? zoneId;

  @override
  State<AdminSingleAppReleasePage> createState() =>
      _AdminSingleAppReleasePageState();
}

class _AdminSingleAppReleasePageState extends State<AdminSingleAppReleasePage> {
  Map<String, dynamic> status = const {};
  List<Map<String, dynamic>> releases = const [];
  List<Map<String, dynamic>> internalAabJobs = const [];
  List<Map<String, dynamic>> buildHistory = const [];
  List<Map<String, dynamic>> distributions = const [];
  int historyPage = 0;
  Map<String, dynamic> publishedRelease = const {};
  String? error;
  bool loading = true;
  bool busy = false;

  bool get canManage => widget.productionAccess;
  Map<String, dynamic> get candidate {
    final raw = status['candidate'];
    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  Map<String, dynamic> get verification {
    final raw = status['verification'];
    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant AdminSingleAppReleasePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productionAccess != widget.productionAccess) _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        supabase.rpc('admin_single_app_release_status'),
        supabase.rpc('admin_build_list'),
        supabase.rpc('latest_app_release',
          params: {'p_platform': 'android'}),
        supabase.rpc('admin_android_update_distributions'),
      ]);
      if (!mounted) return;
      final rawStatus = results[0];
      final rawRows = results[1];
      final rawPublished = results[2];
      final rawDistributions = results[3];
      final androidRows = (rawRows is List ? rawRows : const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) => row['platform'] == 'android')
          .toList();
      setState(() {
        publishedRelease = rawPublished is Map
            ? Map<String, dynamic>.from(rawPublished)
            : <String, dynamic>{};
        status = rawStatus is Map
            ? Map<String, dynamic>.from(rawStatus)
            : <String, dynamic>{};
        distributions = (rawDistributions is List ? rawDistributions : const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        // Show ONLY the specific signed AAB verified in Play Production.
        // Other builds sharing versionCode 141 must not be offered for updates.
        final verifiedJobId = rawStatus is Map
            ? rawStatus['production_verified_build_job_id']?.toString()
            : null;
        buildHistory = androidRows.where((row) =>
            verifiedJobId != null &&
            row['id']?.toString() == verifiedJobId &&
            row['status'] == 'ready' &&
            row['signing_mode'] == 'production'
        ).take(1).toList();
        if (historyPage * 8 >= buildHistory.length) historyPage = 0;
        releases = androidRows
            .where((row) => row['artifact_type'] == 'apk+aab')
            .take(15)
            .toList();
        internalAabJobs = androidRows
            .where((row) => row['artifact_type'] == 'aab')
            .take(15)
            .toList();
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = friendlyError(e);
        loading = false;
      });
    }
  }

  void _message(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message.toString())));
  }

  Future<void> _call(String rpc, Map<String, dynamic> params,
      String confirmationMessage) async {
    if (!canManage || busy) return;
    setState(() => busy = true);
    try {
      await supabase.rpc(rpc, params: params);
      await _refresh();
      _message(confirmationMessage);
    } catch (e) {
      _message('No se pudo realizar la operación: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> _confirm(String title, String detail, String action) async {
    if (!canManage || busy) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(detail),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _queue() async {
    if (!canManage || busy) return;
    // Explicit source target; do not default to the last (possibly stale) candidate.
    const currentVersion = '1.6.2';
    final version = TextEditingController(text: currentVersion);
    final changes = TextEditingController();
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preparar APK y AAB reales de Express'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Se usará el código vigente de main, el paquete oficial '
                'com.express.usuario1 y la firma Android existente. '
                'No crea una app de Prueba ni publica en Google Play. '
                'El trabajo quedará en cola: la APK solo se compila después '
                'de la autorización manual AUTORIZO APK QA en GitHub. '
                'La versión 1.6.2 (build 140) debe corresponder al código fuente.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: version,
                decoration: const InputDecoration(
                  labelText: 'Versión (igual a pubspec.yaml)',
                  hintText: '1.6.2',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: changes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas del candidato',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Siguiente versionCode de Google Play: '
                '${status['next_google_play_build'] ?? '—'}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'version': version.text.trim(),
              'notes': changes.text.trim(),
            }),
            child: const Text('Poner en cola'),
          ),
        ],
      ),
    );
    version.dispose();
    changes.dispose();
    if (data == null || data['version']?.isEmpty != false) return;
    if (data['version'] != currentVersion) {
      _message('Versión incorrecta: para este candidato usa 1.6.2.');
      return;
    }
    await _call('admin_queue_single_app_candidate', {
      'p_version_name': data['version'],
      'p_changelog': data['notes'],
    }, 'Trabajo registrado en cola; NO se compilará hasta autorización manual en GitHub. No afecta Google Play.');
  }

  /// Consulta el SHA firmado actual. Nunca toma SHA de campos de usuario.
  Future<String> _currentSignedQaSha() async {
    final url = Uri.parse(
      'https://api.github.com/repos/jorge2610g/Expressdelivery/'
      'branches/work%2Fexpress-unified-android-build141',
    );
    final response = await http.get(url, headers: {
      'Accept': 'application/vnd.github+json',
    }).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('No se pudo verificar la versión firmada.');
    }
    final obj = jsonDecode(response.body);
    final raw = obj is Map && obj['commit'] is Map
        ? (obj['commit'] as Map)['sha']
        : null;
    final sha = raw?.toString().toLowerCase() ?? '';
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sha)) {
      throw StateError('No se pudo verificar la versión en GitHub.');
    }
    return sha;
  }

  /// Solo el administrador autenticado puede registrar el trabajo oficial.
  Future<void> _queueInternalAab() async {
    if (!canManage || busy) return;
    String sourceSha;
    try {
      sourceSha = await _currentSignedQaSha();
    } catch (_) {
      _message('No se pudo verificar GitHub. Ningún AAB se solicitó.');
      return;
    }
    if (!mounted || !canManage || busy) return;
    final sha = TextEditingController(text: sourceSha);
    final notes = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar solo AAB · Pruebas internas'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Se generará solo el AAB firmado de Express '
                  '(com.express.usuario1), sin APK. '
                  'No publica en Google Play ni afecta Producción. '
                  'El servidor debe tener activado el modo AAB-only.',
                ),
                const SizedBox(height: 12),
                const Text('Versión 1.6.3 · Build 141'),
                const SizedBox(height: 10),
                TextField(
                  controller: sha,
                  autocorrect: false,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Versión firmada (verificada)',
                    helperText: 'Se comprobará nuevamente antes de ponerlo en cola',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'El trabajo quedará en cola hasta autorizarlo en GitHub. '
                  'Subir a Pruebas internas requerirá una segunda autorización.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'sha': sha.text.trim().toLowerCase(),
              'notes': notes.text.trim(),
            }),
            child: const Text('Solicitar AAB'),
          ),
        ],
      ),
    );
    sha.dispose();
    notes.dispose();
    if (result == null) return;
    sourceSha = result['sha'] ?? '';
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sourceSha)) {
      _message('La versión firmada no es válida. Intenta de nuevo.');
      return;
    }
    try {
      if (await _currentSignedQaSha() != sourceSha) {
        _message('La rama firmada cambió. Vuelve a solicitar el AAB.');
        return;
      }
    } catch (_) {
      _message('No se pudo verificar GitHub. Ningún AAB se solicitó.');
      return;
    }
    if (!mounted || !canManage || busy) return;
    await _call('admin_create_build_job', {
      'p_platform': 'android',
      'p_artifact_type': 'aab',
      'p_version_name': '1.6.3',
      'p_build_number': 141,
      'p_changelog': result['notes']?.isNotEmpty == true
          ? result['notes']
          : 'AAB solo para Google Play Pruebas internas.',
      'p_commit_sha': sourceSha,
    }, 'AAB en cola. Falta autorización de compilación en GitHub. No publicado en Play.');
  }

  Future<void> _certify() async {
    if (!canManage || busy || candidate['id'] == null) return;
    final notes = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar pruebas Android del APK real'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Instala el APK del candidato firmado y comprueba inicio, '
                'login, GPS/permisos, mapas, llamadas, notificaciones y '
                'funciones de conductor/pasajero necesarias. '
                'Registra únicamente pruebas realizadas.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Evidencia de las pruebas (mínimo 30 caracteres)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, notes.text.trim()),
            child: const Text('Certificar pruebas'),
          ),
        ],
      ),
    );
    notes.dispose();
    if (result == null || result.length < 30) return;
    await _call('admin_certify_single_app_candidate', {
      'p_candidate_id': candidate['id'],
      'p_qa_notes': result,
    }, 'Pruebas registradas para esta versión.');
  }

  Future<void> _approve() async {
    final ok = await _confirm(
      'Aprobar candidato Android',
      'Se fijarán la versión y los archivos exactos del APK y AAB '
      'que ya probaste. No se recompilará para Producción.',
      'Aprobar candidato',
    );
    if (!ok) return;
    await _call('admin_approve_single_app_candidate', {
      'p_candidate_id': candidate['id'],
    }, 'Candidato Android aprobado sin una segunda aplicación de Prueba.');
  }

  Future<void> _promote() async {
    final ok = await _confirm(
      'Promover APK/AAB a Producción',
      'Se usarán exactamente los mismos archivos firmados y la misma versión '
      'hashes que fueron certificados. Esto reserva el versionCode '
      'de Google Play; NO publica automáticamente la actualización.',
      'Promover sin recompilar',
    );
    if (!ok) return;
    await _call('admin_promote_single_app_candidate', {
      'p_candidate_id': candidate['id'],
    }, 'APK/AAB promovidos sin recompilar. Queda por decidir su publicación.');
  }

  bool _isCertifiedPromotion(Map<String, dynamic> row) =>
      canManage &&
      row['status'] == 'ready' &&
      row['signing_mode'] == 'production' &&
      row['artifact_type'] == 'apk+aab' &&
      verification['promoted_build_id']?.toString() == row['id']?.toString() &&
      status['qa_certified'] == true &&
      status['approved'] == true &&
      status['promoted'] == true;

  Future<void> _publish(Map<String, dynamic> row) async {
    if (!_isCertifiedPromotion(row) || busy) return;
    var playConfirmed = false;
    var mandatory = false;
    final selection = await showDialog<Map<String, bool>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Registrar actualización en Google Play'),
          content: SizedBox(
            width: 475,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  'Versión ${row['version_name']} · build ${row['build_number']}. '
                  'Esta operación NO sube el APK/AAB a Google Play. '
                  'Primero debes publicarlo en Play Console y confirmar '
                  'que el mismo versionCode ya está disponible para los usuarios.',
                ),
                const SizedBox(height: 12),
                const SelectableText(
                  'https://play.google.com/store/apps/details?id=com.express.usuario1',
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Confirmo que esta compilación ya está disponible en Google Play'),
                  subtitle: const Text(
                    'No continuar mientras esté en revisión ni durante un '
                    'despliegue escalonado que aún excluya a usuarios.',
                  ),
                  value: playConfirmed,
                  onChanged: (value) =>
                      setDialog(() => playConfirmed = value == true),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Actualización obligatoria'),
                  subtitle: const Text(
                    'Desactivada por defecto. Solo usar si la nueva versión '
                    'ya está disponible para todos los usuarios previstos.',
                  ),
                  value: mandatory,
                  onChanged: (value) =>
                      setDialog(() => mandatory = value == true),
                ),
                const Text(
                  'Registrar la versión activa el aviso en la aplicación '
                  'cuando detecte una versión antigua. No envía avisos masivos.',
                  style: TextStyle(fontSize: 12),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: !playConfirmed ? null :
                  () => Navigator.pop(dialogContext, {'mandatory': mandatory}),
              child: const Text('Registrar versión verificada'),
            ),
          ],
        ),
      ),
    );
    if (selection == null) return;
    // Existing production-guarded release RPC. The Android client
    // always supplies the canonical Play Store link.
    await _call('admin_publish_build', {
      'p_build_id': row['id'],
      'p_mandatory': selection['mandatory'] == true,
    }, 'Versión registrada. Google Play debe estar disponible antes de este paso.');
  }


  Map<String, dynamic>? _savedDistribution(String jobId, String channel) {
    for (final item in distributions) {
      if (item['build_job_id']?.toString() == jobId &&
          item['channel']?.toString() == channel) {
        return item;
      }
    }
    return null;
  }

  /// Configuración visual semejante a Historial de Builds → Distribución.
  /// Solo el canal production confirmado alimenta latest_app_release.
  /// Configuración de avisos EXCLUSIVA de Google Play Producción.
  /// No modifica ninguna pista Play; la app consume latest_app_release.
  Future<void> _configureDistribution(Map<String, dynamic> job) async {
    if (!canManage || busy || job['status'] != 'ready') return;
    final jobId = job['id']?.toString() ?? '';
    final verifiedId = status['production_verified_build_job_id']?.toString();
    final storeBuild =
        int.tryParse(status['production_store_build']?.toString() ?? '') ?? 0;
    final build =
        int.tryParse(job['build_number']?.toString() ?? '') ?? 0;
    if (jobId.isEmpty || verifiedId == null || jobId != verifiedId ||
        build == 0 || build != storeBuild || job['signing_mode'] != 'production') {
      _message('Solo puedes configurar la versión firmada y verificada en Play Producción.');
      return;
    }

    final saved = _savedDistribution(jobId, 'production');
    bool isCurrent = saved?['is_current'] == true;
    bool isCritical = saved?['is_critical'] == true;
    bool confirmedPlay = false;
    bool confirmedCritical = false;
    final notes = TextEditingController(
      text: saved?['notes']?.toString() ?? '',
    );
    final playUrl = TextEditingController(
      text: saved?['play_store_url']?.toString() ??
        'https://play.google.com/store/apps/details?id=com.express.usuario1',
    );

    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) {
          final mustConfirm = isCurrent && !confirmedPlay;
          final mustConfirmCritical = isCritical && !confirmedCritical;
          return AlertDialog(
            title: const Text('Distribución · Google Play Producción'),
            content: SizedBox(
              width: 510,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Configura el aviso para usuarios de Producción:'),
                    const SizedBox(height: 6),
                    Text(
                      'Express ${job['version_name']} · Build $build',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Destino: Google Play · Producción',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Versión actual'),
                      subtitle: const Text(
                        'Mostrar a quienes tengan una versión anterior un aviso '
                        'con botón de Play Store y opción Más tarde.',
                      ),
                      value: isCurrent,
                      onChanged: (value) => setDialog(() {
                        isCurrent = value;
                        if (!value) isCritical = false;
                        confirmedPlay = false;
                        confirmedCritical = false;
                      }),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Actualización crítica'),
                      subtitle: const Text(
                        'Exigir actualizar antes de continuar usando la aplicación. '
                        'Actívala únicamente cuando sea imprescindible.',
                      ),
                      value: isCritical,
                      onChanged: (value) => setDialog(() {
                        isCritical = value;
                        if (value) isCurrent = true;
                        confirmedPlay = false;
                        confirmedCritical = false;
                      }),
                    ),
                    if (isCritical) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '¡Importante! Una actualización crítica puede '
                          'interrumpir a pasajeros y conductores que todavía '
                          'estén trabajando. Actívala fuera de horas críticas.',
                          style: TextStyle(
                            color: Color(0xFFB42318), fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: notes,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 800,
                      decoration: const InputDecoration(
                        labelText: 'Notas de la versión',
                        hintText: 'Correcciones de estabilidad y mejoras...',
                        helperText: 'Aparecerán en el aviso de actualización.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: playUrl,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Enlace oficial de Play Store',
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: confirmedPlay,
                        onChanged: (value) =>
                          setDialog(() => confirmedPlay = value == true),
                        title: const Text(
                          'Confirmo que este Build está disponible en '
                          'Google Play Producción',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      if (isCritical)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: confirmedCritical,
                          onChanged: (value) =>
                            setDialog(() => confirmedCritical = value == true),
                          title: const Text(
                            'Confirmo que deseo bloquear versiones antiguas',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: mustConfirm || mustConfirmCritical ? null : () {
                  Navigator.pop(dialogContext, {
                    'is_current': isCurrent,
                    'is_critical': isCritical,
                    'notes': notes.text.trim(),
                    'play_store_url': playUrl.text.trim(),
                    'confirmed_play': confirmedPlay,
                    'confirmed_critical': confirmedCritical,
                  });
                },
                child: const Text('Guardar distribución'),
              ),
            ],
          );
        },
      ),
    );
    notes.dispose();
    playUrl.dispose();
    if (values == null) return;
    await _call('admin_save_android_update_distribution', {
      'p_build_id': jobId,
      'p_channel': 'production',
      'p_is_current': values['is_current'],
      'p_is_critical': values['is_critical'],
      'p_notes': values['notes'],
      'p_play_store_url': values['play_store_url'],
      'p_confirmed_in_play': values['confirmed_play'],
      'p_confirmed_critical': values['confirmed_critical'],
    }, values['is_current'] == true
      ? 'Aviso de Producción actualizado para Express Build $build.'
      : 'Distribución guardada sin aviso activo.');
  }

  Future<void> _announcePublishedRelease() async {
    final version = publishedRelease['version_name']?.toString();
    if (!canManage || busy || version == null ||
        publishedRelease['build_number'] == null) {
      return;
    }
    var audience = 'all';
    var globalScope = true;
    final selected = await showDialog<Map<String, String?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) {
          final scopedZone = globalScope ? null : widget.zoneId;
          return AlertDialog(
            title: const Text('Avisar actualización a usuarios'),
            content: SizedBox(
              width: 485,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Express $version · build '
                    '${publishedRelease['build_number']}. '
                    'El aviso se enviará como notificación y en la bandeja de la aplicación. '
                    'No actualiza los teléfonos por sí solo.'),
                  const SizedBox(height: 14),
                  AdminDropdownField<String>(
                    initialValue: audience,
                    decoration: const InputDecoration(labelText: 'Destinatarios'),
                    items: const [
                      DropdownMenuItem(value: 'all',
                        child: Text('Todos (pasajeros y conductores)')),
                      DropdownMenuItem(value: 'drivers',
                        child: Text('Solo conductores')),
                      DropdownMenuItem(value: 'passengers',
                        child: Text('Solo pasajeros')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialog(() => audience = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: globalScope,
                    title: const Text('Todas las zonas de Producción'),
                    subtitle: Text(widget.zoneId == null
                        ? 'Selecciona una zona en la barra del administrador '
                          'si quieres limitar los destinatarios.'
                        : 'Desactivar para usar solamente la zona seleccionada.'),
                    onChanged: widget.zoneId == null ? null :
                        (value) => setDialog(() => globalScope = value),
                  ),
                  FutureBuilder<dynamic>(
                    key: ValueKey('estimate-$audience-${scopedZone ?? 'global'}'),
                    future: supabase.rpc('admin_push_audience_estimate_v2',
                      params: {
                        'p_channel': 'production',
                        'p_audience': audience,
                        'p_zone_id': scopedZone,
                        'p_partner_id': null,
                      }),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      final raw = snapshot.data;
                      final estimate = raw is Map ? Map<String, dynamic>.from(raw)
                          : <String, dynamic>{};
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text('Destinatarios: ${estimate['recipients'] ?? '—'}'
                          ' · Push activo: ${estimate['push_enabled'] ?? '—'}'),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Solo cuentas de Producción. No se incluirán usuarios '
                    'del grupo de Prueba ni se enviará nada antes de confirmar.',
                    style: TextStyle(fontSize: 12),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, {
                'audience': audience, 'zone_id': scopedZone,
              }), child: const Text('Enviar aviso ahora')),
            ],
          );
        },
      ),
    );
    if (selected == null) return;
    final title = 'Actualización disponible: Express $version';
    final body = 'Ya está disponible la nueva versión de Express '
        '(build ${publishedRelease['build_number']}). '
        'Actualiza desde Google Play: '
        'https://play.google.com/store/apps/details?id=com.express.usuario1';
    // Reuse the audited channel-aware campaign RPC. Nothing is sent until
    // the operator confirms this dialog.
    await _call('admin_send_announcement_v4', {
      'p_channel': 'production',
      'p_title': title,
      'p_body': body,
      'p_audience': selected['audience'],
      'p_zone_id': selected['zone_id'],
      'p_partner_id': null,
    }, 'Campaña de actualización creada para la audiencia seleccionada. '
       'Verifica las entregas FCM en Notificaciones / Avisos.');
  }

  Future<void> _open(String? value) async {
    if (value == null || value.isEmpty) return;
    final url = Uri.tryParse(value);
    if (url == null || (url.scheme != 'https')) return;
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _message('No se pudo abrir el archivo.');
    }
  }

  Widget _section(String title, Widget child) => Card(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );

  Widget _details(Map<String, dynamic> row) {
    final sha = row['commit_sha']?.toString() ?? '';
    // Identificadores y huellas: útiles para revisión técnica, ocultos por defecto.
    final technical = <Widget>[
      if (row['id'] != null)
        SelectableText('Trabajo GitHub: ${row['id']}',
            style: const TextStyle(fontSize: 12)),
      if (sha.isNotEmpty)
        SelectableText('Versión del código: $sha',
            style: const TextStyle(fontSize: 12)),
      if (row['apk_sha256'] != null)
        SelectableText('Huella del APK: ${row['apk_sha256']}',
            style: const TextStyle(fontSize: 11)),
      if (row['aab_sha256'] != null)
        SelectableText('Huella del AAB: ${row['aab_sha256']}',
            style: const TextStyle(fontSize: 11)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Versión ${row['version_name']} · build ${row['build_number']} '
            '· ${friendlyStatus(row['status']?.toString() ?? '')}'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (row['apk_url'] != null)
            OutlinedButton.icon(
              onPressed: () => _open(row['apk_url']?.toString()),
              icon: const Icon(Icons.android),
              label: const Text('Probar APK real'),
            ),
          if (row['aab_url'] != null)
            OutlinedButton.icon(
              onPressed: () => _open(row['aab_url']?.toString()),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Ver AAB'),
            ),
        ]),
        if (technical.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: const Text('Detalles técnicos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              children: technical,
            ),
          ),
      ],
    );
  }


  Widget _historyDistributionRow(Map<String, dynamic> build) {
    final id = build['id']?.toString() ?? '';
    final saved = _savedDistribution(id, 'production');
    final current = saved?['is_current'] == true;
    final critical = saved?['is_critical'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Express ${build['version_name']} · Build ${build['build_number']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Google Play · Producción · AAB firmado',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  current
                    ? (critical ? 'Aviso crítico activo' : 'Aviso normal activo')
                    : 'Aviso desactivado',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: canManage && !busy
              ? () => _configureDistribution(build)
              : null,
            icon: const Icon(Icons.rocket_launch_outlined),
            label: const Text('Distribución'),
          ),
          if (build['aab_url'] != null)
            TextButton.icon(
              onPressed: () => _open(build['aab_url']?.toString()),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Ver AAB'),
            ),
        ],
      ),
    );
  }

  Widget _buildDistributionHistory() {
    const pageSize = 8;
    final maxPages = buildHistory.isEmpty
      ? 1 : (buildHistory.length + pageSize - 1) ~/ pageSize;
    final safePage = historyPage < maxPages ? historyPage : 0;
    final rows = buildHistory.skip(safePage * pageSize).take(pageSize);
    return _section('Distribución de actualizaciones · Producción', Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Controla el aviso de actualización para la versión '
          'verificada en Google Play Producción. '
          'No modifica Google Play ni envía notificaciones push.',
        ),
        const SizedBox(height: 12),
        if (buildHistory.isEmpty)
          const Text('No se encontró una versión firmada y verificada en Google Play Producción.'),
        for (final build in rows) ...[
          const Divider(height: 12),
          _historyDistributionRow(build),
        ],
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton(
            onPressed: safePage > 0
              ? () => setState(() => historyPage = safePage - 1) : null,
            child: const Text('Anterior'),
          ),
          const SizedBox(width: 10),
          Text('Página ' + (safePage + 1).toString() +
              ' de ' + maxPages.toString()),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: safePage + 1 < maxPages
              ? () => setState(() => historyPage = safePage + 1) : null,
            child: const Text('Siguiente'),
          ),
        ]),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final row = candidate;
    final hasCandidate = row['id'] != null;
    final ready = row['status'] == 'ready';
    final certified = status['qa_certified'] == true;
    final approved = status['approved'] == true;
    final promoted = status['promoted'] == true;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Express · Una sola aplicación', style: TextStyle(
          fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Una sola aplicación para pasajeros y conductores: la web se revisa primero. '
            'Generar un APK o AAB requiere aprobación manual, además de la cola de compilación.'),
        const SizedBox(height: 12),
        if (!canManage)
          _section('Solo lectura',
            const Text('Tu cuenta no tiene permiso para administrar '
              'publicaciones Android. Las compilaciones son globales '
              'para Express, sin separación por país, zona ni APK de Prueba.')),
        if (error != null)
          _section('Error al consultar builds', Text(error!,
              style: const TextStyle(color: Colors.red))),
        if (loading)
          const LinearProgressIndicator(),
        _section('Flujo único Android', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Google Play: build vigente ${status['production_store_build'] ?? '—'} '
                '· siguiente ${status['next_google_play_build'] ?? '—'}'),
            const SizedBox(height: 8),
            const Text('1. Poner la versión en cola  →  2. Autorizar la prueba Android '
              '(frase de confirmación: AUTORIZO APK QA)  →  3. Revisar la firma y probar '
              'esa misma APK  →  4. Certificar y aprobar  →  5. Publicar solo con visto bueno.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: canManage && !busy ? _queue : null,
              icon: const Icon(Icons.build_rounded),
              label: const Text('Preparar candidato 1.6.2 (no compila aún)'),
            ),
            const SizedBox(height: 14),
            const Divider(),
            const Text('Google Play · Pruebas internas',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Prepara únicamente el AAB firmado. No genera APK '
              'ni publica automáticamente en Google Play.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: canManage && !busy ? _queueInternalAab : null,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Preparar solo AAB · Build 141'),
            ),
            if (hasCandidate) ...[
              const SizedBox(height: 16),
              _details(row),
              const SizedBox(height: 12),
              Text('Pruebas: ${certified ? 'certificadas' : 'pendientes'}  ·  '
                   'Aprobación: ${approved ? 'aprobada' : 'pendiente'}  ·  '
                   'Publicada: ${promoted ? 'sí' : 'no'}'),
              if (verification['qa_notes'] != null)
                Text('Evidencia: ${verification['qa_notes']}'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: canManage && !busy && ready && !promoted
                      ? _certify : null,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Registrar pruebas Android'),
                ),
                OutlinedButton.icon(
                  onPressed: canManage && !busy && certified &&
                          !approved && !promoted ? _approve : null,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Aprobar'),
                ),
                FilledButton.icon(
                  onPressed: canManage && !busy && approved &&
                          !promoted ? _promote : null,
                  icon: const Icon(Icons.publish_outlined),
                  label: const Text('Promover APK/AAB'),
                ),
              ]),
            ],
          ],
        )),
        _buildDistributionHistory(),
        _section('Avisar actualización a pasajeros y conductores', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              publishedRelease['build_number'] == null
                  ? 'Todavía no hay una versión Android publicada en el '
                    'registro oficial. No se pueden enviar avisos de actualización.'
                  : 'Versión publicada: ${publishedRelease['version_name']} '
                    '· build ${publishedRelease['build_number']}',
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: canManage && !busy &&
                      publishedRelease['build_number'] != null
                  ? _announcePublishedRelease : null,
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('Avisar actualización'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Puedes elegir todos, pasajeros o conductores; todas las zonas '
              'o la zona seleccionada. El aviso no es automático ni modifica '
              'la publicación de Google Play.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        )),
        _section('Compilaciones AAB · Pruebas internas', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estos trabajos no son publicaciones de Producción. '
              'Solo compilan el AAB y requieren aprobación del '
              'propietario en GitHub. La subida a Play es independiente.',
            ),
            if (internalAabJobs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Todavía no hay trabajos AAB internos solicitados.'),
              ),
            for (final job in internalAabJobs) ...[
              const Divider(),
              _details(job),
            ],
          ],
        )),
        _section('Publicaciones de Producción', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (releases.isEmpty)
              const Text('Aún no hay APK/AAB promovidos y listos.'),
            for (final release in releases) ...[
              const Divider(),
              _details(release),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: !busy && _isCertifiedPromotion(release)
                    ? () => _publish(release) : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Registrar versión disponible en Play Store'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar estado'),
            ),
          ],
        )),
      ],
    );
  }
}
