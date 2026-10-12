import 'package:flutter/material.dart';

import 'core/supabase_client.dart';
import 'admin_marketplace.dart';
import 'admin_marketplace_demos.dart';
import 'admin_marketplace_phase2.dart';
import 'admin_delivery_settlements.dart';

/// Admin central: a single Delivery menu, shared merchant IDs, scoped by zone
/// and the authenticated account's runtime. No writes happen on page load.
class AdminDeliveryUnifiedPage extends StatefulWidget {
  final String channel;
  final String? countryCode;
  final String? zoneId;
  final bool readOnly;
  final Widget Function()? buildDirectDeliveries;

  const AdminDeliveryUnifiedPage({
    super.key,
    required this.channel,
    this.countryCode,
    this.zoneId,
    this.readOnly = false,
    this.buildDirectDeliveries,
  });

  @override
  State<AdminDeliveryUnifiedPage> createState() =>
      _AdminDeliveryUnifiedPageState();
}

class _AdminDeliveryUnifiedPageState extends State<AdminDeliveryUnifiedPage> {
  int selectedTab = 0;
  String statusFilter = 'all';
  final search = TextEditingController();
  late Future<Map<String, dynamic>> businesses;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant AdminDeliveryUnifiedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoneId != widget.zoneId ||
        oldWidget.channel != widget.channel ||
        oldWidget.countryCode != widget.countryCode) {
      _refresh();
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _refresh() {
    businesses = _loadBusinesses();
    revision++;
  }

  Future<Map<String, dynamic>> _loadBusinesses() async {
    if ((widget.zoneId ?? '').isEmpty ||
        (widget.countryCode ?? '').isEmpty) {
      return {'merchants': <dynamic>[]};
    }
    final data = await supabase.rpc('admin_marketplace_state_scoped', params: {
      'p_country_code': widget.countryCode,
      'p_zone_id': widget.zoneId,
    });
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  List<Map<String, dynamic>> _rows(Object? raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m)).toList();
  }

  bool _visible(Map<String, dynamic> row) =>
      row[widget.channel == 'preview'
          ? 'preview_visible' : 'production_visible'] == true;

  String _merchantStatus(Map<String, dynamic> row) {
    if (row['active'] != true) return 'inactive';
    return _visible(row) ? 'active' : 'pending';
  }

  String _statusLabel(String status) => switch (status) {
    'active' => 'Activo',
    'pending' => 'Pendiente de publicar',
    'inactive' => 'Inactivo',
    _ => 'Todos',
  };

  void _openProducts(Map<String, dynamic> merchant) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AdminMerchantCatalogPage(merchant: merchant),
    ));
    if (mounted) setState(_refresh);
  }

  Future<void> _openMerchant(Map<String, dynamic> merchant) async {
    await showDialog<void>(context: context, builder: (_) =>
        _UnifiedMerchantDialog(
          merchant: merchant,
          channel: widget.channel,
          readOnly: widget.readOnly,
          openProducts: () {
            Navigator.of(context, rootNavigator: true).pop();
            _openProducts(merchant);
          },
        ));
    if (mounted) setState(_refresh);
  }

  Widget _businesses() => FutureBuilder<Map<String, dynamic>>(
    future: businesses,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('No se pudieron cargar los locales: ${snapshot.error}'),
          TextButton(onPressed: () => setState(_refresh),
              child: const Text('Reintentar')),
        ]));
      }
      final all = _rows(snapshot.data?['merchants']);
      final needle = search.text.trim().toLowerCase();
      final filtered = all.where((row) {
        final matchText = needle.isEmpty ||
            (row['name'] ?? '').toString().toLowerCase().contains(needle) ||
            (row['category_key'] ?? '').toString().toLowerCase().contains(needle);
        return matchText &&
            (statusFilter == 'all' || _merchantStatus(row) == statusFilter);
      }).toList();
      final pending = all.where((r) => _merchantStatus(r) == 'pending').length;
      final active = all.where((r) => _merchantStatus(r) == 'active').length;
      final inactive = all.where((r) => _merchantStatus(r) == 'inactive').length;
      return ListView(padding: const EdgeInsets.all(18), children: [
        Text('Negocios de la zona', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('${all.length} locales registrados · $active activos · '
            '$pending pendientes · $inactive inactivos',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(spacing: 9, runSpacing: 9, children: [
          SizedBox(width: 250, child: TextField(
            controller: search,
            decoration: const InputDecoration(
              hintText: 'Buscar negocio o categoría',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          )),
          for (final status in ['all','active','pending','inactive'])
            ChoiceChip(
              label: Text('${_statusLabel(status)}'
                '${status == 'all' ? ' (${all.length})' : ''}'),
              selected: statusFilter == status,
              onSelected: (_) => setState(() => statusFilter = status),
            ),
          IconButton(onPressed: () => setState(_refresh),
            tooltip: 'Actualizar', icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 16),
        if (filtered.isEmpty) const Card(child: Padding(
          padding: EdgeInsets.all(22),
          child: Text('No hay comercios con este filtro en la zona seleccionada.'),
        )),
        for (final merchant in filtered)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.storefront)),
              title: Text(merchant['name']?.toString() ?? 'Comercio',
                style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${merchant['category_key'] ?? 'Sin categoría'}'
                ' · ${_statusLabel(_merchantStatus(merchant))}'
                ' · ${widget.channel.toUpperCase()}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openMerchant(merchant),
            ),
          ),
        const SizedBox(height: 20),
        if (!widget.readOnly && (widget.zoneId ?? '').isNotEmpty)
          AdminMarketplaceDemoSection(
            zoneId: widget.zoneId!,
            channel: widget.channel,
            onOpenProducts: _openProducts,
          ),
      ]);
    },
  );

  @override
  Widget build(BuildContext context) {
    final choices = <(String, IconData)>[
      ('Negocios', Icons.storefront),
      ('Banners y categorías', Icons.campaign),
      ('Tarifas y Plus', Icons.local_shipping),
      ('Pedidos', Icons.receipt_long),
      ('Envíos directos', Icons.inventory_2),
      ('Liquidaciones', Icons.account_balance_wallet),
    ];
    Widget page = switch (selectedTab) {
      0 => _businesses(),
      1 => AdminMarketplacePage(
        key: ValueKey('promos-${widget.channel}-${widget.zoneId}'),
        channel: widget.channel,
        zoneId: widget.zoneId,
        countryCode: widget.countryCode,
        showMerchants: false,
      ),
      2 => AdminMarketplacePhase2Page(
        key: ValueKey('logistics-${widget.channel}-${widget.zoneId}'),
        channel: widget.channel, zoneId: widget.zoneId,
        countryCode: widget.countryCode,
      ),
      3 => AdminMarketplacePhase2Page(
        key: ValueKey('orders-${widget.channel}-${widget.zoneId}'),
        ordersOnly: true, channel: widget.channel,
        zoneId: widget.zoneId, countryCode: widget.countryCode,
      ),
      4 => widget.buildDirectDeliveries?.call() ??
          const Center(child: Text('Envíos no disponibles para esta cuenta.')),
      _ => AdminDeliverySettlementsPage(
        key: ValueKey('settlements-${widget.channel}-${widget.zoneId}'),
        channel: widget.channel, zoneId: widget.zoneId,
      ),
    };
    return Column(children: [
      Material(color: Colors.white, child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_shipping, color: Color(0xFF2563EB)),
            const SizedBox(width: 9),
            Text('Delivery', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            Chip(label: Text(widget.channel == 'preview'
                ? 'PRUEBAS' : 'PRODUCCIÓN')),
          ]),
          const Text('Comercios, productos, publicidad, repartos, '
            'Express Plus y liquidaciones en un solo lugar.'),
          const SizedBox(height: 10),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < choices.length; i++)
                Padding(padding: const EdgeInsets.only(right: 7), child:
                  ChoiceChip(
                    avatar: Icon(choices[i].$2, size: 17),
                    label: Text(choices[i].$1),
                    selected: selectedTab == i,
                    onSelected: (_) => setState(() => selectedTab = i),
                  )),
            ])),
        ]),
      )),
      Expanded(child: page),
    ]);
  }
}

