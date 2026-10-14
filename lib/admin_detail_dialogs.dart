import 'package:flutter/material.dart';

import 'core/supabase_client.dart';
import 'admin_environment_store.dart';
import 'core/driver_license_review_state.dart';

const Color _detailBlue = Color(0xFF2563EB);
const Color _detailDark = Color(0xFF0F172A);
const Color _detailMuted = Color(0xFF64748B);
const Color _detailBorder = Color(0xFFE2E8F0);
const Color _detailSoft = Color(0xFFF8FAFC);

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _text(Object? value, [String fallback = '—']) {
  final raw = value?.toString().trim() ?? '';
  return raw.isEmpty ? fallback : raw;
}

String _date(Object? raw) {
  final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (value == null) return '—';
  final d = value.day.toString().padLeft(2, '0');
  final m = value.month.toString().padLeft(2, '0');
  final h = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  return '$d/$m/${value.year} · $h:$min';
}

String _money(Object? raw, [String currency = '']) {
  final amount = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
  if (amount == null) return '—';
  final prefix = currency.trim().isEmpty ? '' : '${currency.trim()} ';
  return '$prefix${amount.toStringAsFixed(2)}';
}

String _friendlyDriverDocumentType(Object? raw) {
  switch ((raw?.toString().trim().toLowerCase() ?? '')) {
    case 'driver_license':
      return 'Licencia de conducir';
    case 'identity_card':
    case 'national_id':
    case 'id_card':
      return 'Cédula de identidad';
    case 'vehicle_registration':
      return 'Documento del vehículo';
    case 'insurance':
      return 'Seguro del vehículo';
    default:
      return 'Documento del conductor';
  }
}

String _friendlyDocumentStatus(Object? raw) {
  switch ((raw?.toString().trim().toLowerCase() ?? '')) {
    case 'verified':
    case 'approved':
      return 'Aprobado';
    case 'rejected':
      return 'Rechazado';
    case 'expired':
      return 'Vencido';
    default:
      return 'Pendiente';
  }
}

Future<List<Map<String, dynamic>>> _zones(String channel) async {
  if (channel == 'preview') {
    // Only the retired shared-database QA mode reads shadow configuration.
    return const AdminEnvironmentStore('preview').previewList('service_zones');
  }
  // The real Preview site has its own service_zones and admin RPCs.

  final raw = await supabase.rpc('admin_zone_list_scoped');
  return _maps(raw);
}

Future<bool> showAdminDriverEditor(
  BuildContext context,
  String userId, {
  required String channel,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DriverEditorDialog(
          userId: userId,
          channel: channel,
        ),
      ) ??
      false;
}

Future<bool> showAdminUserEditor(
  BuildContext context,
  String userId, {
  required String channel,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UserEditorDialog(
          userId: userId,
          channel: channel,
        ),
      ) ??
      false;
}

Future<void> showAdminTripDetail(
  BuildContext context,
  String tripId, {
  required String channel,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _TripDetailDialog(
      tripId: tripId,
      channel: channel,
    ),
  );
}

