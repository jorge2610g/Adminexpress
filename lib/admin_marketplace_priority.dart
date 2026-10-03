import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const _blue = Color(0xFF2563EB);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

Map<String, dynamic> _obj(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

num _n(Object? value, [num fallback = 0]) =>
    value is num ? value : num.tryParse(value?.toString() ?? '') ?? fallback;

void _error(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $error')),
  );
}

class AdminMarketplacePage extends StatefulWidget {
  const AdminMarketplacePage({super.key});

  @override
  State<AdminMarketplacePage> createState() => _AdminMarketplacePageState();
}

class _AdminMarketplacePageState extends State<AdminMarketplacePage> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<Map<String, dynamic>> _load() async =>
      _obj(await supabase.rpc('admin_marketplace_state'));

  void _reload() => setState(() => future = _load());

  Future<void> _editSettings(Map<String, dynamic> settings) async {
    var preview = settings['preview_enabled'] == true;
    var production = settings['production_enabled'] == true;
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
          title: const Text('Configurar Express Market'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preview,
                    onChanged: (v) => setLocal(() => preview = v),
                    title: const Text('Habilitado en Preview'),
                    subtitle: const Text(
                      'Permite probar el módulo sin mostrarlo en Producción.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: production,
                    onChanged: (v) => setLocal(() => production = v),
                    title: const Text('Habilitado en Producción'),
                    subtitle: const Text(
                      'Actívalo solo después de aprobar la Preview.',
                    ),
                  ),
                  TextField(
                    controller: module,
                    decoration:
                        const InputDecoration(labelText: 'Nombre del módulo'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: search,
                    decoration:
                        const InputDecoration(labelText: 'Texto del buscador'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hero,
                    decoration:
                        const InputDecoration(labelText: 'Título principal'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: subtitle,
                    decoration:
                        const InputDecoration(labelText: 'Subtítulo principal'),
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

    if (save != true) return;
    try {
      await supabase.rpc(
        'admin_marketplace_update_settings',
        params: {
          'p_preview_enabled': preview,
          'p_production_enabled': production,
          'p_module_name': module.text.trim(),
          'p_search_placeholder': search.text.trim(),
          'p_hero_title': hero.text.trim(),
          'p_hero_subtitle': subtitle.text.trim(),
        },
      );
      _reload();
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      module.dispose();
      search.dispose();
      hero.dispose();
      subtitle.dispose();
    }
  }

  Future<void> _editCategory(Map<String, dynamic> row) async {
    final name = TextEditingController(text: row['name']?.toString());
    final order = TextEditingController(
      text: (row['sort_order'] ?? 100).toString(),
    );
    var active = row['active'] == true;
    var preview = row['preview_visible'] == true;
    var production = row['production_visible'] == true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Editar ${row['name'] ?? 'categoría'}'),
          content: SizedBox(
            width: 470,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Orden en la app'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                  title: const Text('Activa'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: preview,
                  onChanged: (v) => setLocal(() => preview = v),
                  title: const Text('Visible en Preview'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: production,
                  onChanged: (v) => setLocal(() => production = v),
                  title: const Text('Visible en Producción'),
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;
    try {
      await supabase.rpc(
        'admin_marketplace_upsert_category',
        params: {
          'p_id': row['id'],
          'p_category_key': row['category_key'],
          'p_name': name.text.trim(),
          'p_icon_key': row['icon_key'] ?? 'storefront',
          'p_active': active,
          'p_preview_visible': preview,
          'p_production_visible': production,
          'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
        },
      );
      _reload();
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      name.dispose();
      order.dispose();
    }
  }

  Future<void> _editBanner(Map<String, dynamic> row) async {
    final title = TextEditingController(text: row['title']?.toString());
    final subtitle = TextEditingController(text: row['subtitle']?.toString());
    final cta = TextEditingController(text: row['cta_label']?.toString());
    var active = row['active'] == true;
    var preview = row['preview_visible'] == true;
    var production = row['production_visible'] == true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Editar banner'),
          content: SizedBox(
            width: 470,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: subtitle,
                  decoration: const InputDecoration(labelText: 'Subtítulo'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cta,
                  decoration: const InputDecoration(labelText: 'Botón'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                  title: const Text('Activo'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: preview,
                  onChanged: (v) => setLocal(() => preview = v),
                  title: const Text('Visible en Preview'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: production,
                  onChanged: (v) => setLocal(() => production = v),
                  title: const Text('Visible en Producción'),
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;
    try {
      await supabase.rpc(
        'admin_marketplace_upsert_banner',
        params: {
          'p_id': row['id'],
          'p_title': title.text.trim(),
          'p_subtitle': subtitle.text.trim(),
          'p_cta_label': cta.text.trim(),
          'p_style_key': row['style_key'] ?? 'blue',
          'p_active': active,
          'p_preview_visible': preview,
          'p_production_visible': production,
          'p_sort_order': row['sort_order'] ?? 100,
        },
      );
      _reload();
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      title.dispose();
      subtitle.dispose();
      cta.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ModuleError(error: snapshot.error, onRetry: _reload);
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final settings = _obj(data['settings']);
        final categories = _rows(data['categories']);
        final banners = _rows(data['banners']);
        final merchants = _rows(data['merchants']);

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _Header(
              icon: Icons.storefront_rounded,
              title: 'Express Market',
              subtitle:
                  'Configuración central del marketplace para Preview y Producción.',
              action: FilledButton.icon(
                onPressed: () => _editSettings(settings),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Configurar'),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Status(
                  title: 'Preview',
                  value: settings['preview_enabled'] == true
                      ? 'Habilitado'
                      : 'Apagado',
                  active: settings['preview_enabled'] == true,
                ),
                _Status(
                  title: 'Producción',
                  value: settings['production_enabled'] == true
                      ? 'Habilitado'
                      : 'Apagado',
                  active: settings['production_enabled'] == true,
                ),
                _Status(
                  title: 'Contenido',
                  value:
                      '${categories.length} categorías · ${banners.length} banners · ${merchants.length} locales',
                  active: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _Title('Categorías'),
            const SizedBox(height: 8),
            ...categories.map(
              (row) => _Tile(
                icon: Icons.category_outlined,
                title: row['name']?.toString() ?? 'Categoría',
                subtitle:
                    '${row['category_key']} · orden ${row['sort_order'] ?? 100}',
                tags: [
                  row['active'] == true ? 'Activa' : 'Inactiva',
                  if (row['preview_visible'] == true) 'Preview',
                  if (row['production_visible'] == true) 'Producción',
                ],
                onTap: () => _editCategory(row),
              ),
            ),
            const SizedBox(height: 18),
            const _Title('Banners y promociones'),
            const SizedBox(height: 8),
            ...banners.map(
              (row) => _Tile(
                icon: Icons.campaign_outlined,
                title: row['title']?.toString() ?? 'Banner',
                subtitle: row['subtitle']?.toString() ?? '',
                tags: [
                  row['active'] == true ? 'Activo' : 'Inactivo',
                  if (row['preview_visible'] == true) 'Preview',
                  if (row['production_visible'] == true) 'Producción',
                ],
                onTap: () => _editBanner(row),
              ),
            ),
            const SizedBox(height: 18),
            const _Title('Locales'),
            const SizedBox(height: 8),
            if (merchants.isEmpty)
              const _Info(
                'La estructura de locales y productos ya está creada. '
                'Los comercios se cargarán aquí en la siguiente etapa del módulo.',
              )
            else
              ...merchants.map(
                (row) => _Tile(
                  icon: Icons.store_mall_directory_outlined,
                  title: row['name']?.toString() ?? 'Local',
                  subtitle: row['category_key']?.toString() ?? '',
                ),
              ),
          ],
        );
      },
    );
  }
}

class AdminDriverPriorityPage extends StatefulWidget {
  const AdminDriverPriorityPage({super.key});

  @override
  State<AdminDriverPriorityPage> createState() =>
      _AdminDriverPriorityPageState();
}

class _AdminDriverPriorityPageState extends State<AdminDriverPriorityPage> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<Map<String, dynamic>> _load() async =>
      _obj(await supabase.rpc('admin_driver_priority_state'));

  void _reload() => setState(() => future = _load());

  Future<void> _edit(Map<String, dynamic> s) async {
    var preview = s['preview_enabled'] == true;
    var production = s['production_enabled'] == true;
    var previewApply = s['preview_enforcement_enabled'] == true;
    var productionApply = s['production_enforcement_enabled'] == true;

    TextEditingController c(String key, num fallback) =>
        TextEditingController(text: _n(s[key], fallback).toString());

    final high = c('high_min_score', 80);
    final medium = c('medium_min_score', 55);
    final rating = c('rating_weight', 35);
    final reviews = c('reviews_weight', 25);
    final experience = c('experience_weight', 20);
    final frequency = c('frequency_weight', 20);
    final reviewTarget = c('review_target', 20);
    final tripTarget = c('experience_trip_target', 100);
    final monthTarget = c('frequency_30d_target', 30);

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Configurar prioridad'),
          content: SizedBox(
            width: 620,
            height: 650,
            child: ListView(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: preview,
                  onChanged: (v) => setLocal(() => preview = v),
                  title: const Text('Mostrar en Preview'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: previewApply,
                  onChanged: preview
                      ? (v) => setLocal(() => previewApply = v)
                      : null,
                  title: const Text('Aplicar ranking en despacho Preview'),
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: production,
                  onChanged: (v) => setLocal(() => production = v),
                  title: const Text('Mostrar en Producción'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: productionApply,
                  onChanged: production
                      ? (v) => setLocal(() => productionApply = v)
                      : null,
                  title: const Text('Aplicar ranking en despacho Producción'),
                  subtitle: const Text(
                    'Déjalo apagado hasta aprobar el comportamiento en Preview.',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Niveles',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _Numbers([
                  ('Alta desde', high),
                  ('Media desde', medium),
                ]),
                const SizedBox(height: 14),
                const Text(
                  'Pesos del puntaje',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _Numbers([
                  ('Calificación', rating),
                  ('Reseñas', reviews),
                  ('Experiencia', experience),
                  ('Frecuencia', frequency),
                ]),
                const SizedBox(height: 14),
                const Text(
                  'Metas para 100%',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _Numbers([
                  ('Reseñas', reviewTarget),
                  ('Viajes históricos', tripTarget),
                  ('Viajes en 30 días', monthTarget),
                ]),
              ],
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

    if (save != true) return;
    num parse(TextEditingController value, num fallback) =>
        num.tryParse(value.text.trim().replaceAll(',', '.')) ?? fallback;

    try {
      await supabase.rpc(
        'admin_update_driver_priority_settings',
        params: {
          'p_preview_enabled': preview,
          'p_production_enabled': production,
          'p_preview_enforcement_enabled': previewApply,
          'p_production_enforcement_enabled': productionApply,
          'p_high_min_score': parse(high, 80),
          'p_medium_min_score': parse(medium, 55),
          'p_rating_weight': parse(rating, 35),
          'p_reviews_weight': parse(reviews, 25),
          'p_experience_weight': parse(experience, 20),
          'p_frequency_weight': parse(frequency, 20),
          'p_review_target': parse(reviewTarget, 20).round(),
          'p_experience_trip_target': parse(tripTarget, 100).round(),
          'p_frequency_30d_target': parse(monthTarget, 30).round(),
        },
      );
      _reload();
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      for (final item in [
        high,
        medium,
        rating,
        reviews,
        experience,
        frequency,
        reviewTarget,
        tripTarget,
        monthTarget,
      ]) {
        item.dispose();
      }
    }
  }

  String _level(String? value) {
    if (value == 'high') return 'Alta';
    if (value == 'medium') return 'Media';
    return 'Baja';
  }

  Color _levelColor(String? value) {
    if (value == 'high') return const Color(0xFF14804A);
    if (value == 'medium') return const Color(0xFFC76B16);
    return const Color(0xFFD92D20);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ModuleError(error: snapshot.error, onRetry: _reload);
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final settings = _obj(data['settings']);
        final drivers = _rows(data['drivers']);

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _Header(
              icon: Icons.workspace_premium_rounded,
              title: 'Prioridad de conductores',
              subtitle:
                  'Controla Alta / Media / Baja y el ranking del despacho.',
              action: FilledButton.icon(
                onPressed: () => _edit(settings),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Configurar ranking'),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Status(
                  title: 'Preview',
                  value: settings['preview_enforcement_enabled'] == true
                      ? 'Ranking activo'
                      : 'Solo visual',
                  active: settings['preview_enabled'] == true,
                ),
                _Status(
                  title: 'Producción',
                  value: settings['production_enforcement_enabled'] == true
                      ? 'Ranking activo'
                      : 'Sin afectar despacho',
                  active: settings['production_enabled'] == true,
                ),
                _Status(
                  title: 'Umbrales',
                  value:
                      'Alta ${settings['high_min_score'] ?? 80} · Media ${settings['medium_min_score'] ?? 55}',
                  active: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _Title('Conductores'),
            const SizedBox(height: 8),
            ...drivers.map((row) {
              final priority = _obj(row['priority']);
              final metrics = _obj(priority['metrics']);
              final raw = priority['level']?.toString();
              final color = _levelColor(raw);
              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: .12),
                      foregroundColor: color,
                      child: const Icon(Icons.drive_eta_rounded),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row['name']?.toString() ?? 'Conductor',
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '★ ${priority['average_rating'] ?? 0} · '
                            '${priority['completed_trips'] ?? 0} viajes · '
                            '${priority['review_count'] ?? 0} reseñas',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              _Metric('Rep.', metrics['rating']),
                              _Metric('Reseñas', metrics['reviews']),
                              _Metric('Exp.', metrics['experience']),
                              _Metric('Frec.', metrics['frequency']),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        Text(
                          _level(raw),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${_n(priority['score']).toStringAsFixed(1)}/100',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget action;
  const _Header({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _blue),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        action,
      ],
    );
  }
}

class _Status extends StatelessWidget {
  final String title;
  final String value;
  final bool active;
  const _Status({
    required this.title,
    required this.value,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 200),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            color: active
                ? const Color(0xFF14804A)
                : const Color(0xFF98A2B3),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _ink,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> tags;
  final VoidCallback? onTap;
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tags = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF2FF),
          foregroundColor: _blue,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty) Text(subtitle),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: tags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final Object? value;
  const _Metric(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '$label ${_n(value).toStringAsFixed(0)}%',
          style: const TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _Numbers extends StatelessWidget {
  final List<(String, TextEditingController)> items;
  const _Numbers(this.items);

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map(
              (item) => SizedBox(
                width: 245,
                child: TextField(
                  controller: item.$2,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: item.$1),
                ),
              ),
            )
            .toList(),
      );
}

class _Info extends StatelessWidget {
  final String text;
  const _Info(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(text, style: const TextStyle(color: _muted)),
      );
}

class _ModuleError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const _ModuleError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 40),
                const SizedBox(height: 8),
                Text(error.toString()),
                const SizedBox(height: 10),
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
