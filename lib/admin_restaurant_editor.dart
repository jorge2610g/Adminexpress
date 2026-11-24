import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import 'admin_image_upload_field.dart';
import 'admin_restaurant_panel_access.dart';
import 'business_hours.dart';
import 'core/admin_friendly_error.dart';
import 'core/supabase_client.dart';

/// Editor completo de un restaurante para el administrador: datos, fotos, ubicación en el mapa,
/// horarios, tiempos y pedido mínimo, cuentas de acceso (correo, contraseña temporal) y
/// servicios y tarifas. Sirve también para crear un restaurante nuevo.
class AdminRestaurantEditorPage extends StatefulWidget {
  const AdminRestaurantEditorPage({
    super.key,
    required this.merchant,
    required this.categories,
    required this.zones,
    this.defaultZoneId,
    this.onEditServices,
  });

  /// null = restaurante nuevo.
  final Map<String, dynamic>? merchant;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> zones;
  final String? defaultZoneId;
  final Future<void> Function(Map<String, dynamic> merchant)? onEditServices;

  @override
  State<AdminRestaurantEditorPage> createState() => _AdminRestaurantEditorPageState();
}

class _AdminRestaurantEditorPageState extends State<AdminRestaurantEditorPage> {
  static const _line = Color(0xFFE4E7EC);

  String? _id;
  Map<String, dynamic> _row = {};
  bool _loading = true;
  bool _saving = false;

  String? _zoneId;
  String _categoryKey = '';
  bool _active = true;
  bool _visible = true;
  bool _sponsored = false;
  bool _openOverride = true;
  double _rating = 5;

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _logo = TextEditingController();
  final _cover = TextEditingController();
  final _address = TextEditingController();
  final _search = TextEditingController();
  final _minimum = TextEditingController();
  final _etaMin = TextEditingController(text: '15');
  final _etaMax = TextEditingController(text: '40');
  final _fee = TextEditingController(text: '0');
  final _order = TextEditingController(text: '100');
  final _transfer = TextEditingController();
  final _tags = TextEditingController();
  final _map = MapController();

  LatLng? _point;
  List<({String label, double lat, double lng})> _results = const [];
  bool _searching = false;
  Map<String, List<({String from, String to})>> _hours = parseBusinessHours(null);
  List<Map<String, dynamic>> _users = const [];
  final _newUserEmail = TextEditingController();

