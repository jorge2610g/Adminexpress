import 'package:flutter/material.dart';

import 'core/admin_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/supabase_client.dart';

/// One Express Android package. The signed Production candidate itself is
/// tested/certified; no permanent Preview APK is involved.
class AdminSingleAppReleasePage extends StatefulWidget {
  const AdminSingleAppReleasePage({super.key, required this.productionAccess});
  // Capability from server-side admin_access_context; never a Preview/Production UI mode.
  final bool productionAccess;

  @override
  State<AdminSingleAppReleasePage> createState() =>
      _AdminSingleAppReleasePageState();
}

class _AdminSingleAppReleasePageState extends State<AdminSingleAppReleasePage> {
  Map<String, dynamic> status = const {};
  List<Map<String, dynamic>> releases = const [];
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
      ]);
      if (!mounted) return;
      final rawStatus = results[0];
      final rawRows = results[1];
      setState(() {
        status = rawStatus is Map
            ? Map<String, dynamic>.from(rawStatus)
            : <String, dynamic>{};
        releases = (rawRows is List ? rawRows : const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .where((row) =>
                row['platform'] == 'android' &&
                row['artifact_type'] == 'apk+aab')
            .take(15)
            .toList();
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
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
    final currentVersion = candidate['version_name']?.toString() ?? '1.6.1';
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
                'No crea Express Preview ni publica en Google Play.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: version,
                decoration: const InputDecoration(
                  labelText: 'Versión (igual a pubspec.yaml)',
                  hintText: '1.6.1',
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
    await _call('admin_queue_single_app_candidate', {
      'p_version_name': data['version'],
      'p_changelog': data['notes'],
    }, 'Candidato real en cola. No afecta el APK instalado ni Google Play.');
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
    }, 'Pruebas registradas para el SHA y los hashes de este APK/AAB.');
  }

  Future<void> _approve() async {
    final ok = await _confirm(
      'Aprobar candidato Android',
      'Se fijarán SHA, árbol de código y SHA-256 del APK y AAB exactos '
      'que ya probaste. No se recompilará para Producción.',
      'Aprobar candidato',
    );
    if (!ok) return;
    await _call('admin_approve_single_app_candidate', {
      'p_candidate_id': candidate['id'],
    }, 'Candidato Android aprobado sin segunda aplicación Preview.');
  }

  Future<void> _promote() async {
    final ok = await _confirm(
      'Promover APK/AAB a Producción',
      'Se utilizarán exactamente los mismos archivos firmados, SHA y '
      'hashes que fueron certificados. Esto reserva el versionCode '
      'de Google Play; NO publica automáticamente la actualización.',
      'Promover sin recompilar',
    );
    if (!ok) return;
    await _call('admin_promote_single_app_candidate', {
      'p_candidate_id': candidate['id'],
    }, 'APK/AAB promovidos sin recompilar. Queda por decidir su publicación.');
  }

  Future<void> _publish(Map<String, dynamic> row) async {
    final ok = await _confirm(
      'Publicar actualización de Express',
      'Esta acción actualiza el canal de distribución de la aplicación. '
      'Solo puedes publicar una release de Producción que ya fue promovida.',
      'Publicar versión',
    );
    if (!ok) return;
    await _call('admin_publish_build', {
      'p_build_id': row['id'],
      'p_mandatory': false,
    }, 'Actualización publicada.');
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Versión ${row['version_name']} · build ${row['build_number']} '
            '· ${row['status']}'),
        if (sha.isNotEmpty)
          SelectableText('Código SHA: $sha', style: const TextStyle(fontSize: 12)),
        if (row['apk_sha256'] != null)
          SelectableText('APK SHA-256: ${row['apk_sha256']}',
              style: const TextStyle(fontSize: 11)),
        if (row['aab_sha256'] != null)
          SelectableText('AAB SHA-256: ${row['aab_sha256']}',
              style: const TextStyle(fontSize: 11)),
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
      ],
    );
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
        const AdminPageHero(
          title: 'Express · Una sola aplicación',
          subtitle: 'Desarrollo y pruebas compartidas: Web primero. Android se compila cuando hay una función nativa que verificar o una nueva publicación.',
          icon: Icons.android_rounded,
        ),
        const SizedBox(height: 12),
        if (!canManage)
          _section('Solo lectura',
            const Text('Tu cuenta no tiene permiso para administrar '
              'publicaciones Android. Las compilaciones son globales '
              'para Express, sin separación por país, zona ni APK Preview.')),
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
            const Text('Preparar APK/AAB firmado → probar ese mismo APK → '
              'certificar → aprobar → promover el mismo archivo → publicar.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: canManage && !busy ? _queue : null,
              icon: const Icon(Icons.build_rounded),
              label: const Text('Crear candidato Android (sin APK Preview)'),
            ),
            if (hasCandidate) ...[
              const SizedBox(height: 16),
              _details(row),
              const SizedBox(height: 12),
              Text('QA: ${certified ? 'certificado' : 'pendiente'}  ·  '
                   'Aprobación: ${approved ? 'aprobado' : 'pendiente'}  ·  '
                   'Promovido: ${promoted ? 'sí' : 'no'}'),
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
        _section('Publicaciones de Producción', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (releases.isEmpty)
              const Text('Aún no hay APK/AAB promovidos.'),
            for (final release in releases) ...[
              const Divider(),
              _details(release),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: canManage && !busy &&
                        release['status'] == 'ready'
                    ? () => _publish(release) : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Publicar versión aprobada'),
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
