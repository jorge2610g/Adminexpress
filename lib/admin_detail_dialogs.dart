import 'package:flutter/material.dart';

import 'core/admin_design_tokens.dart';
import 'core/admin_widgets.dart';
import 'core/supabase_client.dart';
import 'admin_environment_store.dart';

const Color _detailBlue = AdminColors.blue;
const Color _detailDark = AdminColors.ink;
const Color _detailMuted = AdminColors.muted;
const Color _detailBorder = Color(0xFFE2E8F0);
const Color _detailSoft = AdminColors.surfaceSoft;

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

Future<List<Map<String, dynamic>>> _driverDocumentRequirements(
  String channel,
) async {
  if (channel == 'preview') {
    return const AdminEnvironmentStore('preview')
        .previewList('driver_document_requirements');
  }
  final raw = await supabase.rpc('admin_driver_document_requirement_list');
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
    final size = MediaQuery.sizeOf(context);
    final width = size.width < 920 ? size.width - 28 : 900.0;
    final height = size.height * .88;

    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: height,
        ),
        child: Material(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
                decoration: const BoxDecoration(
                  gradient: AdminGradients.hero,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .16),
                        ),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.25,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AdminColors.headerMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: child,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                decoration: const BoxDecoration(
                  color: AdminColors.surfaceSoft,
                  border: Border(
                    top: BorderSide(color: AdminColors.border),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        color: AdminColors.surfaceSoft,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminSectionHeading(
              title: title,
              icon: icon,
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
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
  bool loading = true;
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> zones = const [];
  List<Map<String, dynamic>> requirements = const [];
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
      final loadedRequirements =
          await _driverDocumentRequirements(widget.channel);
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
        requirements = loadedRequirements;
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

  Future<void> _previewDriverAsset(
    String? path, {
    String title = 'Vista previa',
  }) async {
    final value = path?.trim() ?? '';
    if (value.isEmpty) return;
    try {
      final signed = await supabase.storage
          .from('driver-onboarding')
          .createSignedUrl(value, 3600);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 720,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 620),
              child: InteractiveViewer(
                minScale: .8,
                maxScale: 4,
                child: Image.network(
                  signed,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 240,
                    child: Center(
                      child: Text('No se pudo visualizar esta fotografía.'),
                    ),
                  ),
                ),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la fotografía: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _applicableRequirements(
    Map<String, dynamic> driver,
  ) {
    final currentCountry =
        _text(driver['country_code'], '').trim().toUpperCase();
    final currentZone = _text(driver['zone_id'], '');
    final chosen = <String, ({int rank, Map<String, dynamic> row})>{};

    for (final row in requirements) {
      final rowCountry =
          _text(row['country_code'], '').trim().toUpperCase();
      final rowZone = _text(row['zone_id'], '');
      final matchesGlobal = rowCountry.isEmpty && rowZone.isEmpty;
      final matchesCountry =
          rowCountry == currentCountry && rowZone.isEmpty;
      final matchesZone =
          currentZone.isNotEmpty && rowZone == currentZone;
      if (!matchesGlobal && !matchesCountry && !matchesZone) continue;

      final rank = matchesZone ? 3 : matchesCountry ? 2 : 1;
      final code = _text(row['code'], _text(row['id'])).toLowerCase();
      final previous = chosen[code];
      if (previous == null || rank >= previous.rank) {
        chosen[code] = (rank: rank, row: row);
      }
    }

    final result = chosen.values
        .map((entry) => entry.row)
        .where((row) => row['active'] != false)
        .toList();
    result.sort((a, b) {
      final left = int.tryParse(_text(a['sort_order'], '100')) ?? 100;
      final right = int.tryParse(_text(b['sort_order'], '100')) ?? 100;
      if (left != right) return left.compareTo(right);
      return _text(a['label']).compareTo(_text(b['label']));
    });
    return result;
  }

  Map<String, dynamic>? _documentForRequirement(
    Map<String, dynamic> requirement,
    List<Map<String, dynamic>> documents,
  ) {
    final requirementId = _text(requirement['id'], '');
    if (requirementId.isNotEmpty) {
      for (final doc in documents) {
        if (_text(doc['requirement_id'], '') == requirementId) return doc;
      }
    }
    final code = _text(requirement['code'], '').toLowerCase();
    if (code.isNotEmpty) {
      for (final doc in documents) {
        if (_text(doc['document_type'], '').toLowerCase() == code) return doc;
      }
    }
    return null;
  }

  Map<String, dynamic> _photoPart(
    Map<String, dynamic> document,
    String slot,
  ) {
    final parts = _map(document['review_parts']);
    final saved = _map(parts[slot]);
    final directPath = switch (slot) {
      'front' => _text(document['front_object_path'], ''),
      'back' => _text(document['back_object_path'], ''),
      'selfie' => _text(document['selfie_object_path'], ''),
      _ => '',
    };
    final documentStatus =
        _text(document['status'], 'pending').toLowerCase();
    final fallbackStatus = documentStatus == 'verified'
        ? 'approved'
        : documentStatus == 'rejected'
            ? 'rejected'
            : 'pending';
    return <String, dynamic>{
      'path': _text(saved['path'], directPath),
      'status': _text(saved['status'], fallbackStatus).toLowerCase(),
      'version': int.tryParse(_text(saved['version'], '0')) ?? 0,
      'reason': _text(
        saved['reason'],
        documentStatus == 'rejected'
            ? _text(document['rejection_reason'], '')
            : '',
      ),
    };
  }

  String _photoLabel(String slot) => switch (slot) {
    'front' => 'Frente',
    'back' => 'Reverso',
    'selfie' => 'Foto facial',
    _ => 'Fotografía',
  };

  Future<String?> _rejectionReason(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Rechazar $title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo del rechazo',
            hintText: 'Indica claramente qué debe corregir el conductor.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.length < 5) return;
              Navigator.pop(dialogContext, reason);
            },
            child: const Text('Confirmar rechazo'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  bool _isIdentityRequirement(Map<String, dynamic> requirement) {
    final code = _text(requirement['code'], '').toLowerCase();
    const identityCodes = <String>{
      'identity_card',
      'national_id',
      'id_card',
      'identity',
      'carnet',
      'cedula',
      'cédula',
    };
    return identityCodes.contains(code);
  }

  Future<void> _reviewPhoto(
    Map<String, dynamic> document,
    Map<String, dynamic> requirement,
    String slot,
    String nextStatus,
    int expectedVersion, {
    String? reason,
  }) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await supabase.rpc(
        _isIdentityRequirement(requirement)
            ? 'admin_driver_kyc_bolivia_manual_review_part'
            : 'admin_driver_document_review_part_v2',
        params: {
          'p_document_id': document['id'],
          'p_slot': slot,
          'p_status': nextStatus,
          'p_reason': reason,
          'p_expected_version': expectedVersion,
          'p_channel': widget.channel,
        },
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_text(requirement['label'], 'Documento')} · '
              '${_photoLabel(slot)}: '
              '${nextStatus == 'approved' ? 'aprobada' : 'rechazada'}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = 'No se pudo actualizar la fotografía. $e');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _openPhotoReview(
    Map<String, dynamic> document,
    Map<String, dynamic> requirement,
    String slot,
  ) async {
    final part = _photoPart(document, slot);
    final path = _text(part['path'], '');
    if (path.isEmpty) return;
    final signed = await supabase.storage
        .from('driver-onboarding')
        .createSignedUrl(path, 3600);
    if (!mounted) return;

    final label = _photoLabel(slot);
    final status = _text(part['status'], 'pending');
    final version = part['version'] is int
        ? part['version'] as int
        : int.tryParse(_text(part['version'], '0')) ?? 0;
    final reason = _text(part['reason'], '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_text(requirement['label'], 'Documento')} · $label'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 520),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _detailSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _detailBorder),
                  ),
                  child: InteractiveViewer(
                    minScale: .8,
                    maxScale: 4,
                    child: Image.network(
                      signed,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 240,
                        child: Center(
                          child: Text('No se pudo visualizar esta fotografía.'),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      status == 'approved'
                          ? Icons.check_circle_rounded
                          : status == 'rejected'
                              ? Icons.cancel_rounded
                              : Icons.hourglass_top_rounded,
                      color: status == 'approved'
                          ? AdminColors.ok
                          : status == 'rejected'
                              ? AdminColors.danger
                              : AdminColors.warn,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status == 'approved'
                          ? 'Aprobada'
                          : status == 'rejected'
                              ? 'Rechazada'
                              : 'Pendiente',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Motivo: $reason'),
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
          OutlinedButton.icon(
            onPressed: saving
                ? null
                : () async {
                    final rejection = await _rejectionReason(
                      '${_text(requirement['label'], 'documento')} · $label',
                    );
                    if (rejection == null || !dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    await _reviewPhoto(
                      document,
                      requirement,
                      slot,
                      'rejected',
                      version,
                      reason: rejection,
                    );
                  },
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Rechazar'),
          ),
          FilledButton.icon(
            onPressed: saving || status == 'approved'
                ? null
                : () async {
                    Navigator.pop(dialogContext);
                    await _reviewPhoto(
                      document,
                      requirement,
                      slot,
                      'approved',
                      version,
                    );
                  },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Aprobar'),
          ),
        ],
      ),
    );
  }

  Widget _requirementCard(
    Map<String, dynamic> requirement,
    Map<String, dynamic>? document,
  ) {
    final overallStatus = document == null
        ? 'pending'
        : _text(document['status'], 'pending').toLowerCase();
    final label = _text(requirement['label'], 'Documento');
    final number = document == null
        ? ''
        : _text(document['document_number'], '');
    final slots = <(String, String, IconData)>[
      if (requirement['require_front'] == true)
        ('front', 'Ver frente', Icons.credit_card_rounded),
      if (requirement['require_back'] == true)
        ('back', 'Ver reverso', Icons.flip_to_back_rounded),
      if (requirement['require_selfie'] == true)
        ('selfie', 'Ver foto facial', Icons.face_rounded),
    ];

    Widget photoButton((String, String, IconData) slot) {
      final part = document == null
          ? <String, dynamic>{'status': 'pending', 'path': ''}
          : _photoPart(document, slot.$1);
      final status = _text(part['status'], 'pending');
      final path = _text(part['path'], '');
      final statusColor = status == 'approved'
          ? AdminColors.ok
          : status == 'rejected'
              ? AdminColors.danger
              : _detailMuted;
      return OutlinedButton.icon(
        onPressed: document == null || path.isEmpty
            ? null
            : () => _openPhotoReview(document, requirement, slot.$1),
        icon: Icon(
          status == 'approved'
              ? Icons.check_circle_rounded
              : status == 'rejected'
                  ? Icons.cancel_rounded
                  : slot.$3,
          size: 16,
          color: statusColor,
        ),
        label: Text(slot.$2),
      );
    }

    return SizedBox(
      width: 430,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdminColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                AdminStatusChip(
                  _friendlyDocumentStatus(overallStatus),
                  tone: overallStatus == 'verified' || overallStatus == 'approved'
                      ? AdminStatusTone.success
                      : overallStatus == 'rejected'
                          ? AdminStatusTone.danger
                          : AdminStatusTone.warning,
                ),
              ],
            ),
            if (number.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Número: $number',
                style: const TextStyle(color: _detailMuted, fontSize: 11),
              ),
            ],
            const SizedBox(height: 10),
            if (document == null)
              const Text(
                'El conductor todavía no cargó este requisito.',
                style: TextStyle(color: _detailMuted, fontSize: 11),
              )
            else if (slots.isEmpty)
              const Text(
                'Este requisito no exige fotografías.',
                style: TextStyle(color: _detailMuted, fontSize: 11),
              )
            else
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: slots.map(photoButton).toList(),
              ),
            const Spacer(),
            if (document != null && slots.isEmpty)
              Wrap(
                spacing: 8,
                children: [
                  if (overallStatus != 'verified')
                    FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () => _reviewDocument(document, 'verified'),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Aprobar requisito'),
                    ),
                  if (overallStatus != 'rejected')
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () => _reviewDocument(document, 'rejected'),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Rechazar'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
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
                                    onPressed: () => _previewDriverAsset(
                                      profilePhotoPath,
                                    ),
                                    icon: const Icon(Icons.account_circle_outlined),
                                    label: const Text('Ver foto de perfil'),
                                  ),
                                for (var i = 0; i < vehiclePhotos.length; i++)
                                  OutlinedButton.icon(
                                    onPressed: () => _previewDriverAsset(vehiclePhotos[i]),
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
                        child: Builder(
                          builder: (context) {
                            final scopedRequirements =
                                _applicableRequirements(driver);
                            if (scopedRequirements.isEmpty) {
                              return const Text(
                                'No hay requisitos activos configurados para este conductor.',
                                style: TextStyle(
                                  color: _detailMuted,
                                  fontSize: 11,
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cada tarjeta corresponde a un requisito activo de su país o zona. '
                                  'Abre cada fotografía para aprobarla o rechazarla sin salir del panel.',
                                  style: TextStyle(
                                    color: _detailMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 272,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: scopedRequirements.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      final requirement =
                                          scopedRequirements[index];
                                      final document = _documentForRequirement(
                                        requirement,
                                        documents,
                                      );
                                      return _requirementCard(
                                        requirement,
                                        document,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
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
