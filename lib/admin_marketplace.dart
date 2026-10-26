import 'dart:async';

import 'package:flutter/material.dart';

import 'core/admin_friendly_error.dart';
import 'core/admin_dropdown_field.dart';

import 'core/supabase_client.dart';
import 'admin_marketplace_demos.dart';
import 'admin_marketplace_requirements.dart';

const _blue = Color(0xFF2563EB);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _bg = Color(0xFFF1F5F9);

class AdminMarketplacePage extends StatefulWidget {
  final String channel;
  final String? countryCode;
  final String? zoneId;
  final bool showMerchants;

  const AdminMarketplacePage({
    super.key,
    this.channel = 'production',
    this.countryCode,
    this.zoneId,
    this.showMerchants = true,
  });

  @override
  State<AdminMarketplacePage> createState() => _AdminMarketplacePageState();
}

class _AdminMarketplacePageState extends State<AdminMarketplacePage> {
  late Future<Map<String, dynamic>> future;
  late Future<List<Map<String, dynamic>>> applicationsFuture;

  @override
  void initState() {
    super.initState();
    future = _load();
    applicationsFuture = _loadApplications();
  }

  Future<List<Map<String, dynamic>>> _loadApplications() async {
    final value = await supabase.rpc(
      'admin_marketplace_merchant_applications',
      params: {'p_channel': widget.channel, 'p_zone_id': widget.zoneId},
    );
    return _rows(value);
  }

  Future<Map<String, dynamic>> _load() async {
    final zoneId = widget.zoneId;
    final countryCode = widget.countryCode;
    if (zoneId == null ||
        zoneId.isEmpty ||
        countryCode == null ||
        countryCode.isEmpty) {
      return <String, dynamic>{
        'settings': <String, dynamic>{},
        'categories': <Map<String, dynamic>>[],
        'banners': <Map<String, dynamic>>[],
        'merchants': <Map<String, dynamic>>[],
      };
    }
    final value = await supabase.rpc(
      'admin_marketplace_state_scoped',
      params: {'p_country_code': countryCode, 'p_zone_id': zoneId},
    );
    final state =
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    // Marketplace configuration is shared across account environments. Keep
    // environment filtering only for operational records such as applications.
    return state;
  }

  List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  void _refresh() => setState(() {
        future = _load();
        applicationsFuture = _loadApplications();
      });

