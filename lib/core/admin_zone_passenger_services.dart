/// One set of zone-level passenger switches controls both landing cards and
/// the corresponding service availability. No landing-mode or default toggle.
const zonePassengerRideServiceKeys = <String>[
  'economy', 'comfort', 'motorcycle', 'xl',
];
const zonePassengerParcelServiceKeys = <String>['parcel', 'delivery'];
const zonePassengerModuleKeys = <String>['ride', 'delivery', 'market'];

bool zonePassengerServiceActive(Map<String, dynamic> service) =>
    service['enabled'] == true && service['passenger_visible'] == true;

/// A single visible module opens directly; multiple modules open the chooser.
/// A zone with none selected cannot be saved.
String zonePassengerStartHint(List<String> modules) {
  if (modules.isEmpty) return 'Selecciona al menos un servicio.';
  if (modules.length == 1) {
    switch (modules.first) {
      case 'ride':
        return '1 servicio · abrir Viajes directamente';
      case 'delivery':
        return '1 servicio · abrir Envíos directamente';
      default:
        return '1 servicio · abrir Market directamente';
    }
  }
  return '${modules.length} servicios · mostrar página de aterrizaje';
}

/// Produce only changed service flags. Never edits fares, bidding, scheduling,
/// driver visibility, identity permissions or service catalog metadata.
///
/// Taxi category availability remains intact when the module is toggled off:
/// only passenger visibility changes. When turning Taxi on with no enabled
/// category, chooses one safe, country-specific entry from the zone catalog.
/// Envíos requires BOTH `parcel` (passenger trip) and `delivery` (landing
/// compatibility); those two flags must be kept in sync.
List<Map<String, dynamic>> zonePassengerServiceChanges({
  required List<Map<String, dynamic>> services,
  required bool rides,
  required bool parcels,
  required String countryCode,
}) {
  final entries = <String, Map<String, dynamic>>{
    for (final row in services)
      if (row['service_key'] != null)
        row['service_key'].toString(): Map<String, dynamic>.from(row),
  };
  for (final key in zonePassengerParcelServiceKeys) {
    entries.putIfAbsent(key, () => <String, dynamic>{
      'service_key': key, 'enabled': false, 'passenger_visible': false,
      'driver_visible': false, 'allow_bidding': true,
      'allow_fixed_price': true, 'scheduled_enabled': true,
      'sort_order': key == 'parcel' ? 48 : 50,
    });
  }
  final rideKeys = zonePassengerRideServiceKeys
      .where(entries.containsKey).toList();
  final currentlyEnabled = rideKeys.where(
    (key) => entries[key]?['enabled'] == true,
  ).toList();
  final fallbackKey = countryCode.toUpperCase() == 'BO'
      ? 'motorcycle' : 'economy';
  final chosenRideKey = currentlyEnabled.isNotEmpty
      ? currentlyEnabled.first
      : entries.containsKey(fallbackKey)
          ? fallbackKey
          : rideKeys.isNotEmpty ? rideKeys.first : null;

  final updates = <Map<String, dynamic>>[];
  for (final key in rideKeys) {
    final old = entries[key]!;
    final turnOn = rides && (old['enabled'] == true || key == chosenRideKey);
    final wantedEnabled = rides && key == chosenRideKey &&
            currentlyEnabled.isEmpty
        ? true
        : old['enabled'] == true;
    final wantedVisible = turnOn;
    if (old['enabled'] == wantedEnabled &&
        old['passenger_visible'] == wantedVisible) continue;
    updates.add(<String, dynamic>{
      ...old,
      'enabled': wantedEnabled,
      'passenger_visible': wantedVisible,
    });
  }
  for (final key in zonePassengerParcelServiceKeys) {
    final old = entries[key]!;
    if (old['enabled'] == parcels && old['passenger_visible'] == parcels) {
      continue;
    }
    updates.add(<String, dynamic>{
      ...old,
      'enabled': parcels,
      'passenger_visible': parcels,
    });
  }
  return updates;
}
