/// The only authority for an operating zone's coverage is coverage_mode.
/// A stored radius can remain as inert legacy data when polygon is active.
/// Never label it as the active coverage unless mode == 'radius'.
String adminZoneCoverageSummary(Map<String, dynamic> zone) {
  switch (zone['coverage_mode']?.toString()) {
    case 'polygon':
      return 'Polígono';
    case 'radius':
      final radius = zone['radius_km'];
      final text = radius == null ? '—' : radius.toString();
      return 'Radio $text km';
    default:
      return 'Sin información';
  }
}
