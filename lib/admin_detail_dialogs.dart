import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/supabase_client.dart';

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

Future<List<Map<String, dynamic>>> _zones() async {
  final raw = await supabase.rpc('admin_zone_list');
  return _maps(raw);
}

Future<bool> showAdminDriverEditor(
  BuildContext context,
  String userId,
) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DriverEditorDialog(userId: userId),
      ) ??
      false;
}

Future<bool> showAdminUserEditor(
  BuildContext context,
  String userId,
) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UserEditorDialog(userId: userId),
      ) ??
      false;
}

Future<void> showAdminTripDetail(
  BuildContext context,
  String tripId,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _TripDetailDialog(tripId: tripId),
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
  const _DriverEditorDialog({required this.userId});

  @override
  State<_DriverEditorDialog> createState() => _DriverEditorDialogState();
}

class _DriverEditorDialogState extends State<_DriverEditorDialog> {
  bool loading = true;
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> zones = const [];
  Map<String, dynamic> detail = const {};

  final fullName = TextEditingController();
  final phone = TextEditingController();
  final license = TextEditingController();
  final city = TextEditingController();
  final brand = TextEditingController();
  final model = TextEditingController();
  final color = TextEditingController();
  final plate = TextEditingController();
  final year = TextEditingController();

  String accountStatus = 'active';
  String approvalStatus = 'pending';
  String onlineStatus = 'offline';
  String vehicleType = 'motorcycle';
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
    city.dispose();
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
        'admin_driver_detail',
        params: {'p_user_id': widget.userId},
      );
      final loadedZones = await _zones();
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
      city.text = _text(driver['city'], '');
      brand.text = _text(vehicle['brand'], '');
      model.text = _text(vehicle['model'], '');
      color.text = _text(vehicle['color'], '');
      plate.text = _text(vehicle['plate'], '');
      year.text = _text(vehicle['year'], '');

      if (!mounted) return;
      setState(() {
        detail = loaded;
        zones = loadedZones;
        accountStatus = _text(user['account_status'], 'active');
        approvalStatus = _text(driver['approval_status'], 'pending');
        onlineStatus = _text(driver['online_status'], 'offline');
        vehicleType = _text(vehicle['vehicle_type'], 'motorcycle');
        zoneId = driver['zone_id']?.toString();
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
    if (zoneId == null || zoneId!.isEmpty) {
      setState(() => error = 'Selecciona una zona para el conductor.');
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
        'admin_update_driver_profile',
        params: {
          'p_user_id': widget.userId,
          'p_full_name': fullName.text.trim(),
          'p_phone': phone.text.trim(),
          'p_account_status': accountStatus,
          'p_license_number': license.text.trim(),
          'p_city': city.text.trim(),
          'p_zone_id': zoneId,
          'p_approval_status': approvalStatus,
          'p_online_status': onlineStatus,
          'p_vehicle_type': vehicleType,
          'p_vehicle_brand': brand.text.trim(),
          'p_vehicle_model': model.text.trim(),
          'p_vehicle_color': color.text.trim(),
          'p_vehicle_plate': plate.text.trim(),
          'p_vehicle_year': vehicleYear,
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
    if (value.isEmpty) return;
    try {
      final signed = await supabase.storage
          .from('driver-onboarding')
          .createSignedUrl(value, 3600);
      final ok = await launchUrl(
        Uri.parse(signed),
        mode: LaunchMode.platformDefault,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el archivo.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el archivo: $e')),
        );
      }
    }
  }

  Future<void> _editDocument([Map<String, dynamic>? document]) async {
    final type = TextEditingController(
      text: document?['document_type']?.toString() ?? '',
    );
    final number = TextEditingController(
      text: document?['document_number']?.toString() ?? '',
    );
    final url = TextEditingController(
      text: document?['document_url']?.toString() ?? '',
    );
    final expires = TextEditingController(
      text: document?['expires_at']?.toString().split('T').first ?? '',
    );
    final notes = TextEditingController(
      text: document?['notes']?.toString() ?? '',
    );
    var status = document?['status']?.toString() ?? 'pending';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: Text(document == null ? 'Agregar documento' : 'Editar documento'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de documento',
                      hintText: 'Licencia, CI, permiso...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: number,
                    decoration: const InputDecoration(
                      labelText: 'Número',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: url,
                    decoration: const InputDecoration(
                      labelText: 'URL / referencia del archivo',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                      DropdownMenuItem(value: 'verified', child: Text('Verificado')),
                      DropdownMenuItem(value: 'rejected', child: Text('Rechazado')),
                      DropdownMenuItem(value: 'expired', child: Text('Vencido')),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocal(() => status = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: expires,
                    decoration: const InputDecoration(
                      labelText: 'Vence (AAAA-MM-DD)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notas'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && type.text.trim().isNotEmpty) {
      DateTime? parsedExpiry;
      if (expires.text.trim().isNotEmpty) {
        parsedExpiry = DateTime.tryParse(expires.text.trim());
      }
      try {
        await supabase.rpc(
          'admin_upsert_driver_document',
          params: {
            'p_document_id': document?['id'],
            'p_driver_id': widget.userId,
            'p_document_type': type.text.trim(),
            'p_document_number': number.text.trim(),
            'p_document_url': url.text.trim(),
            'p_status': status,
            'p_expires_at': parsedExpiry?.toUtc().toIso8601String(),
            'p_notes': notes.text.trim(),
          },
        );
        await _load();
      } catch (e) {
        if (mounted) setState(() => error = e.toString());
      }
    }

    type.dispose();
    number.dispose();
    url.dispose();
    expires.dispose();
    notes.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _map(detail['user']);
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
                                        initialValue: zoneId,
                                        decoration: const InputDecoration(labelText: 'Zona'),
                                        items: zones
                                            .map(
                                              (z) => DropdownMenuItem<String>(
                                                value: z['id']?.toString(),
                                                child: Text(
                                                  _text(z['name']) + ' · ' + _text(z['currency_code']),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) => setState(() => zoneId = value),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: license,
                              decoration: const InputDecoration(labelText: 'Número de licencia'),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: city,
                              decoration: const InputDecoration(labelText: 'Ciudad'),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () => _editDocument(),
                                icon: const Icon(Icons.add_rounded, size: 17),
                                label: const Text('Agregar documento'),
                              ),
                            ),
                            if (documents.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  'No hay documentos administrativos cargados.',
                                  style: TextStyle(color: _detailMuted, fontSize: 11),
                                ),
                              )
                            else
                              ...documents.map(
                                (doc) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _detailSoft,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _detailBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.description_outlined,
                                            color: _detailBlue,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _text(doc['document_type']),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Chip(
                                            label: Text(_text(doc['status'])),
                                          ),
                                          IconButton(
                                            tooltip: 'Editar documento',
                                            onPressed: () => _editDocument(doc),
                                            icon: const Icon(Icons.edit_outlined),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'N° ' + _text(doc['document_number']) +
                                            ' · vence ' + _date(doc['expires_at']),
                                        style: const TextStyle(
                                          color: _detailMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Wrap(
                                        spacing: 7,
                                        runSpacing: 7,
                                        children: [
                                          if (_text(doc['front_object_path'], '').isNotEmpty)
                                            OutlinedButton.icon(
                                              onPressed: () => _openDriverAsset(
                                                doc['front_object_path']?.toString(),
                                              ),
                                              icon: const Icon(Icons.credit_card_rounded, size: 16),
                                              label: const Text('Ver frente'),
                                            ),
                                          if (_text(doc['back_object_path'], '').isNotEmpty)
                                            OutlinedButton.icon(
                                              onPressed: () => _openDriverAsset(
                                                doc['back_object_path']?.toString(),
                                              ),
                                              icon: const Icon(Icons.flip_to_back_rounded, size: 16),
                                              label: const Text('Ver reverso'),
                                            ),
                                          if (_text(doc['selfie_object_path'], '').isNotEmpty)
                                            OutlinedButton.icon(
                                              onPressed: () => _openDriverAsset(
                                                doc['selfie_object_path']?.toString(),
                                              ),
                                              icon: const Icon(Icons.face_rounded, size: 16),
                                              label: const Text('Ver selfie'),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const Divider(),
                            Text(
                              'Verificaciones de identidad: ${verifications.length}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            if (verifications.isNotEmpty)
                              ...verifications.take(5).map(
                                (v) => Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _text(v['document_type'], 'Identidad') +
                                        ' · ' + _text(v['status']) +
                                        ' · ' + _date(v['created_at']),
                                    style: const TextStyle(color: _detailMuted, fontSize: 10),
                                  ),
                                ),
                              ),
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
  const _UserEditorDialog({required this.userId});

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
        'admin_user_detail',
        params: {'p_user_id': widget.userId},
      );
      final loadedZones = await _zones();
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
        'admin_update_user_profile',
        params: {
          'p_user_id': widget.userId,
          'p_full_name': fullName.text.trim(),
          'p_phone': phone.text.trim(),
          'p_active_mode': activeMode,
          'p_account_status': accountStatus,
          'p_zone_id': zoneId,
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
  const _TripDetailDialog({required this.tripId});

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
      'admin_trip_detail',
      params: {'p_trip_id': widget.tripId},
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
