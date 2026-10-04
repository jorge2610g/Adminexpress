import 'dart:convert';

import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const _v2Blue = Color(0xFF2563EB);
const _v2Ink = Color(0xFF0F172A);
const _v2Muted = Color(0xFF64748B);
const _v2Bg = Color(0xFFF1F5F9);

double _v2Number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> _v2Rows(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

class AdminExpressDeliveryV2Page extends StatefulWidget {
  const AdminExpressDeliveryV2Page({super.key});

  @override
  State<AdminExpressDeliveryV2Page> createState() =>
      _AdminExpressDeliveryV2PageState();
}

class _AdminExpressDeliveryV2PageState
    extends State<AdminExpressDeliveryV2Page> {
  String? zoneId;
  int tab = 0;
  int revision = 0;

  Future<Map<String, dynamic>> _load() async {
    final value = await supabase.rpc(
      'admin_marketplace_v2_state',
      params: {'p_zone_id': zoneId},
    );
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  void _reload() => setState(() => revision++);

  void _snack(Object value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value.toString())),
    );
  }

  Future<void> _action(Future<void> Function() callback) async {
    try {
      await callback();
      _reload();
    } catch (e) {
      _snack(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('delivery-v2-admin-$revision-$zoneId'),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminV2Error(
            error: snapshot.error.toString(),
            onRetry: _reload,
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final zones = _v2Rows(data['zones']);
        final sections = _v2Rows(data['home_sections']);
        final coupons = _v2Rows(data['coupons']);
        final merchants = _v2Rows(data['merchants']);
        final menuSections = _v2Rows(data['menu_sections']);
        final products = _v2Rows(data['products']);
        final groups = _v2Rows(data['modifier_groups']);

        return Scaffold(
          backgroundColor: _v2Bg,
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Express Delivery · Experiencia V2',
                                style: TextStyle(
                                  color: _v2Ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Home, cupones, menús, promociones, modificadores y operación por zona.',
                                style: TextStyle(
                                  color: _v2Muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Actualizar',
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String?>(
                            value: zoneId,
                            decoration: const InputDecoration(
                              labelText: 'Zona',
                              prefixIcon: Icon(Icons.public_rounded),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todas las zonas'),
                              ),
                              ...zones.map(
                                (zone) => DropdownMenuItem<String?>(
                                  value: zone['id']?.toString(),
                                  child: Text(
                                    (zone['city']?.toString() ?? 'Zona') +
                                        ' · ' +
                                        (zone['country']?.toString() ?? '') +
                                        ' · ' +
                                        (zone['currency_code']?.toString() ??
                                            ''),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                zoneId = value;
                                revision++;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Metric(
                                label: 'Secciones Home',
                                value: sections.length.toString(),
                              ),
                              _Metric(
                                label: 'Cupones',
                                value: coupons.length.toString(),
                              ),
                              _Metric(
                                label: 'Comercios',
                                value: merchants.length.toString(),
                              ),
                              _Metric(
                                label: 'Productos',
                                value: products.length.toString(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(
                            value: 0,
                            icon: Icon(Icons.view_carousel_outlined),
                            label: Text('Home'),
                          ),
                          ButtonSegment(
                            value: 1,
                            icon: Icon(Icons.local_offer_outlined),
                            label: Text('Cupones'),
                          ),
                          ButtonSegment(
                            value: 2,
                            icon: Icon(Icons.restaurant_menu_rounded),
                            label: Text('Menús'),
                          ),
                          ButtonSegment(
                            value: 3,
                            icon: Icon(Icons.fastfood_outlined),
                            label: Text('Productos'),
                          ),
                          ButtonSegment(
                            value: 4,
                            icon: Icon(Icons.storefront_outlined),
                            label: Text('Comercios'),
                          ),
                        ],
                        selected: {tab},
                        onSelectionChanged: (value) =>
                            setState(() => tab = value.first),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (tab) {
                  1 => _couponsTab(coupons, zones),
                  2 => _menusTab(menuSections, merchants, products, groups),
                  3 => _productsTab(products, menuSections),
                  4 => _merchantsTab(merchants),
                  _ => _homeTab(sections, zones),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _homeTab(
    List<Map<String, dynamic>> sections,
    List<Map<String, dynamic>> zones,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AdminV2Header(
          title: 'Secciones del Home',
          subtitle:
              'Configura carruseles como más pedidos, promociones, buen precio y recomendaciones.',
          actionLabel: 'Nueva sección',
          onAction: () => _editHomeSection(null, zones),
        ),
        const SizedBox(height: 12),
        if (sections.isEmpty)
          const _AdminV2Empty(
            icon: Icons.view_carousel_outlined,
            title: 'No hay secciones configuradas',
            text: 'Crea bloques para el Home de Express Delivery.',
          )
        else
          ...sections.map(
            (row) => _AdminRowCard(
              title: row['title']?.toString() ?? 'Sección',
              subtitle: [
                row['source_rule'],
                row['section_type'],
                row['country_code'],
              ].whereType<Object>().map((e) => e.toString()).join(' · '),
              badges: [
                if (row['preview_visible'] == true) 'Preview',
                if (row['production_visible'] == true) 'Producción',
                if (row['active'] != true) 'Desactivada',
              ],
              onEdit: () => _editHomeSection(row, zones),
            ),
          ),
      ],
    );
  }

  Widget _couponsTab(
    List<Map<String, dynamic>> coupons,
    List<Map<String, dynamic>> zones,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AdminV2Header(
          title: 'Cupones y promociones',
          subtitle:
              'Cada cupón puede limitarse por zona o país. Producción permanece independiente.',
          actionLabel: 'Nuevo cupón',
          onAction: () => _editCoupon(null, zones),
        ),
        const SizedBox(height: 12),
        if (coupons.isEmpty)
          const _AdminV2Empty(
            icon: Icons.local_offer_outlined,
            title: 'No hay cupones',
            text: 'Crea códigos promocionales para Preview cuando lo necesites.',
          )
        else
          ...coupons.map(
            (row) => _AdminRowCard(
              title: (row['code']?.toString() ?? 'CUPON') +
                  ' · ' +
                  (row['title']?.toString() ?? ''),
              subtitle: _couponSummary(row),
              badges: [
                if (row['preview_visible'] == true) 'Preview',
                if (row['production_visible'] == true) 'Producción',
                if (row['active'] != true) 'Desactivado',
              ],
              onEdit: () => _editCoupon(row, zones),
            ),
          ),
      ],
    );
  }

  Widget _menusTab(
    List<Map<String, dynamic>> menuSections,
    List<Map<String, dynamic>> merchants,
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> groups,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AdminV2Header(
          title: 'Menús y modificadores',
          subtitle:
              'Crea secciones internas del menú y opciones como tamaño, extras o salsas.',
          actionLabel: 'Nueva sección',
          onAction: merchants.isEmpty
              ? null
              : () => _editMenuSection(null, merchants),
        ),
        const SizedBox(height: 12),
        ...menuSections.map((row) {
          final merchant = merchants.firstWhere(
            (m) => m['id']?.toString() == row['merchant_id']?.toString(),
            orElse: () => <String, dynamic>{},
          );
          return _AdminRowCard(
            title: row['name']?.toString() ?? 'Sección',
            subtitle: merchant['name']?.toString() ?? 'Comercio',
            badges: [
              if (row['preview_visible'] == true) 'Preview',
              if (row['production_visible'] == true) 'Producción',
            ],
            onEdit: () => _editMenuSection(row, merchants),
          );
        }),
        const SizedBox(height: 18),
        _AdminV2Header(
          title: 'Grupos de opciones',
          subtitle:
              'Define selección mínima/máxima y opciones con costo adicional.',
          actionLabel: 'Nuevo grupo',
          onAction: products.isEmpty
              ? null
              : () => _editModifierGroup(null, products),
        ),
        const SizedBox(height: 12),
        ...groups.map((row) {
          final product = products.firstWhere(
            (p) => p['id']?.toString() == row['product_id']?.toString(),
            orElse: () => <String, dynamic>{},
          );
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              title: Text(
                row['name']?.toString() ?? 'Opciones',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                (product['name']?.toString() ?? 'Producto') +
                    ' · mínimo ' +
                    (row['min_select'] ?? 0).toString() +
                    ' / máximo ' +
                    (row['max_select'] ?? 1).toString(),
              ),
              trailing: IconButton(
                tooltip: 'Editar grupo',
                onPressed: () => _editModifierGroup(row, products),
                icon: const Icon(Icons.edit_outlined),
              ),
              children: [
                ..._v2Rows(row['options']).map(
                  (option) => ListTile(
                    title: Text(option['name']?.toString() ?? 'Opción'),
                    subtitle: Text(
                      'Adicional: ' +
                          _v2Number(option['price_delta']).toStringAsFixed(2),
                    ),
                    trailing: IconButton(
                      tooltip: 'Editar',
                      onPressed: () => _editModifier(option, row),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: OutlinedButton.icon(
                    onPressed: () => _editModifier(null, row),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar opción'),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _productsTab(
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> sections,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _AdminV2Header(
          title: 'Productos y promociones',
          subtitle:
              'Asigna sección, precio promocional, etiqueta, destacado, anuncio y tags.',
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          const _AdminV2Empty(
            icon: Icons.fastfood_outlined,
            title: 'No hay productos',
            text: 'Los productos del catálogo aparecerán aquí.',
          )
        else
          ...products.map(
            (row) => _AdminRowCard(
              title: row['name']?.toString() ?? 'Producto',
              subtitle: [
                row['merchant_name'],
                row['currency_code'],
                row['price'],
              ].whereType<Object>().map((e) => e.toString()).join(' · '),
              badges: [
                if (row['promo_price'] != null) 'Promo',
                if (row['is_featured'] == true) 'Destacado',
                if (row['is_sponsored'] == true) 'Anuncio',
              ],
              onEdit: () => _editProduct(row, sections, products),
            ),
          ),
      ],
    );
  }

  Widget _merchantsTab(List<Map<String, dynamic>> merchants) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _AdminV2Header(
          title: 'Configuración de comercios',
          subtitle:
              'Horario, pedido mínimo, etiquetas, anuncio y apertura manual.',
        ),
        const SizedBox(height: 12),
        ...merchants.map(
          (row) => _AdminRowCard(
            title: row['name']?.toString() ?? 'Comercio',
            subtitle: [
              row['zone_key'],
              row['country_code'],
              row['currency_code'],
            ].whereType<Object>().map((e) => e.toString()).join(' · '),
            badges: [
              if (row['is_sponsored'] == true) 'Anuncio',
              if (row['open_override'] == true) 'Forzado abierto',
              if (row['open_override'] == false) 'Forzado cerrado',
            ],
            onEdit: () => _editMerchant(row),
          ),
        ),
      ],
    );
  }

  Future<void> _editHomeSection(
    Map<String, dynamic>? row,
    List<Map<String, dynamic>> zones,
  ) async {
    final key = TextEditingController(
      text: row?['section_key']?.toString() ?? '',
    );
    final title = TextEditingController(
      text: row?['title']?.toString() ?? '',
    );
    final subtitle = TextEditingController(
      text: row?['subtitle']?.toString() ?? '',
    );
    final order = TextEditingController(
      text: row?['sort_order']?.toString() ?? '100',
    );
    final config = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(
        row?['config'] is Map ? row!['config'] : <String, dynamic>{},
      ),
    );
    String? localZone = row?['zone_id']?.toString() ?? zoneId;
    String sectionType = row?['section_type']?.toString() ?? 'merchants';
    String sourceRule = row?['source_rule']?.toString() ?? 'popular';
    bool active = row?['active'] != false;
    bool preview = row?['preview_visible'] != false;
    bool production = row?['production_visible'] == true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Nueva sección Home' : 'Editar sección'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String?>(
                    value: localZone,
                    decoration: const InputDecoration(labelText: 'Zona'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Global'),
                      ),
                      ...zones.map(
                        (z) => DropdownMenuItem<String?>(
                          value: z['id']?.toString(),
                          child: Text(
                            (z['city']?.toString() ?? 'Zona') +
                                ' · ' +
                                (z['country']?.toString() ?? ''),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => localZone = v),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: key,
                    decoration: const InputDecoration(
                      labelText: 'Clave',
                      hintText: 'ej. pizza_night',
                    ),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: subtitle,
                    decoration: const InputDecoration(labelText: 'Subtítulo'),
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    value: sectionType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de contenido',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'merchants',
                        child: Text('Comercios'),
                      ),
                      DropdownMenuItem(
                        value: 'products',
                        child: Text('Productos'),
                      ),
                      DropdownMenuItem(
                        value: 'promotions',
                        child: Text('Promociones'),
                      ),
                    ],
                    onChanged: (v) =>
                        setLocal(() => sectionType = v ?? sectionType),
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    value: sourceRule,
                    decoration: const InputDecoration(
                      labelText: 'Regla',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'popular',
                        child: Text('Más pedidos'),
                      ),
                      DropdownMenuItem(
                        value: 'trusted',
                        child: Text('Mejor calificados'),
                      ),
                      DropdownMenuItem(
                        value: 'preferences',
                        child: Text('Preferencias'),
                      ),
                      DropdownMenuItem(
                        value: 'deals',
                        child: Text('Descuentos'),
                      ),
                      DropdownMenuItem(
                        value: 'lowest_price',
                        child: Text('Buen precio'),
                      ),
                      DropdownMenuItem(
                        value: 'sponsored',
                        child: Text('Patrocinados'),
                      ),
                      DropdownMenuItem(
                        value: 'manual',
                        child: Text('Manual'),
                      ),
                    ],
                    onChanged: (v) =>
                        setLocal(() => sourceRule = v ?? sourceRule),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Orden'),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: config,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Configuración JSON',
                    ),
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
      await _action(() async {
        dynamic parsed = <String, dynamic>{};
        try {
          parsed = jsonDecode(config.text.trim().isEmpty ? '{}' : config.text);
        } catch (_) {
          throw Exception('Configuración JSON inválida');
        }
        await supabase.rpc(
          'admin_marketplace_upsert_home_section',
          params: {
            'p_id': row?['id'],
            'p_zone_id': localZone,
            'p_country_code': null,
            'p_section_key': key.text.trim(),
            'p_title': title.text.trim(),
            'p_subtitle': subtitle.text.trim(),
            'p_section_type': sectionType,
            'p_source_rule': sourceRule,
            'p_config': parsed,
            'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
            'p_active': active,
            'p_preview_visible': preview,
            'p_production_visible': production,
            'p_starts_at': row?['starts_at'],
            'p_ends_at': row?['ends_at'],
          },
        );
      });
    }
    key.dispose();
    title.dispose();
    subtitle.dispose();
    order.dispose();
    config.dispose();
  }

  Future<void> _editCoupon(
    Map<String, dynamic>? row,
    List<Map<String, dynamic>> zones,
  ) async {
    final code = TextEditingController(text: row?['code']?.toString() ?? '');
    final title =
        TextEditingController(text: row?['title']?.toString() ?? '');
    final description =
        TextEditingController(text: row?['description']?.toString() ?? '');
    final value =
        TextEditingController(text: row?['discount_value']?.toString() ?? '');
    final minimum =
        TextEditingController(text: row?['min_order']?.toString() ?? '0');
    final maximum =
        TextEditingController(text: row?['max_discount']?.toString() ?? '');
    final usage =
        TextEditingController(text: row?['usage_limit']?.toString() ?? '');
    final perUser = TextEditingController(
      text: row?['per_user_limit']?.toString() ?? '1',
    );
    String? localZone = row?['zone_id']?.toString() ?? zoneId;
    String type = row?['discount_type']?.toString() ?? 'percent';
    String funded = row?['funded_by']?.toString() ?? 'express';
    bool active = row?['active'] != false;
    bool preview = row?['preview_visible'] != false;
    bool production = row?['production_visible'] == true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Nuevo cupón' : 'Editar cupón'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String?>(
                    value: localZone,
                    decoration: const InputDecoration(labelText: 'Zona'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas / por país'),
                      ),
                      ...zones.map(
                        (z) => DropdownMenuItem<String?>(
                          value: z['id']?.toString(),
                          child: Text(
                            (z['city']?.toString() ?? 'Zona') +
                                ' · ' +
                                (z['country']?.toString() ?? ''),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => localZone = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Código'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: description,
                    decoration:
                        const InputDecoration(labelText: 'Descripción'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: type,
                          decoration:
                              const InputDecoration(labelText: 'Tipo'),
                          items: const [
                            DropdownMenuItem(
                              value: 'percent',
                              child: Text('Porcentaje'),
                            ),
                            DropdownMenuItem(
                              value: 'fixed',
                              child: Text('Monto fijo'),
                            ),
                          ],
                          onChanged: (v) =>
                              setLocal(() => type = v ?? type),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: value,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Valor'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minimum,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Compra mínima'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: maximum,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Descuento máximo',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: funded,
                    decoration:
                        const InputDecoration(labelText: 'Financiado por'),
                    items: const [
                      DropdownMenuItem(
                        value: 'express',
                        child: Text('Express'),
                      ),
                      DropdownMenuItem(
                        value: 'merchant',
                        child: Text('Comercio'),
                      ),
                    ],
                    onChanged: (v) =>
                        setLocal(() => funded = v ?? funded),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: usage,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Usos totales'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: perUser,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Usos por usuario'),
                        ),
                      ),
                    ],
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
                    title: const Text('Preview'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: production,
                    onChanged: (v) => setLocal(() => production = v),
                    title: const Text('Producción'),
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
      await _action(() async {
        await supabase.rpc(
          'admin_marketplace_upsert_coupon',
          params: {
            'p_id': row?['id'],
            'p_zone_id': localZone,
            'p_country_code': row?['country_code'],
            'p_code': code.text.trim(),
            'p_title': title.text.trim(),
            'p_description': description.text.trim(),
            'p_discount_type': type,
            'p_discount_value':
                double.tryParse(value.text.trim()) ?? 0,
            'p_min_order': double.tryParse(minimum.text.trim()) ?? 0,
            'p_max_discount': double.tryParse(maximum.text.trim()),
            'p_funded_by': funded,
            'p_usage_limit': int.tryParse(usage.text.trim()),
            'p_per_user_limit':
                int.tryParse(perUser.text.trim()) ?? 1,
            'p_starts_at': row?['starts_at'],
            'p_ends_at': row?['ends_at'],
            'p_active': active,
            'p_preview_visible': preview,
            'p_production_visible': production,
          },
        );
      });
    }
    code.dispose();
    title.dispose();
    description.dispose();
    value.dispose();
    minimum.dispose();
    maximum.dispose();
    usage.dispose();
    perUser.dispose();
  }

  Future<void> _editMenuSection(
    Map<String, dynamic>? row,
    List<Map<String, dynamic>> merchants,
  ) async {
    String? merchantId =
        row?['merchant_id']?.toString() ?? merchants.firstOrNull?['id']?.toString();
    final key = TextEditingController(
      text: row?['section_key']?.toString() ?? '',
    );
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final subtitle =
        TextEditingController(text: row?['subtitle']?.toString() ?? '');
    final order = TextEditingController(
      text: row?['sort_order']?.toString() ?? '100',
    );
    bool active = row?['active'] != false;
    bool preview = row?['preview_visible'] != false;
    bool production = row?['production_visible'] == true;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            row == null ? 'Nueva sección de menú' : 'Editar sección de menú',
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: merchantId,
                    decoration:
                        const InputDecoration(labelText: 'Comercio'),
                    items: merchants
                        .map(
                          (m) => DropdownMenuItem<String>(
                            value: m['id']?.toString(),
                            child: Text(m['name']?.toString() ?? 'Comercio'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => merchantId = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: key,
                    decoration: const InputDecoration(
                      labelText: 'Clave',
                      hintText: 'ej. bebidas',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: subtitle,
                    decoration:
                        const InputDecoration(labelText: 'Subtítulo'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Orden'),
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
                    title: const Text('Preview'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: production,
                    onChanged: (v) => setLocal(() => production = v),
                    title: const Text('Producción'),
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

    if (save == true && merchantId != null) {
      await _action(() async {
        await supabase.rpc(
          'admin_marketplace_upsert_menu_section',
          params: {
            'p_id': row?['id'],
            'p_merchant_id': merchantId,
            'p_section_key': key.text.trim(),
            'p_name': name.text.trim(),
            'p_subtitle': subtitle.text.trim(),
            'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
            'p_active': active,
            'p_preview_visible': preview,
            'p_production_visible': production,
          },
        );
      });
    }
    key.dispose();
    name.dispose();
    subtitle.dispose();
    order.dispose();
  }

  Future<void> _editModifierGroup(
    Map<String, dynamic>? row,
    List<Map<String, dynamic>> products,
  ) async {
    String? productId =
        row?['product_id']?.toString() ?? products.firstOrNull?['id']?.toString();
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final description =
        TextEditingController(text: row?['description']?.toString() ?? '');
    final min = TextEditingController(
      text: row?['min_select']?.toString() ?? '0',
    );
    final max = TextEditingController(
      text: row?['max_select']?.toString() ?? '1',
    );
    final order = TextEditingController(
      text: row?['sort_order']?.toString() ?? '100',
    );
    bool required = row?['required'] == true;
    bool active = row?['active'] != false;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Nuevo grupo de opciones' : 'Editar grupo'),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: productId,
                    decoration:
                        const InputDecoration(labelText: 'Producto'),
                    items: products
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p['id']?.toString(),
                            child: Text(
                              (p['name']?.toString() ?? 'Producto') +
                                  ' · ' +
                                  (p['merchant_name']?.toString() ?? ''),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => productId = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ej. Elige tamaño',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: description,
                    decoration:
                        const InputDecoration(labelText: 'Descripción'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: min,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Mínimo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: max,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Máximo'),
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
                    value: required,
                    onChanged: (v) => setLocal(() => required = v),
                    title: const Text('Obligatorio'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                    title: const Text('Activo'),
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

    if (save == true && productId != null) {
      await _action(() async {
        await supabase.rpc(
          'admin_marketplace_upsert_modifier_group',
          params: {
            'p_id': row?['id'],
            'p_product_id': productId,
            'p_name': name.text.trim(),
            'p_description': description.text.trim(),
            'p_min_select': int.tryParse(min.text.trim()) ?? 0,
            'p_max_select': int.tryParse(max.text.trim()) ?? 1,
            'p_required': required,
            'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
            'p_active': active,
          },
        );
      });
    }
    name.dispose();
    description.dispose();
    min.dispose();
    max.dispose();
    order.dispose();
  }

  Future<void> _editModifier(
    Map<String, dynamic>? row,
    Map<String, dynamic> group,
  ) async {
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final price = TextEditingController(
      text: row?['price_delta']?.toString() ?? '0',
    );
    final order = TextEditingController(
      text: row?['sort_order']?.toString() ?? '100',
    );
    bool active = row?['active'] != false;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Nueva opción' : 'Editar opción'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Costo adicional'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Orden'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                  title: const Text('Activa'),
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
    if (save == true) {
      await _action(() async {
        await supabase.rpc(
          'admin_marketplace_upsert_modifier',
          params: {
            'p_id': row?['id'],
            'p_group_id': group['id'],
            'p_name': name.text.trim(),
            'p_price_delta': double.tryParse(price.text.trim()) ?? 0,
            'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
            'p_active': active,
          },
        );
      });
    }
    name.dispose();
    price.dispose();
    order.dispose();
  }

  Future<void> _editProduct(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> menuSections,
    List<Map<String, dynamic>> allProducts,
  ) async {
    String? sectionId = row['menu_section_id']?.toString();
    final compare = TextEditingController(
      text: row['compare_at_price']?.toString() ?? '',
    );
    final promo = TextEditingController(
      text: row['promo_price']?.toString() ?? '',
    );
    final label = TextEditingController(
      text: row['promo_label']?.toString() ?? '',
    );
    final tags = TextEditingController(
      text: row['tags'] is List
          ? (row['tags'] as List).join(', ')
          : '',
    );
    bool sponsored = row['is_sponsored'] == true;
    bool featured = row['is_featured'] == true;
    final crossSellRaw = await supabase.rpc(
      'admin_marketplace_product_cross_sells',
      params: {'p_product_id': row['id']},
    );
    final selectedCrossSells = _v2Rows(crossSellRaw)
        .map((e) => e['recommended_product_id']?.toString())
        .whereType<String>()
        .toSet();
    final recommendations = allProducts
        .where((p) =>
            p['merchant_id']?.toString() == row['merchant_id']?.toString() &&
            p['id']?.toString() != row['id']?.toString())
        .toList();
    final validSections = menuSections
        .where((s) => s['merchant_id']?.toString() == row['merchant_id']?.toString())
        .toList();

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Producto · ' + (row['name']?.toString() ?? '')),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String?>(
                    value: sectionId,
                    decoration:
                        const InputDecoration(labelText: 'Sección del menú'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin sección'),
                      ),
                      ...validSections.map(
                        (s) => DropdownMenuItem<String?>(
                          value: s['id']?.toString(),
                          child: Text(s['name']?.toString() ?? 'Sección'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => sectionId = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: compare,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Precio anterior',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: promo,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Precio promocional',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: label,
                    decoration: const InputDecoration(
                      labelText: 'Etiqueta de promo',
                      hintText: 'Ej. 30% DCTO',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tags,
                    decoration: const InputDecoration(
                      labelText: 'Tags separados por coma',
                      hintText: 'pizza, cena, familiar',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: featured,
                    onChanged: (v) => setLocal(() => featured = v),
                    title: const Text('Destacado'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: sponsored,
                    onChanged: (v) => setLocal(() => sponsored = v),
                    title: const Text('Anuncio / patrocinado'),
                  ),
                  if (recommendations.isNotEmpty) ...[
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Venta cruzada / productos recomendados',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...recommendations.map(
                      (product) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selectedCrossSells
                            .contains(product['id']?.toString()),
                        title: Text(
                          product['name']?.toString() ?? 'Producto',
                        ),
                        onChanged: (checked) => setLocal(() {
                          final id = product['id']?.toString();
                          if (id == null) return;
                          if (checked == true) {
                            selectedCrossSells.add(id);
                          } else {
                            selectedCrossSells.remove(id);
                          }
                        }),
                      ),
                    ),
                  ],
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
      await _action(() async {
        await supabase.rpc(
          'admin_marketplace_update_product_v2',
          params: {
            'p_product_id': row['id'],
            'p_menu_section_id': sectionId,
            'p_compare_at_price': double.tryParse(compare.text.trim()),
            'p_promo_price': double.tryParse(promo.text.trim()),
            'p_promo_label': label.text.trim(),
            'p_promo_start_at': row['promo_start_at'],
            'p_promo_end_at': row['promo_end_at'],
            'p_is_sponsored': sponsored,
            'p_is_featured': featured,
            'p_tags': tags.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
          },
        );
        await supabase.rpc(
          'admin_marketplace_set_cross_sells',
          params: {
            'p_product_id': row['id'],
            'p_recommended_ids': selectedCrossSells.toList(),
          },
        );
      });
    }
    compare.dispose();
    promo.dispose();
    label.dispose();
    tags.dispose();
  }

  Future<void> _editMerchant(Map<String, dynamic> row) async {
    final minimum = TextEditingController(
      text: row['minimum_order']?.toString() ?? '0',
    );
    final tags = TextEditingController(
      text: row['tags'] is List ? (row['tags'] as List).join(', ') : '',
    );
    final hours = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(
        row['business_hours'] is Map
            ? row['business_hours']
            : <String, dynamic>{},
      ),
    );
    bool sponsored = row['is_sponsored'] == true;
    bool? openOverride = row['open_override'] as bool?;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Comercio · ' + (row['name']?.toString() ?? '')),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: minimum,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Pedido mínimo'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tags,
                    decoration: const InputDecoration(
                      labelText: 'Tags separados por coma',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hours,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Horario JSON',
                      hintText:
                          '{"mon":{"open":"09:00","close":"22:00"}}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<bool?>(
                    value: openOverride,
                    decoration:
                        const InputDecoration(labelText: 'Apertura manual'),
                    items: const [
                      DropdownMenuItem<bool?>(
                        value: null,
                        child: Text('Según horario'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: true,
                        child: Text('Forzar abierto'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: false,
                        child: Text('Forzar cerrado'),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => openOverride = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: sponsored,
                    onChanged: (v) => setLocal(() => sponsored = v),
                    title: const Text('Anuncio / patrocinado'),
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
      await _action(() async {
        dynamic parsed;
        try {
          parsed = jsonDecode(hours.text.trim().isEmpty ? '{}' : hours.text);
        } catch (_) {
          throw Exception('Horario JSON inválido');
        }
        await supabase.rpc(
          'admin_marketplace_update_merchant_v2',
          params: {
            'p_merchant_id': row['id'],
            'p_business_hours': parsed,
            'p_open_override': openOverride,
            'p_minimum_order': double.tryParse(minimum.text.trim()) ?? 0,
            'p_is_sponsored': sponsored,
            'p_tags': tags.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
          },
        );
      });
    }
    minimum.dispose();
    tags.dispose();
    hours.dispose();
  }

  String _couponSummary(Map<String, dynamic> row) {
    final type = row['discount_type']?.toString() ?? 'percent';
    final value = _v2Number(row['discount_value']);
    final amount = type == 'percent'
        ? value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2) + '%'
        : value.toStringAsFixed(2);
    return amount +
        ' · mínimo ' +
        _v2Number(row['min_order']).toStringAsFixed(2) +
        ' · financiado por ' +
        (row['funded_by']?.toString() ?? 'express');
  }
}

class _AdminV2Header extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _AdminV2Header({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _v2Ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: _v2Muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label + ': ' + value,
        style: const TextStyle(
          color: _v2Ink,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AdminRowCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> badges;
  final VoidCallback onEdit;

  const _AdminRowCard({
    required this.title,
    required this.subtitle,
    required this.badges,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: _v2Ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(color: _v2Muted, fontSize: 11),
              ),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: badges
                    .map(
                      (badge) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: _v2Blue,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          tooltip: 'Editar',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
      ),
    );
  }
}

class _AdminV2Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _AdminV2Empty({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: _v2Blue, size: 40),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: _v2Ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _v2Muted),
          ),
        ],
      ),
    );
  }
}

class _AdminV2Error extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _AdminV2Error({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _AdminV2Empty(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo cargar Express Delivery V2',
        text: error,
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