  Future<void> _reviewApplication(
    Map<String, dynamic> row, {
    required bool approve,
  }) async {
    if (approve && (widget.zoneId == null || widget.zoneId!.isEmpty)) {
      _snack('Selecciona una zona activa antes de aprobar el restaurante.');
      return;
    }
    if (approve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Aprobar restaurante'),
          content: Text(
            'Se creará “${row['restaurant_name'] ?? 'Restaurante'}” '
            'en ${widget.channel == 'preview' ? 'Preview' : 'Producción'} '
            'y la cuenta registrada quedará como propietaria.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Aprobar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await supabase.rpc(
          'admin_marketplace_approve_merchant_application',
          params: {'p_application_id': row['id'], 'p_zone_id': widget.zoneId},
        );
        _snack('Restaurante aprobado.');
        _refresh();
      } catch (error) {
        _snack('No se pudo aprobar la solicitud: $error');
      }
      return;
    }

    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await supabase.rpc(
          'admin_marketplace_reject_merchant_application',
          params: {
            'p_application_id': row['id'],
            'p_reason': reason.text.trim(),
          },
        );
        _snack('Solicitud rechazada.');
        _refresh();
      } catch (error) {
        _snack('No se pudo rechazar la solicitud: $error');
      }
    }
    reason.dispose();
  }

  Future<void> _showApplicationDocuments(Map<String, dynamic> row) async {
    final raw = row['requirements'];
    final documents = raw is List
        ? raw
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList()
        : <Map<String, dynamic>>[];
    final prepared = <Map<String, dynamic>>[];
    for (final document in documents) {
      final path = document['object_path']?.toString() ?? '';
      if (path.isEmpty) continue;
      try {
        final url = await supabase.storage
            .from('marketplace-merchant-requirements')
            .createSignedUrl(path, 600);
        prepared.add({...document, 'signed_url': url});
      } catch (_) {
        prepared.add({...document, 'signed_url': null});
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Documentos · ${row['restaurant_name'] ?? 'Restaurante'}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (prepared.isEmpty)
                  const Text('No se cargaron documentos adicionales.'),
                for (final document in prepared) ...[
                  Text(document['label']?.toString() ?? 'Documento',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (document['signed_url'] is String)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        document['signed_url'].toString(),
                        height: 260,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Text('No se pudo mostrar la imagen.'),
                      ),
                    )
                  else
                    const Text('No se pudo abrir este documento.'),
                  const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'))
        ],
      ),
    );
  }

  Widget _applicationInfo(
    IconData icon,
    String label,
    String value, {
    int maxLines = 2,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: _muted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _applicationCard(Map<String, dynamic> row) {
    final name = row['restaurant_name']?.toString().trim();
    final email = row['email']?.toString().trim() ?? '';
    final city = row['city']?.toString().trim() ?? '';
    final address = row['address']?.toString().trim() ?? '';
    final lat = double.tryParse(row['latitude']?.toString() ?? '');
    final lng = double.tryParse(row['longitude']?.toString() ?? '');
    final coordinates = lat == null || lng == null
        ? ''
        : '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    final logo = row['logo_url']?.toString() ?? '';
    final cover = row['cover_image_url']?.toString() ?? '';
    final requirements = row['requirements'] is List
        ? (row['requirements'] as List).length
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7ECF3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final infoWidth = constraints.maxWidth >= 760
              ? 230.0
              : constraints.maxWidth >= 500
              ? 210.0
              : constraints.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: logo.isEmpty
                        ? Container(
                            width: 50,
                            height: 50,
                            color: const Color(0xFFEAF2FF),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: _blue,
                              size: 24,
                            ),
                          )
                        : Image.network(
                            logo,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 50,
                              height: 50,
                              color: const Color(0xFFEAF2FF),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: _blue,
                                size: 24,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name?.isNotEmpty == true ? name! : 'Restaurante',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (cover.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        cover,
                        width: 78,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 78,
                          height: 50,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(
                            Icons.photo_outlined,
                            size: 20,
                            color: _muted,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Pendiente',
                      style: TextStyle(
                        color: Color(0xFFC76B16),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 18,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: infoWidth,
                    child: _applicationInfo(
                      Icons.location_city_outlined,
                      'Ciudad',
                      city.isEmpty ? 'Sin ciudad seleccionada' : city,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(
                    width: infoWidth,
                    child: _applicationInfo(
                      Icons.location_on_outlined,
                      'Dirección del local',
                      address.isEmpty ? 'Sin dirección' : address,
                      maxLines: 2,
                    ),
                  ),
                  if (coordinates.isNotEmpty)
                    SizedBox(
                      width: infoWidth,
                      child: _applicationInfo(
                        Icons.map_outlined,
                        'Ubicación en el mapa',
                        coordinates,
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (requirements > 0)
                    OutlinedButton.icon(
                      onPressed: () => _showApplicationDocuments(row),
                      icon: const Icon(Icons.description_outlined, size: 17),
                      label: Text('Documentos · $requirements'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _reviewApplication(row, approve: false),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: widget.zoneId == null
                        ? null
                        : () => _reviewApplication(row, approve: true),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('Aprobar restaurante'),
                  ),
                  if (widget.zoneId == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Selecciona primero la zona activa.',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _applicationsSection() => FutureBuilder<List<Map<String, dynamic>>>(
    future: applicationsFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.red),
            title: const Text('Solicitudes de restaurantes'),
            subtitle: const Text('No se pudieron cargar las solicitudes.'),
            trailing: IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        );
      }
      final rows = snapshot.data ?? const <Map<String, dynamic>>[];
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, color: _blue, size: 22),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Solicitudes de restaurantes',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${rows.length} pendientes',
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Actualizar solicitudes',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Revisa cada solicitud antes de aprobarla en ${widget.channel == 'preview' ? 'Preview' : 'Producción'}. '
                '${widget.zoneId == null ? 'Selecciona una zona activa para aprobar.' : 'Zona activa lista para revisar.'}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 14),
              if (rows.isEmpty &&
                  snapshot.connectionState == ConnectionState.done)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE7ECF3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.inbox_outlined, color: _muted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No hay solicitudes pendientes.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              for (final row in rows) _applicationCard(row),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _openSupport(Map<String, dynamic> merchant) async {
    try {
      final raw = await supabase.rpc(
        'admin_marketplace_support_open',
        params: {'p_merchant_id': merchant['id']},
      );
      if (raw is! Map || raw['session_id'] == null) {
        throw StateError('Admin no devolvió una sesión temporal.');
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdminMarketplaceSupportPage(
            sessionId: raw['session_id'].toString(),
            merchantName: raw['merchant_name']?.toString() ?? 'Restaurante',
            expiresAt: DateTime.tryParse(raw['expires_at']?.toString() ?? '') ??
                DateTime.now().add(const Duration(minutes: 20)),
          ),
        ),
      );
      _refresh();
    } catch (error) {
      _snack('No se pudo abrir el panel temporal: $error');
    }
  }

  Future<void> _openRestaurantRequirements() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AdminMarketplaceRequirementsPage(
        channel: widget.channel,
        countryCode: widget.countryCode,
        zoneId: widget.zoneId,
      ),
    ));
    _refresh();
  }

  void _snack(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message.toString())));
  }

  Future<void> _editSettings(Map<String, dynamic> settings) async {
    final sharedAvailability = settings['production_enabled'] == true;
    final module = TextEditingController(
      text: settings['module_name']?.toString() ?? 'Express Market',
    );
    final search = TextEditingController(
      text: settings['search_placeholder']?.toString() ??
          'Locales, productos y promociones',
    );
    final hero = TextEditingController(
      text: settings['hero_title']?.toString() ??
          'Todo lo que necesitas, en Express',
    );
    final subtitle = TextEditingController(
      text: settings['hero_subtitle']?.toString() ??
          'Comida, mercados, tiendas y más.',
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Configuración de Express Market'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'La disponibilidad de Market para cada zona se elige '
                      'desde Zonas de operación → Servicios para pasajeros. '
                      'Aquí solamente se personaliza el contenido de Market.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: module,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del módulo',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: 'Texto del buscador',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: hero,
                    decoration: const InputDecoration(
                      labelText: 'Título principal',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subtitle,
                    decoration: const InputDecoration(
                      labelText: 'Subtítulo principal',
                    ),
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

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_marketplace_update_settings',
          params: {
            'p_preview_enabled': sharedAvailability,
            'p_production_enabled': sharedAvailability,
            'p_module_name': module.text.trim(),
            'p_search_placeholder': search.text.trim(),
            'p_hero_title': hero.text.trim(),
            'p_hero_subtitle': subtitle.text.trim(),
          },
        );
        _refresh();
        _snack('Configuración actualizada.');
      } catch (e) {
        _snack(e);
      }
    }

    module.dispose();
    search.dispose();
    hero.dispose();
    subtitle.dispose();
  }

  Future<void> _editCategory(Map<String, dynamic>? row) async {
    final key = TextEditingController(
      text: row?['category_key']?.toString() ?? '',
    );
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final icon = TextEditingController(
      text: row?['icon_key']?.toString() ?? 'storefront',
    );
    final order = TextEditingController(
      text: row?['sort_order']?.toString() ?? '100',
    );
    bool active = row?['active'] != false;
    bool visible = row == null ? true : row['production_visible'] == true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Nueva categoría' : 'Editar categoría'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: key,
                    enabled: row == null,
                    decoration: const InputDecoration(
                      labelText: 'Clave',
                      hintText: 'ej. pharmacies',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: icon,
                    decoration: const InputDecoration(
                      labelText: 'Icono interno',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Orden'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setLocal(() => active = value),
                    title: const Text('Categoría activa'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: visible,
                    onChanged: (value) => setLocal(() => visible = value),
                    title: const Text('Disponible para los usuarios'),
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

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_marketplace_upsert_category',
          params: {
            'p_id': row?['id'],
            'p_category_key': key.text.trim(),
            'p_name': name.text.trim(),
            'p_icon_key': icon.text.trim(),
            'p_active': active,
            'p_preview_visible': visible,
            'p_production_visible': visible,
            'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
          },
        );
        _refresh();
        _snack('Categoría guardada.');
      } catch (e) {
        _snack(e);
      }
    }

    key.dispose();
    name.dispose();
    icon.dispose();
    order.dispose();
  }

  Future<void> _editBanner(Map<String, dynamic>? row) async {
    final title = TextEditingController(text: row?['title']?.toString() ?? '');
    final subtitle = TextEditingController(
      text: row?['subtitle']?.toString() ?? '',
    );
    final cta = TextEditingController(
      text: row?['cta_label']?.toString() ?? '',
    );
    final style = TextEditingController(
      text: row?['style_key']?.toString() ?? 'blue',
    );
    final order = TextEditingController(
      text: row?['sort_order']?.toString() ?? '100',
    );
    bool active = row?['active'] != false;
    bool visible = row == null ? true : row['production_visible'] == true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Nuevo banner' : 'Editar banner'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subtitle,
                    decoration: const InputDecoration(labelText: 'Subtítulo'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cta,
                    decoration: const InputDecoration(labelText: 'Botón / CTA'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: style,
                    decoration: const InputDecoration(
                      labelText: 'Estilo',
                      hintText: 'blue, yellow, green, purple',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Orden'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setLocal(() => active = value),
                    title: const Text('Banner activo'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: visible,
                    onChanged: (value) => setLocal(() => visible = value),
                    title: const Text('Disponible para los usuarios'),
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

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_marketplace_upsert_banner',
          params: {
            'p_id': row?['id'],
            'p_title': title.text.trim(),
            'p_subtitle': subtitle.text.trim(),
            'p_cta_label': cta.text.trim(),
            'p_style_key': style.text.trim(),
            'p_active': active,
            'p_preview_visible': visible,
            'p_production_visible': visible,
            'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
          },
        );
        _refresh();
        _snack('Banner guardado.');
      } catch (e) {
        _snack(e);
      }
    }

    title.dispose();
    subtitle.dispose();
    cta.dispose();
    style.dispose();
    order.dispose();
  }

  Future<List<Map<String, dynamic>>> _zones() async {
    final value = await supabase.rpc(
      'admin_zone_list_for_country',
      params: {'p_country_code': widget.countryCode},
    );
    return _rows(value)
        .where((row) => row['id']?.toString() == widget.zoneId)
        .toList();
  }

  Future<void> _editMerchant(
    Map<String, dynamic>? row,
    List<Map<String, dynamic>> categories,
  ) async {
    final zones = await _zones();
    if (!mounted) return;

    String? zoneId = row?['zone_id']?.toString() ?? widget.zoneId;
    String categoryKey = row?['category_key']?.toString() ??
        (categories.isEmpty
            ? ''
            : categories.first['category_key']?.toString() ?? '');
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final description = TextEditingController(
      text: row?['description']?.toString() ?? '',
    );
    final image = TextEditingController(
      text: row?['image_url']?.toString() ?? '',
    );
    final rating = TextEditingController(
      text: row?['rating']?.toString() ?? '5',
    );
    final etaMin = TextEditingController(
      text: row?['eta_min_minutes']?.toString() ?? '15',
    );
    final etaMax = TextEditingController(
      text: row?['eta_max_minutes']?.toString() ?? '40',
    );
    final fee = TextEditingController(
      text: row?['delivery_fee']?.toString() ?? '0',
    );
    final order = TextEditingController(
      text: row?['sort_order']?.toString() ?? '100',
    );
    bool active = row?['active'] != false;
    bool visible = row == null ? true : row['production_visible'] == true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Nuevo comercio' : 'Editar comercio'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  AdminDropdownField<String?>(
                    value: zoneId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Zona'),
                    items: [
                      ...zones.map(
                        (z) => DropdownMenuItem<String?>(
                          value: z['id']?.toString(),
                          child: Text(
                            (z['name'] ?? 'Zona').toString() +
                                ' · ' +
                                (z['city'] ?? '').toString(),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setLocal(() => zoneId = value),
                  ),
                  const SizedBox(height: 10),
                  AdminDropdownField<String>(
                    value: categoryKey.isEmpty ? null : categoryKey,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c['category_key']?.toString(),
                            child: Text(c['name']?.toString() ?? 'Categoría'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setLocal(() => categoryKey = value ?? ''),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: image,
                    decoration: const InputDecoration(
                      labelText: 'URL de imagen',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rating,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Rating',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: fee,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Costo envío',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: etaMin,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ETA mínimo',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: etaMax,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ETA máximo',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: order,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Orden'),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setLocal(() => active = value),
                    title: const Text('Comercio activo'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: visible,
                    onChanged: (value) => setLocal(() => visible = value),
                    title: const Text('Disponible para los usuarios'),
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

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_marketplace_upsert_merchant',
          params: {
            'p_id': row?['id'],
            'p_zone_id': zoneId,
            'p_category_key': categoryKey,
            'p_name': name.text.trim(),
            'p_description': description.text.trim(),
            'p_image_url': image.text.trim(),
            'p_active': active,
            'p_preview_visible': visible,
            'p_production_visible': visible,
            'p_rating': double.tryParse(rating.text.trim()) ?? 5,
            'p_eta_min_minutes': int.tryParse(etaMin.text.trim()) ?? 15,
            'p_eta_max_minutes': int.tryParse(etaMax.text.trim()) ?? 40,
            'p_delivery_fee': double.tryParse(fee.text.trim()) ?? 0,
            'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
          },
        );
        _refresh();
        _snack('Comercio guardado.');
      } catch (e) {
        _snack(e);
      }
    }

    name.dispose();
    description.dispose();
    image.dispose();
    rating.dispose();
    etaMin.dispose();
    etaMax.dispose();
    fee.dispose();
    order.dispose();
  }

  Future<void> _openProducts(Map<String, dynamic> merchant) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MerchantProductsPage(merchant: merchant),
      ),
    );
    _refresh();
  }

  Widget _tag(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F8EF) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFF14804A) : _muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required List<Widget> chips,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront_rounded, color: _blue),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 5, runSpacing: 5, children: chips),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }

  Widget _section(
    String title,
    String subtitle,
    String actionLabel,
    VoidCallback action,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: action,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _grid(children),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final settings = data['settings'] is Map
              ? Map<String, dynamic>.from(data['settings'] as Map)
              : <String, dynamic>{};
          final categories = _rows(data['categories']);
          final banners = _rows(data['banners']);
          final merchants = _rows(data['merchants']);

          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Express Market',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Una sola configuración compartida para todas las cuentas.',
                          style: TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualizar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _editSettings(settings),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Configuración'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _tag('Disponible', settings['production_enabled'] == true),
                  _tag(categories.length.toString() + ' categorías', true),
                  _tag(banners.length.toString() + ' banners', true),
                  _tag(merchants.length.toString() + ' comercios', true),
                ],
              ),
              const SizedBox(height: 24),
              if (widget.showMerchants) _applicationsSection(),
              if (widget.showMerchants) const SizedBox(height: 22),
              if (widget.showMerchants)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.fact_check_outlined)),
                    title: const Text('Requisitos de restaurantes', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Añade, edita o desactiva documentos por ciudad.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openRestaurantRequirements,
                  ),
                ),
              if (widget.showMerchants) const SizedBox(height: 22),
              _section(
                'Categorías',
                'Orden, icono y disponibilidad compartidos.',
                'Nueva categoría',
                () => _editCategory(null),
                categories
                    .map(
                      (row) => _card(
                        title: row['name']?.toString() ?? 'Categoría',
                        subtitle: row['category_key']?.toString() ?? '',
                        chips: [
                          _tag('Activa', row['active'] == true),
                          _tag('Disponible', row['production_visible'] == true),
                        ],
                        onTap: () => _editCategory(row),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 26),
              _section(
                'Banners y promociones',
                'Contenido promocional del Home.',
                'Nuevo banner',
                () => _editBanner(null),
                banners
                    .map(
                      (row) => _card(
                        title: row['title']?.toString() ?? 'Banner',
                        subtitle: row['subtitle']?.toString() ?? '',
                        chips: [
                          _tag('Activo', row['active'] == true),
                          _tag('Disponible', row['production_visible'] == true),
                        ],
                        onTap: () => _editBanner(row),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 26),
              if (widget.showMerchants &&
                  widget.channel == 'preview' &&
                  widget.zoneId != null &&
                  widget.zoneId!.isNotEmpty)
                AdminMarketplaceDemoSection(
                  key: ValueKey('${widget.channel}-${widget.zoneId}'),
                  zoneId: widget.zoneId!,
                  channel: widget.channel,
                  onOpenProducts: _openProducts,
                ),
              const SizedBox(height: 26),
              if (widget.showMerchants)
                _section(
                  'Comercios y productos',
                  'Locales, tiempos, costo de envío y catálogo.',
                  'Nuevo comercio',
                  () => _editMerchant(null, categories),
                  merchants
                      .map(
                        (row) => _card(
                          title: row['name']?.toString() ?? 'Comercio',
                          subtitle: (row['category_key'] ?? '').toString() +
                              ' · ' +
                              (row['eta_min_minutes'] ?? 15).toString() +
                              '-' +
                              (row['eta_max_minutes'] ?? 40).toString() +
                              ' min',
                          chips: [
                            _tag('Activo', row['active'] == true),
                            _tag('Disponible', row['production_visible'] == true),
                          ],
                          onTap: () => _openProducts(row),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editMerchant(row, categories);
                              } else if (value == 'support') {
                                _openSupport(row);
                              } else {
                                _openProducts(row);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar comercio'),
                              ),
                              PopupMenuItem(
                                value: 'products',
                                child: Text('Productos'),
                              ),
                              PopupMenuItem(
                                value: 'support',
                                child: Text('Abrir panel temporal'),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class AdminMarketplaceSupportPage extends StatefulWidget {
  const AdminMarketplaceSupportPage({
    super.key,
    required this.sessionId,
    required this.merchantName,
    required this.expiresAt,
  });

  final String sessionId;
  final String merchantName;
  final DateTime expiresAt;

  @override
  State<AdminMarketplaceSupportPage> createState() =>
      _AdminMarketplaceSupportPageState();
}

class _AdminMarketplaceSupportPageState
    extends State<AdminMarketplaceSupportPage> {
  late Future<Map<String, dynamic>> _future;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  Future<Map<String, dynamic>> _load() async {
    final value = await supabase.rpc(
      'admin_marketplace_support_state',
      params: {'p_session_id': widget.sessionId},
    );
    if (value is! Map)
      throw StateError('El panel temporal no está disponible.');
    return Map<String, dynamic>.from(value);
  }

  void _tick() {
    if (!mounted) return;
    final left = widget.expiresAt.difference(DateTime.now());
    setState(() => _remaining = left.isNegative ? Duration.zero : left);
  }

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    try {
      await supabase.rpc(
        'admin_marketplace_support_close',
        params: {'p_session_id': widget.sessionId},
      );
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_closed) {
      unawaited(
        supabase.rpc(
          'admin_marketplace_support_close',
          params: {'p_session_id': widget.sessionId},
        ).catchError((_) {}),
      );
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.merchantName),
          actions: [
            TextButton.icon(
              onPressed: _close,
              icon: const Icon(Icons.close),
              label: const Text('Cerrar sesión temporal'),
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || _remaining == Duration.zero) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'La sesión temporal terminó o no está disponible.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _close,
                      child: const Text('Volver a Admin'),
                    ),
                  ],
                ),
              );
            }
            final data = snapshot.data ?? const <String, dynamic>{};
            final merchant = data['merchant'] is Map
                ? Map<String, dynamic>.from(data['merchant'] as Map)
                : <String, dynamic>{};
            final products = _rows(data['products']);
            final categories = _rows(data['categories']);
            final orders = _rows(data['orders']);
            final minutes = _remaining.inMinutes;
            final seconds = _remaining.inSeconds % 60;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  color: const Color(0xFFEAF2FF),
                  child: ListTile(
                    leading: const Icon(Icons.support_agent, color: _blue),
                    title:
                        const Text('Vista temporal de soporte · solo lectura'),
                    subtitle: Text(
                      'Expira en $minutes:${seconds.toString().padLeft(2, '0')}. '
                      'No has iniciado sesión como el restaurante.',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  merchant['name']?.toString() ?? widget.merchantName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(merchant['address']?.toString() ??
                    'Dirección sin registrar'),
                const SizedBox(height: 18),
                Text(
                  'Categorías (${categories.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final category in categories)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.category_outlined),
                    title: Text(category['name']?.toString() ?? 'Categoría'),
                  ),
                Text(
                  'Productos (${products.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final product in products)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.fastfood_outlined),
                    title: Text(product['name']?.toString() ?? 'Producto'),
                    subtitle: Text(
                      product['active'] == true ? 'Disponible' : 'Oculto',
                    ),
                  ),
                Text(
                  'Pedidos recientes (${orders.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final order in orders)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(
                      'Pedido ${order['id']?.toString().substring(0, 8) ?? ''}',
                    ),
                    subtitle: Text(order['status']?.toString() ?? 'Sin estado'),
                  ),
              ],
            );
          },
        ),
      );
}

