import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

class AdminDriverDocumentRequirementsPanel extends StatefulWidget {
  final String channel;

  const AdminDriverDocumentRequirementsPanel({
    super.key,
    required this.channel,
  });

  @override
  State<AdminDriverDocumentRequirementsPanel> createState() =>
      _AdminDriverDocumentRequirementsPanelState();
}

class _AdminDriverDocumentRequirementsPanelState
    extends State<AdminDriverDocumentRequirementsPanel> {
  int revision = 0;

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  Future<({List<Map<String, dynamic>> requirements, List<Map<String, dynamic>> zones})>
      _load() async {
    final values = await Future.wait([
      supabase.rpc('admin_driver_document_requirement_list'),
      supabase.rpc('admin_zone_list_v2'),
    ]);
    return (
      requirements: _list(values[0]),
      zones: _list(values[1]),
    );
  }

  Future<void> _edit({
    Map<String, dynamic>? row,
    required List<Map<String, dynamic>> zones,
  }) async {
    final code = TextEditingController(text: row?['code']?.toString() ?? '');
    final label = TextEditingController(text: row?['label']?.toString() ?? '');
    final description =
        TextEditingController(text: row?['description']?.toString() ?? '');
    final sortOrder = TextEditingController(
      text: (row?['sort_order'] ?? 100).toString(),
    );

    String scope = row?['zone_id'] != null
        ? 'zone'
        : row?['country_code'] != null
            ? 'country'
            : 'global';
    String? countryCode = row?['country_code']?.toString();
    String? zoneId = row?['zone_id']?.toString();
    bool required = row?['required'] != false;
    bool requireNumber = row?['require_number'] == true;
    bool requireFront = row?['require_front'] != false;
    bool requireBack = row?['require_back'] == true;
    bool requireSelfie = row?['require_selfie'] == true;
    bool active = row?['active'] != false;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          final zoneOptions = zones.where((zone) {
            if (countryCode == null || countryCode!.isEmpty) return true;
            return zone['country_code']?.toString() == countryCode;
          }).toList();

          return AlertDialog(
            title: Text(row == null ? 'Nuevo documento requerido' : 'Editar documento requerido'),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB)),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Define qué documento debe cargar el conductor. Puedes aplicarlo a todos, a un país o solamente a una ciudad.',
                              style: TextStyle(fontSize: 11, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: label,
                      decoration: const InputDecoration(
                        labelText: 'Nombre visible',
                        hintText: 'Carné de identidad, Licencia...',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: code,
                      decoration: const InputDecoration(
                        labelText: 'Código interno',
                        hintText: 'identity_card',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: description,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: scope,
                      decoration: const InputDecoration(
                        labelText: 'Aplicar a',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'global', child: Text('Todas las ciudades')),
                        DropdownMenuItem(value: 'country', child: Text('Un país')),
                        DropdownMenuItem(value: 'zone', child: Text('Una ciudad')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setLocal(() {
                          scope = value;
                          if (scope == 'global') {
                            countryCode = null;
                            zoneId = null;
                          } else if (scope == 'country') {
                            zoneId = null;
                          }
                        });
                      },
                    ),
                    if (scope != 'global') ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: countryCode,
                        decoration: const InputDecoration(labelText: 'País'),
                        items: const [
                          DropdownMenuItem(value: 'BO', child: Text('Bolivia')),
                          DropdownMenuItem(value: 'CL', child: Text('Chile')),
                        ],
                        onChanged: (value) => setLocal(() {
                          countryCode = value;
                          if (zoneId != null &&
                              !zoneOptions.any((z) => z['id']?.toString() == zoneId)) {
                            zoneId = null;
                          }
                        }),
                      ),
                    ],
                    if (scope == 'zone') ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: zoneId,
                        decoration: const InputDecoration(labelText: 'Ciudad'),
                        items: zoneOptions
                            .map(
                              (zone) => DropdownMenuItem<String>(
                                value: zone['id']?.toString(),
                                child: Text(
                                  (zone['city'] ?? zone['name'] ?? 'Ciudad').toString(),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setLocal(() => zoneId = value),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: required,
                      onChanged: (value) => setLocal(() => required = value),
                      title: const Text('Documento obligatorio'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: requireNumber,
                      onChanged: (value) => setLocal(() => requireNumber = value),
                      title: const Text('Solicitar número del documento'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: requireFront,
                      onChanged: (value) => setLocal(() => requireFront = value),
                      title: const Text('Solicitar foto del frente'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: requireBack,
                      onChanged: (value) => setLocal(() => requireBack = value),
                      title: const Text('Solicitar foto del reverso'),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: requireSelfie,
                      onChanged: (value) => setLocal(() => requireSelfie = value),
                      title: const Text('Solicitar selfie para comparación facial'),
                      subtitle: const Text(
                        'La selfie queda disponible para revisión manual o proveedor automático.',
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      onChanged: (value) => setLocal(() => active = value),
                      title: const Text('Activo'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: sortOrder,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Orden',
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
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (save == true) {
      if (label.text.trim().isEmpty || code.text.trim().isEmpty) {
        _snack('Completa nombre y código.');
      } else if (scope != 'global' && (countryCode == null || countryCode!.isEmpty)) {
        _snack('Selecciona el país.');
      } else if (scope == 'zone' && (zoneId == null || zoneId!.isEmpty)) {
        _snack('Selecciona la ciudad.');
      } else {
        try {
          await supabase.rpc(
            'admin_upsert_driver_document_requirement',
            params: {
              'p_id': row?['id'],
              'p_code': code.text.trim(),
              'p_label': label.text.trim(),
              'p_description': description.text.trim(),
              'p_country_code': scope == 'global' ? null : countryCode,
              'p_zone_id': scope == 'zone' ? zoneId : null,
              'p_required': required,
              'p_require_number': requireNumber,
              'p_require_front': requireFront,
              'p_require_back': requireBack,
              'p_require_selfie': requireSelfie,
              'p_active': active,
              'p_sort_order': int.tryParse(sortOrder.text.trim()) ?? 100,
            },
          );
          if (mounted) setState(() => revision++);
        } catch (e) {
          _snack(e.toString());
        }
      }
    }

    code.dispose();
    label.dispose();
    description.dispose();
    sortOrder.dispose();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar requisito'),
        content: Text(
          '¿Eliminar “' + (row['label'] ?? 'este documento').toString() + '”? Los documentos ya enviados por conductores no se borrarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD92D20)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await supabase.rpc(
        'admin_delete_driver_document_requirement',
        params: {'p_id': row['id']},
      );
      if (mounted) setState(() => revision++);
    } catch (e) {
      _snack(e.toString());
    }
  }

  String _scopeLabel(Map<String, dynamic> row) {
    if (row['zone_id'] != null) {
      return (row['zone_name'] ?? row['zone_key'] ?? 'Ciudad').toString();
    }
    if (row['country_code'] != null) {
      return switch (row['country_code']?.toString()) {
        'BO' => 'Bolivia',
        'CL' => 'Chile',
        _ => row['country_code'].toString(),
      };
    }
    return 'Todas las ciudades';
  }

  void _snack(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({List<Map<String, dynamic>> requirements, List<Map<String, dynamic>> zones})>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFD92D20)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(snapshot.error.toString())),
                  TextButton(
                    onPressed: () => setState(() => revision++),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ??
            (requirements: <Map<String, dynamic>>[], zones: <Map<String, dynamic>>[]);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFEAF2FF),
                      child: Icon(Icons.folder_shared_outlined, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Documentos requeridos para conductores',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Crea, edita o elimina los documentos que debe cargar cada conductor según país o ciudad.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _edit(zones: data.zones),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nuevo documento'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (data.requirements.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: Text('No hay requisitos configurados.')),
                  )
                else
                  ...data.requirements.map(
                    (row) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: row['active'] == false
                            ? const Color(0xFFF8FAFC)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            row['require_selfie'] == true
                                ? Icons.face_retouching_natural_rounded
                                : Icons.badge_outlined,
                            color: const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (row['label'] ?? 'Documento').toString(),
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 3),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Chip(label: Text(_scopeLabel(row))),
                                    if (row['required'] == true)
                                      const Chip(label: Text('Obligatorio')),
                                    if (row['require_front'] == true)
                                      const Chip(label: Text('Frente')),
                                    if (row['require_back'] == true)
                                      const Chip(label: Text('Reverso')),
                                    if (row['require_selfie'] == true)
                                      const Chip(label: Text('Selfie')),
                                    if (row['active'] == false)
                                      const Chip(label: Text('Inactivo')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: () => _edit(row: row, zones: data.zones),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () => _delete(row),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
