import 'package:flutter/material.dart';
import 'core/admin_friendly_error.dart';
import 'core/admin_friendly_labels.dart';
import 'core/admin_hero.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/supabase_client.dart';
import 'admin_marketplace.dart';
import 'admin_marketplace_phase2.dart';
import 'admin_restaurant_panel_access.dart';
import 'admin_delivery_settlements.dart';
import 'admin_delivery_dashboard.dart';

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
    revision++;
  }

  void _openProducts(Map<String, dynamic> merchant) =>
      goToRestaurantPanel(context, merchant);

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


  // Preview shares the administrator's existing permissions. It is not
  // an impersonation session and never grants merchant credentials.
  Future<void> _previewMerchant(Map<String, dynamic> merchant) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _DeliveryMerchantPreview(
        merchant: merchant, channel: widget.channel,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final choices = <(String, IconData)>[
      ('Resumen', Icons.dashboard_outlined),
      ('Restaurantes', Icons.storefront),
      ('Banners y categorías', Icons.campaign),
      ('Tarifas y Plus', Icons.local_shipping),
      ('Pedidos', Icons.receipt_long),
      ('Envíos directos', Icons.inventory_2),
      ('Liquidaciones', Icons.account_balance_wallet),
    ];
    Widget page = switch (selectedTab) {
      0 => AdminDeliveryDashboard(
        key: ValueKey('summary-${widget.channel}-${widget.zoneId}'),
        channel: widget.channel,
        zoneId: widget.zoneId,
        onOpenTab: (tab) => setState(() => selectedTab = tab),
      ),
      1 => AdminMarketplacePage(
        key: ValueKey('restaurants-${widget.channel}-${widget.zoneId}'),
        channel: widget.channel,
        zoneId: widget.zoneId,
        countryCode: widget.countryCode,
        showPromos: false,
        merchantActions: [
          (label: 'Promociones y destacados', onTap: _openMerchant),
          (label: 'Vista del local (como la ve el cliente)', onTap: _previewMerchant),
        ],
      ),
      2 => AdminMarketplacePage(
        key: ValueKey('promos-${widget.channel}-${widget.zoneId}'),
        channel: widget.channel,
        zoneId: widget.zoneId,
        countryCode: widget.countryCode,
        showMerchants: false,
      ),
      3 => AdminMarketplacePhase2Page(
        key: ValueKey('logistics-${widget.channel}-${widget.zoneId}'),
        channel: widget.channel, zoneId: widget.zoneId,
        countryCode: widget.countryCode,
      ),
      4 => AdminMarketplacePhase2Page(
        key: ValueKey('orders-${widget.channel}-${widget.zoneId}'),
        ordersOnly: true, channel: widget.channel,
        zoneId: widget.zoneId, countryCode: widget.countryCode,
      ),
      5 => widget.buildDirectDeliveries?.call() ??
          const Center(child: Text('Envíos no disponibles para esta cuenta.')),
      6 => AdminDeliverySettlementsPage(
        key: ValueKey('settlements-${widget.channel}-${widget.zoneId}'),
        channel: widget.channel, zoneId: widget.zoneId,
      ),
      _ => const Center(child: Text('Sección no disponible.')),
    };

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: AdminHero(
          icon: Icons.local_shipping_rounded,
          title: 'Delivery',
          subtitle: 'Gestión unificada de comercios y repartos',
          badge: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(20)),
            child: Text(
              widget.channel == 'preview' ? 'PRUEBAS' : 'PRODUCCIÓN',
              style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
          ),
        ),
      ),
      Material(color: Colors.white, child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(builder: (context, box) {
              // Las 7 secciones caben en una sola fila en pantallas anchas.
              final cols = box.maxWidth >= 1120 ? 7
                  : box.maxWidth >= 600 ? 4 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: choices.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 8, crossAxisSpacing: 8,
                  mainAxisExtent: 58,
                ),
                itemBuilder: (context, index) {
                  final chosen = index == selectedTab;
                  return Semantics(
                    button: true, selected: chosen,
                    child: Material(
                      color: chosen ? const Color(0xFF2563EB)
                        : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => selectedTab = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          decoration: BoxDecoration(
                            border: Border.all(color: chosen
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(choices[index].$2, size: 18,
                                color: chosen ? Colors.white
                                  : const Color(0xFF475569)),
                              const SizedBox(width: 5),
                              Flexible(child: Text(choices[index].$1,
                                textAlign: TextAlign.center,
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: chosen ? Colors.white
                                    : const Color(0xFF334155)))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
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
      return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
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
        'p_preview_visible': true,
        'p_production_visible': true,
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
            Text('${friendlyError(snapshot.error)}') :
            const CircularProgressIndicator());
        }
        final raw = snapshot.data!;
        final row = raw['merchant'] is Map
            ? Map<String, dynamic>.from(raw['merchant'] as Map)
            : widget.merchant;
        final products = _products(raw['products']);
        final visible = row['production_visible'] == true;
        return ListView(padding: const EdgeInsets.all(21), children: [
          Row(children: [
            const Icon(Icons.storefront, color: Color(0xFF2563EB)),
            const SizedBox(width: 9),
            Expanded(child: Text(row['name']?.toString() ?? 'Comercio',
              style: Theme.of(context).textTheme.titleLarge)),
            IconButton(onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
          ]),
          Text('Catálogo compartido · '
            '${row['active'] != true ? 'Inactivo' : visible ?
              'Activo' : 'Pendiente de publicar'}'),
          const Divider(),
          if (widget.readOnly) const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Vista administrativa de solo lectura. No es una sesión del dueño del restaurante.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          const Text('Perfil y visibilidad',
            style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Categoría: ${friendlyCategory((row['category_key'] ?? '-').toString())}'),
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
            OutlinedButton.icon(onPressed: widget.readOnly ? null : widget.openProducts,
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Ir al panel del restaurante')),
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


/// Read-only view of the merchant, fetched with the signed-in administrator's
/// existing access rights. No merchant password, session swap or role elevation.
class _DeliveryMerchantPreview extends StatefulWidget {
  final Map<String, dynamic> merchant;
  final String channel;
  const _DeliveryMerchantPreview({
    required this.merchant, required this.channel,
  });

  @override
  State<_DeliveryMerchantPreview> createState() =>
      _DeliveryMerchantPreviewState();
}

class _DeliveryMerchantPreviewState extends State<_DeliveryMerchantPreview> {
  late final Future<Map<String, dynamic>> details = () async {
    final data = await supabase.rpc('admin_marketplace_merchant_detail',
      params: {'p_merchant_id': widget.merchant['id']});
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF1F5F9),
    appBar: AppBar(
      title: const Text('Vista administrativa del local'),
      leading: IconButton(
        tooltip: 'Volver a Delivery',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: details,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: snapshot.hasError
            ? const Text('No se pudo cargar el restaurante.')
            : const CircularProgressIndicator());
        }
        final raw = snapshot.data!;
        final merchant = raw['merchant'] is Map
          ? Map<String, dynamic>.from(raw['merchant'] as Map)
          : widget.merchant;
        final products = raw['products'] is List
          ? (raw['products'] as List).whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p)).toList()
          : <Map<String, dynamic>>[];
        final featured = products.where(
          (p) => p['is_featured'] == true).length;
        return LayoutBuilder(builder: (context, bounds) {
          final width = bounds.maxWidth;
          final columns = width >= 1050 ? 3
              : width >= 620 ? 2 : 1;
          return ListView(
            padding: EdgeInsets.all(width < 600 ? 12 : 20),
            children: [
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RESUMEN DEL LOCAL · SOLO LECTURA',
                      style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2563EB))),
                    const SizedBox(height: 8),
                    Text(merchant['name']?.toString() ?? 'Restaurante',
                      style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(friendlyCategory(merchant['category_key']?.toString() ?? 'Comercio')
                      + ' · ' + (widget.channel == 'preview' ? 'Prueba' : 'Producción'),
                      style: const TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(height: 7),
                    Text(merchant['address']?.toString() ??
                        'Sin dirección configurada',
                      style: const TextStyle(fontSize: 12)),
                    const Divider(height: 24),
                    const Text('Esta es una vista administrativa. Para '
                      'gestionar pedidos y productos, el propietario debe '
                      'acceder con su propia cuenta al portal de restaurantes.',
                      style: TextStyle(fontSize: 12,
                        color: Color(0xFF475569))),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Abrir portal de propietarios'),
                      onPressed: () => launchUrl(
                        Uri.parse('https://expressviajes.online/restaurantes/'),
                        mode: LaunchMode.externalApplication),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _previewMetric('Productos',
                  products.length.toString(), Icons.restaurant_menu_outlined)),
                const SizedBox(width: 9),
                Expanded(child: _previewMetric('Destacados',
                  featured.toString(), Icons.star_border_rounded)),
              ]),
              const SizedBox(height: 18),
              Text('Productos del local', style: Theme.of(context)
                .textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (products.isEmpty)
                const Card(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Este negocio no tiene productos registrados.'),
                )),
              if (products.isNotEmpty)
                GridView.builder(
                  itemCount: products.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 10, crossAxisSpacing: 10,
                    mainAxisExtent: 110,
                  ),
                  itemBuilder: (context, index) {
                    final p = products[index];
                    return Card(child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Row(children: [
                        const Icon(Icons.lunch_dining_outlined,
                          color: Color(0xFF2563EB)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['name']?.toString() ?? 'Producto',
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text((p['currency_code']?.toString() ?? '')
                              + ' ' + (p['price']?.toString() ?? ''),
                              style: const TextStyle(fontSize: 12,
                                color: Color(0xFF64748B))),
                            if (p['is_featured'] == true)
                              const Text('★ Destacado',
                                style: TextStyle(fontSize: 11,
                                  color: Color(0xFFB45309))),
                          ],
                        )),
                      ]),
                    ));
                  },
                ),
            ],
          );
        });
      },
    ),
  );

  Widget _previewMetric(String label, String count, IconData icon) =>
    Card(child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF2563EB)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(
              color: Color(0xFF64748B), fontSize: 11)),
            Text(count, style: const TextStyle(fontSize: 21,
              fontWeight: FontWeight.w900)),
          ],
        )),
      ]),
    ));
}