class _MerchantProductsPage extends StatefulWidget {
  final Map<String, dynamic> merchant;

  const _MerchantProductsPage({required this.merchant});

  @override
  State<_MerchantProductsPage> createState() => _MerchantProductsPageState();
}

class _MerchantProductsPageState extends State<_MerchantProductsPage> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final value = await supabase.rpc(
      'admin_marketplace_merchant_detail',
      params: {'p_merchant_id': widget.merchant['id']},
    );
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  void _refresh() => setState(() => future = _load());

  Future<void> _editProduct(Map<String, dynamic>? row) async {
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final description = TextEditingController(
      text: row?['description']?.toString() ?? '',
    );
    final price = TextEditingController(text: row?['price']?.toString() ?? '0');
    final currency = TextEditingController(
      text: row?['currency_code']?.toString() ?? 'CLP',
    );
    final image = TextEditingController(
      text: row?['image_url']?.toString() ?? '',
    );
    final order = TextEditingController(
      text: row?['sort_order']?.toString() ?? '100',
    );
    bool active = row?['active'] != false;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Nuevo producto' : 'Editar producto'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: price,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Precio',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: currency,
                          decoration: const InputDecoration(
                            labelText: 'Moneda',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: image,
                    decoration: const InputDecoration(
                      labelText: 'URL de imagen',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Orden'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setLocal(() => active = value),
                    title: const Text('Producto activo'),
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

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_marketplace_upsert_product',
          params: {
            'p_id': row?['id'],
            'p_merchant_id': widget.merchant['id'],
            'p_name': name.text.trim(),
            'p_description': description.text.trim(),
            'p_price': double.tryParse(price.text.trim()) ?? 0,
            'p_currency_code': currency.text.trim(),
            'p_image_url': image.text.trim(),
            'p_active': active,
            'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
          },
        );
        if (mounted) _refresh();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }

    name.dispose();
    description.dispose();
    price.dispose();
    currency.dispose();
    image.dispose();
    order.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(widget.merchant['name']?.toString() ?? 'Productos'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editProduct(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Producto'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(friendlyError(snapshot.error)));
          }
          final products = _rows(snapshot.data?['products']);
          if (products.isEmpty) {
            return const Center(
              child: Text('Todavía no hay productos en este comercio.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = products[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: row['active'] == true
                        ? const Color(0xFFE8F8EF)
                        : const Color(0xFFF2F4F7),
                    child: const Icon(Icons.inventory_2_outlined),
                  ),
                  title: Text(
                    row['name']?.toString() ?? 'Producto',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    (row['currency_code'] ?? '').toString() +
                        ' ' +
                        (row['price'] ?? 0).toString() +
                        ' · ' +
                        (row['active'] == true ? 'Activo' : 'Inactivo'),
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editProduct(row),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Public entry to an existing merchant's catalog editor from unified Delivery.
class AdminMerchantCatalogPage extends StatelessWidget {
  final Map<String, dynamic> merchant;
  const AdminMerchantCatalogPage({super.key, required this.merchant});

  @override
  Widget build(BuildContext context) =>
      _MerchantProductsPage(merchant: merchant);
}
