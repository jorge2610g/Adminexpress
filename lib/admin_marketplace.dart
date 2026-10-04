import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const _blue = Color(0xFF2563EB);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _bg = Color(0xFFF1F5F9);

class AdminMarketplacePage extends StatefulWidget {
  final String channel;

  const AdminMarketplacePage({
    super.key,
    this.channel = 'production',
  });

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

  Future<Map<String, dynamic>> _load() async {
    final value = await supabase.rpc('admin_marketplace_state');
    final state = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    final visibilityKey = widget.channel == 'preview'
        ? 'preview_visible'
        : 'production_visible';
    for (final key in const ['categories', 'banners', 'merchants']) {
      state[key] = _rows(state[key])
          .where((row) => row[visibilityKey] == true)
          .toList();
    }
    return state;
  }

  List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  void _refresh() => setState(() => future = _load());

  void _snack(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.toString())),
    );
  }

  Future<void> _editSettings(Map<String, dynamic> settings) async {
    bool preview = settings['preview_enabled'] == true;
    bool production = settings['production_enabled'] == true;
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
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: preview,
                    onChanged: widget.channel == 'preview'
                        ? (value) => setLocal(() => preview = value)
                        : null,
                    title: const Text('Activo en Preview'),
                    subtitle: const Text(
                      'Permite probar el módulo sin activarlo en producción.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: production,
                    onChanged: widget.channel == 'production'
                        ? (value) => setLocal(() => production = value)
                        : null,
                    title: const Text('Activo en Producción'),
                    subtitle: const Text(
                      'Actívalo solo después de aprobar la Preview.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: module,
                    decoration:
                        const InputDecoration(labelText: 'Nombre del módulo'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: search,
                    decoration:
                        const InputDecoration(labelText: 'Texto del buscador'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: hero,
                    decoration:
                        const InputDecoration(labelText: 'Título principal'),
                  ),
                  const SizedBox(height: 10),
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

    if (save == true) {
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
    final key =
        TextEditingController(text: row?['category_key']?.toString() ?? '');
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final icon = TextEditingController(
      text: row?['icon_key']?.toString() ?? 'storefront',
    );
    final order = TextEditingController(
      text: row?['sort_order']?.toString() ?? '100',
    );
    bool active = row?['active'] != false;
    if (row != null &&
        row['preview_visible'] == true &&
        row['production_visible'] == true) {
      _snack(
        'Este registro está compartido entre Prueba y Producción. '
        'Debe separarse antes de editarlo.',
      );
      return;
    }
    bool preview = row == null
        ? widget.channel == 'preview'
        : row['preview_visible'] == true;
    bool production = row == null
        ? widget.channel == 'production'
        : row['production_visible'] == true;

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
                    decoration:
                        const InputDecoration(labelText: 'Icono interno'),
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
                    value: preview,
                    onChanged: widget.channel == 'preview'
                        ? (value) => setLocal(() => preview = value)
                        : null,
                    title: const Text('Visible en Preview'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: production,
                    onChanged: widget.channel == 'production'
                        ? (value) => setLocal(() => production = value)
                        : null,
                    title: const Text('Visible en Producción'),
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
            'p_preview_visible': preview,
            'p_production_visible': production,
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
    final subtitle =
        TextEditingController(text: row?['subtitle']?.toString() ?? '');
    final cta =
        TextEditingController(text: row?['cta_label']?.toString() ?? '');
    final style = TextEditingController(
      text: row?['style_key']?.toString() ?? 'blue',
    );
    final order = TextEditingController(
      text: row?['sort_order']?.toString() ?? '100',
    );
    bool active = row?['active'] != false;
    if (row != null &&
        row['preview_visible'] == true &&
        row['production_visible'] == true) {
      _snack(
        'Este registro está compartido entre Prueba y Producción. '
        'Debe separarse antes de editarlo.',
      );
      return;
    }
    bool preview = row == null
        ? widget.channel == 'preview'
        : row['preview_visible'] == true;
    bool production = row == null
        ? widget.channel == 'production'
        : row['production_visible'] == true;

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
                    decoration:
                        const InputDecoration(labelText: 'Botón / CTA'),
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
                    value: preview,
                    onChanged: widget.channel == 'preview'
                        ? (value) => setLocal(() => preview = value)
                        : null,
                    title: const Text('Visible en Preview'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: production,
                    onChanged: widget.channel == 'production'
                        ? (value) => setLocal(() => production = value)
                        : null,
                    title: const Text('Visible en Producción'),
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
            'p_preview_visible': preview,
            'p_production_visible': production,
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
    final value = await supabase.rpc('admin_zone_list');
    return _rows(value);
  }

  Future<void> _editMerchant(
    Map<String, dynamic>? row,
    List<Map<String, dynamic>> categories,
  ) async {
    final zones = await _zones();
    if (!mounted) return;

    String? zoneId = row?['zone_id']?.toString();
    String categoryKey = row?['category_key']?.toString() ??
        (categories.isEmpty
            ? ''
            : categories.first['category_key']?.toString() ?? '');
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final description =
        TextEditingController(text: row?['description']?.toString() ?? '');
    final image =
        TextEditingController(text: row?['image_url']?.toString() ?? '');
    final rating =
        TextEditingController(text: row?['rating']?.toString() ?? '5');
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
    if (row != null &&
        row['preview_visible'] == true &&
        row['production_visible'] == true) {
      _snack(
        'Este registro está compartido entre Prueba y Producción. '
        'Debe separarse antes de editarlo.',
      );
      return;
    }
    bool preview = row == null
        ? widget.channel == 'preview'
        : row['preview_visible'] == true;
    bool production = row == null
        ? widget.channel == 'production'
        : row['production_visible'] == true;

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
                  DropdownButtonFormField<String?>(
                    value: zoneId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Zona'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas / sin zona fija'),
                      ),
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
                  DropdownButtonFormField<String>(
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
                    decoration:
                        const InputDecoration(labelText: 'URL de imagen'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rating,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Rating'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: fee,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Costo envío'),
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
                          decoration:
                              const InputDecoration(labelText: 'ETA mínimo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: etaMax,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'ETA máximo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: order,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Orden'),
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
                    value: preview,
                    onChanged: widget.channel == 'preview'
                        ? (value) => setLocal(() => preview = value)
                        : null,
                    title: const Text('Visible en Preview'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: production,
                    onChanged: widget.channel == 'production'
                        ? (value) => setLocal(() => production = value)
                        : null,
                    title: const Text('Visible en Producción'),
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
            'p_preview_visible': preview,
            'p_production_visible': production,
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
        final width =
            (constraints.maxWidth - (columns - 1) * 10) / columns;
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
                          'Administra el módulo para Preview y Producción desde un solo lugar.',
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
                  _tag('Preview', settings['preview_enabled'] == true),
                  _tag('Producción', settings['production_enabled'] == true),
                  _tag(categories.length.toString() + ' categorías', true),
                  _tag(banners.length.toString() + ' banners', true),
                  _tag(merchants.length.toString() + ' comercios', true),
                ],
              ),
              const SizedBox(height: 24),
              _section(
                'Categorías',
                'Orden, icono y visibilidad por entorno.',
                'Nueva categoría',
                () => _editCategory(null),
                categories
                    .map(
                      (row) => _card(
                        title: row['name']?.toString() ?? 'Categoría',
                        subtitle: row['category_key']?.toString() ?? '',
                        chips: [
                          _tag('Activa', row['active'] == true),
                          _tag('Preview', row['preview_visible'] == true),
                          _tag('Prod', row['production_visible'] == true),
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
                          _tag('Preview', row['preview_visible'] == true),
                          _tag('Prod', row['production_visible'] == true),
                        ],
                        onTap: () => _editBanner(row),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 26),
              _section(
                'Comercios y productos',
                'Locales, tiempos, costo de envío y catálogo.',
                'Nuevo comercio',
                () => _editMerchant(null, categories),
                merchants
                    .map(
                      (row) => _card(
                        title: row['name']?.toString() ?? 'Comercio',
                        subtitle:
                            (row['category_key'] ?? '').toString() +
                                ' · ' +
                                (row['eta_min_minutes'] ?? 15).toString() +
                                '-' +
                                (row['eta_max_minutes'] ?? 40).toString() +
                                ' min',
                        chips: [
                          _tag('Activo', row['active'] == true),
                          _tag('Preview', row['preview_visible'] == true),
                          _tag('Prod', row['production_visible'] == true),
                        ],
                        onTap: () => _openProducts(row),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editMerchant(row, categories);
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
    final description =
        TextEditingController(text: row?['description']?.toString() ?? '');
    final price =
        TextEditingController(text: row?['price']?.toString() ?? '0');
    final currency = TextEditingController(
      text: row?['currency_code']?.toString() ?? 'CLP',
    );
    final image =
        TextEditingController(text: row?['image_url']?.toString() ?? '');
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
                          decoration:
                              const InputDecoration(labelText: 'Precio'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: currency,
                          decoration:
                              const InputDecoration(labelText: 'Moneda'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: image,
                    decoration:
                        const InputDecoration(labelText: 'URL de imagen'),
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
            return Center(child: Text(snapshot.error.toString()));
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