  @override
  void initState() {
    super.initState();
    _id = widget.merchant?['id']?.toString();
    _zoneId = widget.merchant?['zone_id']?.toString() ?? widget.defaultZoneId;
    _categoryKey = widget.merchant?['category_key']?.toString() ??
        (widget.categories.isEmpty ? '' : widget.categories.first['category_key']?.toString() ?? '');
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name, _description, _logo, _cover, _address, _search, _minimum, _etaMin, _etaMax,
      _fee, _order, _transfer, _tags, _newUserEmail
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _list(Object? v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  String _numText(Object? v, {int decimals = 2}) {
    final n = double.tryParse(v?.toString() ?? '');
    if (n == null) return '';
    return n.toStringAsFixed(decimals).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<void> _load() async {
    if (_id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final detail = await supabase.rpc('admin_marketplace_merchant_detail',
          params: {'p_merchant_id': _id});
      final m = detail is Map && detail['merchant'] is Map
          ? Map<String, dynamic>.from(detail['merchant'] as Map)
          : Map<String, dynamic>.from(widget.merchant ?? {});
      _row = m;
      _zoneId = m['zone_id']?.toString() ?? _zoneId;
      _categoryKey = m['category_key']?.toString() ?? _categoryKey;
      _name.text = m['name']?.toString() ?? '';
      _description.text = m['description']?.toString() ?? '';
      _logo.text = m['image_url']?.toString() ?? '';
      _cover.text = m['cover_image_url']?.toString() ?? '';
      _address.text = m['address']?.toString() ?? '';
      _minimum.text = _numText(m['minimum_order']);
      _etaMin.text = m['eta_min_minutes']?.toString() ?? '15';
      _etaMax.text = m['eta_max_minutes']?.toString() ?? '40';
      _fee.text = _numText(m['delivery_fee']);
      _order.text = m['sort_order']?.toString() ?? '100';
      _transfer.text = m['transfer_instructions']?.toString() ?? '';
      _tags.text = (m['tags'] is List ? (m['tags'] as List).join(', ') : '');
      _active = m['active'] != false;
      _visible = m['production_visible'] == true || m['preview_visible'] == true;
      _sponsored = m['is_sponsored'] == true;
      _openOverride = m['open_override'] != false;
      _rating = double.tryParse(m['rating']?.toString() ?? '') ?? 5;
      _hours = parseBusinessHours(m['business_hours']);
      final lat = double.tryParse(m['latitude']?.toString() ?? '');
      final lng = double.tryParse(m['longitude']?.toString() ?? '');
      if (lat != null && lng != null) _point = LatLng(lat, lng);
      await _loadUsers();
    } catch (e) {
      if (mounted) _snack('No se pudo cargar el restaurante: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUsers() async {
    if (_id == null) return;
    final value = await supabase.rpc('admin_marketplace_merchant_users',
        params: {'p_merchant_id': _id});
    if (mounted) setState(() => _users = _list(value));
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ── Ubicación ──
  Future<void> _searchAddress() async {
    final q = _search.text.trim();
    if (q.length < 3) return;
    setState(() => _searching = true);
    try {
      final zone = widget.zones.where((z) => z['id']?.toString() == _zoneId);
      final country = zone.isEmpty ? '' : (zone.first['country_code']?.toString() ?? '').toLowerCase();
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'q': q,
        'limit': '6',
        'accept-language': 'es',
        if (country.length == 2) 'countrycodes': country,
      });
      final response = await http.get(uri);
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() => _results = [
            if (data is List)
              for (final r in data.whereType<Map>())
                (
                  label: r['display_name']?.toString() ?? '',
                  lat: double.tryParse(r['lat']?.toString() ?? '') ?? 0,
                  lng: double.tryParse(r['lon']?.toString() ?? '') ?? 0,
                ),
          ]);
      if (_results.isEmpty) _snack('No encontré esa dirección. Marca el punto en el mapa.');
    } catch (_) {
      _snack('No se pudo buscar la dirección. Marca el punto en el mapa.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pickPoint(LatLng p, {String? label}) {
    setState(() {
      _point = p;
      _results = const [];
      if (label != null) _address.text = label;
    });
    try {
      _map.move(p, 16);
    } catch (_) {}
  }

  // ── Guardar ──
  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) return _snack('Escribe el nombre del restaurante.');
    if (_zoneId == null || _zoneId!.isEmpty) return _snack('Elige la zona.');
    if (_categoryKey.isEmpty) return _snack('Elige la categoría.');
    for (final day in businessHourDayKeys) {
      for (final r in _hours[day]!) {
        if (r.from.compareTo(r.to) >= 0) {
          return _snack('${businessHourDayNames[day]}: el cierre debe ser después de la apertura.');
        }
      }
    }
    setState(() => _saving = true);
    try {
      final saved = await supabase.rpc('admin_marketplace_upsert_merchant', params: {
        'p_id': _id,
        'p_zone_id': _zoneId,
        'p_category_key': _categoryKey,
        'p_name': name,
        'p_description': _description.text.trim(),
        'p_image_url': _logo.text.trim(),
        'p_active': _active,
        'p_preview_visible': _visible,
        'p_production_visible': _visible,
        'p_rating': _rating,
        'p_eta_min_minutes': int.tryParse(_etaMin.text.trim()) ?? 15,
        'p_eta_max_minutes': int.tryParse(_etaMax.text.trim()) ?? 40,
        'p_delivery_fee': double.tryParse(_fee.text.trim().replaceAll(',', '.')) ?? 0,
        'p_sort_order': int.tryParse(_order.text.trim()) ?? 100,
      });
      final id = (saved ?? _id)?.toString();
      if (id == null) throw StateError('No se pudo guardar el restaurante.');
      await supabase.rpc('admin_marketplace_update_merchant_v2', params: {
        'p_merchant_id': id,
        'p_business_hours': businessHoursToJson(_hours),
        'p_open_override': _openOverride,
        'p_minimum_order': double.tryParse(_minimum.text.trim().replaceAll(',', '.')) ?? 0,
        'p_is_sponsored': _sponsored,
        'p_tags': [
          for (final t in _tags.text.split(','))
            if (t.trim().isNotEmpty) t.trim(),
        ],
      });
      await supabase.rpc('admin_marketplace_update_merchant_logistics', params: {
        'p_merchant_id': id,
        'p_address': _address.text.trim(),
        'p_latitude': _point?.latitude,
        'p_longitude': _point?.longitude,
        'p_transfer_instructions': _transfer.text.trim(),
      });
      await supabase.rpc('admin_marketplace_set_merchant_media', params: {
        'p_merchant_id': id,
        'p_cover_image_url': _cover.text.trim(),
      });
      if (!mounted) return;
      if (_id == null) {
        _id = id;
        _snack('Restaurante creado. Ahora puedes vincular su cuenta.');
        setState(() => _row = {..._row, 'id': id, 'name': name});
        await _loadUsers();
      } else {
        _snack('Cambios guardados.');
      }
    } catch (e) {
      _snack('No se pudo guardar: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Cuentas de acceso ──
  Future<void> _assignUser() async {
    final email = _newUserEmail.text.trim();
    if (email.isEmpty || _id == null) return;
    try {
      await supabase.rpc('admin_marketplace_assign_merchant_user',
          params: {'p_merchant_id': _id, 'p_email': email, 'p_role': 'manager'});
      _newUserEmail.clear();
      await _loadUsers();
    } catch (e) {
      _snack('No se pudo vincular: ${friendlyError(e)}');
    }
  }

  Future<void> _toggleUser(Map<String, dynamic> u, bool active) async {
    try {
      await supabase.rpc('admin_marketplace_set_merchant_user_active', params: {
        'p_merchant_id': _id,
        'p_user_id': u['user_id'],
        'p_active': active,
      });
      await _loadUsers();
    } catch (e) {
      _snack('No se pudo cambiar: ${friendlyError(e)}');
    }
  }

  Future<void> _changeAccess(Map<String, dynamic> u) async {
    final email = TextEditingController(text: u['email']?.toString() ?? '');
    var generate = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('Correo y contraseña de la cuenta'),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo de acceso'),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: generate,
                onChanged: (v) => setLocal(() => generate = v),
                title: const Text('Generar contraseña temporal'),
                subtitle: const Text('Se muestra una sola vez al guardar. La anterior no se recupera.'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    final newEmail = email.text.trim();
    email.dispose();
    if (ok != true) return;
    try {
      final result = await supabase.functions.invoke('admin-restaurant-access', body: {
        'merchant_id': _id,
        'user_id': u['user_id'],
        'new_email': newEmail == (u['email']?.toString() ?? '') ? '' : newEmail,
        'generate_password': generate,
      });
      final data = result.data is Map ? Map<String, dynamic>.from(result.data as Map) : {};
      if (result.status < 200 || result.status >= 300) {
        throw StateError(data['error']?.toString() ?? 'No se pudo cambiar el acceso.');
      }
      final password = data['temporary_password']?.toString();
      await _loadUsers();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Acceso actualizado'),
          content: SelectableText('Correo: ${data['email'] ?? newEmail}\n'
              '${password == null ? 'Los cambios quedaron guardados.' : 'Contraseña temporal (solo se muestra ahora):\n$password\n\nEntrégala por un canal seguro.'}'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Listo')),
          ],
        ),
      );
    } catch (e) {
      var message = e.toString().replaceFirst('Bad state: ', '');
      if (e is FunctionException && e.details is Map && (e.details as Map)['error'] != null) {
        message = (e.details as Map)['error'].toString();
      }
      _snack(message);
    }
  }

  // ── Construcción ──
  Widget _section(String title, List<Widget> children, {String? hint}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
            ),
          const SizedBox(height: 14),
          ...children,
        ]),
      );

  Widget _gap([double h = 12]) => SizedBox(height: h);

  Future<void> _pickTime(String day, int i, bool from) async {
    final list = _hours[day]!;
    final current = (from ? list[i].from : list[i].to).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(current.first) ?? 9,
          minute: int.tryParse(current.length > 1 ? current[1] : '0') ?? 0),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    final text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => list[i] = from ? (from: text, to: list[i].to) : (from: list[i].from, to: text));
  }