class _UnifiedMerchantDialog extends StatefulWidget {
  final Map<String, dynamic> merchant;
  final String channel;
  final bool readOnly;
  final VoidCallback openProducts;
  const _UnifiedMerchantDialog({
    required this.merchant, required this.channel,
    required this.readOnly, required this.openProducts,
  });

  @override
  State<_UnifiedMerchantDialog> createState() => _UnifiedMerchantDialogState();
}

class _UnifiedMerchantDialogState extends State<_UnifiedMerchantDialog> {
  late Future<Map<String, dynamic>> info;
  bool busy = false;

  @override
  void initState() { super.initState(); _reload(); }
  void _reload() {
    info = () async {
      final value = await supabase.rpc('admin_marketplace_merchant_detail',
        params: {'p_merchant_id': widget.merchant['id']});
      return value is Map ? Map<String, dynamic>.from(value) : {};
    }();
  }
  List<Map<String, dynamic>> _products(Object? data) =>
      data is List ? data.whereType<Map>().map((m) =>
        Map<String, dynamic>.from(m)).toList() : [];

  Future<void> _updatePromotion(Map<String, dynamic> row, bool value) async {
    if (busy || widget.readOnly) return;
    setState(() => busy = true);
    try {
      await supabase.rpc('admin_marketplace_update_merchant_v2', params: {
        'p_merchant_id': row['id'],
        'p_business_hours': row['business_hours'] ?? <String, dynamic>{},
        'p_open_override': row['open_override'],
        'p_minimum_order': row['minimum_order'] ?? 0,
        'p_is_sponsored': value,
        'p_tags': row['tags'] is List ? row['tags'] : <String>[],
      });
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se guardó el destacado: $e')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _updateFeaturedProduct(
      Map<String, dynamic> p, bool featured) async {
    if (busy || widget.readOnly) return;
    setState(() => busy = true);
    try {
      await supabase.rpc('admin_marketplace_update_product_v2', params: {
        'p_product_id': p['id'],
        'p_menu_section_id': p['menu_section_id'],
        'p_compare_at_price': p['compare_at_price'],
        'p_promo_price': p['promo_price'],
        'p_promo_label': p['promo_label'],
        'p_promo_start_at': p['promo_start_at'],
        'p_promo_end_at': p['promo_end_at'],
        'p_is_sponsored': p['is_sponsored'] == true,
        'p_is_featured': featured,
        'p_tags': p['tags'] is List ? p['tags'] : <String>[],
      });
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se guardó el producto: $e')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _bannerForMerchant(Map<String, dynamic> row) async {
    if (widget.readOnly || busy) return;
    final title = TextEditingController(
      text: 'Descubre ${row['name'] ?? 'este local'}');
    final subtitle = TextEditingController(
      text: 'Productos y ofertas disponibles en tu zona.');
    final result = await showDialog<bool>(context: context, builder: (c) =>
      AlertDialog(title: const Text('Banner promocional'), content: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const Text('Este banner es informativo. La app actual no admite '
            'todavía abrir directamente el restaurante al tocarlo.'),
          TextField(controller: title, decoration:
            const InputDecoration(labelText: 'Título del banner')),
          TextField(controller: subtitle, decoration:
            const InputDecoration(labelText: 'Descripción')),
        ]), actions: [
          TextButton(onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true),
            child: const Text('Crear banner')),
        ]));
    final name = title.text.trim();
    final description = subtitle.text.trim();
    title.dispose(); subtitle.dispose();
    if (result != true || name.isEmpty || !mounted) return;
    setState(() => busy = true);
    try {
      await supabase.rpc('admin_marketplace_upsert_banner', params: {
        'p_id': null,
        'p_title': name, 'p_subtitle': description,
        'p_cta_label': row['name']?.toString() ?? '',
        'p_style_key': 'blue', 'p_active': true,
        'p_preview_visible': widget.channel == 'preview',
        'p_production_visible': false,
        'p_sort_order': 100,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banner guardado. Revisa la sección '
          'Banners y categorías para editarlo.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se creó el banner: $e')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Dialog(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 800, maxHeight: 740),
    child: FutureBuilder<Map<String, dynamic>>(
      future: info,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: snapshot.hasError ?
            Text('Error al abrir negocio: ${snapshot.error}') :
            const CircularProgressIndicator());
        }
        final raw = snapshot.data!;
        final row = raw['merchant'] is Map
            ? Map<String, dynamic>.from(raw['merchant'] as Map)
            : widget.merchant;
        final products = _products(raw['products']);
        final visible = row[widget.channel == 'preview'
            ? 'preview_visible' : 'production_visible'] == true;
        return ListView(padding: const EdgeInsets.all(21), children: [
          Row(children: [
            const Icon(Icons.storefront, color: Color(0xFF2563EB)),
            const SizedBox(width: 9),
            Expanded(child: Text(row['name']?.toString() ?? 'Comercio',
              style: Theme.of(context).textTheme.titleLarge)),
            IconButton(onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
          ]),
          Text('Zona del comercio · ${widget.channel.toUpperCase()} · '
            '${row['active'] != true ? 'Inactivo' : visible ?
              'Activo' : 'Pendiente de publicar'}'),
          const Divider(),
          const Text('Perfil y visibilidad',
            style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Categoría: ${row['category_key'] ?? '-'}'),
          Text('Dirección: ${row['address'] ?? 'Sin configurar'}'),
          Text('Tiempo de entrega: ${row['eta_min_minutes'] ?? '-'}-'
            '${row['eta_max_minutes'] ?? '-'} minutos'),
          Text('Productos: ${products.length}'),
          const SizedBox(height: 12),
          const Text('Publicidad del negocio',
            style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Negocio destacado / patrocinado'),
            subtitle: const Text('Prioriza el local en las secciones '
                'patrocinadas de Delivery.'),
            value: row['is_sponsored'] == true,
            onChanged: widget.readOnly || busy ? null :
              (v) => _updatePromotion(row, v),
          ),
          const Text('Productos destacados',
            style: TextStyle(fontWeight: FontWeight.bold)),
          for (final p in products)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(p['name']?.toString() ?? 'Producto'),
              subtitle: Text('${p['currency_code'] ?? ''} ${p['price'] ?? ''}'),
              value: p['is_featured'] == true,
              onChanged: widget.readOnly || busy ? null :
                (v) => _updateFeaturedProduct(p, v),
            ),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 9, children: [
            OutlinedButton.icon(onPressed: widget.openProducts,
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Editar menú y productos')),
            OutlinedButton.icon(
              onPressed: widget.readOnly || busy ? null :
                () => _bannerForMerchant(row),
              icon: const Icon(Icons.campaign),
              label: const Text('Crear banner del local')),
          ]),
          const SizedBox(height: 12),
          const Text('Para editar la ubicación, métodos de cobro y beneficios '
            'Express Plus utiliza la pestaña Tarifas y Plus de este mismo '
            'módulo Delivery.', style: TextStyle(fontSize: 12)),
        ]);
      },
    ),
  ));
}
