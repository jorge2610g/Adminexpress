import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'core/supabase_client.dart';
import 'core/admin_environment_navigation.dart';
import 'admin_environment_store.dart';
import 'admin_runtime_scope.dart';
import 'admin_control_sections.dart';
import 'admin_single_app_release.dart';
import 'admin_audit_sandbox.dart';
import 'admin_load_lab.dart';
import 'admin_driver_subscriptions.dart';
import 'admin_marketplace.dart';
import 'admin_marketplace_phase2.dart';
import 'admin_driver_priority.dart';
import 'admin_dynamic_pricing.dart';
import 'admin_detail_dialogs.dart';
import 'admin_environment_reports.dart';
import 'admin_environment_audit.dart';
import 'admin_manual_identity.dart';

const Color adminBlue = Color(0xFF2563EB);
const Color adminDark = Color(0xFF0F172A);
const Color adminMuted = Color(0xFF64748B);
const Color adminBg = Color(0xFFF1F5F9);
const Color adminNavy = Color(0xFF0B1220);
const Color adminNavySoft = Color(0xFF111C31);
const Color adminCyan = Color(0xFF22D3EE);


ThemeData _expressAdminTheme(BuildContext context) {
  final base = Theme.of(context);
  final scheme = ColorScheme.fromSeed(
    seedColor: adminBlue,
    brightness: Brightness.light,
    surface: Colors.white,
  );

  OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: adminBg,
    canvasColor: Colors.white,
    dividerColor: const Color(0xFFEAECF0),
    cardColor: Colors.white,
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: const Color(0x1A0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDDE6F0)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: adminDark,
      surfaceTintColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 60,
      titleTextStyle: TextStyle(
        color: adminDark,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      labelStyle: const TextStyle(
        color: adminMuted,
        fontSize: 11,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF98A2B3),
        fontSize: 11,
      ),
      border: inputBorder(const Color(0xFFD0D5DD)),
      enabledBorder: inputBorder(const Color(0xFFD0D5DD)),
      focusedBorder: inputBorder(adminBlue),
      errorBorder: inputBorder(const Color(0xFFD92D20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        side: const BorderSide(color: Color(0xFFD0D5DD)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
        foregroundColor: adminDark,
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(38, 38),
        maximumSize: const Size(42, 42),
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFEAF2FF),
      disabledColor: const Color(0xFFF2F4F7),
      side: const BorderSide(color: Color(0xFFE4E7EC)),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      labelStyle: const TextStyle(
        color: adminDark,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: const TextStyle(
        color: adminBlue,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titleTextStyle: const TextStyle(
        color: adminDark,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
      ),
      textStyle: const TextStyle(
        color: adminDark,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: adminDark,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}

class ExpressAdminPanel extends StatefulWidget {
  final VoidCallback onExit;
  const ExpressAdminPanel({super.key, required this.onExit});

  @override
  State<ExpressAdminPanel> createState() => _ExpressAdminPanelState();
}

class _ExpressAdminPanelState extends State<ExpressAdminPanel> {
  int section = 0;
  int revision = 0;
  String adminChannel = adminIsPreview ? 'preview' : 'production';
  bool allowPreview = true;
  bool allowProduction = true;
  String? liveZoneId;

  String tripPeriod = 'today';
  DateTimeRange? tripCustomRange;
  String deliveryPeriod = 'today';
  DateTimeRange? deliveryCustomRange;

  String? usersZoneId;
  String? usersCity;
  String? usersRegionDepartment;

  String? adminCountryCode;
  String? adminZoneId;
  Map<String, dynamic> adminAccess = const {};

  bool get _isZoneMonitor =>
      adminAccess['role']?.toString() == 'zone_monitor';
  // Android releases belong to the entire Express app, never to a
  // country, city or service zone. Operational sections still require scope.
  // These administration modules cover the entire Express system rather than
  // an operational country, zone, or a separate Preview/Production mode.
  static const Set<int> _globalSections = {10, 12, 14}; // Reports, Builds, Audit
  // The only Preview modules vetted for shared-database scoped operations.
  // Every other module may run unscoped RPCs and must fail closed in QA.
  static const Set<int> _previewScopedModules = {
    0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 14, 16, 17, 18, 27,
  };
  static bool _requiresZoneScope(int selectedSection) =>
      !_globalSections.contains(selectedSection);

  bool get _scopeReady =>
      adminCountryCode != null &&
      adminCountryCode!.isNotEmpty &&
      adminZoneId != null &&
      adminZoneId!.isNotEmpty;

  Future<bool>? _authFuture;
  Future<({Map<String, dynamic> state, List<Map<String, dynamic>> zones})>?
      _liveFuture;

  @override
  void initState() {
    super.initState();
    _authFuture = _authorized();
    _liveFuture = null;
  }

  static const sections = <(String, IconData)>[
    ('Dashboard', Icons.dashboard_rounded),
    ('Operación en vivo', Icons.map_rounded),
    ('Viajes', Icons.local_taxi_rounded),
    ('Delivery', Icons.local_shipping_rounded),
    ('Conductores', Icons.drive_eta_rounded),
    ('Usuarios', Icons.people_rounded),
    ('Seguridad / SOS', Icons.shield_rounded),
    ('Zonas y cobertura', Icons.hexagon_outlined),
    ('Tarifas', Icons.payments_outlined),
    ('Pagos / Billetera', Icons.account_balance_wallet_rounded),
    ('Reportes', Icons.bar_chart_rounded),
    ('Configuración', Icons.settings_rounded),
    ('Builds', Icons.build_circle_outlined),
    ('Despacho manual', Icons.alt_route_rounded),
    ('Auditoría', Icons.history_rounded),
    ('Notificaciones / Avisos', Icons.notifications_active_rounded),
    ('Servicios', Icons.apps_rounded),
    ('Cobertura y seguridad', Icons.gpp_good_rounded),
    ('Verificación de identidad', Icons.verified_user_rounded),
    ('Configuración avanzada', Icons.tune_rounded),
    ('Entornos de prueba', Icons.science_rounded),
    ('Carga QA', Icons.speed_rounded),
    ('Suscripciones', Icons.workspace_premium_rounded),
    ('Express Market', Icons.storefront_rounded),
    ('Delivery Fase 2 / Express Plus', Icons.delivery_dining_rounded),
    ('Prioridad conductores', Icons.workspace_premium_outlined),
    ('Pedidos Delivery', Icons.receipt_long_rounded),
    ('Verificación manual', Icons.fact_check_outlined),
    ('Demanda y precios', Icons.trending_up_rounded),
  ];

  Future<bool> _authorized() async {
    final value = await supabase.rpc('admin_access_context');
    if (value is! Map) return false;
    final access = Map<String, dynamic>.from(value);
    if (access['allowed'] != true) return false;

    // Both websites connect to MAIN. Backend checks allow_preview and
    // allow_production, plus target account runtime environment.
    adminAccess = access;
    allowPreview = adminIsPreview && access['allow_preview'] != false;
    allowProduction = !adminIsPreview && access['allow_production'] != false;
    adminChannel = adminIsPreview ? 'preview' : 'production';
    if (adminIsPreview ? !allowPreview : !allowProduction) return false;

    if (access['role']?.toString() == 'zone_monitor') {
      adminCountryCode =
          access['country_code']?.toString().trim().toUpperCase();
      adminZoneId = access['zone_id']?.toString();
      liveZoneId = adminZoneId;
    }
    return true;
  }

  Future<Map<String, dynamic>> _dashboardState() async {
    if (!_scopeReady) return <String, dynamic>{};
    final value = await supabase.rpc(
      'admin_dashboard_state_v2',
      params: {
        'p_channel': adminChannel,
        'p_zone_id': adminZoneId,
      },
    );
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  Future<({Map<String, dynamic> state, List<Map<String, dynamic>> zones})>
      _liveState() async {
    if (!_scopeReady) {
      return (
        state: <String, dynamic>{},
        zones: <Map<String, dynamic>>[],
      );
    }
    final state = await _dashboardState();
    final zones = await _filterZones();
    return (state: state, zones: zones);
  }

  String _zoneCountryCode(Map<String, dynamic> row) {
    final direct = row['country_code']?.toString().trim().toUpperCase();
    if (direct != null && direct.isNotEmpty) return direct;
    final country = row['country']?.toString().trim().toLowerCase() ?? '';
    if (country == 'chile') return 'CL';
    if (country == 'bolivia') return 'BO';
    return country.toUpperCase();
  }

  Future<Set<String>> _geoScopeZoneIds() async {
    if (adminZoneId != null && adminZoneId!.isNotEmpty) {
      return {adminZoneId!};
    }
    final country = adminCountryCode;
    if (country == null || country.isEmpty) return <String>{};
    final zones = await _filterZones();
    return zones
        .where((row) => _zoneCountryCode(row) == country)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  bool _matchesGeoScope(Map<String, dynamic> row, Set<String> zoneIds) {
    if (zoneIds.isEmpty) {
      return adminCountryCode == null && adminZoneId == null;
    }
    final zoneId = row['zone_id']?.toString();
    return zoneId != null && zoneIds.contains(zoneId);
  }

  Future<List<Map<String, dynamic>>> _drivers() async {
    if (!_scopeReady) return const [];
    final value = await supabase.rpc(
      'admin_driver_list_v3',
      params: {
        'p_channel': adminChannel,
        'p_zone_id': adminZoneId,
      },
    );
    return _list(value);
  }

  Future<List<Map<String, dynamic>>> _filterCountries() async {
    final value = await supabase.rpc('admin_country_list_scoped');
    return _list(value);
  }

  Future<List<Map<String, dynamic>>> _filterZones() async {
    final country = adminCountryCode;
    if (country == null || country.isEmpty) return const [];

    final value = await supabase.rpc(
      'admin_zone_list_for_country',
      params: {'p_country_code': country},
    );
    return _list(value);
  }

  ({DateTime from, DateTime to}) _periodBounds(
    String period,
    DateTimeRange? custom,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case 'week':
        final from = today.subtract(Duration(days: today.weekday - 1));
        return (from: from, to: from.add(const Duration(days: 7)));
      case 'month':
        final from = DateTime(now.year, now.month, 1);
        final to = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        return (from: from, to: to);
      case 'custom':
        final range = custom;
        if (range != null) {
          final from = DateTime(
            range.start.year,
            range.start.month,
            range.start.day,
          );
          final endDay = DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
          );
          return (from: from, to: endDay.add(const Duration(days: 1)));
        }
        return (from: today, to: today.add(const Duration(days: 1)));
      case 'today':
      default:
        return (from: today, to: today.add(const Duration(days: 1)));
    }
  }

  Future<List<Map<String, dynamic>>> _users() async {
    if (!_scopeReady) return const [];
    final value = await supabase.rpc(
      'admin_user_list_v4',
      params: {
        'p_channel': adminChannel,
        'p_zone_id': adminZoneId,
        'p_search': null,
        'p_limit': 100,
        'p_offset': 0,
      },
    );
    return _list(value);
  }

  Future<List<Map<String, dynamic>>> _trips() async {
    if (!_scopeReady) return const [];
    final range = _periodBounds(tripPeriod, tripCustomRange);
    final value = await supabase.rpc(
      'admin_trip_list_v4',
      params: {
        'p_channel': adminChannel,
        'p_from': range.from.toUtc().toIso8601String(),
        'p_to': range.to.toUtc().toIso8601String(),
        'p_zone_id': adminZoneId,
        'p_status': null,
        'p_limit': 200,
        'p_offset': 0,
      },
    );
    return _list(value);
  }

  Future<List<Map<String, dynamic>>> _deliveries() async {
    if (!_scopeReady) return const [];
    final range = _periodBounds(deliveryPeriod, deliveryCustomRange);
    final value = await supabase.rpc(
      'admin_delivery_list_v4',
      params: {
        'p_channel': adminChannel,
        'p_from': range.from.toUtc().toIso8601String(),
        'p_to': range.to.toUtc().toIso8601String(),
        'p_zone_id': adminZoneId,
        'p_status': null,
        'p_limit': 200,
        'p_offset': 0,
      },
    );
    return _list(value);
  }

  Widget _periodFilter(String target) {
    final isTrip = target == 'trip';
    final period = isTrip ? tripPeriod : deliveryPeriod;
    final custom = isTrip ? tripCustomRange : deliveryCustomRange;

    Future<void> selectCustom() async {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: custom ??
            DateTimeRange(
              start: DateTime(now.year, now.month, now.day),
              end: DateTime(now.year, now.month, now.day),
            ),
      );
      if (picked == null || !mounted) return;
      setState(() {
        if (isTrip) {
          tripPeriod = 'custom';
          tripCustomRange = picked;
        } else {
          deliveryPeriod = 'custom';
          deliveryCustomRange = picked;
        }
        revision++;
      });
    }

    void select(String value) {
      setState(() {
        if (isTrip) {
          tripPeriod = value;
        } else {
          deliveryPeriod = value;
        }
        revision++;
      });
    }

    final label = custom == null
        ? 'Fecha'
        : custom.start.day.toString() +
            '/' +
            custom.start.month.toString() +
            '/' +
            custom.start.year.toString() +
            ' – ' +
            custom.end.day.toString() +
            '/' +
            custom.end.month.toString() +
            '/' +
            custom.end.year.toString();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ChoiceChip(
          label: const Text('Hoy'),
          selected: period == 'today',
          onSelected: (_) => select('today'),
        ),
        ChoiceChip(
          label: const Text('Semana'),
          selected: period == 'week',
          onSelected: (_) => select('week'),
        ),
        ChoiceChip(
          label: const Text('Mes'),
          selected: period == 'month',
          onSelected: (_) => select('month'),
        ),
        OutlinedButton.icon(
          onPressed: selectCustom,
          icon: const Icon(Icons.date_range_outlined, size: 17),
          label: Text(label),
        ),
      ],
    );
  }

  Widget _userGeoFilters() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _filterZones(),
      builder: (context, snapshot) {
        final zones = snapshot.data ?? const <Map<String, dynamic>>[];
        final cities = zones
            .map((row) => row['city']?.toString().trim())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final regions = zones
            .map((row) => row['region_department']?.toString().trim())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String?>(
                value: usersZoneId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Zona',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas las zonas'),
                  ),
                  ...zones.map(
                    (row) => DropdownMenuItem<String?>(
                      value: row['id']?.toString(),
                      child: Text(
                        (row['name'] ?? 'Zona').toString() +
                            ' · ' +
                            (row['city'] ?? '').toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    usersZoneId = value;
                    if (value != null) {
                      final zone = zones.firstWhere(
                        (row) => row['id']?.toString() == value,
                      );
                      usersCity = zone['city']?.toString();
                      usersRegionDepartment =
                          zone['region_department']?.toString();
                    }
                    revision++;
                  });
                },
              ),
            ),
            SizedBox(
              width: 165,
              child: DropdownButtonFormField<String?>(
                value: usersCity,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Ciudad',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas'),
                  ),
                  ...cities.map(
                    (value) => DropdownMenuItem<String?>(
                      value: value,
                      child: Text(value, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    usersCity = value;
                    usersZoneId = null;
                    revision++;
                  });
                },
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String?>(
                value: usersRegionDepartment,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Región / departamento',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas'),
                  ),
                  ...regions.map(
                    (value) => DropdownMenuItem<String?>(
                      value: value,
                      child: Text(value, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    usersRegionDepartment = value;
                    usersZoneId = null;
                    revision++;
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _globalGeoScopeSwitcher() {
    if (_isZoneMonitor) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFFF0FDF4),
          border: Border(
            bottom: BorderSide(color: Color(0xFFBBF7D0)),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: Color(0xFF15803D),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Monitor de zona · ' +
                    (adminAccess['country'] ?? '').toString() +
                    ' · ' +
                    (adminAccess['zone_name'] ?? '').toString(),
                style: const TextStyle(
                  color: Color(0xFF166534),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Text(
              'Solo lectura',
              style: TextStyle(
                color: Color(0xFF166534),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _filterCountries(),
      builder: (context, countrySnapshot) {
        final countries =
            countrySnapshot.data ?? const <Map<String, dynamic>>[];

        Widget zoneField = const SizedBox(
          width: 220,
          child: TextField(
            enabled: false,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Zona',
              hintText: 'Primero selecciona un país',
            ),
          ),
        );

        if (adminCountryCode != null && adminCountryCode!.isNotEmpty) {
          zoneField = FutureBuilder<List<Map<String, dynamic>>>(
            future: _filterZones(),
            builder: (context, zoneSnapshot) {
              final zones =
                  zoneSnapshot.data ?? const <Map<String, dynamic>>[];
              return SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  value: adminZoneId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Zona',
                  ),
                  hint: const Text('Selecciona una zona'),
                  items: zones
                      .map(
                        (row) => DropdownMenuItem<String?>(
                          value: row['id']?.toString(),
                          child: Text(
                            (row['name'] ?? 'Zona').toString() +
                                ' · ' +
                                (row['city'] ?? '').toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      adminZoneId = value;
                      liveZoneId = value;
                      revision++;
                      _liveFuture =
                          value == null ? null : _liveState();
                    });
                  },
                ),
              );
            },
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 9, 18, 9),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public_rounded, size: 18, color: adminBlue),
                  SizedBox(width: 6),
                  Text(
                    'Ámbito obligatorio',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: adminDark,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String?>(
                  value: adminCountryCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'País',
                  ),
                  hint: const Text('Selecciona un país'),
                  items: countries
                      .map(
                        (row) => DropdownMenuItem<String?>(
                          value: row['country_code']
                              ?.toString()
                              .trim()
                              .toUpperCase(),
                          child: Text(
                            (row['country'] ?? row['country_code'] ?? '')
                                .toString(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      adminCountryCode = value;
                      adminZoneId = null;
                      liveZoneId = null;
                      revision++;
                      _liveFuture = null;
                    });
                  },
                ),
              ),
              zoneField,
              if (!_scopeReady)
                const Text(
                  'Selecciona país y zona para cargar datos.',
                  style: TextStyle(
                    color: adminMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _refresh() {
    setState(() {
      revision++;
      _liveFuture =
          _scopeReady && section == 1 ? _liveState() : null;
    });
  }

  // ADMIN_ENV selects a fixed website data channel, not a database project.
  // Preview is restricted to reviewed channel-scoped modules.
  Widget _environmentSwitcher() {
    final preview = adminIsPreview;
    final icon = Icon(
      preview ? Icons.science_rounded : Icons.verified_rounded,
      size: 19,
      color: preview ? const Color(0xFFB54708) : const Color(0xFF14804A),
    );
    final title = Text(
      preview
          ? 'EXPRESS PREVIEW · Solo registros de prueba'
          : 'EXPRESS PRODUCCIÓN · Datos reales',
      style: TextStyle(
        color: preview ? const Color(0xFF7A2E0E) : const Color(0xFF0F6848),
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: preview ? const Color(0xFFFFF7E6) : const Color(0xFFE8F8EF),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On narrow phones the button sits on its own line.
          final badge = Row(
            children: [
              icon,
              const SizedBox(width: 9),
              Expanded(child: title),
            ],
          );
          if (constraints.maxWidth < 580) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                badge,
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: const AdminEnvironmentLinkButton(),
                ),
              ],
            );
          }
          return Row(
            children: [
              icon,
              const SizedBox(width: 9),
              Expanded(child: title),
              const SizedBox(width: 12),
              const AdminEnvironmentLinkButton(),
            ],
          );
        },
      ),
    );
  }

  void _goTo(int value) {
    setState(() {
      if (value == 1 && section != 1 && _scopeReady) {
        _liveFuture = _liveState();
      }
      section = value;
    });
  }

  Future<void> _driverStatus(String id, String status) async {
    try {
      await supabase.rpc(
        'admin_set_driver_approval_v2',
        params: {
          'p_user_id': id,
          'p_status': status,
          'p_channel': adminChannel,
        },
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conductor: ' + status)),
      );
    } catch (e) {
      if (!mounted) return;
      _errorSnack(e);
    }
  }

  Future<void> _accountStatus(String id, String status) async {
    try {
      await supabase.rpc(
        'admin_set_account_status_v2',
        params: {
          'p_user_id': id,
          'p_status': status,
          'p_channel': adminChannel,
        },
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cuenta: ' + status)),
      );
    } catch (e) {
      if (!mounted) return;
      _errorSnack(e);
    }
  }

  void _errorSnack(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ' + error.toString())),
    );
  }
  Future<void> _resolveEmergency(String id) async {
    try {
      await supabase.rpc(
        'admin_resolve_emergency_v2',
        params: {
          'p_emergency_id': id,
          'p_channel': adminChannel,
        },
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergencia marcada como resuelta.')),
      );
    } catch (e) {
      if (!mounted) return;
      _errorSnack(e);
    }
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authFuture ??= _authorized(),
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: adminBg,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.data != true) {
          return _Unauthorized(onExit: widget.onExit);
        }

        return Theme(
          data: _expressAdminTheme(context),
          child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1180;

            return Scaffold(
              backgroundColor: adminBg,
              appBar: compact
                  ? AppBar(
                      title: const _Brand(compact: true),
                      actions: [
                        if (!_isZoneMonitor)
                          IconButton(
                            tooltip: 'Nuevo viaje',
                            onPressed: () => _goTo(13),
                            icon: const Icon(Icons.add_circle_outline_rounded),
                          ),
                        IconButton(
                          tooltip: 'Actualizar',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Cuenta',
                          onSelected: (value) {
                            if (value == 'logout') widget.onExit();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'logout',
                              child: Text('Cerrar sesión'),
                            ),
                          ],
                          icon: const Icon(Icons.more_vert_rounded),
                        ),
                      ],
                    )
                  : null,
              drawer: compact
                  ? Drawer(
                      child: SafeArea(
                        child: _Navigation(
                          selected: section,
                          channel: adminChannel,
                          readOnly: _isZoneMonitor,
                          onSelected: (value) {
                            Navigator.pop(context);
                            _goTo(value);
                          },
                          onExit: widget.onExit,
                        ),
                      ),
                    )
                  : null,
              body: Row(
                children: [
                  if (!compact)
                    SizedBox(
                      width: 248,
                      child: _Navigation(
                        selected: section,
                        channel: adminChannel,
                        readOnly: _isZoneMonitor,
                        onSelected: _goTo,
                        onExit: widget.onExit,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        if (!compact)
                          _TopBar(
                            title: sections[section].$1,
                            onRefresh: _refresh,
                            onNewTrip: () => _goTo(13),
                            onExit: widget.onExit,
                            showNewTrip: !_isZoneMonitor,
                          ),
                        if (!_globalSections.contains(section))
                          _environmentSwitcher(),
                        if (_globalSections.contains(section))
                          _environmentSwitcher(),
                        if (_requiresZoneScope(section))
                          _globalGeoScopeSwitcher(),
                        Expanded(
                          child: KeyedSubtree(
                            key: ValueKey(
                              AdminRuntimeScope(
                                environment:
                                    AdminEnvironment.parse(adminChannel),
                                countryCode: _requiresZoneScope(section)
                                    ? adminCountryCode
                                    : null,
                                zoneId: _requiresZoneScope(section)
                                    ? adminZoneId
                                    : null,
                              ).cacheKey,
                            ),
                            child: _body(section),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        );
      },
    );
  }

  Widget _body(int value) {
    // Fail closed: a shared database also has REAL merchants, subscriptions,
    // payments and releases. Never run unscoped Preview module RPCs.
    if (adminIsPreview && !_previewScopedModules.contains(value)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Este módulo todavía no tiene aislamiento seguro por canal. '
            'Está bloqueado en Prueba para proteger los datos reales. '
            'Puedes gestionar conductores, documentos, viajes y '
            'configuración QA desde sus secciones.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_requiresZoneScope(value) && !_scopeReady) {
      return const _ScopeSelectionRequired();
    }

    if (_isZoneMonitor &&
        !const {0, 1, 2, 3, 4, 5, 6, 26}.contains(value)) {
      return const _ZoneMonitorRestricted();
    }

    switch (value) {
      case 0:
        return _dashboard();
      case 1:
        return _liveOperations();
      case 2:
        return _tripList();
      case 3:
        return _deliveryList();
      case 4:
        return _driverList();
      case 5:
        return _userList();
      case 6:
        return _security();
      case 7:
        return DefaultTabController(
          key: ValueKey('unified-zones-$adminZoneId-$adminChannel'),
          length: 2,
          child: Column(
            children: [
              const Material(
                color: Colors.white,
                child: TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.location_city_outlined),
                        text: 'Zonas y servicios'),
                    Tab(icon: Icon(Icons.shield_outlined),
                        text: 'Cobertura y seguridad'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(children: [
                  AdminZonesPage(
                    channel: adminChannel,
                    countryCode: adminCountryCode,
                    zoneId: adminZoneId,
                  ),
                  AdminGeoSafetyPage(
                    channel: adminChannel,
                    countryCode: adminCountryCode,
                    zoneId: adminZoneId,
                  ),
                ]),
              ),
            ],
          ),
        );
      case 8:
        return AdminFaresPage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 9:
        return AdminPaymentsPage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 10:
        return AdminEnvironmentReportsPage(
          includePreview: allowPreview,
          includeProduction: allowProduction,
        );
      case 11:
        return AdminSettingsPage(channel: adminChannel);
      case 12:
        return AdminSingleAppReleasePage(
          productionAccess: allowProduction && !adminIsPreview,
        );
      case 13:
        return AdminDispatchPage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 14:
        return AdminEnvironmentAuditPage(
          includePreview: allowPreview,
          includeProduction: allowProduction,
        );
      case 15:
        return AdminCommunicationsPage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 16:
        return AdminServicesPage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 17:
        return AdminGeoSafetyPage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 18:
        return DefaultTabController(
          key: ValueKey('unified-identity-$adminZoneId-$adminChannel'),
          length: 2,
          child: Column(
            children: [
              const Material(
                color: Colors.white,
                child: TabBar(tabs: [
                  Tab(icon: Icon(Icons.fact_check_outlined),
                      text: 'Revisión de documentos'),
                  Tab(icon: Icon(Icons.settings_outlined),
                      text: 'Requisitos de identidad'),
                ]),
              ),
              Expanded(child: TabBarView(children: [
                AdminManualIdentityPage(
                  channel: adminChannel,
                  countryCode: adminCountryCode,
                  zoneId: adminZoneId,
                ),
                AdminIdentitySecurityPage(
                  channel: adminChannel,
                  countryCode: adminCountryCode,
                  zoneId: adminZoneId,
                ),
              ])),
            ],
          ),
        );
      case 19:
        return AdminAdvancedSettingsPage(channel: adminChannel);
      case 20:
        return AdminAuditSandboxPage(channel: adminChannel);
      case 21:
        return AdminLoadLabPage(channel: adminChannel);
      case 22:
        return AdminDriverSubscriptionsPage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 23:
        return AdminMarketplacePage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 24:
        return AdminMarketplacePhase2Page(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 25:
        return AdminDriverPriorityPage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 26:
        return AdminMarketplacePhase2Page(
          ordersOnly: true,
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 27:
        return AdminManualIdentityPage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 28:
        return AdminDynamicPricingPage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _dashboard() {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('dashboard-' + revision.toString()),
      future: _dashboardState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading();
        }
        if (snapshot.hasError) {
          return _ErrorView(error: snapshot.error, onRetry: _refresh);
        }

        final state = snapshot.data ?? const <String, dynamic>{};
        final metrics = _map(state['metrics']);
        final activity = _list(state['activity']);

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final header = const _Header(
                    title: 'Express Delivery',
                    subtitle: 'Bienvenido al panel de control de tu empresa.',
                    badge: 'Activa',
                  );
                  final liveButton = FilledButton.icon(
                    onPressed: () => _goTo(1),
                    icon: const Icon(Icons.bolt_rounded, size: 17),
                    label: const Text('Ver en vivo'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  );

                  if (constraints.maxWidth < 680) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        header,
                        const SizedBox(height: 12),
                        liveButton,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: _Header(
                        title: 'Express Delivery',
                        subtitle: 'Bienvenido al panel de control de tu empresa.',
                        badge: 'Activa',
                      )),
                      const SizedBox(width: 16),
                      liveButton,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final cardWidth = width < 700
                      ? width
                      : width < 1100
                          ? (width - 12) / 2
                          : (width - 42) / 4;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _Metric(
                          'Viajes activos',
                          metrics['active_trips'],
                          Icons.location_on_outlined,
                          tone: _MetricTone.green,
                          footnote: 'En operación ahora',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _Metric(
                          'Viajes hoy',
                          metrics['trips_today'],
                          Icons.schedule_rounded,
                          tone: _MetricTone.blue,
                          footnote: 'Solicitudes del día',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _Metric(
                          'Conductores',
                          metrics['drivers_online'],
                          Icons.drive_eta_rounded,
                          tone: _MetricTone.orange,
                          footnote:
                              'de ' + (metrics['drivers_total'] ?? 0).toString() + ' conectados',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _Metric(
                          'Completados',
                          metrics['completed_today'],
                          Icons.task_alt_rounded,
                          tone: _MetricTone.purple,
                          footnote: 'Finalizados hoy',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final quick = _QuickActions(
                    onLive: () => _goTo(1),
                    onDrivers: () => _goTo(4),
                    onDispatch: () => _goTo(13),
                  );
                  final system = _SystemStatus(metrics: metrics);

                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        quick,
                        const SizedBox(height: 14),
                        system,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: quick),
                      const SizedBox(width: 14),
                      Expanded(flex: 2, child: system),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final recent = _Activity(rows: activity);
                  final summary = _DailySummary(metrics: metrics);

                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        SizedBox(height: 330, child: recent),
                        const SizedBox(height: 14),
                        summary,
                      ],
                    );
                  }

                  return SizedBox(
                    height: 330,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: recent),
                        const SizedBox(width: 14),
                        Expanded(flex: 2, child: summary),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _liveOperations() {
    return FutureBuilder<
        ({Map<String, dynamic> state, List<Map<String, dynamic>> zones})>(
      key: ValueKey('live-' + revision.toString()),
      future: _liveFuture ??= _liveState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading();
        }
        if (snapshot.hasError) {
          return _ErrorView(error: snapshot.error, onRetry: _refresh);
        }

        final data = snapshot.data;
        final state = data?.state ?? const <String, dynamic>{};
        final zones = data?.zones ?? const <Map<String, dynamic>>[];
        final drivers = _list(state['drivers']);
        final trips = _list(state['active_trips']);
        final deliveries = _list(state['active_deliveries']);
        final emergencies = _list(state['emergencies']);

        Map<String, dynamic>? selectedZone;
        if (liveZoneId != null) {
          for (final zone in zones) {
            if ((zone['id'] ?? '').toString() == liveZoneId) {
              selectedZone = zone;
              break;
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LiveZoneStrip(
                zones: zones,
                selectedZoneId: liveZoneId,
                onSelected: (value) {
                  setState(() {
                    liveZoneId = value;
                    adminZoneId = value;
                    if (value != null) {
                      final zone = zones.firstWhere(
                        (row) => row['id']?.toString() == value,
                      );
                      adminCountryCode = _zoneCountryCode(zone);
                    }
                    revision++;
                    _liveFuture = _liveState();
                  });
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = _LiveSidePanel(
                      trips: trips,
                      drivers: drivers,
                    );
                    final map = _OperationsMap(
                      key: ValueKey('live-map-' + (liveZoneId ?? 'all')),
                      drivers: drivers,
                      trips: trips,
                      deliveries: deliveries,
                      emergencies: emergencies,
                      selectedZone: selectedZone,
                      fullScreen: true,
                    );

                    if (constraints.maxWidth < 980) {
                      return ListView(
                        children: [
                          SizedBox(height: 430, child: side),
                          const SizedBox(height: 12),
                          SizedBox(height: 560, child: map),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 405, child: side),
                        const SizedBox(width: 12),
                        Expanded(child: map),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tripList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('trips-' + revision.toString()),
      future: _trips(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading();
        }
        if (snapshot.hasError) {
          return _ErrorView(error: snapshot.error, onRetry: _refresh);
        }

        final rows = snapshot.data ?? const [];
        return _Records(
          title: 'Viajes',
          subtitle: 'Historial y operación de viajes Express.',
          empty: 'Todavía no hay viajes.',
          rows: rows,
          serverFilters: _periodFilter('trip'),
          item: (row) => _OperationCard(
            icon: Icons.local_taxi_rounded,
            title:
                (row['pickup_address'] ?? 'Origen').toString() +
                ' → ' +
                (row['destination_address'] ?? 'Destino').toString(),
            subtitle:
                (row['status'] ?? '—').toString() +
                ' · ' +
                (row['category'] ?? 'Express').toString() +
                ' · Bs ' +
                (row['final_fare'] ?? '—').toString(),
            details: [
              'Pasajero: ' + (row['passenger_name'] ?? '—').toString(),
              'Conductor: ' + (row['driver_name'] ?? '—').toString(),
              'Pago: ' + (row['payment_status'] ?? '—').toString(),
              'Creado: ' + _formatDate(row['created_at']),
            ],
            onTap: _isZoneMonitor
                ? null
                : () => showAdminTripDetail(
                      context,
                      row['id'].toString(),
                      channel: adminChannel,
                    ),
          ),
        );
      },
    );
  }

  Widget _deliveryList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('delivery-' + revision.toString()),
      future: _deliveries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading();
        }
        if (snapshot.hasError) {
          return _ErrorView(error: snapshot.error, onRetry: _refresh);
        }

        final rows = snapshot.data ?? const [];
        return _Records(
          title: 'Delivery',
          subtitle: 'Pedidos y entregas de Express.',
          empty: 'Todavía no hay delivery.',
          rows: rows,
          serverFilters: _periodFilter('delivery'),
          item: (row) => _OperationCard(
            icon: Icons.local_shipping_rounded,
            title:
                (row['pickup_address'] ?? 'Origen').toString() +
                ' → ' +
                (row['dropoff_address'] ?? 'Destino').toString(),
            subtitle:
                (row['status'] ?? '—').toString() +
                ' · ' +
                (row['package_type'] ?? 'Paquete').toString() +
                ' · Bs ' +
                (row['proposed_fare'] ?? '—').toString(),
            details: [
              'Cliente: ' + (row['customer_name'] ?? '—').toString(),
              'Repartidor: ' + (row['courier_name'] ?? '—').toString(),
              'Pago: ' + (row['payment_method'] ?? '—').toString(),
              'Creado: ' + _formatDate(row['created_at']),
            ],
          ),
        );
      },
    );
  }

  Widget _driverList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('drivers-' + revision.toString()),
      future: _drivers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading();
        }
        if (snapshot.hasError) {
          return _ErrorView(error: snapshot.error, onRetry: _refresh);
        }

        return _Records(
          title: 'Conductores',
          subtitle:
              'Aprobación, estado, licencia, vehículo y control de conductores.',
          empty: 'Todavía no hay conductores registrados.',
          rows: snapshot.data ?? const [],
          showQaFilter: false,
          item: (row) {
            final status = (row['approval_status'] ?? 'pending').toString();
            final online = (row['online_status'] ?? 'offline').toString();
            final name = row['full_name']?.toString().trim();

            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE7ECF3)),
                borderRadius: BorderRadius.circular(11),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final identity = Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFEAF2FF),
                        child: Icon(
                          online == 'online'
                              ? Icons.online_prediction_rounded
                              : Icons.person_rounded,
                          size: 18,
                          color: adminBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name != null && name.isNotEmpty
                                  ? name
                                  : 'Conductor',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: adminDark,
                              ),
                            ),
                            Text(
                              row['email']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: adminMuted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final Widget actions = _isZoneMonitor
                      ? const SizedBox.shrink()
                      : PopupMenuButton<String>(
                    tooltip: 'Acciones',
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final changed = await showAdminDriverEditor(
                          context,
                          row['user_id'].toString(),
                          channel: adminChannel,
                        );
                        if (changed && mounted) _refresh();
                        return;
                      }
                      await _driverStatus(
                        row['user_id'].toString(),
                        value,
                      );
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.manage_accounts_outlined),
                          title: Text('Ver / editar ficha'),
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'approved',
                        child: Text('Aprobar'),
                      ),
                      PopupMenuItem(
                        value: 'pending',
                        child: Text('Marcar pendiente'),
                      ),
                      PopupMenuItem(
                        value: 'rejected',
                        child: Text('Rechazar'),
                      ),
                      PopupMenuItem(
                        value: 'suspended',
                        child: Text('Suspender'),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded),
                  );

                  if (wide) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 240, child: identity),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              row['vehicle_summary']?.toString() ?? 'Sin vehículo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: adminMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(
                              row['city']?.toString() ?? '—',
                              style: const TextStyle(
                                color: adminMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          _Chip(status),
                          const SizedBox(width: 6),
                          _Chip(online),
                          const SizedBox(width: 4),
                          actions,
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        identity,
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Chip(status),
                            _Chip(online),
                          ],
                        ),
                        const SizedBox(height: 9),
                        _Line(
                          Icons.directions_car_outlined,
                          row['vehicle_summary']?.toString() ?? 'Sin vehículo',
                        ),
                        _Line(
                          Icons.phone_outlined,
                          row['phone']?.toString() ?? 'Sin teléfono',
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: actions,
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _userList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('users-' + revision.toString()),
      future: _users(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading();
        }
        if (snapshot.hasError) {
          return _ErrorView(error: snapshot.error, onRetry: _refresh);
        }

        return _Records(
          title: 'Usuarios',
          subtitle:
              'Pasajeros, conductores y control del estado de las cuentas.',
          empty: 'Todavía no hay usuarios registrados.',
          rows: snapshot.data ?? const [],
          serverFilters: _userGeoFilters(),
          showQaFilter: true,
          item: (row) => Container(
            margin: const EdgeInsets.only(bottom: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE7ECF3)),
              borderRadius: BorderRadius.circular(11),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEAF2FF),
                child: Icon(
                  row['active_mode'] == 'driver'
                      ? Icons.drive_eta_rounded
                      : Icons.person_rounded,
                  size: 18,
                  color: adminBlue,
                ),
              ),
              title: Text(
                row['full_name']?.toString().trim().isNotEmpty == true
                    ? row['full_name'].toString()
                    : row['email']?.toString() ?? 'Usuario',
              ),
              subtitle: Text(
                (row['email'] ?? '').toString() +
                    ' · ' +
                    (row['active_mode'] ?? 'passenger').toString() +
                    ' · ' +
                    (row['account_status'] ?? 'active').toString(),
              ),
              trailing: _isZoneMonitor
                  ? null
                  : PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    final changed = await showAdminUserEditor(
                      context,
                      row['user_id'].toString(),
                      channel: adminChannel,
                    );
                    if (changed && mounted) _refresh();
                    return;
                  }
                  await _accountStatus(
                    row['user_id'].toString(),
                    value,
                  );
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.manage_accounts_outlined),
                      title: Text('Ver / editar perfil'),
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'active',
                    child: Text('Activar'),
                  ),
                  PopupMenuItem(
                    value: 'suspended',
                    child: Text('Suspender'),
                  ),
                  PopupMenuItem(
                    value: 'blocked',
                    child: Text('Bloquear'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _security() {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('security-' + revision.toString()),
      future: _dashboardState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading();
        }
        if (snapshot.hasError) {
          return _ErrorView(error: snapshot.error, onRetry: _refresh);
        }

        final rows = _list(snapshot.data?['emergencies']);
        return _Records(
          title: 'Seguridad / SOS',
          subtitle:
              'Emergencias activas registradas desde Viajes y Delivery.',
          empty: 'No hay emergencias abiertas.',
          rows: rows,
          item: (row) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFE4E8),
                child: Icon(Icons.sos_rounded, color: Color(0xFFD92D20)),
              ),
              title: Text(
                row['user_name']?.toString().trim().isNotEmpty == true
                    ? row['user_name'].toString()
                    : 'Usuario Express',
              ),
              subtitle: Text(
                (row['status'] ?? 'open').toString() +
                    ' · ' +
                    _formatDate(row['created_at']),
              ),
              trailing: _isZoneMonitor
                  ? null
                  : FilledButton.icon(
                      onPressed: () =>
                          _resolveEmergency(row['id'].toString()),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Resolver'),
                    ),
            ),
          ),
        );
      },
    );
  }
}


