import 'package:flutter/material.dart';

import 'core/admin_friendly_error.dart';
import 'core/admin_dropdown_field.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_client.dart';
import 'banner_calendar_field.dart';
import 'banner_form_validation.dart';
import 'banner_slides_editor.dart';

/// Scoped advertising management for passenger and driver app surfaces.
/// Market's own store promotions remain separate.
const List<(String, String)> _adPlacementOptions = [
  ('home_landing', 'Lanzador del pasajero · Inicio superior'),
  ('taxi_home_top', 'Taxi · Inicio superior'),
  ('map_home', 'Taxi · Inicio inferior del pasajero'),
  ('passenger_landing_bottom', 'Lanzador del pasajero · Inicio inferior'),
  ('ride_chooser', 'Taxi · Selector de viaje'),
  ('taxi_search', 'Taxi · Buscando conductor'),
  ('taxi_complete', 'Taxi · Viaje completado'),
  ('popup', 'Pantalla completa · Al abrir'),
  ('delivery_home', 'Delivery · Inicio'),
  ('services_home', 'Servicios · Inicio'),
  ('driver_home_top', 'Conductor · Inicio superior'),
  ('driver_home_bottom', 'Conductor · Inicio inferior'),
];

String _placementLabels(Object? raw) {
  final keys = (raw as List?)?.map((item) => item.toString()).toList() ??
      const ['home_landing'];
  final labels = [
    for (final option in _adPlacementOptions)
      if (keys.contains(option.$1)) option.$2,
  ];
  return labels.isEmpty ? 'Sin lugar' : labels.join(', ');
}

