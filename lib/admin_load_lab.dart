import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'core/supabase_client.dart';

class AdminLoadLabPage extends StatefulWidget {
  const AdminLoadLabPage({super.key});

  @override
  State<AdminLoadLabPage> createState() => _AdminLoadLabPageState();
}

class _AdminLoadLabPageState extends State<AdminLoadLabPage> {
  static const center = LatLng(-20.2307, -70.1357);
  int driversWanted = 100;
  int requestsWanted = 100;
  double radiusKm = 3;
  bool busy = false;
  String? error;
  Map<String, dynamic> snapshot = const {};
  Map<String, dynamic>? result;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  List<Map<String, dynamic>> _maps(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _load() async {
    try {
      final value = await supabase.rpc('admin_audit_load_snapshot');
      if (!mounted) return;
      setState(() {
        snapshot = value is Map
            ? Map<String, dynamic>.from(value)
            : <String, dynamic>{};
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _call(String action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await supabase.functions.invoke(
        'express-load-lab',
        body: action == 'seed'
            ? {
                'action': 'seed',
                'drivers': driversWanted,
                'requests': requestsWanted,
                'center_latitude': center.latitude,
                'center_longitude': center.longitude,
                'radius_km': radiusKm,
              }
            : {'action': 'cleanup'},
      );
      final data = response.data;
      if (data is Map && data['ok'] != true) {
        throw StateError((data['error'] ?? 'Operación fallida').toString());
      }
      if (!mounted) return;
      setState(() {
        result = data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
      });
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  double? _d(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final runRaw = snapshot['run'];
    final run =
        runRaw is Map ? Map<String, dynamic>.from(runRaw) : <String, dynamic>{};
    final drivers = _maps(snapshot['drivers']);
    final requests = _maps(snapshot['requests']);
    final active = run['status'] == 'active';
    final metricsRaw = run['metrics'];
    final metrics = metricsRaw is Map
        ? Map<String, dynamic>.from(metricsRaw)
        : <String, dynamic>{};

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      children: [
        const Text(
          'Laboratorio de carga QA',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Genera conductores y solicitudes sintéticas en Iquique. Solo existen dentro del sandbox QA y no generan push.',
          style: TextStyle(color: Color(0xFF64748B), height: 1.45),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _selector(
                  'Conductores',
                  driversWanted,
                  (v) => setState(() => driversWanted = v),
                ),
                _selector(
                  'Solicitudes',
                  requestsWanted,
                  (v) => setState(() => requestsWanted = v),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<double>(
                    initialValue: radiusKm,
                    decoration:
                        const InputDecoration(labelText: 'Radio de prueba'),
                    items: const [1.5, 3.0, 5.0]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(v.toStringAsFixed(1) + ' km'),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null) setState(() => radiusKm = v);
                          },
                  ),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : () => _call('seed'),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.science_rounded),
                  label: Text(
                    active ? 'Recrear escenario' : 'Crear escenario',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy || !active ? null : () => _call('cleanup'),
                  icon: const Icon(Icons.cleaning_services_rounded),
                  label: const Text('Limpiar prueba'),
                ),
                IconButton(
                  onPressed: busy ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualizar',
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _notice(error!, true),
        ],
        if (result != null) ...[
          const SizedBox(height: 12),
          _notice(result.toString(), false),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth < 760
                ? constraints.maxWidth
                : (constraints.maxWidth - 36) / 4;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(w, 'Estado', active ? 'ACTIVO' : 'LIMPIO',
                    Icons.bolt_rounded),
                _metric(w, 'Conductores', drivers.length.toString(),
                    Icons.drive_eta_rounded),
                _metric(w, 'Solicitudes', requests.length.toString(),
                    Icons.local_taxi_rounded),
                _metric(
                  w,
                  'Creación',
                  metrics['seed_duration_ms'] == null
                      ? '—'
                      : metrics['seed_duration_ms'].toString() + ' ms',
                  Icons.speed_rounded,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 620,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FlutterMap(
                  options: const MapOptions(
                    initialCenter: center,
                    initialZoom: 13.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.express.admin',
                    ),
                    MarkerLayer(
                      markers: [
                        ...drivers.map((row) {
                          final lat = _d(row['latitude']);
                          final lng = _d(row['longitude']);
                          if (lat == null || lng == null) return null;
                          return Marker(
                            point: LatLng(lat, lng),
                            width: 28,
                            height: 28,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.directions_car_filled_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          );
                        }).whereType<Marker>(),
                        ...requests.map((row) {
                          final lat = _d(row['pickup_latitude']);
                          final lng = _d(row['pickup_longitude']);
                          if (lat == null || lng == null) return null;
                          return Marker(
                            point: LatLng(lat, lng),
                            width: 24,
                            height: 24,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFFF97316),
                              size: 24,
                            ),
                          );
                        }).whereType<Marker>(),
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
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Azul: ' +
                          drivers.length.toString() +
                          ' conductores · Naranja: ' +
                          requests.length.toString() +
                          ' solicitudes',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              run.isEmpty
                  ? 'No hay un escenario activo.'
                  : 'Run ' +
                      run['id'].toString() +
                      ' · ' +
                      drivers.length.toString() +
                      ' conductores · ' +
                      requests.length.toString() +
                      ' solicitudes. El escenario mide renderizado, Realtime, filtrado por radio y lectura masiva dentro del sandbox.',
              style: const TextStyle(
                color: Color(0xFF475467),
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _selector(String label, int value, ValueChanged<int> onChanged) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: const [10, 50, 100, 250]
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(v.toString()),
              ),
            )
            .toList(),
        onChanged: busy
            ? null
            : (v) {
                if (v != null) onChanged(v);
              },
      ),
    );
  }

  Widget _metric(double width, String label, String value, IconData icon) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF2563EB)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice(String text, bool danger) {
    final color =
        danger ? const Color(0xFFB42318) : const Color(0xFF067647);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