  Widget _hoursEditor() => Column(children: [
        for (final day in businessHourDayKeys)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 96,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(businessHourDayNames[day]!,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  )),
              Switch(
                value: _hours[day]!.isNotEmpty,
                onChanged: (on) => setState(() => _hours[day] =
                    on ? [(from: '09:00', to: '22:00')] : <({String from, String to})>[]),
              ),
              Expanded(
                child: _hours[day]!.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text('Cerrado', style: TextStyle(color: Color(0xFF667085))))
                    : Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        for (var i = 0; i < _hours[day]!.length; i++) ...[
                          OutlinedButton(
                              onPressed: () => _pickTime(day, i, true),
                              child: Text(_hours[day]![i].from)),
                          const Text('a'),
                          OutlinedButton(
                              onPressed: () => _pickTime(day, i, false),
                              child: Text(_hours[day]![i].to)),
                          if (_hours[day]!.length > 1)
                            IconButton(
                                onPressed: () => setState(() => _hours[day]!.removeAt(i)),
                                icon: const Icon(Icons.close, size: 18)),
                        ],
                        if (_hours[day]!.length < 4)
                          TextButton(
                              onPressed: () => setState(
                                  () => _hours[day]!.add((from: '18:00', to: '22:00'))),
                              child: const Text('+ tramo')),
                        TextButton(
                            onPressed: () => setState(() {
                                  for (final d in businessHourDayKeys) {
                                    if (d != day) _hours[d] = List.of(_hours[day]!);
                                  }
                                }),
                            child: const Text('Copiar a todos')),
                      ]),
              ),
            ]),
          ),
      ]);

  Widget _mapEditor() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _searchAddress(),
              decoration: InputDecoration(
                labelText: 'Buscar dirección',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(onPressed: _searchAddress, icon: const Icon(Icons.arrow_forward)),
              ),
            ),
          ),
        ]),
        for (final r in _results)
          ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined),
            title: Text(r.label, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => _pickPoint(LatLng(r.lat, r.lng), label: r.label),
          ),
        _gap(),
        TextField(
          controller: _address,
          decoration: const InputDecoration(labelText: 'Dirección que ven los clientes'),
        ),
        _gap(),
        SizedBox(
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _point ?? const LatLng(-20.2307, -70.1357),
                initialZoom: _point == null ? 12 : 16,
                onTap: (_, p) => _pickPoint(p),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'online.expressviajes.admin',
                ),
                if (_point != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: _point!,
                      width: 44,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_pin, size: 44, color: Color(0xFFC2413B)),
                    ),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _point == null
              ? 'Toca el mapa para marcar dónde está el restaurante.'
              : 'Ubicación: ${_point!.latitude.toStringAsFixed(6)}, ${_point!.longitude.toStringAsFixed(6)} · toca otro punto para moverla.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
        ),
      ]);

  Widget _accessSection() {
    if (_id == null) {
      return const Text('Guarda el restaurante primero para vincular su cuenta de acceso.',
          style: TextStyle(color: Color(0xFF667085)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_users.isEmpty)
        const Text('Todavía no hay cuentas vinculadas. La persona debe tener una cuenta Express con ese correo.',
            style: TextStyle(color: Color(0xFF667085))),
      for (final u in _users)
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: u['active'] == true,
          onChanged: (v) => _toggleUser(u, v),
          secondary: IconButton(
            tooltip: 'Cambiar correo o generar contraseña temporal',
            onPressed: () => _changeAccess(u),
            icon: const Icon(Icons.key_outlined),
          ),
          title: Text((u['full_name']?.toString().trim().isNotEmpty == true)
              ? u['full_name'].toString()
              : (u['email']?.toString() ?? 'Usuario')),
          subtitle: Text('${u['email'] ?? ''} · ${u['role'] ?? 'manager'}'),
        ),
      _gap(),
      TextField(
        controller: _newUserEmail,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: 'Vincular otra cuenta (correo)',
          suffixIcon: IconButton(onPressed: _assignUser, icon: const Icon(Icons.person_add_alt_1)),
        ),
      ),
      _gap(),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          onPressed: () => goToRestaurantPanel(context, {..._row, 'id': _id, 'name': _name.text}),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Ir al panel del restaurante'),
        ),
        if (widget.onEditServices != null)
          OutlinedButton.icon(
            onPressed: () async {
              await widget.onEditServices!({..._row, 'id': _id, 'name': _name.text});
              await _load();
            },
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Servicios y tarifas'),
          ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _id == null;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(isNew ? 'Nuevo restaurante' : 'Editar · ${_name.text}'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1D2433),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar cambios'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _section('Datos del restaurante', [
                      DropdownButtonFormField<String>(
                        initialValue: widget.zones.any((z) => z['id']?.toString() == _zoneId)
                            ? _zoneId
                            : null,
                        decoration: const InputDecoration(labelText: 'Zona'),
                        items: [
                          for (final z in widget.zones)
                            DropdownMenuItem(
                                value: z['id']?.toString(),
                                child: Text('${z['name'] ?? z['zone_key'] ?? 'Zona'}')),
                        ],
                        onChanged: (v) => setState(() => _zoneId = v),
                      ),
                      _gap(),
                      DropdownButtonFormField<String>(
                        initialValue: widget.categories.any((c) => c['category_key']?.toString() == _categoryKey)
                            ? _categoryKey
                            : null,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: [
                          for (final c in widget.categories)
                            DropdownMenuItem(
                                value: c['category_key']?.toString(),
                                child: Text(c['name']?.toString() ?? '')),
                        ],
                        onChanged: (v) => setState(() => _categoryKey = v ?? ''),
                      ),
                      _gap(),
                      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
                      _gap(),
                      TextField(
                          controller: _description,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Descripción')),
                      _gap(),
                      TextField(
                          controller: _tags,
                          decoration: const InputDecoration(
                              labelText: 'Etiquetas', helperText: 'Separadas por coma: pizza, familiar')),
                      _gap(),
                      TextField(
                          controller: _order,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Orden en la lista', helperText: 'Menor número aparece primero')),
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _active,
                          onChanged: (v) => setState(() => _active = v),
                          title: const Text('Restaurante activo')),
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _visible,
                          onChanged: (v) => setState(() => _visible = v),
                          title: const Text('Disponible para los clientes en la app')),
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _sponsored,
                          onChanged: (v) => setState(() => _sponsored = v),
                          title: const Text('Destacado (patrocinado)')),
                    ]),
                    _section('Fotos', [
                      AdminImageUploadField(controller: _logo, label: 'Logo'),
                      _gap(16),
                      AdminImageUploadField(controller: _cover, label: 'Portada'),
                    ], hint: 'Se eligen de la galería y se suben solas.'),
                    _section('Ubicación', [_mapEditor()],
                        hint: 'De aquí sale el punto de recogida de los repartidores.'),
                    _section('Horarios', [_hoursEditor()],
                        hint: 'Los clientes ven estos horarios. Un día sin tramos aparece cerrado.'),
                    _section('Pedidos y envío', [
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: _minimum,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Pedido mínimo'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextField(
                                controller: _etaMin,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Preparación mín. (min)'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextField(
                                controller: _etaMax,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Preparación máx. (min)'))),
                      ]),
                      _gap(),
                      TextField(
                          controller: _fee,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Costo de envío que se muestra',
                              helperText: 'Lo que se cobra de verdad se configura en «Servicios y tarifas».')),
                      _gap(),
                      TextField(
                          controller: _transfer,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Datos para pagos por transferencia',
                              hintText: 'Banco, cuenta, titular…')),
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _openOverride,
                          onChanged: (v) => setState(() => _openOverride = v),
                          title: const Text('Recibiendo pedidos ahora')),
                    ]),
                    _section('Cuentas de acceso y servicios', [_accessSection()],
                        hint: 'Quién entra al portal del restaurante y qué servicios tiene.'),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ]),
    );
  }
}