class _DialogFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  const _DialogFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width < 900 ? width - 28 : 820.0;
    return AlertDialog(
      insetPadding: const EdgeInsets.all(14),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 6),
      actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _detailDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: _detailMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: maxWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .72,
          ),
          child: child,
        ),
      ),
      actions: actions,
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _detailSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _detailBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _detailBlue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _detailDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final List<(String, String)> items;

  const _InfoGrid(this.items);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final itemWidth =
            constraints.maxWidth < 560 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: const TextStyle(
                          color: _detailMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        item.$2,
                        style: const TextStyle(
                          color: _detailDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DriverEditorDialog extends StatefulWidget {
  final String userId;
  final String channel;
  const _DriverEditorDialog({
    required this.userId,
    required this.channel,
  });

  @override
  State<_DriverEditorDialog> createState() => _DriverEditorDialogState();
}

class _DriverEditorDialogState extends State<_DriverEditorDialog> {
  List<Map<String, dynamic>> workPermissions = const [];
  List<Map<String, dynamic>> parcelVehicleGrants = const [];
  String? parcelGrantError;
  bool parcelGrantSaving = false;
  String? workPermissionsError;
  bool workPermissionSaving = false;
  bool loading = true;
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> zones = const [];
  Map<String, dynamic> detail = const {};

  final fullName = TextEditingController();
  final phone = TextEditingController();
  final license = TextEditingController();
  final brand = TextEditingController();
  final model = TextEditingController();
  final color = TextEditingController();
  final plate = TextEditingController();
  final year = TextEditingController();

  String accountStatus = 'active';
  String approvalStatus = 'pending';
  String onlineStatus = 'offline';
  String vehicleType = 'motorcycle';
  String? countryCode;
  String? zoneId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    fullName.dispose();
    phone.dispose();
    license.dispose();
    brand.dispose();
    model.dispose();
    color.dispose();
    plate.dispose();
    year.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detailValue = await supabase.rpc(
        'admin_driver_detail_v2',
        params: {
          'p_user_id': widget.userId,
          'p_channel': widget.channel,
        },
      );
      final loadedZones = await _zones(widget.channel);
      List<Map<String, dynamic>> loadedWorkPermissions = const [];
      String? permissionError;
      try {
        loadedWorkPermissions = _maps(await supabase.rpc(
          'admin_driver_work_permission_list',
          params: {
            'p_driver_id': widget.userId,
            'p_channel': widget.channel,
          },
        ));
      } catch (_) {
        permissionError = 'Los permisos independientes todavía no están '
            'disponibles en este entorno.';
      }
      List<Map<String, dynamic>> parcelGrants = const [];
      String? parcelReadError;
      try {
        parcelGrants = _maps(await supabase
          .from('driver_parcel_vehicle_grants')
          .select('vehicle_id,parcel_kind,enabled')
          .eq('driver_id', widget.userId)
          .eq('channel', widget.channel));
      } catch (_) {
        parcelReadError = 'No se pudieron consultar los permisos por vehículo.';
      }
      final loaded = _map(detailValue);
      final user = _map(loaded['user']);
      final driver = _map(loaded['driver']);
      final vehicles = _maps(loaded['vehicles']);
      final vehicle = vehicles.where((v) => v['is_active'] == true).isNotEmpty
          ? vehicles.firstWhere((v) => v['is_active'] == true)
          : (vehicles.isEmpty ? <String, dynamic>{} : vehicles.first);

      fullName.text = _text(user['full_name'], '');
      phone.text = _text(user['phone'], '');
      license.text = _text(driver['license_number'], '');
      brand.text = _text(vehicle['brand'], '');
      model.text = _text(vehicle['model'], '');
      color.text = _text(vehicle['color'], '');
      plate.text = _text(vehicle['plate'], '');
      year.text = _text(vehicle['year'], '');

      if (!mounted) return;
      setState(() {
        detail = loaded;
        zones = loadedZones;
        workPermissions = loadedWorkPermissions;
        parcelVehicleGrants = parcelGrants;
        parcelGrantError = parcelReadError;
        workPermissionsError = permissionError;
        accountStatus = _text(user['account_status'], 'active');
        approvalStatus = _text(driver['approval_status'], 'pending');
        onlineStatus = _text(driver['online_status'], 'offline');
        vehicleType = _text(vehicle['vehicle_type'], 'motorcycle');
        countryCode = _text(driver['country_code'], '').toUpperCase();
        zoneId = driver['zone_id']?.toString();
        if ((countryCode == null || countryCode!.isEmpty) && zoneId != null) {
          final matches = loadedZones.where(
            (z) => z['id']?.toString() == zoneId,
          );
          if (matches.isNotEmpty) {
            countryCode = _text(matches.first['country_code'], '').toUpperCase();
          }
        }
        if ((zoneId == null || zoneId!.isEmpty) &&
            countryCode != null &&
            countryCode!.isNotEmpty) {
          final legacyCity = _text(driver['city'], '');
          final matches = loadedZones.where(
            (z) =>
                _text(z['country_code'], '').toUpperCase() == countryCode &&
                _text(z['city'], '').toLowerCase() ==
                    legacyCity.toLowerCase(),
          );
          if (matches.length == 1) {
            zoneId = matches.first['id']?.toString();
          }
        }
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

  Future<void> _setWorkPermission(String serviceKey, String status) async {
    if (workPermissionSaving) return;
    setState(() {
      workPermissionSaving = true;
      workPermissionsError = null;
    });
    try {
      await supabase.rpc('admin_set_driver_work_permission', params: {
        'p_driver_id': widget.userId,
        'p_service_key': serviceKey,
        'p_status': status,
        'p_channel': widget.channel,
      });
      final fresh = _maps(await supabase.rpc(
        'admin_driver_work_permission_list',
        params: {
          'p_driver_id': widget.userId,
          'p_channel': widget.channel,
        },
      ));
      if (mounted) {
        setState(() => workPermissions = fresh);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permiso actualizado: $serviceKey · $status')),
        );
      }
    } catch (e) {
      if (mounted) setState(() =>
          workPermissionsError = 'No se pudo actualizar el permiso: $e');
    } finally {
      if (mounted) setState(() => workPermissionSaving = false);
    }
  }

  Widget _workPermissionPanel() {
    const labels = <String, String>{
      'ride': 'Taxi / pasajeros',
      'parcel': 'Envíos / paquetería',
      'market': 'Delivery de comercios',
    };
    return _Section(
      title: 'Servicios autorizados al conductor',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'El tipo de vehículo no otorga permisos de trabajo. '
            'Aprueba por separado Taxi, Envíos y Delivery.',
            style: TextStyle(fontSize: 11, color: _detailMuted),
          ),
          if (workPermissionsError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(workPermissionsError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          for (final key in const ['ride', 'parcel', 'market']) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final row = workPermissions.where(
                (r) => r['service_key']?.toString() == key,
              );
              final status = row.isEmpty
                  ? 'not_requested'
                  : row.first['status']?.toString() ?? 'not_requested';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(labels[key] ?? key,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(switch (status) {
                    'approved' => 'Aprobado',
                    'pending' => 'Solicitud pendiente',
                    'rejected' => 'No autorizado',
                    _ => 'Sin solicitar',
                  }, style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(
                      onPressed: workPermissionSaving || workPermissionsError != null
                          ? null : () => _setWorkPermission(key, 'approved'),
                      child: const Text('Aprobar'),
                    ),
                    OutlinedButton(
                      onPressed: workPermissionSaving || workPermissionsError != null
                          ? null : () => _setWorkPermission(key, 'rejected'),
                      child: const Text('Revocar'),
                    ),
                  ]),
                ],
              );
            }),
          ],
          const Divider(height: 28),
          const Text(
            'Tamaños de paquete por vehículo',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _parcelVehiclePermissionsPanel(),
        ],
      ),
    );
  }


  int _parcelCapacity(String type) => switch(type) {
    'motorcycle' || 'moto' => 1,
    'car' || 'auto' => 2,
    'xl' => 2,
    'van' || 'truck' || 'camioneta' || 'camion' => 3,
    _ => 0,
  };
  Future<void> _setParcelVehicleGrant(
      String vehicleId, String kind, bool enabled) async {
    if (parcelGrantSaving || parcelGrantError != null) return;
    setState(() { parcelGrantSaving = true; parcelGrantError = null; });
    try {
      await supabase.rpc('admin_set_driver_parcel_vehicle_grant', params: {
        'p_driver_id': widget.userId,
        'p_vehicle_id': vehicleId,
        'p_channel': widget.channel,
        'p_parcel_kind': kind,
        'p_enabled': enabled,
      });
      final refreshed = _maps(await supabase
        .from('driver_parcel_vehicle_grants')
        .select('vehicle_id,parcel_kind,enabled')
        .eq('driver_id',widget.userId)
        .eq('channel',widget.channel));
      if (mounted) setState(() => parcelVehicleGrants = refreshed);
    } catch (e) {
      if (mounted) setState(() =>
        parcelGrantError = 'No se pudo actualizar permiso: ' + e.toString());
    } finally {
      if (mounted) setState(() => parcelGrantSaving = false);
    }
  }

  Widget _parcelVehiclePermissionsPanel() {
    final vehicles = _maps(detail['vehicles'])
        .where((vehicle) => vehicle['is_active'] == true)
        .toList();
    final parcelApproved = workPermissions.any((row) =>
        row['service_key'] == 'parcel' && row['status'] == 'approved');
    final hasEnabledGrant = parcelVehicleGrants.any((grant) =>
        grant['enabled'] == true &&
        vehicles.any((vehicle) =>
            vehicle['id']?.toString() == grant['vehicle_id']?.toString()));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (parcelApproved && !hasEnabledGrant)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Envíos está aprobado, pero este conductor no recibirá ofertas '
              'de Paquetes hasta autorizar al menos un tamaño compatible '
              'con su vehículo activo.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF965A00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const Text('Selecciona el tamaño máximo autorizado por vehículo. '
          'Auto también admite solicitudes Moto; Carga admite Auto y Moto. '
          'Moto no puede recibir Auto ni Carga. '
          'Sin ninguna selección, Envíos no se ofrece al conductor. '
          'No modifica los permisos de Taxi.',
          style: TextStyle(fontSize: 11, color: _detailMuted)),
        if (vehicles.isEmpty)
          const Text('No hay vehículo activo.')
        else
          for (final vehicle in vehicles) ...[
            const SizedBox(height: 10),
            Text('Vehículo: ' +
              (vehicle['brand']?.toString() ?? '') + ' ' +
              (vehicle['model']?.toString() ?? '') + ' · ' +
              (vehicle['plate']?.toString() ?? ''),
              style: const TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 8, runSpacing: 5, children: [
              for (final kind in const [
                ('moto', 'Moto', 1),
                ('auto', 'Auto', 2),
                ('carga', 'Carga', 3),
              ])
                Builder(builder: (context) {
                  final id = vehicle['id']?.toString() ?? '';
                  final eligible = id.isNotEmpty &&
                    _parcelCapacity(vehicle['vehicle_type']?.toString() ?? '')
                      >= kind.$3;
                  final selected = parcelVehicleGrants.any((grant) =>
                    grant['vehicle_id']?.toString() == id &&
                    grant['parcel_kind']?.toString() == kind.$1 &&
                    grant['enabled'] == true);
                  return FilterChip(
                    label: Text(kind.$2), selected: selected,
                    onSelected: eligible && !parcelGrantSaving &&
                      parcelGrantError == null
                      ? (checked) => _setParcelVehicleGrant(
                          id,kind.$1,checked)
                      : null,
                  );
                }),
            ]),
          ],
        if (parcelGrantError != null)
          Text(parcelGrantError!,style: const TextStyle(color: Colors.red)),
      ]);
  }

  Future<void> _save() async {
    if (saving) return;
    if (countryCode == null || countryCode!.isEmpty) {
      setState(() => error = 'Selecciona un país para el conductor.');
      return;
    }
    if (zoneId == null || zoneId!.isEmpty) {
      setState(() => error = 'Selecciona una zona para el conductor.');
      return;
    }
    final selectedZoneMatches = zones.where(
      (z) => z['id']?.toString() == zoneId,
    );
    if (selectedZoneMatches.isEmpty) {
      setState(() => error = 'La zona seleccionada ya no está disponible.');
      return;
    }
    final selectedZone = selectedZoneMatches.first;
    final selectedCity = _text(
      selectedZone['city'],
      _text(selectedZone['name'], ''),
    );
    final selectedCountryCode =
        _text(selectedZone['country_code'], countryCode!).toUpperCase();
    if (selectedCountryCode != countryCode) {
      setState(() => error = 'La zona no corresponde al país seleccionado.');
      return;
    }

    final vehicleYear =
        year.text.trim().isEmpty ? null : int.tryParse(year.text.trim());
    if (year.text.trim().isNotEmpty && vehicleYear == null) {
      setState(() => error = 'El año del vehículo no es válido.');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });
    try {
      await supabase.rpc(
        'admin_update_driver_profile_v2',
        params: {
          'p_user_id': widget.userId,
          'p_full_name': fullName.text.trim(),
          'p_phone': phone.text.trim(),
          'p_account_status': accountStatus,
          'p_license_number': license.text.trim(),
          'p_city': selectedCity,
          'p_zone_id': zoneId,
          'p_approval_status': approvalStatus,
          'p_online_status': onlineStatus,
          'p_vehicle_type': vehicleType,
          'p_vehicle_brand': brand.text.trim(),
          'p_vehicle_model': model.text.trim(),
          'p_vehicle_color': color.text.trim(),
          'p_vehicle_plate': plate.text.trim(),
          'p_vehicle_year': vehicleYear,
          'p_channel': widget.channel,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        saving = false;
      });
    }
  }

  Future<void> _openDriverAsset(String? path) async {
    final value = path?.trim() ?? '';
    if (value.isEmpty || !mounted) return;
    try {
      // Keep private evidence inside the driver sheet, instead of launching a
      // new tab with a long-lived signed URL.
      final signed = await supabase.storage
          .from('driver-onboarding')
          .createSignedUrl(value, 300);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (previewContext) {
          final available = MediaQuery.sizeOf(previewContext);
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: const Color(0xFF111827),
            child: SizedBox(
              width: available.width > 940 ? 900 : available.width - 32,
              height: available.height > 780 ? 700 : available.height * .84,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Vista previa del documento',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar vista previa',
                          onPressed: () => Navigator.pop(previewContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF374151)),
                  Expanded(
                    child: ClipRect(
                      child: InteractiveViewer(
                        minScale: .5,
                        maxScale: 5,
                        child: Center(
                          child: Image.network(
                            signed,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, image, progress) =>
                                progress == null
                                    ? image
                                    : const CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                            errorBuilder: (context, imageError, stackTrace) =>
                                const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No fue posible mostrar la imagen. '
                                'Vuelve a intentar o verifica el archivo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo mostrar el archivo: $e')),
        );
      }
    }
  }

  Future<void> _reviewDocument(
    Map<String, dynamic> document,
    String newStatus,
  ) async {
    if (saving) return;
    final documentId = document['id']?.toString();
    if (documentId == null || documentId.isEmpty) return;
    final label = _friendlyDriverDocumentType(document['document_type']);
    final rejecting = newStatus == 'rejected';
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(rejecting ? 'Rechazar $label' :
            newStatus == 'verified' ? 'Aprobar $label' :
            'Volver a revisar $label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rejecting
                ? 'Indica por qué se rechaza. El conductor podrá corregirlo.'
                : 'Solo cambiará el estado de este documento. '
                  'La aprobación general del conductor se hace por separado.'),
            if (rejecting) ...[
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo del rechazo',
                  hintText: 'Ej.: foto ilegible o documento incorrecto',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(rejecting ? 'Confirmar rechazo' :
                newStatus == 'verified' ? 'Aprobar documento' :
                'Reabrir revisión'),
          ),
        ],
      ),
    );
    final reason = note.text.trim();
    note.dispose();
    if (accepted != true || !mounted) return;
    if (rejecting && reason.length < 5) {
      setState(() => error = 'Indica un motivo de rechazo de al menos cinco caracteres.');
      return;
    }

    // Preserve all document metadata: admins only change its review status.
    final oldNotes = (document['notes']?.toString() ?? '').trim();
    final newNotes = rejecting
        ? (oldNotes.isEmpty ? 'Motivo del rechazo: $reason'
            : '$oldNotes\nMotivo del rechazo: $reason')
        : oldNotes;
    final expires = DateTime.tryParse(
      document['expires_at']?.toString() ?? '',
    );
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await supabase.rpc(
        'admin_upsert_driver_document_v2',
        params: {
          'p_document_id': documentId,
          'p_driver_id': widget.userId,
          'p_document_type': document['document_type']?.toString() ?? '',
          'p_document_number': document['document_number']?.toString() ?? '',
          'p_document_url': document['document_url']?.toString() ?? '',
          'p_status': newStatus,
          'p_expires_at': expires?.toUtc().toIso8601String(),
          'p_notes': newNotes,
          'p_channel': widget.channel,
        },
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            '$label: ${_friendlyDocumentStatus(newStatus)}.',
          )),
        );
      }
    } catch (e) {
      if (mounted) setState(
        () => error = 'No se pudo actualizar el documento. $e',
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  bool _isManualIdentityDocument(Map<String, dynamic> document) {
    if (_text(document['verification_method'], '').toLowerCase() != 'manual') {
      return false;
    }
    final type = _text(document['document_type'], '').toLowerCase();
    return const <String>{
      'identity_card',
      'national_id',
      'id_card',
      'identity',
      'carnet',
      'cedula',
      'cédula',
    }.contains(type) || type.contains('identity');
  }

  String _identityPartLabel(String slot) => switch (slot) {
        'front' => 'Frente del carné',
        'back' => 'Reverso del carné',
        'selfie' => 'Fotografía facial',
        'profile' => 'Foto de perfil',
        _ => 'Fotografía',
      };

  IconData _identityPartIcon(String slot) => switch (slot) {
        'front' => Icons.credit_card_rounded,
        'back' => Icons.flip_to_back_rounded,
        'selfie' => Icons.face_rounded,
        'profile' => Icons.account_circle_outlined,
        _ => Icons.image_outlined,
      };

  Future<void> _reviewIdentityPart(
    Map<String, dynamic> document,
    String slot,
    String newStatus,
  ) async {
    if (saving) return;
    final documentId = document['id']?.toString();
    if (documentId == null || documentId.isEmpty) return;

    final parts = _map(document['review_parts']);
    final entry = _map(parts[slot]);
    final version = int.tryParse(_text(entry['version'], '0')) ?? 0;
    final label = _identityPartLabel(slot);
    final rejecting = newStatus == 'rejected';
    final note = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          rejecting
              ? 'Rechazar $label'
              : newStatus == 'approved'
                  ? 'Aprobar $label'
                  : 'Reabrir $label',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rejecting
                  ? 'Solo se rechazará esta fotografía. Las demás evidencias aprobadas conservarán su estado.'
                  : 'Solo cambiará el estado de $label. No se modifican las demás fotografías.',
            ),
            if (rejecting) ...[
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo del rechazo',
                  hintText: 'Ej.: foto borrosa, cortada o no corresponde',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              rejecting
                  ? 'Confirmar rechazo'
                  : newStatus == 'approved'
                      ? 'Aprobar fotografía'
                      : 'Reabrir revisión',
            ),
          ),
        ],
      ),
    );

    final reason = note.text.trim();
    note.dispose();
    if (accepted != true || !mounted) return;
    if (rejecting && reason.length < 5) {
      setState(() {
        error = 'Indica un motivo de rechazo de al menos cinco caracteres.';
      });
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });
    try {
      await supabase.rpc(
        'admin_driver_kyc_bolivia_manual_review_part',
        params: {
          'p_document_id': documentId,
          'p_slot': slot,
          'p_status': newStatus,
          'p_reason': rejecting ? reason : null,
          'p_expected_version': version,
          'p_channel': widget.channel,
        },
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$label: ' +
                  _friendlyDocumentStatus(newStatus) +
                  '. Las demás evidencias no cambiaron.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'No se pudo actualizar $label. $e';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _identityPartReviewCard(
    Map<String, dynamic> document,
    String slot,
  ) {
    final parts = _map(document['review_parts']);
    final entry = _map(parts[slot]);
    var path = _text(entry['path'], '');
    if (slot == 'profile' && path.isEmpty) {
      path = _text(_map(detail['driver'])['profile_photo_path'], '');
    }
    if (path.isEmpty) return const SizedBox.shrink();

    final status = _text(entry['status'], 'pending').toLowerCase();
    final reason = _text(entry['reason'], '');
    final tone = status == 'approved'
        ? const Color(0xFF067647)
        : status == 'rejected'
            ? const Color(0xFFB42318)
            : const Color(0xFFB54708);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: status == 'rejected'
            ? const Color(0xFFFFF7F6)
            : status == 'approved'
                ? const Color(0xFFF6FEF9)
                : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withOpacity(.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_identityPartIcon(slot), size: 17, color: tone),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _identityPartLabel(slot),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Chip(
                label: Text(_friendlyDocumentStatus(status)),
                side: BorderSide(color: tone.withOpacity(.28)),
              ),
            ],
          ),
          if (status == 'rejected' && reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Motivo: $reason',
                style: const TextStyle(
                  color: Color(0xFFB42318),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openDriverAsset(path),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Ver'),
              ),
              if (status != 'approved')
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () => _reviewIdentityPart(
                            document,
                            slot,
                            'approved',
                          ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Aprobar'),
                ),
              if (status != 'rejected')
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () => _reviewIdentityPart(
                            document,
                            slot,
                            'rejected',
                          ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Rechazar'),
                ),
              if (status != 'pending')
                TextButton.icon(
                  onPressed: saving
                      ? null
                      : () => _reviewIdentityPart(
                            document,
                            slot,
                            'pending',
                          ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('Reabrir'),
                ),
            ],
          ),
          if (status == 'approved')
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Aprobado · el conductor no tendrá que volver a cargar esta evidencia.',
                style: TextStyle(
                  color: Color(0xFF067647),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Future<void> _reviewLicensePart(
    Map<String, dynamic> document,
    String slot,
    String status, {
    bool generic = false,
  }) async {
    if (saving) return;
    final id = _text(document['id'], '');
    if (id.isEmpty) return;
    final label = generic
        ? switch (slot) {
            'front' => 'Frente del documento',
            'back' => 'Reverso del documento',
            _ => 'Fotografía facial',
          }
        : slot == 'front' ? 'Frente de la licencia' : 'Reverso de la licencia';
    final rejecting = status == 'rejected';
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(rejecting ? 'Rechazar $label'
            : status == 'approved' ? 'Aprobar $label' : 'Reabrir $label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Solo cambiará esta fotografía. La otra cara conservará '
              'su estado y no tendrá que volver a cargarse.',
            ),
            if (rejecting) ...[
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo del rechazo',
                  hintText: 'Ej.: fotografía ilegible o cortada',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(rejecting ? 'Confirmar rechazo'
                : status == 'approved' ? 'Aprobar fotografía' : 'Reabrir revisión'),
          ),
        ],
      ),
    );
    final reason = note.text.trim();
    note.dispose();
    if (!mounted || accepted != true) return;
    if (rejecting && reason.length < 5) {
      setState(() => error = 'Indica un motivo de al menos cinco caracteres.');
      return;
    }
    final entry = _map(_map(document['review_parts'])[slot]);
    final version = int.tryParse(_text(entry['version'], '0')) ?? 0;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await supabase.rpc(
        generic ? 'admin_driver_document_review_part_v2'
                : 'admin_driver_license_review_part', params: {
        'p_document_id': id,
        'p_slot': slot,
        'p_status': status,
        'p_reason': rejecting ? reason : null,
        'p_expected_version': version,
        'p_channel': widget.channel,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label: ${_friendlyDocumentStatus(status)}.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() {
        error = 'No se pudo revisar $label. $e';
      });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _licensePartReviewCard(
    Map<String, dynamic> document,
    String slot, {
    bool generic = false,
  }) {
    final front = slot == 'front';
    final path = _text(
      document[switch (slot) {
        'front' => 'front_object_path',
        'back' => 'back_object_path',
        _ => 'selfie_object_path',
      }], '');
    final entry = _map(_map(document['review_parts'])[slot]);
    final status = generic
        ? _text(entry['status'], 'pending').toLowerCase()
        : driverLicensePartStatus(document, slot);
    final label = generic
        ? switch (slot) {
            'front' => 'Frente',
            'back' => 'Reverso',
            _ => 'Fotografía facial',
          }
        : front ? 'Frente de la licencia' : 'Reverso de la licencia';
    final tone = status == 'approved'
        ? const Color(0xFF067647)
        : status == 'rejected'
            ? const Color(0xFFB42318)
            : const Color(0xFFB54708);
    final reason = _text(entry['reason'], '');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: status == 'approved'
            ? const Color(0xFFF6FEF9)
            : status == 'rejected'
                ? const Color(0xFFFFF7F6)
                : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(slot == 'front' ? Icons.credit_card_rounded
                  : slot == 'back' ? Icons.flip_to_back_rounded : Icons.face_rounded,
                  size: 17, color: tone),
              const SizedBox(width: 7),
              Expanded(
                child: Text(label,
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w800)),
              ),
              Chip(
                label: Text(_friendlyDocumentStatus(status)),
                side: BorderSide(color: tone.withValues(alpha: .3)),
              ),
            ],
          ),
          if (reason.isNotEmpty && status == 'rejected')
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text('Motivo: $reason',
                style: const TextStyle(color: Color(0xFFB42318),
                    fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          if (path.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Fotografía no cargada',
                  style: TextStyle(color: _detailMuted, fontSize: 11)),
            )
          else ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openDriverAsset(path),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Ver'),
                ),
                if (status != 'approved')
                  FilledButton.icon(
                    onPressed: saving ? null
                         : () => _reviewLicensePart(document, slot, 'approved',
                            generic: generic),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Aprobar'),
                  ),
                if (status != 'rejected')
                  OutlinedButton.icon(
                    onPressed: saving ? null
                         : () => _reviewLicensePart(document, slot, 'rejected',
                            generic: generic),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Rechazar'),
                  ),
                if (status != 'pending')
                  TextButton.icon(
                    onPressed: saving ? null
                         : () => _reviewLicensePart(document, slot, 'pending',
                            generic: generic),
                    icon: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text('Reabrir'),
                  ),
              ],
            ),
            if (status == 'approved')
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text('Aprobado · esta cara conserva su aprobación.',
                  style: TextStyle(color: Color(0xFF067647),
                    fontSize: 10, fontWeight: FontWeight.w700)),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _map(detail['user']);
    final driver = _map(detail['driver']);
    final vehicles = _maps(detail['vehicles']);
    final activeVehicle = vehicles.where((v) => v['is_active'] == true).isNotEmpty
        ? vehicles.firstWhere((v) => v['is_active'] == true)
        : (vehicles.isEmpty ? <String, dynamic>{} : vehicles.first);
    final profilePhotoPath = _text(driver['profile_photo_path'], '');
    final vehiclePhotos = activeVehicle['photo_paths'] is List
        ? (activeVehicle['photo_paths'] as List)
            .map((e) => e.toString().trim())
            .where(
              (e) =>
                  e.isNotEmpty &&
                  e != profilePhotoPath &&
                  e.contains('/vehicle/'),
            )
            .toList()
        : <String>[];

    final countriesByCode = <String, String>{};
    for (final zone in zones) {
      final code = _text(zone['country_code'], '').toUpperCase();
      if (code.isEmpty) continue;
      countriesByCode[code] = _text(zone['country'], code);
    }
    final countryCodes = countriesByCode.keys.toList()..sort();
    final selectedCountryCode =
        countryCodes.contains(countryCode) ? countryCode : null;
    final filteredZones = countryCode == null || countryCode!.isEmpty
        ? <Map<String, dynamic>>[]
        : zones
            .where(
              (z) =>
                  _text(z['country_code'], '').toUpperCase() == countryCode,
            )
            .toList()
          ..sort((a, b) {
            final ac = _text(a['city'], _text(a['name'], ''));
            final bc = _text(b['city'], _text(b['name'], ''));
            return ac.compareTo(bc);
          });
    final selectedZoneId = filteredZones.any(
      (z) => z['id']?.toString() == zoneId,
    )
        ? zoneId
        : null;
    final documents = _maps(detail['documents']);
    final verifications = _maps(detail['identity_verifications']);
    final rating = _map(detail['rating_summary']);
    final subscription = _map(detail['subscription']);
    final qa = _map(detail['qa']);
    final partner = _map(detail['partner']);

    return _DialogFrame(
      title: 'Ficha del conductor',
      subtitle: loading
          ? 'Cargando información completa...'
          : _text(user['email'], widget.userId),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: loading || saving ? null : _save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded, size: 17),
          label: const Text('Guardar cambios'),
        ),
      ],
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null && detail.isEmpty
              ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      if (error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: Color(0xFFB42318),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      // Approvals belong inside the driver's existing editor, not
                      // only in a detached helper that cannot be navigated to.
                      _Section(
                        title: 'Fotos para aprobación',
                        icon: Icons.photo_library_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (profilePhotoPath.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: () => _openDriverAsset(
                                      profilePhotoPath,
                                    ),
                                    icon: const Icon(Icons.account_circle_outlined),
                                    label: const Text('Ver foto de perfil'),
                                  ),
                                for (var i = 0; i < vehiclePhotos.length; i++)
                                  OutlinedButton.icon(
                                    onPressed: () => _openDriverAsset(vehiclePhotos[i]),
                                    icon: const Icon(Icons.directions_car_outlined),
                                    label: Text('Foto vehículo ${i + 1}'),
                                  ),
                              ],
                            ),
                            if (profilePhotoPath.isEmpty && vehiclePhotos.isEmpty)
                              const Text(
                                'El conductor todavía no cargó fotografías.',
                                style: TextStyle(
                                  color: _detailMuted,
                                  fontSize: 11,
                                ),
                              )
                            else if (vehiclePhotos.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'No hay fotos del vehículo cargadas.',
                                  style: TextStyle(
                                    color: _detailMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _Section(
                        title: 'Datos personales y operación',
                        icon: Icons.person_rounded,
                        child: Column(
                          children: [
                            TextField(
                              controller: fullName,
                              decoration: const InputDecoration(labelText: 'Nombre completo'),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: phone,
                              decoration: const InputDecoration(labelText: 'Teléfono'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              initialValue: _text(user['email'], ''),
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Correo (solo lectura)',
                              ),
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (_, c) {
                                final w = c.maxWidth < 560 ? c.maxWidth : (c.maxWidth - 10) / 2;
                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    SizedBox(
                                      width: w,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: accountStatus,
                                        decoration: const InputDecoration(labelText: 'Estado de cuenta'),
                                        items: const [
                                          DropdownMenuItem(value: 'active', child: Text('Activa')),
                                          DropdownMenuItem(value: 'suspended', child: Text('Suspendida')),
                                          DropdownMenuItem(value: 'blocked', child: Text('Bloqueada')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) setState(() => accountStatus = value);
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: w,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: approvalStatus,
                                        decoration: const InputDecoration(labelText: 'Aprobación conductor'),
                                        items: const [
                                          DropdownMenuItem(value: 'approved', child: Text('Aprobado')),
                                          DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                                          DropdownMenuItem(value: 'rejected', child: Text('Rechazado')),
                                          DropdownMenuItem(value: 'suspended', child: Text('Suspendido')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) setState(() => approvalStatus = value);
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: w,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: onlineStatus,
                                        decoration: const InputDecoration(labelText: 'Estado operativo'),
                                        items: const [
                                          DropdownMenuItem(value: 'offline', child: Text('Fuera de línea')),
                                          DropdownMenuItem(value: 'online', child: Text('En línea')),
                                          DropdownMenuItem(value: 'busy', child: Text('Ocupado')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) setState(() => onlineStatus = value);
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: w,
                                      child: DropdownButtonFormField<String>(
                                        key: ValueKey('driver-country-${selectedCountryCode ?? 'unselected'}'),
                                        initialValue: selectedCountryCode,
                                        isExpanded: true,
                                        decoration: const InputDecoration(labelText: 'País'),
                                        items: countryCodes
                                            .map(
                                              (code) => DropdownMenuItem<String>(
                                                value: code,
                                                child: Text(
                                                  (countriesByCode[code] ?? code) + ' · ' + code,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            countryCode = value;
                                            final stillValid = zones.any(
                                              (z) =>
                                                  z['id']?.toString() == zoneId &&
                                                  _text(z['country_code'], '').toUpperCase() == value,
                                            );
                                            if (!stillValid) zoneId = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              key: ValueKey('driver-zone-${countryCode ?? 'unselected'}'),
                              initialValue: selectedZoneId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Zona / ciudad',
                                hintText: 'Selecciona una zona del país',
                              ),
                              items: filteredZones
                                  .map(
                                    (z) => DropdownMenuItem<String>(
                                      value: z['id']?.toString(),
                                      child: Text(
                                        _text(z['city'], _text(z['name'])) +
                                            (_text(z['name'], '') ==
                                                    _text(z['city'], '')
                                                ? ''
                                                : ' · ' + _text(z['name'])) +
                                            ' · ' +
                                            _text(z['region_department'], _text(z['currency_code'])),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: countryCode == null || countryCode!.isEmpty
                                  ? null
                                  : (value) {
                                      setState(() {
                                        zoneId = value;
                                        final matches = zones.where(
                                          (z) => z['id']?.toString() == value,
                                        );
                                        if (matches.isNotEmpty) {
                                          countryCode = _text(
                                            matches.first['country_code'],
                                            countryCode!,
                                          ).toUpperCase();
                                        }
                                      });
                                    },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: license,
                              decoration: const InputDecoration(labelText: 'Número de licencia'),
                            ),
                          ],
                        ),
                      ),
                      _workPermissionPanel(),
                      _Section(
                        title: 'Vehículo',
                        icon: Icons.two_wheeler_rounded,
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: vehicleType,
                              decoration: const InputDecoration(labelText: 'Tipo'),
                              items: const [
                                DropdownMenuItem(value: 'motorcycle', child: Text('Moto')),
                                DropdownMenuItem(value: 'car', child: Text('Auto')),
                                DropdownMenuItem(value: 'xl', child: Text('XL')),
                              ],
                              onChanged: (value) {
                                if (value != null) setState(() => vehicleType = value);
                              },
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (_, c) {
                                final w = c.maxWidth < 560 ? c.maxWidth : (c.maxWidth - 10) / 2;
                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    SizedBox(width: w, child: TextField(controller: brand, decoration: const InputDecoration(labelText: 'Marca'))),
                                    SizedBox(width: w, child: TextField(controller: model, decoration: const InputDecoration(labelText: 'Modelo'))),
                                    SizedBox(width: w, child: TextField(controller: color, decoration: const InputDecoration(labelText: 'Color'))),
                                    SizedBox(width: w, child: TextField(controller: plate, decoration: const InputDecoration(labelText: 'Placa'))),
                                    SizedBox(width: w, child: TextField(controller: year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Año'))),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      _Section(
                        title: 'Documentos e identidad',
                        icon: Icons.badge_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Revisa las imágenes y aprueba o rechaza cada '
                              'documento. No necesitas editar datos técnicos.',
                              style: TextStyle(color: _detailMuted, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            if (documents.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  'El conductor todavía no cargó documentos.',
                                  style: TextStyle(color: _detailMuted, fontSize: 11),
                                ),
                              )
                            else
                              ...documents.map((doc) {
                                final status =
                                    (doc['status'] ?? 'pending').toString();
                                final expiry = doc['expires_at'];
                                final rejectionNote = _text(
                                  doc['rejection_reason'] ?? doc['notes'],
                                  '',
                                );
                                final manualIdentity =
                                    _isManualIdentityDocument(doc);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 9),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _detailSoft,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _detailBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 9,
                                        runSpacing: 7,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            _friendlyDriverDocumentType(
                                              doc['document_type'],
                                            ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              _friendlyDocumentStatus(status),
                                            ),
                                          ),
                                          if (manualIdentity)
                                            const Chip(
                                              avatar: Icon(
                                                Icons.photo_library_outlined,
                                                size: 15,
                                              ),
                                              label: Text(
                                                'Revisión por fotografía',
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (_text(
                                        doc['document_number'],
                                        '',
                                      ).isNotEmpty)
                                        Text(
                                          'Número: ' +
                                              doc['document_number'].toString(),
                                          style: const TextStyle(
                                            color: _detailMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      if (expiry != null)
                                        Text(
                                          'Vencimiento: ' + _date(expiry),
                                          style: const TextStyle(
                                            color: _detailMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      if (!manualIdentity &&
                                          status == 'rejected' &&
                                          rejectionNote.isNotEmpty)
                                        Text(
                                          rejectionNote,
                                          style: const TextStyle(
                                            color: Color(0xFFB42318),
                                            fontSize: 11,
                                          ),
                                        ),
                                      if (_text(doc['document_type'], '')
                                          .toLowerCase() == 'driver_license') ...[
                                        const SizedBox(height: 5),
                                        const Text(
                                          'Revisa frente y reverso por separado. '
                                          'Una cara aprobada conserva su estado.',
                                          style: TextStyle(
                                            color: _detailMuted,
                                            fontSize: 11,
                                            height: 1.35,
                                          ),
                                        ),
                                        _licensePartReviewCard(doc, 'front'),
                                        _licensePartReviewCard(doc, 'back'),
                                      ] else if (!manualIdentity &&
                                          _text(doc['requirement_id'], '').isNotEmpty &&
                                          _map(doc['review_parts']).containsKey('front') &&
                                          _text(doc['document_type'], '').toLowerCase() != 'driver_license') ...[
                                        const SizedBox(height: 5),
                                        const Text('Revisa por foto sin alterar las otras evidencias aprobadas.',
                                          style: TextStyle(color: _detailMuted, fontSize: 11)),
                                        for (final slot in const <String>['front', 'back', 'selfie'])
                                          if (_map(doc['review_parts']).containsKey(slot))
                                            _licensePartReviewCard(doc, slot, generic: true),
                                      ] else if (manualIdentity) ...[
                                        const SizedBox(height: 5),
                                        const Text(
                                          'Aprueba o rechaza cada fotografía por separado. '
                                          'Una evidencia aprobada permanece aprobada aunque otra se rechace.',
                                          style: TextStyle(
                                            color: _detailMuted,
                                            fontSize: 11,
                                            height: 1.35,
                                          ),
                                        ),
                                        for (final slot in const <String>[
                                          'front',
                                          'back',
                                          'selfie',
                                          'profile',
                                        ])
                                          _identityPartReviewCard(doc, slot),
                                      ] else ...[
                                        const SizedBox(height: 9),
                                        Wrap(
                                          spacing: 7,
                                          runSpacing: 8,
                                          children: [
                                            if (_text(
                                              doc['front_object_path'],
                                              '',
                                            ).isNotEmpty)
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _openDriverAsset(
                                                  doc['front_object_path']
                                                      ?.toString(),
                                                ),
                                                icon: const Icon(
                                                  Icons.credit_card_rounded,
                                                  size: 16,
                                                ),
                                                label: const Text('Ver frente'),
                                              ),
                                            if (_text(
                                              doc['back_object_path'],
                                              '',
                                            ).isNotEmpty)
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _openDriverAsset(
                                                  doc['back_object_path']
                                                      ?.toString(),
                                                ),
                                                icon: const Icon(
                                                  Icons.flip_to_back_rounded,
                                                  size: 16,
                                                ),
                                                label:
                                                    const Text('Ver reverso'),
                                              ),
                                            if (_text(
                                              doc['selfie_object_path'],
                                              '',
                                            ).isNotEmpty)
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _openDriverAsset(
                                                  doc['selfie_object_path']
                                                      ?.toString(),
                                                ),
                                                icon: const Icon(
                                                  Icons.face_rounded,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Ver foto facial',
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 9),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 7,
                                          children: [
                                            if (status != 'verified')
                                              FilledButton.icon(
                                                onPressed: saving
                                                    ? null
                                                    : () => _reviewDocument(
                                                          doc,
                                                          'verified',
                                                        ),
                                                icon: const Icon(
                                                  Icons
                                                      .check_circle_outline,
                                                  size: 17,
                                                ),
                                                label:
                                                    const Text('Aprobar'),
                                              ),
                                            if (status != 'rejected')
                                              OutlinedButton.icon(
                                                onPressed: saving
                                                    ? null
                                                    : () => _reviewDocument(
                                                          doc,
                                                          'rejected',
                                                        ),
                                                icon: const Icon(
                                                  Icons.cancel_outlined,
                                                  size: 17,
                                                ),
                                                label:
                                                    const Text('Rechazar'),
                                              ),
                                            if (status != 'pending')
                                              TextButton.icon(
                                                onPressed: saving
                                                    ? null
                                                    : () => _reviewDocument(
                                                          doc,
                                                          'pending',
                                                        ),
                                                icon: const Icon(
                                                  Icons.restart_alt,
                                                  size: 17,
                                                ),
                                                label: const Text(
                                                  'Reabrir revisión',
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            const Divider(),
                            const Text(
                              'Historial de verificaciones de identidad',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const Text(
                              'Estos son intentos anteriores de verificación, '
                              'no los estados individuales de las fotografías.',
                              style: TextStyle(color: _detailMuted, fontSize: 11),
                            ),
                            if (verifications.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('Aún no se realizó la revisión.',
                                  style: TextStyle(color: _detailMuted, fontSize: 11)),
                              )
                            else
                              ...verifications.take(3).map((v) {
                                final status = _text(v['status'], 'pending');
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.fact_check_outlined, size: 18),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Intento de verificación manual',
                                              style: TextStyle(fontWeight: FontWeight.w600)),
                                            Text(_date(v['created_at']),
                                              style: const TextStyle(
                                                color: _detailMuted, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                      Chip(label: Text(
                                        _friendlyDocumentStatus(status),
                                      )),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      _Section(
                        title: 'Resumen operativo',
                        icon: Icons.insights_rounded,
                        child: _InfoGrid([
                          ('Calificación', '${_text(rating['average'], '0')} / 5 · ${_text(rating['count'], '0')} evaluaciones'),
                          ('Suscripción', subscription.isEmpty ? 'Sin suscripción' : '${_text(subscription['plan_name'])} · ${_text(subscription['status'])}'),
                          ('Vence suscripción', _date(subscription['expires_at'])),
                          ('QA / pruebas', qa.isEmpty ? 'Cuenta real' : '${_text(qa['group_name'])} · ${_text(qa['role'])}'),
                          ('Empresa / sindicato', partner.isEmpty ? 'Sin organización' : _text(partner['name'])),
                          ('Alta', _date(user['created_at'])),
                        ]),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _UserEditorDialog extends StatefulWidget {
  final String userId;
  final String channel;
  const _UserEditorDialog({
    required this.userId,
    required this.channel,
  });

  @override
  State<_UserEditorDialog> createState() => _UserEditorDialogState();
}

class _UserEditorDialogState extends State<_UserEditorDialog> {
  bool loading = true;
  bool saving = false;
  String? error;
  Map<String, dynamic> detail = const {};
  List<Map<String, dynamic>> zones = const [];

  final fullName = TextEditingController();
  final phone = TextEditingController();
  String activeMode = 'passenger';
  String accountStatus = 'active';
  String? zoneId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    fullName.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detailValue = await supabase.rpc(
        'admin_user_detail_v2',
        params: {
          'p_user_id': widget.userId,
          'p_channel': widget.channel,
        },
      );
      final loadedZones = await _zones(widget.channel);
      final loaded = _map(detailValue);
      final user = _map(loaded['user']);
      fullName.text = _text(user['full_name'], '');
      phone.text = _text(user['phone'], '');

      if (!mounted) return;
      setState(() {
        detail = loaded;
        zones = loadedZones;
        activeMode = _text(user['active_mode'], 'passenger');
        accountStatus = _text(user['account_status'], 'active');
        zoneId = user['last_zone_id']?.toString() ??
            _map(loaded['zone'])['id']?.toString();
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

  Future<void> _save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await supabase.rpc(
        'admin_update_user_profile_v2',
        params: {
          'p_user_id': widget.userId,
          'p_full_name': fullName.text.trim(),
          'p_phone': phone.text.trim(),
          'p_active_mode': activeMode,
          'p_account_status': accountStatus,
          'p_zone_id': zoneId,
          'p_channel': widget.channel,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _map(detail['user']);
    final wallet = _map(detail['wallet']);
    final rating = _map(detail['rating_summary']);
    final qa = _map(detail['qa']);
    final recentTrips = _maps(detail['recent_trips']);

    return _DialogFrame(
      title: 'Ficha del usuario',
      subtitle: loading ? 'Cargando perfil...' : _text(user['email'], widget.userId),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: loading || saving ? null : _save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded, size: 17),
          label: const Text('Guardar cambios'),
        ),
      ],
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null && detail.isEmpty
              ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      if (error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          color: const Color(0xFFFFF1F1),
                          child: Text(error!, style: const TextStyle(color: Color(0xFFB42318))),
                        ),
                      _Section(
                        title: 'Perfil y cuenta',
                        icon: Icons.person_rounded,
                        child: Column(
                          children: [
                            TextField(
                              controller: fullName,
                              decoration: const InputDecoration(labelText: 'Nombre completo'),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: phone,
                              decoration: const InputDecoration(labelText: 'Teléfono'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              initialValue: _text(user['email'], ''),
                              readOnly: true,
                              decoration: const InputDecoration(labelText: 'Correo (solo lectura)'),
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (_, c) {
                                final w = c.maxWidth < 560 ? c.maxWidth : (c.maxWidth - 10) / 2;
                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    SizedBox(
                                      width: w,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: activeMode,
                                        decoration: const InputDecoration(labelText: 'Modo activo'),
                                        items: const [
                                          DropdownMenuItem(value: 'passenger', child: Text('Pasajero')),
                                          DropdownMenuItem(value: 'driver', child: Text('Conductor')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) setState(() => activeMode = value);
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: w,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: accountStatus,
                                        decoration: const InputDecoration(labelText: 'Estado'),
                                        items: const [
                                          DropdownMenuItem(value: 'active', child: Text('Activa')),
                                          DropdownMenuItem(value: 'suspended', child: Text('Suspendida')),
                                          DropdownMenuItem(value: 'blocked', child: Text('Bloqueada')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) setState(() => accountStatus = value);
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: w,
                                      child: DropdownButtonFormField<String?>(
                                        initialValue: zoneId,
                                        decoration: const InputDecoration(labelText: 'Zona'),
                                        items: [
                                          const DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text('Sin zona asignada'),
                                          ),
                                          ...zones.map(
                                            (z) => DropdownMenuItem<String?>(
                                              value: z['id']?.toString(),
                                              child: Text(_text(z['name'])),
                                            ),
                                          ),
                                        ],
                                        onChanged: (value) => setState(() => zoneId = value),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      _Section(
                        title: 'Resumen',
                        icon: Icons.analytics_outlined,
                        child: _InfoGrid([
                          ('Billetera', wallet.isEmpty ? 'Sin billetera' : _money(wallet['balance'], _text(wallet['currency'], ''))),
                          ('Calificación', '${_text(rating['average'], '0')} / 5 · ${_text(rating['count'], '0')} evaluaciones'),
                          ('QA / pruebas', qa.isEmpty ? 'Cuenta real' : '${_text(qa['group_name'])} · ${_text(qa['role'])}'),
                          ('Alta', _date(user['created_at'])),
                        ]),
                      ),
                      _Section(
                        title: 'Viajes recientes',
                        icon: Icons.local_taxi_outlined,
                        child: recentTrips.isEmpty
                            ? const Text(
                                'No hay viajes recientes.',
                                style: TextStyle(color: _detailMuted),
                              )
                            : Column(
                                children: recentTrips.take(10).map(
                                  (trip) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.route_rounded, color: _detailBlue),
                                    title: Text(
                                      _text(trip['pickup_address'], 'Origen') +
                                          ' → ' +
                                          _text(trip['destination_address'], 'Destino'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      _text(trip['status']) +
                                          ' · ' +
                                          _money(trip['final_fare']) +
                                          ' · ' +
                                          _date(trip['created_at']),
                                    ),
                                  ),
                                ).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _TripDetailDialog extends StatefulWidget {
  final String tripId;
  final String channel;
  const _TripDetailDialog({
    required this.tripId,
    required this.channel,
  });

  @override
  State<_TripDetailDialog> createState() => _TripDetailDialogState();
}

class _TripDetailDialogState extends State<_TripDetailDialog> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final value = await supabase.rpc(
      'admin_trip_detail_v2',
      params: {
        'p_trip_id': widget.tripId,
        'p_channel': widget.channel,
      },
    );
    return _map(value);
  }

  @override
  Widget build(BuildContext context) {
    return _DialogFrame(
      title: 'Detalle del viaje',
      subtitle: 'Información operativa, cobro, historial y participantes.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final data = snapshot.data ?? const {};
          final trip = _map(data['trip']);
          final request = _map(data['request']);
          final zone = _map(data['zone']);
          final passenger = _map(data['passenger']);
          final driver = _map(data['driver']);
          final payments = _maps(data['payments']);
          final walletMovements = _maps(data['wallet_movements']);
          final history = _maps(data['status_history']);
          final ratings = _maps(data['ratings']);
          final currency = _text(request['currency'], 'BOB');

          return SingleChildScrollView(
            child: Column(
              children: [
                _Section(
                  title: 'Ruta',
                  icon: Icons.route_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(request['pickup_address'], 'Origen'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 7),
                        child: Icon(Icons.south_rounded, size: 18, color: _detailMuted),
                      ),
                      Text(
                        _text(request['destination_address'], 'Destino'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      _InfoGrid([
                        ('Zona', _text(zone['name'], 'Sin zona')),
                        ('Servicio', _text(request['category'])),
                        ('Distancia', request['route_distance_km'] == null ? '—' : '${request['route_distance_km']} km'),
                        ('Duración estimada', request['route_duration_minutes'] == null ? '—' : '${request['route_duration_minutes']} min'),
                      ]),
                    ],
                  ),
                ),
                _Section(
                  title: 'Participantes',
                  icon: Icons.people_alt_rounded,
                  child: _InfoGrid([
                    ('Pasajero', _text(passenger['full_name'])),
                    ('Teléfono pasajero', _text(passenger['phone'])),
                    ('Conductor', _text(driver['full_name'])),
                    ('Teléfono conductor', _text(driver['phone'])),
                  ]),
                ),
                _Section(
                  title: 'Tarifa y pago',
                  icon: Icons.payments_rounded,
                  child: Column(
                    children: [
                      _InfoGrid([
                        ('Tarifa propuesta', _money(request['proposed_fare'], currency)),
                        ('Tarifa final', _money(trip['final_fare'], currency)),
                        ('Método solicitado', _text(request['payment_method'])),
                        ('Estado de pago', _text(trip['payment_status'])),
                        ('Modo de precio', _text(request['pricing_mode'])),
                        ('Demanda', '${_text(request['demand_level'])} · x${_text(request['demand_multiplier'], '1')}'),
                      ]),
                      if (payments.isNotEmpty) ...[
                        const Divider(height: 24),
                        ...payments.map(
                          (p) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.receipt_long_outlined, color: _detailBlue),
                            title: Text(
                              _money(p['amount'], _text(p['currency'], currency)) +
                                  ' · ' +
                                  _text(p['method']),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              _text(p['status']) +
                                  ' · comisión ' +
                                  _money(p['commission_amount'], _text(p['currency'], currency)) +
                                  ' · ' +
                                  _date(p['created_at']),
                            ),
                          ),
                        ),
                      ],
                      if (walletMovements.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          'Movimientos de billetera: ${walletMovements.length}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        ...walletMovements.map(
                          (m) => Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Row(
                              children: [
                                Expanded(child: Text(_text(m['reference']))),
                                Text(
                                  '${m['amount']} · ${_text(m['status'])}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _Section(
                  title: 'Fechas y estado',
                  icon: Icons.schedule_rounded,
                  child: _InfoGrid([
                    ('Estado actual', _text(trip['status'])),
                    ('Creado', _date(trip['created_at'])),
                    ('Programado', _date(request['scheduled_for'])),
                    ('Completado', _date(trip['completed_at'])),
                    ('Cancelación', _text(trip['cancellation_reason'], _text(request['cancellation_reason']))),
                    ('ID viaje', _text(trip['id'])),
                  ]),
                ),
                _Section(
                  title: 'Historial del viaje',
                  icon: Icons.timeline_rounded,
                  child: history.isEmpty
                      ? const Text('Sin historial.', style: TextStyle(color: _detailMuted))
                      : Column(
                          children: history.map(
                            (h) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.circle, size: 10, color: _detailBlue),
                              title: Text(
                                _text(h['status']),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                _date(h['created_at']) +
                                    ' · ' +
                                    _text(h['changed_by_name'], 'Sistema'),
                              ),
                            ),
                          ).toList(),
                        ),
                ),
                _Section(
                  title: 'Calificaciones',
                  icon: Icons.star_rounded,
                  child: ratings.isEmpty
                      ? const Text(
                          'Este viaje todavía no tiene calificaciones.',
                          style: TextStyle(color: _detailMuted),
                        )
                      : Column(
                          children: ratings.map(
                            (r) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
                              title: Text(
                                '${_text(r['score'])} / 5',
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              subtitle: Text(
                                _text(r['comment'], 'Sin comentario') +
                                    ' · ' +
                                    _date(r['created_at']),
                              ),
                            ),
                          ).toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
