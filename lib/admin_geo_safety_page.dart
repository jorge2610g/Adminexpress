import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'core/supabase_client.dart';

const Color _blue = Color(0xFF0B57D0);
const Color _dark = Color(0xFF101828);
const Color _muted = Color(0xFF667085);
const LatLng _trinidad = LatLng(-14.8333, -64.9000);

class AdminGeoSafetyPage extends StatefulWidget {
  const AdminGeoSafetyPage({super.key});

  @override
  State<AdminGeoSafetyPage> createState() => _AdminGeoSafetyPageState();
}

class _AdminGeoSafetyPageState extends State<AdminGeoSafetyPage> {
  int revision = 0;

  Future<({
    List<Map<String, dynamic>> zones,
    List<Map<String, dynamic>> polygons,
    List<Map<String, dynamic>> security,
  })> _load() async {
    final values = await Future.wait([
      supabase.rpc('admin_zone_list'),
      supabase.rpc('admin_zone_polygon_list'),
      supabase.rpc('admin_security_zone_list'),
    ]);

    return (
      zones: _list(values[0]),
      polygons: _list(values[1]),
      security: _list(values[2]),
    );
  }

  Future<void> _editCoverage(
    List<Map<String, dynamic>> zones, [
    Map<String, dynamic>? row,
  ]) async {
    if (zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero crea una zona base en la sección Zonas.',
          ),
        ),
      );
      return;
    }

    String? zoneId = row?['zone_id']?.toString() ??
        zones.first['id']?.toString();
    final name = TextEditingController(
      text: row?['name']?.toString() ?? 'Cobertura principal',
    );
    var active = row?['active'] != false;
    var points = _points(row?['polygon']);

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          final selectedZone = zones.firstWhere(
            (zone) => zone['id']?.toString() == zoneId,
            orElse: () => zones.first,
          );
          final center = _zoneCenter(selectedZone, points);

          return AlertDialog(
            title: Text(
              row == null
                  ? 'Nuevo polígono de cobertura'
                  : 'Editar polígono de cobertura',
            ),
            content: SizedBox(
              width: 920,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: zoneId,
                            decoration: const InputDecoration(
                              labelText: 'Zona base',
                            ),
                            items: zones
                                .map(
                                  (zone) => DropdownMenuItem(
                                    value: zone['id']?.toString(),
                                    child: Text(
                                      (zone['name'] ?? 'Zona').toString(),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setLocal(() => zoneId = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: name,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del polígono',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      onChanged: (value) =>
                          setLocal(() => active = value),
                      title: const Text('Polígono activo'),
                    ),
                    const SizedBox(height: 8),
                    _PolygonEditor(
                      key: ValueKey('coverage-' + zoneId.toString()),
                      center: center,
                      points: points,
                      fillColor: const Color(0x220B57D0),
                      borderColor: _blue,
                      onAdd: (point) => setLocal(
                        () => points = [...points, point],
                      ),
                      onUndo: points.isEmpty
                          ? null
                          : () => setLocal(
                                () => points = points.sublist(
                                  0,
                                  points.length - 1,
                                ),
                              ),
                      onClear: points.isEmpty
                          ? null
                          : () => setLocal(() => points = []),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Puntos: ' + points.length.toString() +
                          ' · toca el mapa para ir cerrando el área.',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
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
              FilledButton(
                onPressed: zoneId == null || points.length < 3
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Guardar polígono'),
              ),
            ],
          );
        },
      ),
    );

    if (save == true && zoneId != null) {
      try {
        await supabase.rpc(
          'admin_upsert_zone_polygon',
          params: {
            'p_id': row?['id'],
            'p_zone_id': zoneId,
            'p_name': name.text.trim(),
            'p_polygon': _jsonPoints(points),
            'p_active': active,
          },
        );
        if (!mounted) return;
        setState(() => revision++);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Polígono guardado.')),
        );
      } catch (e) {
        if (!mounted) return;
        _snack(e);
      }
    }

    name.dispose();
  }

  Future<void> _editSecurity([Map<String, dynamic>? row]) async {
    final name = TextEditingController(
      text: row?['name']?.toString() ?? '',
    );
    final city = TextEditingController(
      text: row?['city']?.toString() ?? 'Trinidad',
    );
    final country = TextEditingController(
      text: row?['country']?.toString() ?? 'Bolivia',
    );
    final message = TextEditingController(
      text: row?['message']?.toString() ??
          'Precaución: zona marcada por seguridad.',
    );

    var type = row?['zone_type']?.toString() ?? 'red';
    if (!const ['red', 'caution', 'safe'].contains(type)) {
      type = 'red';
    }
    var appliesTo = row?['applies_to']?.toString() ?? 'both';
    if (!const ['both', 'passenger', 'driver'].contains(appliesTo)) {
      appliesTo = 'both';
    }
    var severity = int.tryParse(row?['severity']?.toString() ?? '') ?? 3;
    severity = severity.clamp(1, 5);
    var active = row?['active'] != false;
    var points = _points(row?['polygon']);

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          final border = type == 'safe'
              ? const Color(0xFF14804A)
              : type == 'caution'
                  ? const Color(0xFFC76B16)
                  : const Color(0xFFD92D20);
          final fill = type == 'safe'
              ? const Color(0x2214804A)
              : type == 'caution'
                  ? const Color(0x22C76B16)
                  : const Color(0x22D92D20);

          return AlertDialog(
            title: Text(
              row == null
                  ? 'Nueva zona de seguridad'
                  : 'Editar zona de seguridad',
            ),
            content: SizedBox(
              width: 920,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: name,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: type,
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'red',
                                child: Text('Zona roja'),
                              ),
                              DropdownMenuItem(
                                value: 'caution',
                                child: Text('Precaución'),
                              ),
                              DropdownMenuItem(
                                value: 'safe',
                                child: Text('Zona segura'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setLocal(() => type = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: appliesTo,
                            decoration: const InputDecoration(
                              labelText: 'Aplica a',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'both',
                                child: Text('Pasajero y conductor'),
                              ),
                              DropdownMenuItem(
                                value: 'passenger',
                                child: Text('Solo pasajero'),
                              ),
                              DropdownMenuItem(
                                value: 'driver',
                                child: Text('Solo conductor'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setLocal(() => appliesTo = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: city,
                            decoration: const InputDecoration(
                              labelText: 'Ciudad',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: country,
                            decoration: const InputDecoration(
                              labelText: 'País',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: message,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Mensaje de seguridad',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Severidad',
                          style: TextStyle(
                            color: _dark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: severity.toDouble(),
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: severity.toString(),
                            onChanged: (value) => setLocal(
                              () => severity = value.round(),
                            ),
                          ),
                        ),
                        Text(
                          severity.toString() + '/5',
                          style: const TextStyle(
                            color: _dark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      onChanged: (value) =>
                          setLocal(() => active = value),
                      title: const Text('Zona activa'),
                    ),
                    const SizedBox(height: 8),
                    _PolygonEditor(
                      center: points.isEmpty ? _trinidad : points.first,
                      points: points,
                      fillColor: fill,
                      borderColor: border,
                      onAdd: (point) => setLocal(
                        () => points = [...points, point],
                      ),
                      onUndo: points.isEmpty
                          ? null
                          : () => setLocal(
                                () => points = points.sublist(
                                  0,
                                  points.length - 1,
                                ),
                              ),
                      onClear: points.isEmpty
                          ? null
                          : () => setLocal(() => points = []),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Puntos: ' + points.length.toString() +
                          ' · mínimo 3 para guardar.',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
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
              FilledButton(
                onPressed: name.text.trim().isEmpty || points.length < 3
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Guardar zona'),
              ),
            ],
          );
        },
      ),
    );

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_upsert_security_zone',
          params: {
            'p_id': row?['id'],
            'p_name': name.text.trim(),
            'p_zone_type': type,
            'p_applies_to': appliesTo,
            'p_severity': severity,
            'p_polygon': _jsonPoints(points),
            'p_message': message.text.trim(),
            'p_active': active,
            'p_city': city.text.trim(),
            'p_country': country.text.trim(),
          },
        );
        if (!mounted) return;
        setState(() => revision++);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zona de seguridad guardada.')),
        );
      } catch (e) {
        if (!mounted) return;
        _snack(e);
      }
    }

    name.dispose();
    city.dispose();
    country.dispose();
    message.dispose();
  }

  void _snack(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ' + error.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          List<Map<String, dynamic>> zones,
          List<Map<String, dynamic>> polygons,
          List<Map<String, dynamic>> security,
        })>(
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

        final data = snapshot.data ??
            (
              zones: <Map<String, dynamic>>[],
              polygons: <Map<String, dynamic>>[],
              security: <Map<String, dynamic>>[],
            );

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const _Header(
              title: 'Polígonos y seguridad',
              subtitle:
                  'Delimita cobertura exacta y crea zonas rojas, de precaución o seguras.',
            ),
            const SizedBox(height: 18),
            _SectionHeader(
              title: 'Polígonos de cobertura',
              subtitle:
                  'Reemplazan el simple radio cuando necesites cuadrar una zona por calles o límites reales.',
              action: FilledButton.icon(
                onPressed: data.zones.isEmpty
                    ? null
                    : () => _editCoverage(data.zones),
                icon: const Icon(Icons.polyline_rounded),
                label: const Text('Nuevo polígono'),
              ),
            ),
            const SizedBox(height: 10),
            if (data.zones.isEmpty)
              const _Notice(
                text:
                    'No hay zona base. Crea primero una zona en la sección Zonas.',
              ),
            if (data.polygons.isEmpty)
              const _Empty(text: 'Aún no hay polígonos de cobertura.')
            else
              ...data.polygons.map(
                (row) => _GeoRow(
                  icon: Icons.hexagon_outlined,
                  title: row['name']?.toString() ?? 'Cobertura',
                  subtitle:
                      (row['zone_name'] ?? 'Zona').toString() +
                          ' · ' +
                          _points(row['polygon']).length.toString() +
                          ' puntos',
                  status: row['active'] == true ? 'Activo' : 'Inactivo',
                  active: row['active'] == true,
                  onEdit: () => _editCoverage(data.zones, row),
                ),
              ),
            const SizedBox(height: 26),
            _SectionHeader(
              title: 'Zonas de seguridad',
              subtitle:
                  'Marca zonas rojas o de precaución para proteger a pasajeros y conductores.',
              action: FilledButton.icon(
                onPressed: () => _editSecurity(),
                icon: const Icon(Icons.gpp_bad_outlined),
                label: const Text('Nueva zona'),
              ),
            ),
            const SizedBox(height: 10),
            if (data.security.isEmpty)
              const _Empty(text: 'Aún no hay zonas de seguridad.')
            else
              ...data.security.map(
                (row) {
                  final type = row['zone_type']?.toString() ?? 'red';
                  final label = type == 'safe'
                      ? 'Segura'
                      : type == 'caution'
                          ? 'Precaución'
                          : 'Zona roja';
                  return _GeoRow(
                    icon: type == 'safe'
                        ? Icons.verified_user_outlined
                        : Icons.warning_amber_rounded,
                    title: row['name']?.toString() ?? label,
                    subtitle: label +
                        ' · severidad ' +
                        (row['severity'] ?? '—').toString() +
                        '/5 · ' +
                        _appliesLabel(row['applies_to']?.toString()),
                    status: row['active'] == true ? 'Activa' : 'Inactiva',
                    active: row['active'] == true,
                    danger: type == 'red',
                    onEdit: () => _editSecurity(row),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _PolygonEditor extends StatelessWidget {
  final LatLng center;
  final List<LatLng> points;
  final Color fillColor;
  final Color borderColor;
  final ValueChanged<LatLng> onAdd;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;

  const _PolygonEditor({
    super.key,
    required this.center,
    required this.points,
    required this.fillColor,
    required this.borderColor,
    required this.onAdd,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 390,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0D5DD)),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13.5,
              onTap: (_, point) => onAdd(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.express.delivery',
              ),
              if (points.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: points,
                      color: fillColor,
                      borderColor: borderColor,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              if (points.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < points.length; i++)
                      Marker(
                        point: points[i],
                        width: 28,
                        height: 28,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: borderColor,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            (i + 1).toString(),
                            style: TextStyle(
                              color: borderColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo_rounded, size: 17),
                  label: const Text('Deshacer'),
                ),
                const SizedBox(width: 6),
                FilledButton.tonalIcon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget action;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _dark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              const SizedBox(height: 10),
              action,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: text),
            const SizedBox(width: 12),
            action,
          ],
        );
      },
    );
  }
}

