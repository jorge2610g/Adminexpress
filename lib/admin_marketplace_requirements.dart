import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

class AdminMarketplaceRequirementsPage extends StatefulWidget {
  const AdminMarketplaceRequirementsPage({
    super.key,
    required this.channel,
    this.countryCode,
    this.zoneId,
  });

  final String channel;
  final String? countryCode;
  final String? zoneId;

  @override
  State<AdminMarketplaceRequirementsPage> createState() =>
      _AdminMarketplaceRequirementsPageState();
}

class _AdminMarketplaceRequirementsPageState
    extends State<AdminMarketplaceRequirementsPage> {
  List<Map<String, dynamic>> zones = [];
  List<Map<String, dynamic>> requirements = [];
  String? zoneId;
  bool loading = true;

  List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    zoneId = widget.zoneId;
    _load();
  }

  Future<void> _load() async {
    try {
      final countries = widget.countryCode == null
          ? const ['BO', 'CL']
          : [widget.countryCode!];
      final zoneLists = await Future.wait(countries.map((country) => supabase
          .rpc('admin_zone_list_for_country',
              params: {'p_country_code': country})));
      final allZones = zoneLists.expand(_rows).toList();
      final activeZones = allZones.where((z) => z['active'] != false).toList();
      final selected = activeZones.any((z) => z['id']?.toString() == zoneId)
          ? zoneId
          : activeZones.isNotEmpty
              ? activeZones.first['id']?.toString()
              : null;
      final list = selected == null
          ? <Map<String, dynamic>>[]
          : _rows(await supabase.rpc(
              'admin_marketplace_restaurant_requirements',
              params: {'p_zone_id': selected, 'p_channel': widget.channel},
            ));
      if (mounted)
        setState(() {
          zones = activeZones;
          zoneId = selected;
          requirements = list;
          loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _selectZone(String? id) async {
    if (id == null) return;
    setState(() {
      zoneId = id;
      loading = true;
    });
    try {
      final rows = _rows(await supabase.rpc(
        'admin_marketplace_restaurant_requirements',
        params: {'p_zone_id': id, 'p_channel': widget.channel},
      ));
      if (mounted)
        setState(() {
          requirements = rows;
          loading = false;
        });
    } catch (error) {
      if (mounted) setState(() => loading = false);
      _snack('No se pudieron cargar los requisitos: $error');
    }
  }

  Future<void> _edit({Map<String, dynamic>? row}) async {
    final label = TextEditingController(text: row?['label']?.toString() ?? '');
    final description = TextEditingController(
      text: row?['description']?.toString() ?? '',
    );
    final order = TextEditingController(
      text: (row?['sort_order'] ?? 100).toString(),
    );
    bool required = row?['required'] != false;
    bool active = row?['active'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Añadir requisito' : 'Editar requisito'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: label,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del requisito'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Qué debe cargar el restaurante'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: required,
                  onChanged: (value) => setLocal(() => required = value),
                  title: const Text('Obligatorio'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (value) => setLocal(() => active = value),
                  title: const Text('Activo'),
                ),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Orden de aparición'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (saved == true && zoneId != null) {
      try {
        await supabase
            .rpc('admin_marketplace_upsert_restaurant_requirement', params: {
          'p_id': row?['id'],
          'p_zone_id': zoneId,
          'p_channel': widget.channel,
          'p_label': label.text.trim(),
          'p_description': description.text.trim(),
          'p_required': required,
          'p_active': active,
          'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
        });
        await _selectZone(zoneId);
      } catch (error) {
        _snack('No se pudo guardar: $error');
      }
    }
    label.dispose();
    description.dispose();
    order.dispose();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar requisito'),
        content: Text(
            '¿Eliminar “${row['label'] ?? 'este requisito'}”? Si ya se enviaron documentos, puedes desactivarlo para conservar el historial.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.rpc('admin_marketplace_delete_restaurant_requirement',
          params: {'p_id': row['id']});
      if (zoneId != null) await _selectZone(zoneId);
    } catch (error) {
      _snack(error.toString().contains('documentos enviados')
          ? 'Ya hay documentos enviados. Desactiva este requisito para conservar el historial.'
          : 'No se pudo eliminar: $error');
    }
  }

  void _snack(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Requisitos de restaurantes')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text(
              'Configura qué documentos se solicitan en cada ciudad. Los cambios se guardan por separado para Prueba y Producción.',
              style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: zoneId,
            decoration: const InputDecoration(
                labelText: 'Ciudad', border: OutlineInputBorder()),
            items: zones
                .map((z) => DropdownMenuItem<String>(
                    value: z['id']?.toString(),
                    child: Text(
                        '${z['city'] ?? z['name'] ?? 'Ciudad'} · ${z['country_code'] ?? ''}')))
                .toList(),
            onChanged: _selectZone,
          ),
          const SizedBox(height: 14),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Expanded(
                              child: Text('Requisitos de esta ciudad',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800))),
                          FilledButton.icon(
                              onPressed: zoneId == null ? null : () => _edit(),
                              icon: const Icon(Icons.add),
                              label: const Text('Añadir'))
                        ]),
                        const SizedBox(height: 8),
                        if (loading) const LinearProgressIndicator(),
                        if (!loading && requirements.isEmpty)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                  'No hay requisitos añadidos para esta ciudad.')),
                        for (final row in requirements)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                                child: Icon(row['active'] == true
                                    ? Icons.description_outlined
                                    : Icons.pause_circle_outline)),
                            title:
                                Text(row['label']?.toString() ?? 'Requisito'),
                            subtitle: Text(
                                '${row['required'] == true ? 'Obligatorio' : 'Opcional'} · ${row['active'] == true ? 'Activo' : 'Desactivado'}${(row['description'] ?? '').toString().isEmpty ? '' : '\n${row['description']}'}'),
                            isThreeLine: (row['description'] ?? '')
                                .toString()
                                .isNotEmpty,
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _edit(row: row);
                                if (value == 'delete') _delete(row);
                                if (value == 'toggle')
                                  _edit(row: {
                                    ...row,
                                    'active': row['active'] != true
                                  });
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'edit', child: Text('Editar')),
                                PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(row['active'] == true
                                        ? 'Desactivar'
                                        : 'Activar')),
                                const PopupMenuItem(
                                    value: 'delete', child: Text('Eliminar')),
                              ],
                            ),
                          ),
                      ]))),
        ]),
      );
}
