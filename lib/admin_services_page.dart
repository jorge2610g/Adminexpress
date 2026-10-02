import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

const Color _blue = Color(0xFF0B57D0);
const Color _dark = Color(0xFF101828);
const Color _muted = Color(0xFF667085);

class AdminServicesPage extends StatefulWidget {
  const AdminServicesPage({super.key});

  @override
  State<AdminServicesPage> createState() => _AdminServicesPageState();
}

class _AdminServicesPageState extends State<AdminServicesPage> {
  int revision = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final value = await supabase.rpc('admin_service_list');
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final key = TextEditingController(
      text: row?['service_key']?.toString() ?? '',
    );
    final name = TextEditingController(
      text: row?['name']?.toString() ?? '',
    );
    final description = TextEditingController(
      text: row?['description']?.toString() ?? '',
    );
    final icon = TextEditingController(
      text: row?['icon_key']?.toString() ?? 'local_taxi',
    );
    final order = TextEditingController(
      text: row?['sort_order']?.toString() ?? '100',
    );

    var vehicle = row?['vehicle_type']?.toString() ?? 'car';
    if (!const ['car', 'motorcycle', 'xl', 'any'].contains(vehicle)) {
      vehicle = 'car';
    }
    var enabled = row?['enabled'] != false;
    var bidding = row?['allow_bidding'] != false;
    var fixed = row?['allow_fixed_price'] != false;
    var passengerVisible = row?['passenger_visible'] != false;
    var driverVisible = row?['driver_visible'] != false;
    var scheduled = row?['scheduled_enabled'] != false;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Crear servicio' : 'Editar servicio'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: key,
                          enabled: row == null,
                          decoration: const InputDecoration(
                            labelText: 'Clave interna',
                            hintText: 'ej. premium',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Nombre visible',
                          ),
                        ),
                      ),
                    ],
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
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: vehicle,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de vehículo',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'car',
                              child: Text('Auto'),
                            ),
                            DropdownMenuItem(
                              value: 'motorcycle',
                              child: Text('Moto'),
                            ),
                            DropdownMenuItem(
                              value: 'xl',
                              child: Text('XL'),
                            ),
                            DropdownMenuItem(
                              value: 'any',
                              child: Text('Cualquiera'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setLocal(() => vehicle = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: icon,
                          decoration: const InputDecoration(
                            labelText: 'Ícono interno',
                            hintText: 'local_taxi',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: order,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Orden',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    onChanged: (value) =>
                        setLocal(() => enabled = value),
                    title: const Text('Servicio activo'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: passengerVisible,
                    onChanged: (value) =>
                        setLocal(() => passengerVisible = value),
                    title: const Text('Visible para pasajeros'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: driverVisible,
                    onChanged: (value) =>
                        setLocal(() => driverVisible = value),
                    title: const Text('Visible para conductores'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: bidding,
                    onChanged: (value) =>
                        setLocal(() => bidding = value),
                    title: const Text('Permite ofertas de tarifa'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: fixed,
                    onChanged: (value) =>
                        setLocal(() => fixed = value),
                    title: const Text('Permite precio fijo'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: scheduled,
                    onChanged: (value) =>
                        setLocal(() => scheduled = value),
                    title: const Text('Permite viajes programados'),
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
              onPressed: () {
                if (key.text.trim().isEmpty ||
                    name.text.trim().isEmpty ||
                    (!bidding && !fixed)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Completa clave, nombre y activa oferta o precio fijo.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_upsert_service',
          params: {
            'p_id': row?['id'],
            'p_service_key': key.text.trim().toLowerCase(),
            'p_name': name.text.trim(),
            'p_description': description.text.trim(),
            'p_icon_key': icon.text.trim(),
            'p_vehicle_type': vehicle,
            'p_enabled': enabled,
            'p_allow_bidding': bidding,
            'p_allow_fixed_price': fixed,
            'p_passenger_visible': passengerVisible,
            'p_driver_visible': driverVisible,
            'p_scheduled_enabled': scheduled,
            'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
          },
        );
        if (!mounted) return;
        setState(() => revision++);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio guardado.')),
        );
      } catch (e) {
        if (!mounted) return;
        _snack(e);
      }
    }

    key.dispose();
    name.dispose();
    description.dispose();
    icon.dispose();
    order.dispose();
  }

  void _snack(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ' + error.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorCard(
            error: snapshot.error,
            onRetry: () => setState(() => revision++),
          );
        }

        final rows = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _Header(
              title: 'Servicios',
              subtitle:
                  'Crea y controla las categorías que Express puede ofrecer sin cambiar código.',
              action: FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear servicio'),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Desactivar un servicio lo saca del catálogo operativo. También puedes ocultarlo solo para pasajeros o conductores.',
                style: TextStyle(
                  color: _dark,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const _Empty(text: 'No hay servicios configurados.')
            else
              ...rows.map(
                (row) => Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE7ECF3),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final info = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  row['name']?.toString() ?? 'Servicio',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: _dark,
                                  ),
                                ),
                              ),
                              _Status(
                                text: row['enabled'] == true
                                    ? 'Activo'
                                    : 'Inactivo',
                                active: row['enabled'] == true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (row['service_key'] ?? '—').toString() +
                                ' · ' +
                                (row['vehicle_type'] ?? 'car').toString(),
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 10,
                            ),
                          ),
                          if ((row['description'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              row['description'].toString(),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _Tag(
                                row['passenger_visible'] == true
                                    ? 'Pasajero'
                                    : 'Oculto pasajero',
                              ),
                              _Tag(
                                row['driver_visible'] == true
                                    ? 'Conductor'
                                    : 'Oculto conductor',
                              ),
                              if (row['allow_bidding'] == true)
                                const _Tag('Ofertas'),
                              if (row['allow_fixed_price'] == true)
                                const _Tag('Precio fijo'),
                              if (row['scheduled_enabled'] == true)
                                const _Tag('Programados'),
                            ],
                          ),
                        ],
                      );

                      if (constraints.maxWidth < 680) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            info,
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => _edit(row),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar'),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: info),
                          const SizedBox(width: 14),
                          OutlinedButton.icon(
                            onPressed: () => _edit(row),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const _Header({
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _dark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );

    if (action == null) return text;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              const SizedBox(height: 10),
              action!,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: text),
            const SizedBox(width: 12),
            action!,
          ],
        );
      },
    );
  }
}

class _Status extends StatelessWidget {
  final String text;
  final bool active;

  const _Status({
    required this.text,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFE8F8EF)
            : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active
              ? const Color(0xFF14804A)
              : const Color(0xFF667085),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _dark,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, style: const TextStyle(color: _muted)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
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
}
