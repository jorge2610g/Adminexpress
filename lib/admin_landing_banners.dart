import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_client.dart';

/// Scoped advertising management for the passenger landing page.
/// Market's own store promotions remain separate.
class AdminLandingBannersPage extends StatefulWidget {
  final String channel;
  final String zoneId;
  const AdminLandingBannersPage({
    super.key,
    required this.channel,
    required this.zoneId,
  });

  @override
  State<AdminLandingBannersPage> createState() =>
      _AdminLandingBannersPageState();
}

class _AdminLandingBannersPageState extends State<AdminLandingBannersPage> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void didUpdateWidget(covariant AdminLandingBannersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel ||
        oldWidget.zoneId != widget.zoneId) {
      future = _load();
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final raw = await supabase.rpc(
      'admin_landing_banners_list_v1',
      params: {
        'p_zone_id': widget.zoneId,
        'p_channel': widget.channel,
      },
    );
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  void _refresh() => setState(() => future = _load());

  void _snack(Object value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(value.toString())));
  }

  Future<void> _edit([Map<String, dynamic>? banner]) async {
    final title = TextEditingController(text: banner?['title']?.toString() ?? '');
    final subtitle =
        TextEditingController(text: banner?['subtitle']?.toString() ?? '');
    final cta = TextEditingController(
      text: banner?['cta_label']?.toString() ?? 'Descubrir',
    );
    final imageUrl =
        TextEditingController(text: banner?['image_url']?.toString() ?? '');
    final targetUrl =
        TextEditingController(text: banner?['target_url']?.toString() ?? '');
    final order = TextEditingController(
      text: banner?['sort_order']?.toString() ?? '100',
    );
    final start = TextEditingController(
      text: banner?['starts_at']?.toString() ?? '',
    );
    final end = TextEditingController(
      text: banner?['ends_at']?.toString() ?? '',
    );
    String target = banner?['target_module']?.toString() ?? '';
    String color = banner?['style_key']?.toString() ?? 'blue';
    bool active = banner?['active'] != false;
    Uint8List? pickedBytes;
    String? pickedFilename;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(banner == null ? 'Nuevo anuncio' : 'Editar anuncio'),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: title,
                  decoration: const InputDecoration(labelText: 'Título *')),
                const SizedBox(height: 10),
                TextField(controller: subtitle, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descripción')),
                const SizedBox(height: 10),
                TextField(controller: cta,
                  decoration: const InputDecoration(labelText: 'Texto del botón')),
                const SizedBox(height: 12),
                if (pickedBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(pickedBytes!, height: 125,
                        width: double.infinity, fit: BoxFit.cover),
                  )
                else if (imageUrl.text.startsWith('https://'))
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(imageUrl.text, height: 125,
                        width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Text('Imagen no disponible')),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Subir imagen de banner'),
                  onPressed: () async {
                    final image = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1600,
                      imageQuality: 86,
                    );
                    if (image == null) return;
                    final bytes = await image.readAsBytes();
                    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
                      _snack('La imagen debe pesar menos de 5 MB.');
                      return;
                    }
                    update(() {
                      pickedBytes = bytes;
                      pickedFilename = image.name;
                    });
                  },
                ),
                TextField(controller: imageUrl,
                  decoration: const InputDecoration(
                    labelText: 'URL de imagen (alternativa a subirla)',
                    hintText: 'https://...',
                  )),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: ['','ride','delivery','market'].contains(target)
                      ? target : '',
                  decoration: const InputDecoration(
                    labelText: 'Servicio al pulsar el anuncio'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Ninguno')),
                    DropdownMenuItem(value: 'ride', child: Text('Viajes')),
                    DropdownMenuItem(value: 'delivery', child: Text('Envíos')),
                    DropdownMenuItem(value: 'market', child: Text('Market')),
                  ],
                  onChanged: (value) => update(() => target = value ?? ''),
                ),
                const SizedBox(height: 10),
                TextField(controller: targetUrl,
                  decoration: const InputDecoration(
                    labelText: 'Enlace HTTPS externo (opcional)')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: ['blue','orange','yellow','green','purple']
                      .contains(color) ? color : 'blue',
                  decoration: const InputDecoration(labelText: 'Color'),
                  items: const [
                    DropdownMenuItem(value: 'blue',child: Text('Azul')),
                    DropdownMenuItem(value: 'orange',child: Text('Naranja')),
                    DropdownMenuItem(value: 'yellow',child: Text('Amarillo')),
                    DropdownMenuItem(value: 'green',child: Text('Verde')),
                    DropdownMenuItem(value: 'purple',child: Text('Morado')),
                  ],
                  onChanged: (value) => update(() => color = value ?? 'blue'),
                ),
                const SizedBox(height: 10),
                TextField(controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Orden')),
                const SizedBox(height: 10),
                TextField(controller: start,
                  decoration: const InputDecoration(
                    labelText: 'Inicio (ISO 8601 opcional)',
                    hintText: '2026-10-14T18:00:00-03:00',
                  )),
                const SizedBox(height: 10),
                TextField(controller: end,
                  decoration: const InputDecoration(
                    labelText: 'Fin (ISO 8601 opcional)',
                    hintText: '2026-10-21T18:00:00-03:00',
                  )),
                SwitchListTile.adaptive(
                  title: const Text('Anuncio activo'),
                  subtitle: const Text(
                    'Visible solo en la zona y entorno seleccionados'),
                  value: active,
                  onChanged: (value) => update(() => active = value),
                ),
              ]),
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
        if (title.text.trim().isEmpty) {
          throw StateError('El título es obligatorio.');
        }
        final startsAt = start.text.trim().isEmpty
            ? null : DateTime.tryParse(start.text.trim());
        final endsAt = end.text.trim().isEmpty
            ? null : DateTime.tryParse(end.text.trim());
        if ((start.text.trim().isNotEmpty && startsAt == null) ||
            (end.text.trim().isNotEmpty && endsAt == null)) {
          throw StateError('Revisa las fechas. Usa el formato ISO 8601.');
        }
        String url = imageUrl.text.trim();
        if (pickedBytes != null) {
          final name = (pickedFilename ?? '').toLowerCase();
          final ext = name.endsWith('.png') ? 'png'
              : name.endsWith('.webp') ? 'webp' : 'jpg';
          final contentType = ext == 'png' ? 'image/png'
              : ext == 'webp' ? 'image/webp' : 'image/jpeg';
          final path = '${widget.channel}/${widget.zoneId}/'
              '${DateTime.now().microsecondsSinceEpoch}.$ext';
          await supabase.storage.from('express-landing-banners').uploadBinary(
            path, pickedBytes!,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );
          url = supabase.storage.from('express-landing-banners')
              .getPublicUrl(path);
        }
        if (url.isNotEmpty && !url.startsWith('https://')) {
          throw StateError('La imagen debe tener una URL HTTPS.');
        }
        if (targetUrl.text.trim().isNotEmpty &&
            !targetUrl.text.trim().startsWith('https://')) {
          throw StateError('El enlace debe comenzar por https://');
        }
        await supabase.rpc('admin_landing_banner_save_v1', params: {
          'p_id': banner?['id'],
          'p_zone_id': widget.zoneId,
          'p_channel': widget.channel,
          'p_title': title.text.trim(),
          'p_subtitle': subtitle.text.trim(),
          'p_cta_label': cta.text.trim(),
          'p_image_url': url.isEmpty ? null : url,
          'p_target_module': target.isEmpty ? null : target,
          'p_target_url': targetUrl.text.trim().isEmpty
              ? null : targetUrl.text.trim(),
          'p_style_key': color,
          'p_active': active,
          'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
          'p_starts_at': startsAt?.toUtc().toIso8601String(),
          'p_ends_at': endsAt?.toUtc().toIso8601String(),
        });
        _refresh();
        _snack('Anuncio guardado para ${widget.channel} en esta zona.');
      } catch (error) {
        _snack(error);
      }
    }

    title.dispose();
    subtitle.dispose();
    cta.dispose();
    imageUrl.dispose();
    targetUrl.dispose();
    order.dispose();
    start.dispose();
    end.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Publicidad · Pantalla de inicio',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo banner'),
              ),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ]),
          const SizedBox(height: 10),
          Text(
            'Campañas de ${widget.channel == 'preview' ? 'Prueba' : 'Producción'} '
            'para la zona seleccionada. No modifican los anuncios de Market.',
          ),
          const SizedBox(height: 14),
          if (snapshot.hasError)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(snapshot.error.toString(),
                style: const TextStyle(color: Colors.red)),
            ),
          if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          if (!snapshot.hasError && rows.isEmpty &&
              snapshot.connectionState != ConnectionState.waiting)
            const Padding(padding: EdgeInsets.all(20),
              child: Text('Todavía no hay banners en esta zona.')),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final row = rows[index];
                final image = row['image_url']?.toString() ?? '';
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: SizedBox(
                      width: 72, height: 65,
                      child: image.startsWith('https://')
                          ? Image.network(image, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.campaign_rounded))
                          : const Icon(Icons.campaign_rounded),
                    ),
                    title: Text(row['title']?.toString() ?? 'Anuncio',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${row['subtitle'] ?? ''} · '
                      '${row['active'] == true ? 'Activo' : 'Desactivado'}'
                      ' · posición ${row['sort_order'] ?? 100}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _edit(row),
                  ),
                );
              },
            ),
          ),
        ]);
      },
    ),
  );
}
