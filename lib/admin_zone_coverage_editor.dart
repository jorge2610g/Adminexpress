import 'package:flutter/material.dart';

import 'core/admin_design_tokens.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Pick exactly ONE authoritative geographic mode for the whole operating zone.
/// The DB RPC enforces the same invariant transactionally.
class AdminZoneCoverageEditor extends StatelessWidget {
  const AdminZoneCoverageEditor({
    super.key,
    required this.mode,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.polygonPoints,
    required this.onModeChanged,
    required this.onPolygonChanged,
    required this.onPositionChanged,
  });

  final String mode;
  final TextEditingController latitude;
  final TextEditingController longitude;
  final TextEditingController radiusKm;
  final List<LatLng> polygonPoints;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<List<LatLng>> onPolygonChanged;
  final VoidCallback onPositionChanged;

  double? get _lat => double.tryParse(latitude.text.trim().replaceAll(',', '.'));
  double? get _lng => double.tryParse(longitude.text.trim().replaceAll(',', '.'));
  double? get _radius => double.tryParse(radiusKm.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final isPolygon = mode == 'polygon';
    final center = isPolygon && polygonPoints.isNotEmpty
        ? polygonPoints.first
        : LatLng(_lat ?? -18, _lng ?? -66);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo de cobertura', style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w900,
        )),
        const SizedBox(height: 5),
        const Text('Selecciona un solo método. El otro no tendrá efecto.',
          style: TextStyle(color: AdminColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'radius', icon: Icon(Icons.radar_rounded),
              label: Text('Radio')),
            ButtonSegment(value: 'polygon', icon: Icon(Icons.polyline_rounded),
              label: Text('Polígono')),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onModeChanged(s.first),
        ),
        const SizedBox(height: 12),
        Text(
          isPolygon
            ? 'Dibuja el área exacta marcando 3 o más puntos. El radio no se utilizará.'
            : 'Toca el mapa para elegir un centro. Solo cuenta el radio seleccionado.',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
        ),
        if (!isPolygon) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(
                controller: latitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
                onChanged: (_) => onPositionChanged(),
                decoration: const InputDecoration(labelText: 'Latitud'),
              )),
              const SizedBox(width: 9),
              Expanded(child: TextField(
                controller: longitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
                onChanged: (_) => onPositionChanged(),
                decoration: const InputDecoration(labelText: 'Longitud'),
              )),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: radiusKm,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onPositionChanged(),
            decoration: const InputDecoration(
              labelText: 'Radio (km)',
              helperText: 'Se mostrará como un círculo sobre el mapa.',
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          height: 320,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDDE3EC)),
          ),
          child: FlutterMap(
            key: ValueKey('coverage-map-$mode'),
            options: MapOptions(
              initialCenter: center,
              initialZoom: _lat == null && polygonPoints.isEmpty ? 4.2 : 11,
              onTap: (_, point) {
                if (isPolygon) {
                  onPolygonChanged([...polygonPoints, point]);
                } else {
                  latitude.text = point.latitude.toStringAsFixed(6);
                  longitude.text = point.longitude.toStringAsFixed(6);
                  onPositionChanged();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.express.admin',
              ),
              if (!isPolygon && _lat != null && _lng != null) ...[
                CircleLayer(circles: [
                  CircleMarker(
                    point: LatLng(_lat!, _lng!),
                    radius: ((_radius ?? 0) * 1000).clamp(0, 1000000).toDouble(),
                    useRadiusInMeter: true,
                    color: const Color(0x202563EB),
                    borderColor: AdminColors.blue,
                    borderStrokeWidth: 2,
                  ),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(_lat!, _lng!), width: 40, height: 40,
                    child: const Icon(Icons.location_pin,
                      size: 37, color: AdminColors.blue),
                  ),
                ]),
              ],
              if (isPolygon && polygonPoints.length >= 3)
                PolygonLayer(polygons: [
                  Polygon(
                    points: polygonPoints,
                    color: const Color(0x202563EB),
                    borderColor: AdminColors.blue,
                    borderStrokeWidth: 2,
                  ),
                ]),
              if (isPolygon && polygonPoints.isNotEmpty)
                MarkerLayer(markers: [
                  for (var i = 0; i < polygonPoints.length; i++)
                    Marker(
                      point: polygonPoints[i], width: 31, height: 31,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AdminColors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text('${i + 1}', style: const TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.bold,
                        )),
                      ),
                    ),
                ]),
            ],
          ),
        ),
        if (isPolygon) ...[
          const SizedBox(height: 8),
          Row(children: [
            Text('${polygonPoints.length} puntos',
              style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
              onPressed: polygonPoints.isEmpty ? null
                : () => onPolygonChanged(
                    polygonPoints.sublist(0, polygonPoints.length - 1)),
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Deshacer'),
            ),
            TextButton.icon(
              onPressed: polygonPoints.isEmpty ? null
                : () => onPolygonChanged(<LatLng>[]),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Borrar'),
            ),
          ]),
        ],
      ],
    );
  }
}
