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
  static const Map<String, LatLng> cityCenters = {
    'trinidad': LatLng(-14.8333, -64.9000),
    'iquique': LatLng(-20.2307, -70.1357),
  };

  static const Map<String, String> cityLabels = {
    'trinidad': 'Trinidad',
    'iquique': 'Iquique',
  };

  int driversWanted = 100;
  int requestsWanted = 100;
  double radiusKm = 3;
  String selectedCity = 'trinidad';
  String targetScope = 'sandbox';
  String serviceMode = 'mixed';
  String demandLevel = 'automatic';
  Map<String, dynamic> demandState = const <String, dynamic>{};
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


  String _friendlyError(Object value) {
    try {
      final dynamic dynamicValue = value;
      final details = dynamicValue.details;
      if (details is Map) {
        final rawError = details['error'];
        if (rawError is String && rawError.trim().isNotEmpty) {
          return rawError;
        }
        if (rawError is Map) {
          final nestedMessage = rawError['message']?.toString();
          if (nestedMessage != null && nestedMessage.trim().isNotEmpty) {
            return nestedMessage;
          }
        }
        final message = details['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Algunas implementaciones web minificadas no exponen details.
    }

    final text = value.toString();
    const badStatePrefix = 'Bad state: ';
    return text.startsWith(badStatePrefix)
        ? text.substring(badStatePrefix.length)
        : text;
  }

  Future<void> _load() async {
    try {
      final value = await supabase.rpc('admin_audit_load_snapshot');
      final demandRaw = await supabase.rpc('admin_dynamic_pricing_qa_state');
      if (!mounted) return;
      final demandMap = demandRaw is Map
          ? Map<String, dynamic>.from(demandRaw)
          : <String, dynamic>{};
      setState(() {
        snapshot = value is Map
            ? Map<String, dynamic>.from(value)
            : <String, dynamic>{};
        demandState = demandMap;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<bool> _confirmProductionLaunch() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lanzar carga QA en producción'),
        content: Text(
          'Ciudad QA: $selectedCityLabel. '
          'Este escenario será visible dentro del alcance operativo real. '
          'Los $driversWanted conductores sintéticos aparecerán online y las '
          '$requestsWanted solicitudes podrán verse en la app de producción. '
          'Los push LOADTEST seguirán desactivados. Las solicitudes expiran '
          'automáticamente y puedes usar “Limpiar prueba” en cualquier momento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanzar en producción'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _call(String action) async {
    if (busy) return;
    if (action == 'seed' &&
        targetScope == 'production' &&
        !await _confirmProductionLaunch()) {
      return;
    }
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
                'city_key': selectedCity,
                'center_latitude': selectedCenter.latitude,
                'center_longitude': selectedCenter.longitude,
                'radius_km': radiusKm,
                'scope': targetScope,
                'service_mode': serviceMode,
              }
            : {
                'action': 'cleanup',
                'scope': targetScope,
              },
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
      if (action == 'seed') {
        await _applyDemand(silent: true);
      } else if (action == 'cleanup') {
        final previousLevel = demandLevel;
        demandLevel = 'automatic';
        await _applyDemand(silent: true);
        demandLevel = previousLevel;
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  LatLng get selectedCenter =>
      cityCenters[selectedCity] ?? cityCenters['trinidad']!;

  String get selectedCityLabel =>
      cityLabels[selectedCity] ?? cityLabels['trinidad']!;

  Future<void> _applyDemand({bool silent = false}) async {
    if (!silent && busy) return;
    try {
      final value = await supabase.rpc(
        'admin_set_dynamic_pricing_qa_override',
        params: {
          'p_city_key': selectedCity,
          'p_level': demandLevel,
          'p_minutes': 60,
        },
      );
      if (!mounted) return;
      if (!silent) {
        setState(() {
          result = value is Map
              ? Map<String, dynamic>.from(value)
              : <String, dynamic>{};
        });
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Map<String, dynamic> get selectedDemandCityState {
    final raw = demandState['cities'];
    if (raw is! List) return const <String, dynamic>{};
    for (final item in raw) {
      if (item is Map && item['city_key']?.toString() == selectedCity) {
        return Map<String, dynamic>.from(item);
      }
    }
    return const <String, dynamic>{};
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
          'Genera conductores y solicitudes sintéticas en la ciudad QA que elijas y permite simular demanda para Express Preview. La operación real sigue centrada en Trinidad; LOADTEST y la demanda QA no alteran la tarifa real de producción.',
          style: TextStyle(color: Color(0xFF64748B), height: 1.45),
        ),
        const SizedBox(height: 12),
        _scopeBanner(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: targetScope,
                    decoration: const InputDecoration(labelText: 'Entorno'),
                    items: const [
                      DropdownMenuItem(
                        value: 'sandbox',
                        child: Text('Prueba (aislado)'),
                      ),
                      DropdownMenuItem(
                        value: 'production',
                        child: Text('Producción (real)'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null) setState(() => targetScope = v);
                          },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedCity,
                    decoration: const InputDecoration(labelText: 'Ciudad QA'),
                    items: const [
                      DropdownMenuItem(
                        value: 'trinidad',
                        child: Text('Trinidad'),
                      ),
                      DropdownMenuItem(
                        value: 'iquique',
                        child: Text('Iquique'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null) {
                              setState(() => selectedCity = v);
                            }
                          },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: serviceMode,
                    decoration: const InputDecoration(
                      labelText: 'Servicio QA',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'mixed',
                        child: Text('Mixto · Auto + Moto'),
                      ),
                      DropdownMenuItem(
                        value: 'car',
                        child: Text('Solo Auto'),
                      ),
                      DropdownMenuItem(
                        value: 'motorcycle',
                        child: Text('Solo Moto'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null) setState(() => serviceMode = v);
                          },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: demandLevel,
                    decoration: const InputDecoration(
                      labelText: 'Demanda Preview',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'automatic',
                        child: Text('Automática (real)'),
                      ),
                      DropdownMenuItem(
                        value: 'normal',
                        child: Text('Normal · 1.00x'),
                      ),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text('Media · 1.10x'),
                      ),
                      DropdownMenuItem(
                        value: 'high',
                        child: Text('Alta · 1.20x'),
                      ),
                      DropdownMenuItem(
                        value: 'very_high',
                        child: Text('Muy alta · 1.35x'),
                      ),
                      DropdownMenuItem(
                        value: 'critical',
                        child: Text('Crítica · 1.50x'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null) setState(() => demandLevel = v);
                          },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : _applyDemand,
                  icon: const Icon(Icons.trending_up_rounded),
                  label: const Text('Aplicar demanda'),
                ),
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
                  onPressed: busy ? null : () => _call('cleanup'),
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
                : (constraints.maxWidth - 60) / 6;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(w, 'Estado', active ? 'ACTIVO' : 'LIMPIO',
                    Icons.bolt_rounded),
                _metric(
                  w,
                  'Entorno',
                  ((metrics['scope_mode'] ?? 'sandbox').toString() == 'production')
                      ? 'PRODUCCIÓN'
                      : 'PRUEBA',
                  Icons.layers_rounded,
                ),
                _metric(
                  w,
                  'Ciudad',
                  (metrics['city'] ?? run['city'] ?? selectedCityLabel).toString(),
                  Icons.location_city_rounded,
                ),
                _metric(
                  w,
                  'Demanda QA',
                  selectedDemandCityState['active'] == true
                      ? (selectedDemandCityState['multiplier']?.toString() ?? '1') + 'x'
                      : 'AUTO',
                  Icons.trending_up_rounded,
                ),
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
                  key: ValueKey(
                    (run['id'] ?? 'selector').toString() +
                        '-' +
                        (run['city'] ?? selectedCity).toString(),
                  ),
                  options: MapOptions(
                    initialCenter: run['center_latitude'] != null &&
                            run['center_longitude'] != null
                        ? LatLng(
                            _d(run['center_latitude']) ?? selectedCenter.latitude,
                            _d(run['center_longitude']) ?? selectedCenter.longitude,
                          )
                        : selectedCenter,
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
                            width: 18,
                            height: 18,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.two_wheeler_rounded,
                                color: Colors.white,
                                size: 11,
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
                      (run['city'] ?? selectedCityLabel).toString() +
                          ' · Azul: ' +
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
                      (((metrics['scope_mode'] ?? 'sandbox').toString() == 'production')
                          ? 'PRODUCCIÓN'
                          : 'PRUEBA') +
                      ' · ' +
                      (run['city'] ?? selectedCityLabel).toString() +
                      ' · ' +
                      drivers.length.toString() +
                      ' conductores · ' +
                      requests.length.toString() +
                      ' solicitudes. El escenario mide renderizado, Realtime, filtrado por radio y lectura masiva usando el entorno seleccionado.',
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

  Widget _scopeBanner() {
    final production = targetScope == 'production';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: production
            ? const Color(0xFFFFF4E5)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: production
              ? const Color(0xFFF79009)
              : const Color(0xFF93C5FD),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            production ? Icons.warning_amber_rounded : Icons.science_rounded,
            color: production
                ? const Color(0xFFB54708)
                : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              production
                  ? 'Producción real: los usuarios sintéticos compartirán alcance con usuarios reales y podrán aparecer en la app hasta limpiar o expirar.'
                  : 'Prueba aislada: los usuarios sintéticos solo interactúan dentro de qa-core y no aparecen a usuarios reales.',
              style: TextStyle(
                color: production
                    ? const Color(0xFF7A2E0E)
                    : const Color(0xFF1E3A8A),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
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