enum _BannerAction { edit, statistics, delete }

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
  String placementFilter = 'all';
  String statusFilter = 'all';
  bool savingAction = false;

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
      'admin_landing_banners_list_v2',
      params: {'p_zone_id': widget.zoneId, 'p_channel': widget.channel},
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

  Future<void> _setActive(Map<String, dynamic> row, bool value) async {
    if (savingAction) return;
    setState(() => savingAction = true);
    try {
      await supabase.rpc(
        'admin_landing_banner_save_v3',
        params: {
          'p_id': row['id'],
          'p_zone_id': widget.zoneId,
          'p_channel': widget.channel,
          'p_title': row['title']?.toString() ?? '',
          'p_subtitle': row['subtitle']?.toString() ?? '',
          'p_cta_label': row['cta_label']?.toString() ?? 'Descubrir',
          'p_image_url': row['image_url'],
          'p_target_module': row['target_module'],
          'p_target_url': row['target_url'],
          'p_style_key': row['style_key']?.toString() ?? 'blue',
          'p_active': value,
          'p_sort_order': row['sort_order'] ?? 100,
          'p_starts_at': row['starts_at'],
          'p_ends_at': row['ends_at'],
          'p_media_type': row['media_type']?.toString() ?? 'image',
          'p_media_url': row['media_url'],
          'p_display_seconds': row['display_seconds'] ?? 5,
          'p_advertiser_name': row['advertiser_name']?.toString() ?? '',
          'p_advertiser_contact': row['advertiser_contact']?.toString() ?? '',
          'p_amount_bs': row['amount_bs'],
          'p_payment_status': row['payment_status']?.toString() ?? 'unpaid',
          'p_placements': row['placements'] ?? ['home_landing'],
        },
      );
      _refresh();
    } catch (error) {
      _snack(error);
    } finally {
      if (mounted) setState(() => savingAction = false);
    }
  }

  void _showStatistics(Map<String, dynamic> row) {
    final impressions = row['impressions'] ?? 0;
    final clicks = row['clicks'] ?? 0;
    final ctr = row['ctr'] ?? 0;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Estadísticas · ${row['title'] ?? 'Banner'}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BannerMetricLine(
                icon: Icons.visibility_outlined,
                label: 'Impresiones',
                value: '$impressions',
              ),
              _BannerMetricLine(
                icon: Icons.ads_click_rounded,
                label: 'Clics',
                value: '$clicks',
              ),
              _BannerMetricLine(
                icon: Icons.trending_up_rounded,
                label: 'CTR',
                value: '$ctr%',
              ),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Posición: ${_placementLabels(row['placements'])}'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar banner'),
        content: Text(
          '¿Eliminar “${row['title'] ?? 'Banner'}” y sus estadísticas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await supabase.rpc(
        'admin_landing_banner_delete_v1',
        params: {
          'p_id': row['id'],
          'p_zone_id': widget.zoneId,
          'p_channel': widget.channel,
        },
      );
      _refresh();
      _snack('Banner eliminado.');
    } catch (error) {
      _snack(error);
    }
  }

  Future<void> _edit([Map<String, dynamic>? banner]) async {
    final title = TextEditingController(
      text: banner?['title']?.toString() ?? '',
    );
    final subtitle = TextEditingController(
      text: banner?['subtitle']?.toString() ?? '',
    );
    final cta = TextEditingController(
      text: banner?['cta_label']?.toString() ?? 'Descubrir',
    );
    final slides = <BannerSlideDraft>[
      for (final raw in (banner?['slides'] as List?) ?? const [])
        if (raw is Map)
          BannerSlideDraft(
              imageUrl: raw['image_url']?.toString() ?? '',
              mediaType:
                  raw['media_type']?.toString() == 'video' ? 'video' : 'image',
              videoUrl: raw['video_url']?.toString() ?? '',
              targetUrl: raw['target_url']?.toString() ?? ''),
    ];
    if (slides.isEmpty &&
        banner?['media_type']?.toString() == 'video' &&
        (banner?['media_url'] ?? '').toString().startsWith('https://')) {
      slides.add(BannerSlideDraft(
          mediaType: 'video',
          videoUrl: banner!['media_url'].toString(),
          targetUrl: banner['target_url']?.toString() ?? ''));
    }
    if (slides.isEmpty &&
        (banner?['image_url'] ?? '').toString().startsWith('https://')) {
      slides.add(BannerSlideDraft(
          imageUrl: banner!['image_url'].toString(),
          targetUrl: banner['target_url']?.toString() ?? ''));
    }
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
    final seconds = TextEditingController(
      text: banner?['display_seconds']?.toString() ?? '5',
    );
    final advertiser = TextEditingController(
      text: banner?['advertiser_name']?.toString() ?? '',
    );
    final advertiserContact = TextEditingController(
      text: banner?['advertiser_contact']?.toString() ?? '',
    );
    final amount = TextEditingController(
      text: banner?['amount_bs']?.toString() ?? '',
    );
    String paymentStatus = banner?['payment_status']?.toString() ?? 'unpaid';
    final placements = <String>{
      ...((banner?['placements'] as List?)?.map((item) => item.toString()) ??
          const ['home_landing']),
    };
    String placement = placements.isEmpty ? 'home_landing' : placements.first;

    bool saving = false;
    String? formError;
    Future<void> saveBanner() async {
      final error = validateBannerDraft(
          title: title.text,
          link: slides.isEmpty ? '' : slides.first.targetUrl,
          hasImage: slides.isNotEmpty &&
              slides.every((s) =>
                  s.bytes != null ||
                  (s.mediaType == 'video'
                      ? s.videoUrl.startsWith('https://')
                      : s.imageUrl.startsWith('https://'))),
          seconds: int.tryParse(seconds.text) ?? 0,
          start: DateTime.tryParse(start.text),
          end: DateTime.tryParse(end.text));
      if (error != null) throw StateError(error);

      for (var i = 0; i < slides.length; i++) {
        final link = Uri.tryParse(slides[i].targetUrl.trim());
        if (link == null || link.scheme != 'https' || link.host.isEmpty) {
          throw StateError(
              'La imagen ${i + 1} necesita su URL HTTPS de destino.');
        }
      }
      final startsAt = start.text.trim().isEmpty
          ? null
          : DateTime.tryParse(start.text.trim());
      final endsAt =
          end.text.trim().isEmpty ? null : DateTime.tryParse(end.text.trim());
      if ((start.text.trim().isNotEmpty && startsAt == null) ||
          (end.text.trim().isNotEmpty && endsAt == null)) {
        throw StateError('Revisa las fechas. Usa el formato ISO 8601.');
      }
      // Se valida antes de subir archivos para no dejar imágenes huérfanas.
      if (placements.isEmpty) {
        throw StateError(
          'Elige al menos un lugar donde aparecerá el anuncio',
        );
      }
      for (var i = 0; i < slides.length; i++) {
        final slide = slides[i];
        if (slide.bytes == null) continue;
        final name = slide.filename.toLowerCase();
        final isVideo = slide.mediaType == 'video';
        final ext = isVideo
            ? (name.endsWith('.webm') ? 'webm' : 'mp4')
            : name.endsWith('.png')
                ? 'png'
                : name.endsWith('.webp')
                    ? 'webp'
                    : 'jpg';
        final type = isVideo
            ? (ext == 'webm' ? 'video/webm' : 'video/mp4')
            : ext == 'png'
                ? 'image/png'
                : ext == 'webp'
                    ? 'image/webp'
                    : 'image/jpeg';
        final path =
            '${widget.channel}/${widget.zoneId}/${DateTime.now().microsecondsSinceEpoch}-$i.$ext';
        await supabase.storage.from('express-landing-banners').uploadBinary(
            path, slide.bytes!,
            fileOptions: FileOptions(contentType: type, upsert: false));
        final url =
            supabase.storage.from('express-landing-banners').getPublicUrl(path);
        if (isVideo) {
          slide.videoUrl = url;
        } else {
          slide.imageUrl = url;
        }
        slide.bytes = null;
      }
      final secs = int.tryParse(seconds.text.trim()) ?? 0;
      if (secs < 3 || secs > 60) {
        throw StateError('Los segundos deben estar entre 3 y 60.');
      }
      final amountText = amount.text.trim().replaceAll(',', '.');
      final amountValue =
          amountText.isEmpty ? null : double.tryParse(amountText);
      if (amountText.isNotEmpty && (amountValue == null || amountValue < 0)) {
        throw StateError('El monto debe ser un número mayor o igual a 0.');
      }
      await supabase.rpc(
        'admin_landing_banner_save_v4',
        params: {
          'p_id': banner?['id'],
          'p_zone_id': widget.zoneId,
          'p_channel': widget.channel,
          'p_title': title.text.trim(),
          'p_subtitle': subtitle.text.trim(),
          'p_cta_label': cta.text.trim(),
          'p_image_url': slides.first.mediaType == 'video'
              ? slides.first.videoUrl
              : slides.first.imageUrl,
          'p_target_module': target.isEmpty ? null : target,
          'p_target_url': slides.first.targetUrl.trim(),
          'p_style_key': color,
          'p_active': active,
          'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
          'p_starts_at': startsAt?.toUtc().toIso8601String(),
          'p_ends_at': endsAt?.toUtc().toIso8601String(),
          'p_media_type': slides.first.mediaType,
          'p_media_url':
              slides.first.mediaType == 'video' ? slides.first.videoUrl : null,
          'p_display_seconds': secs,
          'p_advertiser_name': advertiser.text.trim(),
          'p_advertiser_contact': advertiserContact.text.trim(),
          'p_amount_bs': amountValue,
          'p_payment_status': paymentStatus,
          'p_placements': placements.toList(),
          'p_slides': [
            for (final slide in slides)
              {
                'media_type': slide.mediaType,
                if (slide.mediaType == 'video')
                  'video_url': slide.videoUrl
                else
                  'image_url': slide.imageUrl,
                'target_url': slide.targetUrl.trim()
              }
          ],
        },
      );
      _refresh();
      _snack('Anuncio guardado para ${widget.channel} en esta zona.');
    }

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 780,
            maxHeight: MediaQuery.sizeOf(dialogContext).height - 48,
          ),
          child: StatefulBuilder(
            builder: (context, update) => PopScope(
              canPop: !saving,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                banner == null
                                    ? 'Crear Banner'
                                    : 'Editar Banner',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Configura dónde aparece, su imagen y el enlace.',
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(dialogContext, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  if (formError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      child: Text(formError!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: title,
                            decoration: const InputDecoration(
                              labelText: 'Título interno *',
                              helperText:
                                  'Solo identifica el banner en el panel. No aparece en la app.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: subtitle,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Descripción interna',
                              helperText:
                                  'Nota para tu equipo. No aparece en la app.',
                            ),
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = (constraints.maxWidth - 14) / 2;
                              return Wrap(
                                spacing: 14,
                                runSpacing: 8,
                                children: [
                                  SizedBox(
                                    width: width,
                                    child: AdminDropdownField<String>(
                                      initialValue: placement,
                                      decoration: const InputDecoration(
                                        labelText: 'Posición *',
                                      ),
                                      items: [
                                        for (final option
                                            in _adPlacementOptions)
                                          DropdownMenuItem(
                                            value: option.$1,
                                            child: Text(option.$2),
                                          ),
                                      ],
                                      onChanged: (value) => update(() {
                                        placement = value ?? 'home_landing';
                                        placements
                                          ..clear()
                                          ..add(placement);
                                      }),
                                    ),
                                  ),
                                  SizedBox(
                                    width: width,
                                    child: TextField(
                                      controller: order,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Prioridad',
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Las imágenes y videos del carrusel rotan según el tiempo configurado.',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          BannerSlidesEditor(
                              slides: slides,
                              enabled: !saving,
                              onChanged: () => update(() {}),
                              onError: (error) =>
                                  update(() => formError = error)),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = (constraints.maxWidth - 14) / 2;
                              return Wrap(
                                spacing: 14,
                                runSpacing: 8,
                                children: [
                                  SizedBox(
                                    width: width,
                                    child: TextField(
                                      controller: seconds,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Duración en pantalla (3–60 s)',
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(builder: (context, constraints) {
                            final width = constraints.maxWidth < 480
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 14) / 2;
                            return Wrap(spacing: 14, runSpacing: 12, children: [
                              SizedBox(
                                  width: width,
                                  child: BannerCalendarField(
                                    label: 'Fecha de inicio (opcional)',
                                    value: DateTime.tryParse(start.text),
                                    onChanged: (date) => update(() => start
                                        .text = date?.toIso8601String() ?? ''),
                                  )),
                              SizedBox(
                                  width: width,
                                  child: BannerCalendarField(
                                    label: 'Fecha de fin (opcional)',
                                    value: DateTime.tryParse(end.text),
                                    onChanged: (date) => update(() => end
                                        .text = date ==
                                            null
                                        ? ''
                                        : date
                                            .add(const Duration(days: 1))
                                            .subtract(
                                                const Duration(milliseconds: 1))
                                            .toIso8601String()),
                                  )),
                            ]);
                          }),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Banner activo'),
                            value: active,
                            onChanged: (value) => update(() => active = value),
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Datos internos de campaña'),
                            subtitle: const Text(
                              'No se muestran al pasajero ni al conductor',
                            ),
                            children: [
                              TextField(
                                controller: advertiser,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre del anunciante',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: advertiserContact,
                                decoration: const InputDecoration(
                                  labelText: 'Contacto del anunciante',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: amount,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Monto acordado (Bs)',
                                ),
                              ),
                              const SizedBox(height: 10),
                              AdminDropdownField<String>(
                                initialValue: [
                                  'unpaid',
                                  'paid',
                                  'exempt',
                                ].contains(paymentStatus)
                                    ? paymentStatus
                                    : 'unpaid',
                                decoration: const InputDecoration(
                                  labelText: 'Estado de pago',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'unpaid',
                                    child: Text('Sin pagar'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'paid',
                                    child: Text('Pagado'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'exempt',
                                    child: Text('Cortesía'),
                                  ),
                                ],
                                onChanged: (value) => update(
                                  () => paymentStatus = value ?? 'unpaid',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 18, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  update(() {
                                    saving = true;
                                    formError = null;
                                  });
                                  try {
                                    await saveBanner();
                                    if (dialogContext.mounted)
                                      Navigator.pop(dialogContext, true);
                                  } catch (error) {
                                    if (dialogContext.mounted)
                                      update(() {
                                        saving = false;
                                        formError = error is StateError
                                            ? error.message.toString()
                                            : friendlyError(error);
                                      });
                                  }
                                },
                          child: Text(
                            saving
                                ? 'Guardando…'
                                : banner == null
                                    ? 'Crear Banner'
                                    : 'Guardar cambios',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    title.dispose();
    subtitle.dispose();
    cta.dispose();
    order.dispose();
    start.dispose();
    end.dispose();
    seconds.dispose();
    advertiser.dispose();
    advertiserContact.dispose();
    amount.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            final visibleRows = rows.where((row) {
              final places = (row['placements'] as List?)
                      ?.map((value) => value.toString())
                      .toSet() ??
                  <String>{};
              final matchesPlacement =
                  placementFilter == 'all' || places.contains(placementFilter);
              final matchesStatus = statusFilter == 'all' ||
                  (statusFilter == 'active'
                      ? row['active'] == true
                      : row['active'] != true);
              return matchesPlacement && matchesStatus;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Banners Publicitarios',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text('Gestiona los banners de publicidad en la app'),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear Banner'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _refresh,
                      tooltip: 'Actualizar',
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: 270,
                          child: AdminDropdownField<String>(
                            initialValue: placementFilter,
                            decoration: const InputDecoration(
                              labelText: 'Posición',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('Todas'),
                              ),
                              for (final option in _adPlacementOptions)
                                DropdownMenuItem(
                                  value: option.$1,
                                  child: Text(option.$2),
                                ),
                            ],
                            onChanged: (value) => setState(
                                () => placementFilter = value ?? 'all'),
                          ),
                        ),
                        SizedBox(
                          width: 190,
                          child: AdminDropdownField<String>(
                            initialValue: statusFilter,
                            decoration:
                                const InputDecoration(labelText: 'Estado'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'all', child: Text('Todos')),
                              DropdownMenuItem(
                                value: 'active',
                                child: Text('Activos'),
                              ),
                              DropdownMenuItem(
                                value: 'inactive',
                                child: Text('Inactivos'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => statusFilter = value ?? 'all'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(18, 15, 18, 4),
                          child: Text(
                            'Lista de Banners',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (snapshot.hasError)
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              friendlyError(snapshot.error),
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const LinearProgressIndicator(),
                        Expanded(
                          child: visibleRows.isEmpty
                              ? Center(
                                  child: Text(
                                    snapshot.connectionState ==
                                            ConnectionState.waiting
                                        ? 'Cargando banners…'
                                        : 'No hay banners para estos filtros.',
                                  ),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      columnSpacing: 22,
                                      headingRowHeight: 48,
                                      dataRowMinHeight: 72,
                                      dataRowMaxHeight: 84,
                                      columns: const [
                                        DataColumn(label: Text('Vista previa')),
                                        DataColumn(label: Text('Título')),
                                        DataColumn(label: Text('Posición')),
                                        DataColumn(
                                          label: Text('Prioridad'),
                                          numeric: true,
                                        ),
                                        DataColumn(label: Text('Estado')),
                                        DataColumn(
                                          label: Text('Impresiones'),
                                          numeric: true,
                                        ),
                                        DataColumn(
                                          label: Text('Clics'),
                                          numeric: true,
                                        ),
                                        DataColumn(
                                          label: Text('CTR'),
                                          numeric: true,
                                        ),
                                        DataColumn(label: Text('Acciones')),
                                      ],
                                      rows: [
                                        for (final row in visibleRows)
                                          DataRow(
                                            cells: [
                                              DataCell(
                                                _BannerThumbnail(
                                                  url: row['image_url']
                                                          ?.toString() ??
                                                      '',
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: 180,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        row['title']
                                                                ?.toString() ??
                                                            'Banner',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                      if ((row['subtitle'] ??
                                                              '')
                                                          .toString()
                                                          .isNotEmpty)
                                                        Text(
                                                          row['subtitle']
                                                              .toString(),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            color: Theme.of(
                                                                    context)
                                                                .hintColor,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: 210,
                                                  child: Text(
                                                    _placementLabels(
                                                      row['placements'],
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                    '${row['sort_order'] ?? 100}'),
                                              ),
                                              DataCell(
                                                Switch.adaptive(
                                                  value: row['active'] == true,
                                                  onChanged: savingAction
                                                      ? null
                                                      : (value) => _setActive(
                                                          row, value),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                    '${row['impressions'] ?? 0}'),
                                              ),
                                              DataCell(
                                                Text('${row['clicks'] ?? 0}'),
                                              ),
                                              DataCell(
                                                  Text('${row['ctr'] ?? 0}%')),
                                              DataCell(
                                                PopupMenuButton<_BannerAction>(
                                                  tooltip:
                                                      'Acciones del banner',
                                                  onSelected: (action) {
                                                    switch (action) {
                                                      case _BannerAction.edit:
                                                        _edit(row);
                                                        break;
                                                      case _BannerAction
                                                            .statistics:
                                                        _showStatistics(row);
                                                        break;
                                                      case _BannerAction.delete:
                                                        _delete(row);
                                                        break;
                                                    }
                                                  },
                                                  itemBuilder: (context) =>
                                                      const [
                                                    PopupMenuItem(
                                                      value: _BannerAction.edit,
                                                      child: ListTile(
                                                        dense: true,
                                                        leading: Icon(
                                                          Icons.edit_outlined,
                                                        ),
                                                        title: Text('Editar'),
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: _BannerAction
                                                          .statistics,
                                                      child: ListTile(
                                                        dense: true,
                                                        leading: Icon(
                                                          Icons
                                                              .bar_chart_rounded,
                                                        ),
                                                        title: Text(
                                                          'Ver estadísticas',
                                                        ),
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value:
                                                          _BannerAction.delete,
                                                      child: ListTile(
                                                        dense: true,
                                                        leading: Icon(
                                                          Icons
                                                              .delete_outline_rounded,
                                                          color: Colors.red,
                                                        ),
                                                        title: Text(
                                                          'Eliminar',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _BannerImagePlaceholder extends StatelessWidget {
  const _BannerImagePlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_outlined, size: 36)),
      );
}

class _BannerThumbnail extends StatelessWidget {
  final String url;
  const _BannerThumbnail({required this.url});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 100,
          height: 52,
          child: url.startsWith('https://')
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _BannerImagePlaceholder(),
                )
              : const _BannerImagePlaceholder(),
        ),
      );
}

class _BannerMetricLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _BannerMetricLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
