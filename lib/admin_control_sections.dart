import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/supabase_client.dart';

const Color _blue = Color(0xFF2563EB);
const Color _dark = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);

class AdminDispatchPage extends StatefulWidget {
  const AdminDispatchPage({super.key});

  @override
  State<AdminDispatchPage> createState() => _AdminDispatchPageState();
}

class _AdminDispatchPageState extends State<AdminDispatchPage> {
  int revision = 0;

  Future<({
    List<Map<String, dynamic>> rides,
    List<Map<String, dynamic>> deliveries,
    List<Map<String, dynamic>> drivers,
  })> _load() async {
    final values = await Future.wait([
      supabase.rpc('admin_open_service_requests'),
      supabase.rpc('admin_available_drivers'),
    ]);
    final requests = _map(values[0]);
    return (
      rides: _list(requests['rides']),
      deliveries: _list(requests['deliveries']),
      drivers: _list(values[1]),
    );
  }

  Future<void> _assignRide(
    Map<String, dynamic> ride,
    List<Map<String, dynamic>> drivers,
  ) async {
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay conductores disponibles.')),
      );
      return;
    }

    String? driverId = drivers.first['id']?.toString();
    final fare = TextEditingController(
      text: ride['proposed_fare']?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Asignar viaje'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (ride['pickup_address'] ?? 'Origen').toString() +
                      ' → ' +
                      (ride['destination_address'] ?? 'Destino').toString(),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: driverId,
                  decoration:
                      const InputDecoration(labelText: 'Conductor disponible'),
                  items: drivers
                      .map(
                        (driver) => DropdownMenuItem(
                          value: driver['id'].toString(),
                          child: Text(
                            (driver['name'] ?? 'Conductor').toString() +
                                ' · ★ ' +
                                (driver['rating'] ?? '—').toString(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setLocal(() => driverId = value),
                ),
                const SizedBox(height: 10),
                _NumberField(
                  controller: fare,
                  label: 'Tarifa final',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: driverId == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && driverId != null) {
      try {
        await supabase.rpc(
          'admin_assign_ride',
          params: {
            'p_ride_request_id': ride['id'],
            'p_driver_id': driverId,
            'p_final_fare': _num(fare.text),
          },
        );
        if (mounted) {
          setState(() => revision++);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Viaje asignado.')),
          );
        }
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }

    fare.dispose();
  }

  Future<void> _assignDelivery(
    Map<String, dynamic> delivery,
    List<Map<String, dynamic>> drivers,
  ) async {
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay conductores disponibles.')),
      );
      return;
    }

    String? driverId = drivers.first['id']?.toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Asignar delivery'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (delivery['pickup_address'] ?? 'Origen').toString() +
                      ' → ' +
                      (delivery['dropoff_address'] ?? 'Destino').toString(),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: driverId,
                  decoration:
                      const InputDecoration(labelText: 'Repartidor disponible'),
                  items: drivers
                      .map(
                        (driver) => DropdownMenuItem(
                          value: driver['id'].toString(),
                          child: Text(
                            (driver['name'] ?? 'Conductor').toString() +
                                ' · ★ ' +
                                (driver['rating'] ?? '—').toString(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setLocal(() => driverId = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: driverId == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && driverId != null) {
      try {
        await supabase.rpc(
          'admin_assign_delivery',
          params: {
            'p_delivery_id': delivery['id'],
            'p_driver_id': driverId,
          },
        );
        if (mounted) {
          setState(() => revision++);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery asignado.')),
          );
        }
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          List<Map<String, dynamic>> rides,
          List<Map<String, dynamic>> deliveries,
          List<Map<String, dynamic>> drivers,
        })>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading(title: 'Cargando despacho');
        }
        if (snapshot.hasError) {
          return _Error(
            error: snapshot.error,
            onRetry: () => setState(() => revision++),
          );
        }

        final data = snapshot.data ??
            (
              rides: <Map<String, dynamic>>[],
              deliveries: <Map<String, dynamic>>[],
              drivers: <Map<String, dynamic>>[],
            );

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const _Header(
              title: 'Despacho manual',
              subtitle:
                  'Asigna un conductor disponible cuando el despacho automático no resuelva el servicio.',
            ),
            const SizedBox(height: 14),
            Card(
              color: const Color(0xFFEAF2FF),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Conductores disponibles ahora: ' +
                      data.drivers.length.toString(),
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Solicitudes de viaje',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (data.rides.isEmpty)
              const _Empty(text: 'No hay viajes esperando asignación.')
            else
              ...data.rides.map(
                (row) => _DispatchItem(
                  icon: Icons.local_taxi_rounded,
                  title:
                      (row['pickup_address'] ?? 'Origen').toString() +
                      ' → ' +
                      (row['destination_address'] ?? 'Destino').toString(),
                  subtitle:
                      (row['passenger_name'] ?? 'Pasajero').toString() +
                      ' · Bs ' +
                      (row['proposed_fare'] ?? '—').toString(),
                  onAssign: () => _assignRide(row, data.drivers),
                ),
              ),
            const SizedBox(height: 22),
            const Text(
              'Delivery esperando',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (data.deliveries.isEmpty)
              const _Empty(text: 'No hay delivery esperando asignación.')
            else
              ...data.deliveries.map(
                (row) => _DispatchItem(
                  icon: Icons.local_shipping_rounded,
                  title:
                      (row['pickup_address'] ?? 'Origen').toString() +
                      ' → ' +
                      (row['dropoff_address'] ?? 'Destino').toString(),
                  subtitle:
                      (row['customer_name'] ?? 'Cliente').toString() +
                      ' · Bs ' +
                      (row['proposed_fare'] ?? '—').toString(),
                  onAssign: () => _assignDelivery(row, data.drivers),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  int revision = 0;

  String _actionLabel(Object? raw, [Object? entityType]) {
    final action = raw?.toString();
    final entity = entityType?.toString();

    if (action == 'upsert' && entity == 'service_zone_polygon') {
      return 'Polígono de cobertura actualizado';
    }
    if (action == 'resolve' && entity == 'emergency') {
      return 'Emergencia resuelta';
    }
    if (action == 'create' && entity == 'build_job') {
      return 'Compilación solicitada';
    }
    if (action == 'update' && entity == 'app_settings') {
      return 'Configuración actualizada';
    }

    return switch (action) {
      'update_user_profile' => 'Perfil de usuario actualizado',
      'update_driver_profile' => 'Perfil de conductor actualizado',
      'upsert_driver_document' => 'Documento de conductor actualizado',
      'send_announcement' => 'Aviso / promoción enviada',
      'set_driver_approval' => 'Estado de conductor cambiado',
      'set_account_status' => 'Estado de cuenta cambiado',
      'service_zone_polygon' => 'Polígono de cobertura actualizado',
      'upsert_service_zone_polygon' => 'Polígono de cobertura actualizado',
      'update_service_zone_polygon' => 'Polígono de cobertura actualizado',
      'upsert_zone' => 'Zona actualizada',
      'set_zone_service' => 'Servicio de zona actualizado',
      'update_fare_rule' => 'Tarifa actualizada',
      'set_fare_rule' => 'Tarifa actualizada',
      final value when value != null && value.isNotEmpty =>
        value.replaceAll('_', ' '),
      _ => 'Acción administrativa',
    };
  }

  String _entityLabel(Object? raw) {
    return switch (raw?.toString()) {
      'driver_profile' => 'Conductor',
      'driver_document' => 'Documento',
      'user' => 'Usuario',
      'notifications' => 'Notificaciones',
      'service_zone_polygon' => 'Polígono de zona',
      'service_zone' => 'Zona',
      'fare_rule' => 'Tarifa',
      'zone_service' => 'Servicio',
      'driver_subscription' => 'Suscripción',
      final value when value != null && value.isNotEmpty =>
        value.replaceAll('_', ' '),
      _ => 'Sistema',
    };
  }

  List<String> _detailLines(Object? raw) {
    if (raw is! Map || raw.isEmpty) return const [];
    final map = Map<String, dynamic>.from(raw);
    return map.entries
        .map((entry) {
          final key = entry.key
              .replaceAll('_', ' ')
              .replaceFirstMapped(
                RegExp(r'^[a-z]'),
                (m) => m.group(0)!.toUpperCase(),
              );
          final value = entry.value;
          final rendered = value is Map || value is List
              ? value.toString()
              : (value?.toString() ?? '—');
          return '$key: $rendered';
        })
        .toList();
  }

  Future<void> _showDetail(Map<String, dynamic> row) async {
    final lines = _detailLines(row['details']);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_actionLabel(row['action'], row['entity_type'])),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReadOnlyRow(
                  label: 'Módulo',
                  value: _entityLabel(row['entity_type']),
                ),
                _ReadOnlyRow(
                  label: 'Administrador',
                  value: (row['admin_name'] ?? 'Administrador').toString(),
                ),
                _ReadOnlyRow(
                  label: 'Fecha',
                  value: _formatDate(row['created_at']),
                ),
                _ReadOnlyRow(
                  label: 'ID',
                  value: (row['entity_id'] ?? '—').toString(),
                ),
                if (lines.isNotEmpty) ...[
                  const Divider(height: 26),
                  const Text(
                    'Cambios registrados',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  ...lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SelectableText(
                        line,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                        ),
                      ),
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
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final value = await supabase.rpc('admin_build_list');
    return _list(value);
  }

  Future<Map<String, dynamic>> _loadReleaseGate() async {
    final value = await supabase.rpc(
      'admin_release_gate_status',
      params: {'p_platform': 'android'},
    );
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  Future<void> _refreshBuilds({
    bool initial = false,
    bool silent = false,
  }) async {
    if (refreshing) return;
    if (mounted) {
      setState(() {
        refreshing = true;
        if (initial) initialLoading = true;
        if (!silent) loadError = null;
      });
    }
    try {
      final result = await Future.wait<Object>([
        _load(),
        _loadReleaseGate(),
      ]);
      final rows = result[0] as List<Map<String, dynamic>>;
      final gate = result[1] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        buildRows = rows;
        releaseGate = gate;
        initialLoading = false;
        refreshing = false;
        loadError = null;
        lastRefreshAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        initialLoading = false;
        refreshing = false;
        loadError = e;
      });
    }
  }

  Future<void> _openUrl(String? value) async {
    if (value == null || value.trim().isEmpty) return;
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _nextPatchVersion(String raw) {
    final clean = raw.trim().split(RegExp(r'[-+]')).first;
    final parts = clean.split('.');
    if (parts.length != 3) return '1.5.79';
    final major = int.tryParse(parts[0]) ?? 1;
    final minor = int.tryParse(parts[1]) ?? 5;
    final patch = int.tryParse(parts[2]) ?? 78;
    return major.toString() +
        '.' +
        minor.toString() +
        '.' +
        (patch + 1).toString();
  }

  Future<void> _create({required bool production}) async {
    List<Map<String, dynamic>> existing = const [];
    try {
      existing = await _load();
    } catch (_) {}

    final productionRows = existing
        .where((row) =>
            row['platform']?.toString() == 'android' &&
            row['artifact_type']?.toString() == 'apk+aab')
        .toList()
      ..sort((a, b) {
        final aBuild = (a['build_number'] as num?)?.toInt() ?? 0;
        final bBuild = (b['build_number'] as num?)?.toInt() ?? 0;
        return bBuild.compareTo(aBuild);
      });

    final latestProductionBuild = productionRows.fold<int>(
      119,
      (value, row) {
        final raw = row['build_number'];
        final n = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
        return n != null && n > value ? n : value;
      },
    );
    final latestProductionVersion = productionRows.isNotEmpty
        ? productionRows.first['version_name']?.toString() ?? '1.5.78'
        : '1.5.78';

    final previewApproved = releaseGate['preview_approved'] == true;
    final previewVersion = releaseGate['preview_version_name']?.toString();
    final previewBuildRaw = releaseGate['preview_build_number'];
    final previewBuild = previewBuildRaw is num
        ? previewBuildRaw.toInt()
        : int.tryParse(previewBuildRaw?.toString() ?? '');

    if (production && !previewApproved) {
      _snack(
        context,
        'Primero compila una Preview y apruébala. Producción está bloqueada hasta entonces.',
      );
      return;
    }

    final suggestedVersion = production && previewVersion != null
        ? previewVersion
        : _nextPatchVersion(latestProductionVersion);
    final suggestedBuild = production && previewBuild != null
        ? previewBuild
        : latestProductionBuild + 1;

    final version = TextEditingController(text: suggestedVersion);
    final build = TextEditingController(text: suggestedBuild.toString());
    final changelog = TextEditingController();

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          production
              ? 'Compilar Producción aprobada'
              : 'Compilar Express Preview',
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: production
                      ? const Color(0xFFE8F8EF)
                      : const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  production
                      ? 'Producción se compilará desde el SHA exacto de la Preview que aprobaste. No usará un código distinto aunque main haya cambiado.'
                      : 'Esta compilación usa el paquete separado com.express.usuario.preview. No reemplaza la aplicación de producción.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _dark,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: version,
                readOnly: production,
                decoration: InputDecoration(
                  labelText: 'Versión',
                  helperText: production
                      ? 'Debe coincidir con la Preview aprobada.'
                      : 'Sugerida desde la última producción v$latestProductionVersion.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: build,
                readOnly: production,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Build number',
                  helperText: production
                      ? 'Mismo build que la Preview aprobada.'
                      : 'Siguiente build de producción: $suggestedBuild.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: changelog,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notas de actualización',
                  hintText: 'Describe los cambios de esta versión',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: Icon(
              production
                  ? Icons.verified_user_rounded
                  : Icons.science_rounded,
            ),
            label: Text(
              production ? 'Compilar producción' : 'Compilar Preview',
            ),
          ),
        ],
      ),
    );

    if (save == true) {
      final buildNumber = int.tryParse(build.text.trim());
      if (version.text.trim().isEmpty || buildNumber == null || buildNumber < 1) {
        if (mounted) {
          _snack(context, 'Versión o build number no válido.');
        }
      } else {
        try {
          await supabase.rpc(
            'admin_create_build_job',
            params: {
              'p_platform': 'android',
              'p_artifact_type':
                  production ? 'apk+aab' : 'preview-apk+aab',
              'p_version_name': version.text.trim(),
              'p_build_number': buildNumber,
              'p_changelog': changelog.text.trim(),
              'p_commit_sha':
                  production ? releaseGate['approved_commit_sha'] : null,
            },
          );
          if (mounted) {
            await _refreshBuilds(silent: true);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  production
                      ? 'Producción en cola usando el SHA aprobado de Preview.'
                      : 'Preview en cola. Cuando termine, pruébala antes de aprobarla.',
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) _snack(context, e);
        }
      }
    }

    version.dispose();
    build.dispose();
    changelog.dispose();
  }

  Future<void> _approvePreview() async {
    final buildId = releaseGate['preview_build_id']?.toString();
    if (buildId == null || buildId.isEmpty) {
      _snack(context, 'Todavía no hay una Preview terminada para aprobar.');
      return;
    }

    final version = releaseGate['preview_version_name']?.toString() ?? '—';
    final build = releaseGate['preview_build_number']?.toString() ?? '—';
    final sha = releaseGate['preview_commit_sha']?.toString() ?? '—';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aprobar Preview para Producción'),
        content: SizedBox(
          width: 480,
          child: Text(
            'Vas a aprobar Express Preview v$version · build $build.\n\n'
            'SHA: $sha\n\n'
            'Después de aprobarla, Producción quedará bloqueada a este mismo código.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.verified_rounded),
            label: const Text('Sí, Preview está aprobada'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await supabase.rpc(
        'admin_approve_preview_build',
        params: {'p_build_id': buildId},
      );
      if (!mounted) return;
      await _refreshBuilds(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preview aprobada. Producción ya puede compilarse desde el mismo SHA.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) _snack(context, e);
    }
  }

  Future<void> _publish(Map<String, dynamic> row) async {
    bool mandatory = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Publicar actualización'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Express v' +
                      (row['version_name'] ?? '—').toString() +
                      ' · build ' +
                      (row['build_number'] ?? '—').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: mandatory,
                  onChanged: (value) => setLocal(() => mandatory = value),
                  title: const Text('Actualización obligatoria'),
                  subtitle: const Text(
                    'Si la activas, más adelante la app podrá impedir continuar con una versión antigua.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Publicar versión'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase.rpc(
        'admin_publish_build',
        params: {
          'p_build_id': row['id'].toString(),
          'p_mandatory': mandatory,
        },
      );
      if (!mounted) return;
      await _refreshBuilds(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Actualización publicada para Express.'),
        ),
      );
    } catch (e) {
      if (mounted) _snack(context, e);
    }
  }

  Widget _buildHistoryCard(Map<String, dynamic> row) {
    final status = (row['status'] ?? 'queued').toString();
    final apkUrl = row['apk_url']?.toString();
    final aabUrl = row['aab_url']?.toString();
    final runUrl = row['run_url']?.toString();
    final signing = row['signing_mode']?.toString() ?? 'test';
    final error = row['error_message']?.toString();
    final ready = status == 'ready';

    Widget actionButton({
      required String label,
      required IconData icon,
      required VoidCallback? onPressed,
      bool primary = false,
    }) {
      final button = primary
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
            );
      return Expanded(child: button);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.android_rounded,
                  color: Color(0xFF14804A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'v' +
                          (row['version_name'] ?? '—').toString() +
                          ' · build ' +
                          (row['build_number'] ?? '—').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'APK + AAB',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _BuildStatus(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: _muted,
              ),
              const SizedBox(width: 5),
              Text(
                _formatDate(row['created_at']),
                style: const TextStyle(
                  fontSize: 10,
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (ready) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(
                  signing == 'production'
                      ? Icons.verified_user_rounded
                      : Icons.key_off_outlined,
                  size: 15,
                  color: signing == 'production'
                      ? const Color(0xFF14804A)
                      : const Color(0xFFA15C07),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    signing == 'production'
                        ? 'Firmado para producción'
                        : 'Firma de prueba',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: signing == 'production'
                          ? const Color(0xFF14804A)
                          : const Color(0xFFA15C07),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                error,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFD92D20),
                  height: 1.35,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (ready && (apkUrl?.isNotEmpty == true || aabUrl?.isNotEmpty == true)) ...[
            Row(
              children: [
                if (apkUrl?.isNotEmpty == true)
                  actionButton(
                    label: 'APK',
                    icon: Icons.download_rounded,
                    onPressed: () => _openUrl(apkUrl),
                    primary: true,
                  ),
                if (apkUrl?.isNotEmpty == true && aabUrl?.isNotEmpty == true)
                  const SizedBox(width: 8),
                if (aabUrl?.isNotEmpty == true)
                  actionButton(
                    label: 'AAB',
                    icon: Icons.inventory_2_outlined,
                    onPressed: () => _openUrl(aabUrl),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (runUrl?.isNotEmpty == true ||
              (ready && signing == 'production')) ...[
            Row(
              children: [
                if (runUrl?.isNotEmpty == true)
                  actionButton(
                    label: 'Compilación',
                    icon: Icons.terminal_rounded,
                    onPressed: () => _openUrl(runUrl),
                  ),
                if (runUrl?.isNotEmpty == true &&
                    ready &&
                    signing == 'production')
                  const SizedBox(width: 8),
                if (ready && signing == 'production')
                  actionButton(
                    label: 'Publicar',
                    icon: Icons.publish_rounded,
                    onPressed: () => _publish(row),
                    primary: true,
                  ),
              ],
            ),
          ],
          if (ready &&
              signing != 'production' &&
              runUrl?.isNotEmpty != true) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.key_off_outlined, size: 16),
                label: const Text('Falta firma de producción'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (initialLoading && buildRows.isEmpty) {
      return const _Loading(title: 'Cargando compilaciones');
    }
    if (loadError != null && buildRows.isEmpty) {
      return _Error(
        error: loadError,
        onRetry: () => _refreshBuilds(initial: true),
      );
    }

    final rows = List<Map<String, dynamic>>.from(buildRows)
      ..sort((a, b) {
        final aBuild = a['build_number'] is num
            ? (a['build_number'] as num).toInt()
            : int.tryParse(a['build_number']?.toString() ?? '') ?? 0;
        final bBuild = b['build_number'] is num
            ? (b['build_number'] as num).toInt()
            : int.tryParse(b['build_number']?.toString() ?? '') ?? 0;
        return bBuild.compareTo(aBuild);
      });

    Map<String, dynamic>? currentProduction;
    Map<String, dynamic>? activeBuild;
    for (final row in rows) {
      final status = row['status']?.toString();
      if (activeBuild == null &&
          (status == 'queued' || status == 'building')) {
        activeBuild = row;
      }
      if (currentProduction == null &&
          status == 'ready' &&
          row['signing_mode']?.toString() == 'production') {
        currentProduction = row;
      }
    }

    final updated = lastRefreshAt;
    final updatedText = updated == null
        ? '—'
        : updated.hour.toString().padLeft(2, '0') +
            ':' +
            updated.minute.toString().padLeft(2, '0') +
            ':' +
            updated.second.toString().padLeft(2, '0');

    Widget summaryCard({
      required IconData icon,
      required String title,
      required String value,
      required String subtitle,
      required Color accent,
      required Color soft,
      Widget? trailing,
    }) {
      return Container(
        constraints: const BoxConstraints(minWidth: 245),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D101828),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: accent, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        _Header(
          title: 'App Builder',
          subtitle:
              'Compila APK + AAB de Express y sigue el progreso sin que la pantalla se recargue.',
          action: FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.android_rounded),
            label: const Text('Nuevo build Android'),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      size: 14,
                      color: Color(0xFF14804A),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Actualización silenciosa cada 20 s',
                      style: TextStyle(
                        color: Color(0xFF14804A),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (refreshing)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Actualizando',
                      style: TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                )
              else
                Text(
                  'Última actualización: ' + updatedText,
                  style: const TextStyle(fontSize: 10, color: _muted),
                ),
              OutlinedButton.icon(
                onPressed: refreshing
                    ? null
                    : () => _refreshBuilds(silent: true),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Actualizar ahora'),
              ),
              if (loadError != null)
                const Text(
                  'La última actualización falló; se mantienen los datos anteriores.',
                  style: TextStyle(
                    color: Color(0xFFD92D20),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cardWidth = width < 720
                ? width
                : width < 1080
                    ? (width - 12) / 2
                    : (width - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: summaryCard(
                    icon: Icons.verified_rounded,
                    title: 'Versión de producción',
                    value: currentProduction == null
                        ? 'Sin versión lista'
                        : 'v' +
                            (currentProduction!['version_name'] ?? '—')
                                .toString() +
                            ' · build ' +
                            (currentProduction!['build_number'] ?? '—')
                                .toString(),
                    subtitle: currentProduction == null
                        ? 'Todavía no hay un build firmado en producción.'
                        : 'APK + AAB listos y firmados para producción.',
                    accent: const Color(0xFF14804A),
                    soft: const Color(0xFFE8F8EF),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: summaryCard(
                    icon: activeBuild == null
                        ? Icons.check_circle_outline_rounded
                        : Icons.engineering_rounded,
                    title: 'Compilación activa',
                    value: activeBuild == null
                        ? 'Sin trabajos pendientes'
                        : 'v' +
                            (activeBuild!['version_name'] ?? '—').toString() +
                            ' · build ' +
                            (activeBuild!['build_number'] ?? '—').toString(),
                    subtitle: activeBuild == null
                        ? 'La cola está libre.'
                        : activeBuild!['status']?.toString() == 'building'
                            ? 'GitHub Actions está compilando APK + AAB.'
                            : 'El build está en cola esperando al worker.',
                    accent: activeBuild == null
                        ? _blue
                        : const Color(0xFFC76B16),
                    soft: activeBuild == null
                        ? const Color(0xFFEAF2FF)
                        : const Color(0xFFFFF3E7),
                    trailing: activeBuild == null
                        ? null
                        : _BuildStatus(
                            status:
                                activeBuild!['status']?.toString() ?? 'queued',
                          ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: summaryCard(
                    icon: Icons.security_rounded,
                    title: 'Salida Android',
                    value: 'APK + AAB',
                    subtitle:
                        'Firma de producción, Release de GitHub y enlaces de descarga.',
                    accent: const Color(0xFF6941C6),
                    soft: const Color(0xFFF1EBFF),
                  ),
                ),
              ],
            );
          },
        ),
        if (activeBuild != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAEB),
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.android_rounded,
                      color: Color(0xFFC76B16),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        activeBuild!['status']?.toString() == 'building'
                            ? 'Compilando Express ' +
                                (activeBuild!['version_name'] ?? '').toString()
                            : 'Build ' +
                                (activeBuild!['build_number'] ?? '').toString() +
                                ' en cola',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _dark,
                        ),
                      ),
                    ),
                    _BuildStatus(
                      status: activeBuild!['status']?.toString() ?? 'queued',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: activeBuild!['status']?.toString() == 'building'
                      ? null
                      : .12,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Puedes salir de esta sección y volver después. El estado se mantiene y se actualiza sin recargar toda la pantalla.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial de compilaciones',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _dark,
                    ),
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.swipe_rounded,
                        size: 15,
                        color: _muted,
                      ),
                      SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Desliza horizontalmente · los más recientes aparecen primero.',
                          style: TextStyle(fontSize: 10, color: _muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              rows.length.toString() + ' builds',
              style: const TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const _Empty(text: 'Todavía no hay builds registrados.')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 520
                  ? constraints.maxWidth * .86
                  : 340.0;
              return SizedBox(
                height: 310,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => SizedBox(
                    width: cardWidth,
                    child: _buildHistoryCard(rows[index]),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 10),
        const _BuildCloudNotice(),
      ],
    );
  }
}

class _BuildCloudNotice extends StatelessWidget {
  const _BuildCloudNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_queue_rounded, color: _blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Adminexpress crea el trabajo y GitHub Actions compila, firma y publica APK/AAB. Esta pantalla conserva el contenido visible y actualiza los estados silenciosamente cada 20 segundos.',
              style: TextStyle(fontSize: 11, color: _dark, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const _Header({
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -.35,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFFD7E7FA),
            height: 1.4,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A56), Color(0xFF174B91), Color(0xFF0D6B8D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B174B91),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (action == null) {
            return Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withOpacity(.16)),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(child: copy),
              ],
            );
          }

          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 14),
                action!,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white.withOpacity(.16)),
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(child: copy),
              const SizedBox(width: 16),
              action!,
            ],
          );
        },
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String title;
  final String value;

  const _Kpi(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE6F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE1ECFF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: _blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 23,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: _dark,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _NumberField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SettingsCard({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_settingsIcon(title), color: _blue, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _dark,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

IconData _settingsIcon(String title) {
  final value = title.toLowerCase();
  if (value.contains('pago')) return Icons.account_balance_wallet_outlined;
  if (value.contains('servicio') || value.contains('módulo')) return Icons.apps_rounded;
  if (value.contains('operación') || value.contains('dispatch')) return Icons.alt_route_rounded;
  if (value.contains('tarifa') || value.contains('alcance')) return Icons.payments_outlined;
  if (value.contains('soporte') || value.contains('localización')) return Icons.support_agent_rounded;
  return Icons.tune_rounded;
}

class _ReadOnlyRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _dark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildProductCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String badge;
  final String description;
  final String primaryLabel;
  final String secondaryLabel;
  final Color accent;
  final Color soft;
  final VoidCallback? onPrimary;

  const _BuildProductCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.badge,
    required this.description,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.accent,
    required this.soft,
    this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 238),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 23),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _dark,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              height: 1.35,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              child: Text(primaryLabel),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: null,
              child: Text(secondaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildStatus extends StatelessWidget {
  final String status;
  const _BuildStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final ready = normalized == 'ready' || normalized == 'success';
    final failed = normalized == 'failed';
    final cancelled = normalized == 'cancelled';
    final building = normalized == 'building';

    final bg = ready
        ? const Color(0xFFE8F8EF)
        : failed
            ? const Color(0xFFFFE8E8)
            : cancelled
                ? const Color(0xFFF2F4F7)
                : building
                    ? const Color(0xFFEAF2FF)
                    : const Color(0xFFFFF3E7);
    final fg = ready
        ? const Color(0xFF14804A)
        : failed
            ? const Color(0xFFD92D20)
            : cancelled
                ? const Color(0xFF667085)
                : building
                    ? _blue
                    : const Color(0xFFC76B16);
    final label = ready
        ? 'Listo'
        : failed
            ? 'Falló'
            : cancelled
                ? 'Cancelado'
                : building
                    ? 'Compilando'
                    : normalized == 'queued'
                        ? 'En cola'
                        : status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DispatchItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onAssign;

  const _DispatchItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7ECF3)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final info = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: _blue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: onAssign,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                  label: const Text('Asignar conductor'),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onAssign,
                child: const Text('Asignar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  final String text;
  final bool positive;

  const _MiniStatus({
    required this.text,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        positive ? const Color(0xFFE8F8EF) : const Color(0xFFF2F4F7);
    final fg =
        positive ? const Color(0xFF14804A) : const Color(0xFF667085);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(text, style: const TextStyle(color: _muted)),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  final String title;
  const _Loading({required this.title});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        const LinearProgressIndicator(),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _Error({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 46),
              const SizedBox(height: 10),
              Text(error.toString()),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

num? _num(String value) {
  return num.tryParse(value.trim().replaceAll(',', '.'));
}

void _snack(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: ' + error.toString())),
  );
}

String _fareTitle(Map<String, dynamic> row) {
  final scope = row['scope_type']?.toString();
  if (scope == 'global') return 'Global';
  if (scope == 'service') {
    return 'Servicio · ' + (row['service_key'] ?? '—').toString();
  }
  return (row['zone_name'] ?? 'Zona').toString() +
      ' · ' +
      (row['service_key'] ?? '—').toString();
}

String _formatDate(Object? raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (date == null) return '—';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return day +
      '/' +
      month +
      '/' +
      date.year.toString() +
      ' · ' +
      hour +
      ':' +
      minute;
}

String _dateOnly(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return day + '/' + month + '/' + value.year.toString();
}
