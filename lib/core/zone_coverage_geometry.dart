import 'package:latlong2/latlong.dart';

/// The coverage saved for a zone can be a radius or a polygon. A legacy
/// radius_km value can remain populated even when the polygon is selected.
bool usesPolygonCoverage(Object? mode) =>
    mode?.toString().trim().toLowerCase() == 'polygon';

bool usesRadiusCoverage(Object? mode) =>
    mode?.toString().trim().toLowerCase() == 'radius';

/// Parse the same [{lat, lng}, ...] points saved by
/// admin_zone_coverage_save. Reject incomplete geometry rather than drawing a
/// misleading fallback circle for a polygon zone.
List<LatLng> parseZonePolygon(Object? raw) {
  if (raw is! List || raw.length < 3) return const <LatLng>[];
  final points = <LatLng>[];
  final distinct = <String>{};

  for (final value in raw) {
    if (value is! Map) return const <LatLng>[];
    final lat = _coordinate(value['lat']);
    final lng = _coordinate(value['lng']);
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return const <LatLng>[];
    }
    points.add(LatLng(lat, lng));
    distinct.add('$lat:$lng');
  }
  return distinct.length >= 3 ? points : const <LatLng>[];
}

double? _coordinate(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}