class _GeoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final bool active;
  final bool danger;
  final VoidCallback onEdit;

  const _GeoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.active,
    required this.onEdit,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger ? const Color(0xFFD92D20) : _blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: danger
                  ? const Color(0xFFFFE8E8)
                  : const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          _Status(text: status, active: active),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
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

class _Notice extends StatelessWidget {
  final String text;

  const _Notice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFFCE7B2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7A4A0B),
          fontSize: 11,
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
        padding: const EdgeInsets.all(22),
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

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

List<LatLng> _points(Object? value) {
  if (value is! List) return <LatLng>[];
  final result = <LatLng>[];
  for (final item in value) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final lat = double.tryParse(map['lat']?.toString() ?? '');
    final lng = double.tryParse(map['lng']?.toString() ?? '');
    if (lat == null || lng == null) continue;
    result.add(LatLng(lat, lng));
  }
  return result;
}

List<Map<String, double>> _jsonPoints(List<LatLng> points) {
  return points
      .map((point) => {
            'lat': point.latitude,
            'lng': point.longitude,
          })
      .toList();
}

LatLng _zoneCenter(
  Map<String, dynamic> zone,
  List<LatLng> points,
) {
  if (points.isNotEmpty) return points.first;
  final lat =
      double.tryParse(zone['center_latitude']?.toString() ?? '');
  final lng =
      double.tryParse(zone['center_longitude']?.toString() ?? '');
  if (lat != null && lng != null) return LatLng(lat, lng);
  return _trinidad;
}

String _appliesLabel(String? value) {
  if (value == 'driver') return 'solo conductores';
  if (value == 'passenger') return 'solo pasajeros';
  return 'pasajeros y conductores';
}