class _ScopeSelectionRequired extends StatelessWidget {
  const _ScopeSelectionRequired();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_outlined,
              size: 46,
              color: adminBlue,
            ),
            SizedBox(height: 14),
            Text(
              'Selecciona país y zona',
              style: TextStyle(
                color: adminDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'No se cargarán usuarios, viajes, conductores ni métricas hasta elegir el ámbito.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: adminMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneMonitorRestricted extends StatelessWidget {
  const _ZoneMonitorRestricted();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 44,
              color: Color(0xFF64748B),
            ),
            SizedBox(height: 12),
            Text(
              'Módulo reservado al administrador global',
              style: TextStyle(
                color: adminDark,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'El monitor de zona tiene acceso operativo de solo lectura.',
              textAlign: TextAlign.center,
              style: TextStyle(color: adminMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _Navigation extends StatelessWidget {
  final int selected;
  final String channel;
  final bool readOnly;
  final ValueChanged<int> onSelected;
  final VoidCallback onExit;

  const _Navigation({
    required this.selected,
    required this.channel,
    this.readOnly = false,
    required this.onSelected,
    required this.onExit,
  });

  List<(String, List<int>)> get groups => readOnly
      ? const [
          ('GENERAL', [0]),
          ('OPERACIONES', [1, 2, 3, 26, 4, 5, 6]),
        ]
      : const [
          ('GENERAL', [0]),
          ('OPERACIONES', [1, 2, 13, 3, 26, 4, 5, 6]),
          ('MÓDULOS', [23, 24, 25]),
          ('FINANZAS', [9, 8, 22]),
          ('ANÁLISIS', [10, 14]),
          ('COMUNICACIÓN', [15]),
          ('SEGURIDAD', [18]),
          ('CONFIGURACIÓN', [16, 7, 11, 19, 12]),
          ('HERRAMIENTAS QA', [20, 21]),
        ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: adminNavy,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 20, 18, 14),
              child: _Brand(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF17243B), Color(0xFF101A2C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFF263650)),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFF1E3A5F),
                      child: Icon(
                        Icons.apartment_rounded,
                        size: 18,
                        color: adminCyan,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EMPRESA ACTUAL',
                            style: TextStyle(
                              color: Color(0xFF8FA3BF),
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .9,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Express Delivery',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.unfold_more_rounded, size: 16, color: Color(0xFF8FA3BF)),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1E2B41)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                children: [
                  for (final group in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(11, 12, 10, 6),
                      child: Text(
                        group.$1,
                        style: const TextStyle(
                          color: Color(0xFF71839D),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.05,
                        ),
                      ),
                    ),
                    for (final index in group.$2)
                      _NavEntry(
                        index: index,
                        selected: selected == index,
                        onSelected: onSelected,
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1E2B41)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                title: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Color(0xFFD9E2EF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: onExit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavEntry extends StatelessWidget {
  final int index;
  final bool selected;
  final ValueChanged<int> onSelected;

  const _NavEntry({
    required this.index,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final item = _ExpressAdminPanelState.sections[index];
    final alert = index == 6;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF173A68) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? const Color(0xFF25558E) : Colors.transparent,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x3322D3EE),
                        blurRadius: 14,
                        offset: Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF1E4E83)
                        : const Color(0xFF142037),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    item.$2,
                    size: 17,
                    color: selected ? adminCyan : const Color(0xFF91A4BF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.$1,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFC5D0DF),
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ),
                if (alert)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4B1D26),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      'SOS',
                      style: TextStyle(
                        color: Color(0xFFFF8A8A),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else if (selected)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: adminCyan,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final bool compact;
  const _Brand({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final primary = compact ? adminDark : Colors.white;
    final secondary = compact ? adminMuted : const Color(0xFF8FA3BF);

    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Express Delivery',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: -.2,
          ),
        ),
        if (!compact)
          Text(
            'COMMAND CENTER',
            style: TextStyle(
              color: secondary,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
      ],
    );

    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Container(
          width: compact ? 34 : 39,
          height: compact ? 34 : 39,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF22D3EE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3322D3EE),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.bolt_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        if (compact)
          Flexible(child: text)
        else
          Expanded(child: text),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onRefresh;
  final VoidCallback onNewTrip;
  final VoidCallback onExit;
  final bool showNewTrip;

  const _TopBar({
    required this.title,
    required this.onRefresh,
    required this.onNewTrip,
    required this.onExit,
    this.showNewTrip = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE6F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.grid_view_rounded, color: adminBlue, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ADMINISTRACIÓN',
                style: TextStyle(
                  color: adminMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: adminDark,
                ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onNewTrip,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nuevo viaje'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 15),
            ),
          ),
          const SizedBox(width: 7),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notificaciones',
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded, size: 20),
              ),
              const Positioned(
                right: 7,
                top: 7,
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(width: 7),
          PopupMenuButton<String>(
            tooltip: 'Cuenta',
            onSelected: (value) {
              if (value == 'logout') onExit();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: Color(0xFFDBEAFE),
                    child: Icon(Icons.person_rounded, color: adminBlue, size: 17),
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Administrador',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 17),
                ],
              ),
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
  final String? badge;

  const _Header({
    required this.title,
    required this.subtitle,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2854), Color(0xFF174B91), Color(0xFF0D6B8D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33174B91),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 9,
                  runSpacing: 6,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -.4,
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3316A34A),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 6,
                              height: 6,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0xFFBBF7D0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFD7E7FA),
                    height: 1.35,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _MetricTone { blue, green, orange, purple }

class _Metric extends StatelessWidget {
  final String title;
  final Object? value;
  final IconData icon;
  final bool alert;
  final _MetricTone tone;
  final String? footnote;

  const _Metric(
    this.title,
    this.value,
    this.icon, {
    this.alert = false,
    this.tone = _MetricTone.blue,
    this.footnote,
  });

  Color get _soft {
    if (alert) return const Color(0xFFFFE7E7);
    switch (tone) {
      case _MetricTone.green:
        return const Color(0xFFDDF8EA);
      case _MetricTone.orange:
        return const Color(0xFFFFEED0);
      case _MetricTone.purple:
        return const Color(0xFFEDE5FF);
      case _MetricTone.blue:
        return const Color(0xFFE1ECFF);
    }
  }

  Color get _accent {
    if (alert) return const Color(0xFFDC2626);
    switch (tone) {
      case _MetricTone.green:
        return const Color(0xFF0F9F68);
      case _MetricTone.orange:
        return const Color(0xFFD97706);
      case _MetricTone.purple:
        return const Color(0xFF7C3AED);
      case _MetricTone.blue:
        return const Color(0xFF2563EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 138),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _accent.withOpacity(.16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -17,
            right: -17,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: _soft.withOpacity(.72),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: _accent, size: 20),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up_rounded, color: _accent, size: 13),
                        const SizedBox(width: 3),
                        const Text(
                          'HOY',
                          style: TextStyle(
                            color: adminMuted,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                (value ?? 0).toString(),
                style: const TextStyle(
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: adminDark,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  color: adminDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (footnote != null) ...[
                const SizedBox(height: 4),
                Text(
                  footnote!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: adminMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onLive;
  final VoidCallback onDrivers;
  final VoidCallback onDispatch;

  const _QuickActions({
    required this.onLive,
    required this.onDrivers,
    required this.onDispatch,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        'Ver viajes en vivo',
        'Monitorea la operación en tiempo real',
        Icons.location_on_outlined,
        const Color(0xFFCFF3E2),
        const Color(0xFF129B67),
        onLive,
      ),
      (
        'Gestionar conductores',
        'Administra estados, aprobación y flota',
        Icons.drive_eta_rounded,
        const Color(0xFFFFE7A8),
        const Color(0xFFC98000),
        onDrivers,
      ),
      (
        'Despacho manual',
        'Asigna un conductor directamente',
        Icons.alt_route_rounded,
        const Color(0xFFD8E5FF),
        const Color(0xFF246BFD),
        onDispatch,
      ),
    ];

    Widget actionCard(
      (String, String, IconData, Color, Color, VoidCallback) action,
    ) {
      return InkWell(
        onTap: action.$6,
        borderRadius: BorderRadius.circular(13),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: action.$4,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: action.$5.withOpacity(.18),
            ),
            boxShadow: [
              BoxShadow(
                color: action.$5.withOpacity(.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.72),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(action.$3, color: action.$5, size: 19),
                ),
                const SizedBox(height: 12),
                Text(
                  action.$1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: adminDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: adminMuted,
                    height: 1.3,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 10),
                Icon(Icons.arrow_forward_rounded, color: action.$5, size: 18),
              ],
            ),
          ),
        ),
      );
    }

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones rápidas',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: adminDark,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    for (final action in actions) ...[
                      SizedBox(
                        width: double.infinity,
                        child: actionCard(action),
                      ),
                      if (action != actions.last) const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    Expanded(
                      child: SizedBox(
                        height: 166,
                        child: actionCard(actions[i]),
                      ),
                    ),
                    if (i != actions.length - 1) const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SystemStatus extends StatelessWidget {
  final Map<String, dynamic> metrics;

  const _SystemStatus({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final rows = [
      (
        'Conductores',
        metrics['drivers_online'],
        'de ' + (metrics['drivers_total'] ?? 0).toString() + ' conectados',
        Icons.drive_eta_rounded,
      ),
      (
        'Usuarios',
        metrics['users_total'],
        'Registrados',
        Icons.people_alt_outlined,
      ),
      (
        'Solicitudes',
        metrics['ride_searching'],
        'Pendientes',
        Icons.radar_rounded,
      ),
      (
        'SOS',
        metrics['open_emergencies'],
        'Sin alertas',
        Icons.sos_rounded,
      ),
    ];

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado del sistema',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: adminDark,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FA),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(rows[i].$4, size: 16, color: adminMuted),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].$1,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: adminDark,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          rows[i].$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: adminMuted,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    (rows[i].$2 ?? 0).toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: adminDark,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF12B76A),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, color: Color(0xFFEEF1F5)),
          ],
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  final Widget child;
  const _Surface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFDDE6F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LiveZoneStrip extends StatelessWidget {
  final List<Map<String, dynamic>> zones;
  final String? selectedZoneId;
  final ValueChanged<String?> onSelected;

  const _LiveZoneStrip({
    required this.zones,
    required this.selectedZoneId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = <Color>[
      const Color(0xFF0B57D0),
      const Color(0xFF12B76A),
      const Color(0xFFF79009),
      const Color(0xFF7A2CF3),
      const Color(0xFF06AED4),
      const Color(0xFFEF4444),
    ];

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      Color? dot,
      IconData? icon,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? adminBlue : const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? adminBlue : const Color(0xFFE4EAF2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : adminMuted,
                )
              else if (dot != null)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : adminDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 68,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
      child: Row(
        children: [
          chip(
            label: 'Todas las zonas',
            selected: selectedZoneId == null,
            icon: Icons.grid_view_rounded,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: zones.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final zone = zones[index];
                final id = (zone['id'] ?? '').toString();
                return chip(
                  label: (zone['name'] ?? 'Zona').toString(),
                  selected: id.isNotEmpty && id == selectedZoneId,
                  dot: palette[index % palette.length],
                  onTap: () => onSelected(id.isEmpty ? null : id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveSidePanel extends StatefulWidget {
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> drivers;

  const _LiveSidePanel({
    required this.trips,
    required this.drivers,
  });

  @override
  State<_LiveSidePanel> createState() => _LiveSidePanelState();
}

class _LiveSidePanelState extends State<_LiveSidePanel> {
  bool showDrivers = false;

  @override
  Widget build(BuildContext context) {
    final online = widget.drivers.where((row) {
      final status = _driverLiveStatus(row, widget.trips);
      return status != 'offline';
    }).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _LiveMetricCard(
                    label: 'Viajes activos',
                    value: widget.trips.length,
                    icon: Icons.route_rounded,
                    soft: const Color(0xFFE5F8F1),
                    accent: const Color(0xFF12A66A),
                    note: 'En tiempo real',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LiveMetricCard(
                    label: 'Conductores',
                    value: online,
                    icon: Icons.groups_2_outlined,
                    soft: const Color(0xFFF0E8FF),
                    accent: const Color(0xFF7A2CF3),
                    note: 'Conectados ahora',
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 45,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFEEF1F5)),
                bottom: BorderSide(color: Color(0xFFEEF1F5)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _LiveTab(
                    label: 'Viajes (' + widget.trips.length.toString() + ')',
                    selected: !showDrivers,
                    onTap: () {
                      if (showDrivers) setState(() => showDrivers = false);
                    },
                  ),
                ),
                Expanded(
                  child: _LiveTab(
                    label:
                        'Conductores (' + widget.drivers.length.toString() + ')',
                    selected: showDrivers,
                    onTap: () {
                      if (!showDrivers) setState(() => showDrivers = true);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: showDrivers
                ? _LiveDriverList(
                    drivers: widget.drivers,
                    trips: widget.trips,
                  )
                : _LiveTripList(trips: widget.trips),
          ),
        ],
      ),
    );
  }
}

class _LiveMetricCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color soft;
  final Color accent;
  final String note;

  const _LiveMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.soft,
    required this.accent,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const Spacer(),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: adminDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: adminDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: TextStyle(
              color: accent,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LiveTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? adminBlue : adminMuted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          if (selected)
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: adminBlue,
            ),
        ],
      ),
    );
  }
}

class _LiveTripList extends StatelessWidget {
  final List<Map<String, dynamic>> trips;
  const _LiveTripList({required this.trips});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return const Center(
        child: Text(
          'No hay viajes activos.',
          style: TextStyle(color: adminMuted, fontSize: 10),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: trips.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
      itemBuilder: (context, index) {
        final row = trips[index];
        final id = (row['id'] ?? '').toString();
        final shortId = id.length > 7 ? id.substring(0, 7).toUpperCase() : id;
        final status = (row['status'] ?? 'activo').toString();
        final channel =
            (row['channel'] ?? 'production').toString().toLowerCase();
        final isPreview = channel == 'preview';
        final channelLabel = isPreview ? 'Prueba' : 'Producción';
        final channelForeground =
            isPreview ? const Color(0xFFB54708) : const Color(0xFF14804A);
        final channelBackground =
            isPreview ? const Color(0xFFFFF7E6) : const Color(0xFFE8F8EF);
        final pickup = (row['pickup_address'] ?? 'Origen').toString();
        final destination =
            (row['destination_address'] ?? 'Destino').toString();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF246BFD),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shortId.isEmpty ? 'Viaje activo' : '#' + shortId,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: adminDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: channelBackground,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            channelLabel,
                            style: TextStyle(
                              color: channelForeground,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F0FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: adminBlue,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pickup + '  →  ' + destination,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: adminMuted,
                        fontSize: 8,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveDriverList extends StatelessWidget {
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> trips;

  const _LiveDriverList({
    required this.drivers,
    required this.trips,
  });

  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty) {
      return const Center(
        child: Text(
          'No hay conductores para mostrar.',
          style: TextStyle(color: adminMuted, fontSize: 10),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: drivers.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
      itemBuilder: (context, index) {
        final row = drivers[index];
        final status = _driverLiveStatus(row, trips);
        final name = (row['name'] ??
                row['full_name'] ??
                row['driver_name'] ??
                'Conductor')
            .toString();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _driverStatusColor(status).withOpacity(.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.drive_eta_rounded,
                  size: 16,
                  color: _driverStatusColor(status),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: adminDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _driverStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _driverStatusLabel(status),
                style: const TextStyle(
                  color: adminMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OperationsMap extends StatelessWidget {
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> deliveries;
  final List<Map<String, dynamic>> emergencies;
  final Map<String, dynamic>? selectedZone;
  final bool fullScreen;

  const _OperationsMap({
    super.key,
    required this.drivers,
    required this.trips,
    required this.deliveries,
    required this.emergencies,
    this.selectedZone,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    void addMarker(
      Map<String, dynamic> row,
      String latKey,
      String lngKey,
      IconData icon,
      String tooltip,
      Color color,
    ) {
      final lat = _toDouble(row[latKey]);
      final lng = _toDouble(row[lngKey]);
      if (lat == null || lng == null) return;
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 46,
          height: 46,
          child: Tooltip(
            message: tooltip,
            child: _MapDot(icon: icon, color: color),
          ),
        ),
      );
    }

    for (final row in drivers) {
      final status = _driverLiveStatus(row, trips);
      final name = (row['name'] ??
              row['full_name'] ??
              row['driver_name'] ??
              'Conductor')
          .toString();
      addMarker(
        row,
        'latitude',
        'longitude',
        Icons.drive_eta_rounded,
        name + ' · ' + _driverStatusLabel(status),
        _driverStatusColor(status),
      );
    }

    for (final row in trips) {
      addMarker(
        row,
        'pickup_latitude',
        'pickup_longitude',
        Icons.local_taxi_rounded,
        'Viaje · ' + (row['pickup_address'] ?? 'Origen').toString(),
        adminBlue,
      );
    }

    for (final row in deliveries) {
      addMarker(
        row,
        'pickup_latitude',
        'pickup_longitude',
        Icons.local_shipping_rounded,
        'Delivery · ' + (row['pickup_address'] ?? 'Origen').toString(),
        adminDark,
      );
    }

    for (final row in emergencies) {
      addMarker(
        row,
        'latitude',
        'longitude',
        Icons.sos_rounded,
        'SOS · ' + (row['user_name'] ?? 'Usuario').toString(),
        const Color(0xFFD92D20),
      );
    }

    final zoneLat = _toDouble(selectedZone?['center_latitude']);
    final zoneLng = _toDouble(selectedZone?['center_longitude']);
    final zoneRadiusKm = _toDouble(selectedZone?['radius_km']);

    final center = zoneLat != null && zoneLng != null
        ? LatLng(zoneLat, zoneLng)
        : _center(drivers, trips, deliveries, emergencies);

    final available =
        drivers.where((d) => _driverLiveStatus(d, trips) == 'available').length;
    final noSignal =
        drivers.where((d) => _driverLiveStatus(d, trips) == 'signal').length;
    final inTrip =
        drivers.where((d) => _driverLiveStatus(d, trips) == 'trip').length;
    final offline =
        drivers.where((d) => _driverLiveStatus(d, trips) == 'offline').length;

    final map = FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: selectedZone != null ? 13.5 : (fullScreen ? 13 : 12),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.express.delivery',
        ),
        if (zoneLat != null && zoneLng != null && zoneRadiusKm != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: LatLng(zoneLat, zoneLng),
                radius: zoneRadiusKm * 1000,
                useRadiusInMeter: true,
                color: const Color(0x1F0B57D0),
                borderColor: adminBlue,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      surfaceTintColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (!fullScreen) ...[
            const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, color: adminBlue),
                  SizedBox(width: 8),
                  Text(
                    'Mapa operativo',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: map),
                if (selectedZone != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.94),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A101828),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        (selectedZone?['name'] ?? 'Zona').toString(),
                        style: const TextStyle(
                          color: adminDark,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _MapStatusLegend(
                    available: available,
                    noSignal: noSignal,
                    inTrip: inTrip,
                    offline: offline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapStatusLegend extends StatelessWidget {
  final int available;
  final int noSignal;
  final int inTrip;
  final int offline;

  const _MapStatusLegend({
    required this.available,
    required this.noSignal,
    required this.inTrip,
    required this.offline,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Disponibles', available, const Color(0xFF12B76A)),
      ('En línea, sin señal', noSignal, const Color(0xFF246BFD)),
      ('En viaje', inTrip, const Color(0xFFF79009)),
      ('Desconectados', offline, const Color(0xFFE5484D)),
    ];

    return Container(
      width: 190,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.95),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE4EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A101828),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conductores',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: adminDark,
            ),
          ),
          const SizedBox(height: 7),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: row.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        color: adminMuted,
                        fontSize: 8,
                      ),
                    ),
                  ),
                  Text(
                    row.$2.toString(),
                    style: const TextStyle(
                      color: adminDark,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MapDot extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MapDot({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

String _driverLiveStatus(
  Map<String, dynamic> driver,
  List<Map<String, dynamic>> trips,
) {
  final online =
      (driver['online_status'] ?? driver['status'] ?? 'offline')
          .toString()
          .toLowerCase();
  final signal = (driver['signal_status'] ??
          driver['location_status'] ??
          driver['gps_status'] ??
          '')
      .toString()
      .toLowerCase();

  final driverId =
      (driver['user_id'] ?? driver['driver_id'] ?? driver['id'] ?? '')
          .toString();
  final driverName =
      (driver['name'] ?? driver['full_name'] ?? driver['driver_name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

  final inTrip = trips.any((trip) {
    final tripDriverId =
        (trip['driver_id'] ?? trip['driver_user_id'] ?? '').toString();
    final tripDriverName =
        (trip['driver_name'] ?? '').toString().trim().toLowerCase();
    return (driverId.isNotEmpty && tripDriverId == driverId) ||
        (driverName.isNotEmpty && tripDriverName == driverName);
  });

  if (inTrip || online.contains('trip') || online.contains('busy')) {
    return 'trip';
  }

  final connected =
      online == 'online' || online == 'available' || online == 'connected';
  if (!connected) return 'offline';

  final noSignal = signal.contains('no_signal') ||
      signal.contains('no signal') ||
      signal.contains('lost') ||
      signal.contains('stale') ||
      signal.contains('offline');
  if (noSignal) return 'signal';

  return 'available';
}

Color _driverStatusColor(String status) {
  switch (status) {
    case 'trip':
      return const Color(0xFFF79009);
    case 'signal':
      return const Color(0xFF246BFD);
    case 'offline':
      return const Color(0xFFE5484D);
    default:
      return const Color(0xFF12B76A);
  }
}

String _driverStatusLabel(String status) {
  switch (status) {
    case 'trip':
      return 'En viaje';
    case 'signal':
      return 'Sin señal';
    case 'offline':
      return 'Desconectado';
    default:
      return 'Disponible';
  }
}

class _Activity extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _Activity({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actividad reciente',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: adminDark,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'Todavía no hay actividad.',
                      style: TextStyle(color: adminMuted, fontSize: 11),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length > 6 ? 6 : rows.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFEEF1F5)),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final alert = row['kind'] == 'emergency';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 31,
                              height: 31,
                              decoration: BoxDecoration(
                                color: alert
                                    ? const Color(0xFFFFE8E8)
                                    : const Color(0xFFEAF2FF),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                _activityIcon(row['kind']?.toString()),
                                color: alert
                                    ? const Color(0xFFD92D20)
                                    : adminBlue,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row['title']?.toString() ?? 'Actividad',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: adminDark,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    row['subtitle']?.toString() ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: adminMuted,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(row['created_at']),
                              style: const TextStyle(
                                color: Color(0xFF98A2B3),
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DailySummary extends StatelessWidget {
  final Map<String, dynamic> metrics;
  const _DailySummary({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Total de viajes',
        metrics['trips_today'],
        Icons.local_taxi_rounded,
        const Color(0xFFE5F8F1),
        const Color(0xFF129B67),
      ),
      (
        'Completados',
        metrics['completed_today'],
        Icons.task_alt_rounded,
        const Color(0xFFF0E8FF),
        const Color(0xFF7A2CF3),
      ),
      (
        'Viajes activos',
        metrics['active_trips'],
        Icons.location_on_outlined,
        const Color(0xFFE8F0FF),
        const Color(0xFF246BFD),
      ),
      (
        'Conductores online',
        metrics['drivers_online'],
        Icons.drive_eta_rounded,
        const Color(0xFFFFF3D9),
        const Color(0xFFD98A00),
      ),
    ];

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del día',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: adminDark,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: items[i].$4,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(items[i].$3, color: items[i].$5, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i].$1,
                      style: const TextStyle(
                        color: adminDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    (items[i].$2 ?? 0).toString(),
                    style: const TextStyle(
                      color: adminDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1)
              const Divider(height: 1, color: Color(0xFFEEF1F5)),
          ],
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  final Map<String, dynamic> metrics;
  const _Totals({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final items = <(String, Object?)>[
      ('Usuarios', metrics['users_total']),
      ('Conductores', metrics['drivers_total']),
      ('Pendientes', metrics['drivers_pending']),
      ('Viajes hoy', metrics['trips_today']),
      ('Delivery hoy', metrics['deliveries_today']),
      ('Delivery completados', metrics['completed_deliveries_today']),
    ];

    return Card(
      elevation: 0,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 34,
          runSpacing: 18,
          children: items
              .map(
                (item) => SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item.$2 ?? 0).toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        item.$1,
                        style: const TextStyle(
                          color: adminMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _Records extends StatefulWidget {
  final String title;
  final String subtitle;
  final String empty;
  final List<Map<String, dynamic>> rows;
  final Widget Function(Map<String, dynamic>) item;
  final bool showQaFilter;
  final Widget? serverFilters;

  const _Records({
    required this.title,
    required this.subtitle,
    required this.empty,
    required this.rows,
    required this.item,
    this.showQaFilter = false,
    this.serverFilters,
  });

  @override
  State<_Records> createState() => _RecordsState();
}

class _RecordsState extends State<_Records> {
  final search = TextEditingController();
  String query = '';
  String? status;
  String qaFilter = 'all';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statuses = widget.rows
        .map((row) => row['status']?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final visible = widget.rows.where((row) {
      final matchesText = query.isEmpty ||
          row.values
              .map((value) => value?.toString().toLowerCase() ?? '')
              .join(' ')
              .contains(query.toLowerCase());
      final matchesStatus =
          status == null || row['status']?.toString() == status;
      final isQa = row['is_qa'] == true;
      final matchesQa = !widget.showQaFilter ||
          qaFilter == 'all' ||
          (qaFilter == 'qa' && isQa) ||
          (qaFilter == 'real' && !isQa);
      return matchesText && matchesStatus && matchesQa;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        _Header(title: widget.title, subtitle: widget.subtitle),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7ECF3)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.serverFilters != null) widget.serverFilters!,
              SizedBox(
                width: 240,
                child: TextField(
                  controller: search,
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    hintText: 'Buscar',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              ChoiceChip(
                label: Text('Todos (' + widget.rows.length.toString() + ')'),
                selected: status == null,
                onSelected: (_) => setState(() => status = null),
              ),
              for (final value in statuses.take(5))
                ChoiceChip(
                  label: Text(value),
                  selected: status == value,
                  onSelected: (_) => setState(() => status = value),
                ),
              if (widget.showQaFilter) ...[
                const SizedBox(width: 4),
                ChoiceChip(
                  avatar: const Icon(Icons.people_alt_outlined, size: 15),
                  label: const Text('Reales'),
                  selected: qaFilter == 'real',
                  onSelected: (_) => setState(() => qaFilter = 'real'),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.science_outlined, size: 15),
                  label: const Text('QA / pruebas'),
                  selected: qaFilter == 'qa',
                  onSelected: (_) => setState(() => qaFilter = 'qa'),
                ),
                if (qaFilter != 'all')
                  TextButton(
                    onPressed: () => setState(() => qaFilter = 'all'),
                    child: const Text('Quitar filtro QA'),
                  ),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Exportación CSV/Excel se conectará en el módulo de reportes.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded, size: 17),
                label: const Text('Exportar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7ECF3)),
            ),
            child: Text(
              query.isNotEmpty || status != null
                  ? 'No hay resultados para los filtros seleccionados.'
                  : widget.empty,
              style: const TextStyle(color: adminMuted),
            ),
          )
        else
          ...visible.map(widget.item),
      ],
    );
  }
}

class _OperationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> details;
  final VoidCallback? onTap;

  const _OperationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.details,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7ECF3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: onTap != null
          ? ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              onTap: onTap,
              leading: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: adminBlue, size: 17),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: const TextStyle(
                  color: adminMuted,
                  fontSize: 10,
                ),
              ),
              trailing: const Tooltip(
                message: 'Ver detalle completo',
                child: Icon(Icons.open_in_new_rounded, color: adminBlue),
              ),
            )
          : ExpansionTile(
              dense: true,
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              childrenPadding: const EdgeInsets.fromLTRB(50, 0, 14, 12),
              leading: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: adminBlue, size: 17),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: const TextStyle(
                  color: adminMuted,
                  fontSize: 10,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 6,
                    children: details
                        .map(
                          (value) => Text(
                            value,
                            style: const TextStyle(
                              color: adminMuted,
                              fontSize: 10,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    final value = text.toLowerCase();
    final positive =
        value == 'approved' || value == 'online' || value == 'active';
    final warning = value == 'pending';
    final bg = positive
        ? const Color(0xFFE8F8EF)
        : warning
            ? const Color(0xFFFFF3E7)
            : const Color(0xFFF2F4F7);
    final fg = positive
        ? const Color(0xFF14804A)
        : warning
            ? const Color(0xFFC76B16)
            : const Color(0xFF475467);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Line(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(icon, size: 17, color: adminMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: adminMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Coming extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _Coming({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        _Header(title: title, subtitle: description),
        const SizedBox(height: 22),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(icon, size: 52, color: adminBlue),
                const SizedBox(height: 14),
                const Text(
                  'Módulo preparado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ya está incluido en la navegación. El siguiente bloque conectará sus datos y configuración en Supabase.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: adminMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: const [
        _Header(
          title: 'Cargando operación',
          subtitle: 'Sincronizando datos administrativos con Express.',
        ),
        SizedBox(height: 18),
        LinearProgressIndicator(),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'No se pudo cargar el módulo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: adminMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Unauthorized extends StatelessWidget {
  final VoidCallback onExit;
  const _Unauthorized({required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 52),
                  const SizedBox(height: 12),
                  const Text(
                    'Acceso de administrador',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Esta cuenta no está autorizada para administrar Express.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onExit,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

LatLng _center(
  List<Map<String, dynamic>> drivers,
  List<Map<String, dynamic>> trips,
  List<Map<String, dynamic>> deliveries,
  List<Map<String, dynamic>> emergencies,
) {
  for (final row in emergencies) {
    final lat = _toDouble(row['latitude']);
    final lng = _toDouble(row['longitude']);
    if (lat != null && lng != null) return LatLng(lat, lng);
  }
  for (final row in drivers) {
    final lat = _toDouble(row['latitude']);
    final lng = _toDouble(row['longitude']);
    if (lat != null && lng != null) return LatLng(lat, lng);
  }
  for (final row in trips) {
    final lat = _toDouble(row['pickup_latitude']);
    final lng = _toDouble(row['pickup_longitude']);
    if (lat != null && lng != null) return LatLng(lat, lng);
  }
  for (final row in deliveries) {
    final lat = _toDouble(row['pickup_latitude']);
    final lng = _toDouble(row['pickup_longitude']);
    if (lat != null && lng != null) return LatLng(lat, lng);
  }
  return const LatLng(-20.2208, -70.1431);
}

IconData _activityIcon(String? kind) {
  switch (kind) {
    case 'delivery':
      return Icons.local_shipping_rounded;
    case 'emergency':
      return Icons.sos_rounded;
    default:
      return Icons.local_taxi_rounded;
  }
}

String _formatDate(Object? raw) {
  final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (value == null) return '—';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return day +
      '/' +
      month +
      '/' +
      value.year.toString() +
      ' · ' +
      hour +
      ':' +
      minute;
}

String _formatTime(Object? raw) {
  final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (value == null) return '';
  return value.hour.toString().padLeft(2, '0') +
      ':' +
      value.minute.toString().padLeft(2, '0');
}
