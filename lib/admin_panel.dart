import 'dart:convert';

import 'package:flutter/material.dart';
import 'core/admin_friendly_error.dart';
import 'core/admin_dropdown_field.dart';
import 'core/admin_friendly_labels.dart';
import 'core/admin_money.dart';
import 'core/admin_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'core/supabase_client.dart';
import 'admin_runtime_scope.dart';
import 'admin_operators.dart';
import 'admin_control_sections.dart';
import 'admin_single_app_release.dart';
import 'admin_audit_sandbox.dart';
import 'admin_load_lab.dart';
import 'admin_driver_subscriptions.dart';
import 'admin_marketplace.dart';
import 'admin_marketplace_phase2.dart';
import 'admin_delivery_unified.dart';
import 'admin_delivery_settlements.dart';
import 'admin_driver_priority.dart';
import 'admin_driver_championship.dart';
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
    textTheme: base.textTheme
        .apply(fontFamily: 'Plus Jakarta Sans')
        .copyWith(
          // Texto base de 14 px: los desplegables y las listas heredan este tamaño.
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        side: const BorderSide(color: Color(0xFFD0D5DD)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        foregroundColor: adminDark,
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
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
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      titleTextStyle: const TextStyle(
        inherit: false,
        color: adminDark,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: const TextStyle(
        inherit: false,
        color: adminDark,
        fontSize: 13.5,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: adminDark,
      titleTextStyle: TextStyle(
        inherit: false,
        color: adminDark,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      subtitleTextStyle: TextStyle(
        inherit: false,
        color: adminMuted,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14),
      minVerticalPadding: 8,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE4E9F2)),
      ),
      textStyle: const TextStyle(
        inherit: false,
        color: adminDark,
        fontSize: 13,
        fontWeight: FontWeight.w700,
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
  final String initialChannel;

  const ExpressAdminPanel({
    super.key,
    required this.onExit,
    required this.initialChannel,
  });

  @override
  State<ExpressAdminPanel> createState() => _ExpressAdminPanelState();
}

class _ExpressAdminPanelState extends State<ExpressAdminPanel> {
  int section = 0;
  int revision = 0;
  late String adminChannel;
  bool allowPreview = true;
  bool allowProduction = true;
  String? liveZoneId;
  String? selectedLiveTripId;

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

  bool get _readOnly => adminAccess['read_only'] == true;

  // Cuenta con zona asignada (monitor u operador): solo ve su zona, sin selector.
  bool get _zoneScoped =>
      (adminAccess['zone_id'] ?? '').toString().trim().isNotEmpty;

  Widget _assignedZoneLabel() {
    final zone = (adminAccess['zone_name'] ?? '').toString();
    final country = (adminAccess['country'] ?? '').toString();
    final text = [zone, country].where((v) => v.isNotEmpty).join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text.isEmpty ? 'Zona asignada' : text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: adminBlue,
        ),
      ),
    );
  }

  Set<String> get _allowedModules {
    final raw = adminAccess['allowed_modules'];
    if (raw is! List) return const <String>{};
    return raw
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static const Map<int, String> _sectionModuleKeys = {
    0: 'dashboard',
    1: 'live_operations',
    2: 'trips',
    3: 'delivery',
    4: 'drivers',
    5: 'users',
    6: 'safety_sos',
    7: 'zones',
    8: 'fares',
    9: 'payments',
    10: 'reports',
    11: 'settings',
    12: 'builds',
    13: 'manual_dispatch',
    14: 'audit',
    15: 'notifications',
    16: 'services',
    17: 'geo_safety',
    19: 'advanced_settings',
    20: 'test_environments',
    21: 'qa_load',
    22: 'subscriptions',
    23: 'marketplace',
    24: 'delivery_phase2',
    25: 'driver_priority',
    26: 'delivery_orders',
    28: 'dynamic_pricing',
    29: 'fares',
    30: 'marketplace',
    31: 'payments',
    32: 'operators',
  };

  bool _sectionAllowed(int index) {
    // Identity review is already part of the driver record. The old standalone
    // identity entries are deliberately unreachable.
    if (index == 18 || index == 27) return false;
    // Builds (Android) solo se usa en Producción; en Prueba no aparece en el menú.
    if (index == 12 && adminChannel == 'preview') return false;
    final module = _sectionModuleKeys[index];
    if (module == null) return false;
    final allowed = _allowedModules;
    return allowed.contains('*') || allowed.contains(module);
  }

  Set<int> get _allowedSections =>
      _sectionModuleKeys.keys.where(_sectionAllowed).toSet();
  // Android releases belong to the entire Express app, never to a
  // country, city or service zone. Operational sections still require scope.
  // These administration modules cover the entire Express system rather than
  // an operational country, zone, or a separate Preview/Production mode.
  static const Set<int> _globalSections = {10, 12, 14, 32}; // Reports, Builds, Audit, Operadores
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
    adminChannel = widget.initialChannel;
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
    ('Prueba de carga', Icons.speed_rounded),
    ('Suscripciones', Icons.workspace_premium_rounded),
    ('Delivery', Icons.storefront_rounded),
    ('Delivery Fase 2 / Express Plus', Icons.delivery_dining_rounded),
    ('Prioridad conductores', Icons.workspace_premium_outlined),
    ('Pedidos Delivery', Icons.receipt_long_rounded),
    ('Verificación manual', Icons.fact_check_outlined),
    ('Demanda y precios', Icons.trending_up_rounded),
    ('Campeonato Express', Icons.emoji_events_outlined),
    ('Restaurantes', Icons.restaurant_rounded),
    ('Liquidaciones de restaurantes', Icons.receipt_long_rounded),
    ('Operadores', Icons.admin_panel_settings_rounded),
  ];

  Future<bool> _authorized() async {
    final value = await supabase.rpc('admin_access_context');
    if (value is! Map) return false;
    final access = Map<String, dynamic>.from(value);
    if (access['allowed'] != true) return false;

    final runtime = access['runtime_environment']?.toString();
    if (runtime != 'preview' && runtime != 'production') return false;
    if (runtime != widget.initialChannel) return false;

    adminAccess = access;
    adminChannel = runtime!;
    allowPreview =
        adminChannel == 'preview' && access['allow_preview'] != false;
    allowProduction =
        adminChannel == 'production' && access['allow_production'] != false;

    if (!await supabase.rpc(
      'admin_environment_allowed',
      params: {'p_channel': adminChannel},
    )) {
      return false;
    }

    final assignedZone = access['zone_id']?.toString();
    if (assignedZone != null && assignedZone.isNotEmpty) {
      adminCountryCode =
          access['country_code']?.toString().trim().toUpperCase();
      adminZoneId = assignedZone;
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
        AdminPillChoice(
          label: 'Hoy',
          selected: period == 'today',
          showCheck: true,
          onSelected: (_) => select('today'),
        ),
        AdminPillChoice(
          label: 'Semana',
          selected: period == 'week',
          showCheck: true,
          onSelected: (_) => select('week'),
        ),
        AdminPillChoice(
          label: 'Mes',
          selected: period == 'month',
          showCheck: true,
          onSelected: (_) => select('month'),
        ),
        OutlinedButton.icon(
          onPressed: selectCustom,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 13),
          ),
          icon: const Icon(Icons.date_range_outlined, size: 16),
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
              child: AdminDropdownField<String?>(
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
              child: AdminDropdownField<String?>(
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
              child: AdminDropdownField<String?>(
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
    if (_readOnly) {
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
                child: AdminDropdownField<String?>(
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public_rounded, size: 18, color: adminBlue),
                  SizedBox(width: 6),
                  Text(
                    _zoneScoped ? 'Zona asignada' : 'Ámbito obligatorio',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: adminDark,
                    ),
                  ),
                ],
              ),
              if (!_zoneScoped)
              SizedBox(
                width: 190,
                child: AdminDropdownField<String?>(
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
              if (!_zoneScoped) zoneField,
              if (_zoneScoped) _assignedZoneLabel(),
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

  /// Visible runtime badge. The authenticated identity fixes the environment;
  /// there is deliberately no in-app Preview/Production switch.
  Widget _environmentSwitcher() {
    final preview = adminChannel == 'preview';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: preview ? const Color(0xFFFFF7E6) : const Color(0xFFE8F8EF),
      child: Row(
        children: [
          Icon(
            preview ? Icons.science_rounded : Icons.verified_rounded,
            size: 19,
            color: preview ? const Color(0xFFB54708) : const Color(0xFF14804A),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              preview
                  ? 'PRUEBA · Datos de prueba'
                  : 'EXPRESS PRODUCCIÓN · Datos reales',
              style: TextStyle(
                color:
                    preview ? const Color(0xFF7A2E0E) : const Color(0xFF0F6848),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            'Entorno asignado por usuario',
            style: TextStyle(
              color:
                  preview ? const Color(0xFF935B0B) : const Color(0xFF156C41),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _goTo(int value) {
    if (!_sectionAllowed(value)) return;
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
      SnackBar(content: Text(friendlyError(error))),
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
                        if (!_readOnly && _sectionAllowed(13))
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
                          readOnly: _readOnly,
                          allowedSections: _allowedSections,
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
                        readOnly: _readOnly,
                        allowedSections: _allowedSections,
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
                            showNewTrip: !_readOnly && _sectionAllowed(13),
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
    // Preview y Producción comparten el mismo árbol de navegación.
    // La autorización de cada acción la resuelve el backend y los permisos del admin.
    if (_requiresZoneScope(value) && !_scopeReady) {
      return const _ScopeSelectionRequired();
    }

    if (!_sectionAllowed(value)) {
      return const _PermissionRestricted();
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
                        text: 'Zonas y cobertura'),
                    Tab(icon: Icon(Icons.shield_outlined),
                        text: 'Seguridad'),
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
        return AdminSettingsPage(
          key: ValueKey('settings-$adminChannel-$adminCountryCode-$adminZoneId'),
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 12:
        return AdminSingleAppReleasePage(
          productionAccess: allowProduction && adminChannel == 'production',
          zoneId: adminZoneId,
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
        return AdminDeliveryUnifiedPage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
          readOnly: _readOnly,
          buildDirectDeliveries: _deliveryList,
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
      case 30:
        return AdminMarketplacePage(
          channel: adminChannel,
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 32:
        return const AdminOperatorsPage();
      case 31:
        return AdminDeliverySettlementsPage(
          channel: adminChannel,
          zoneId: adminZoneId,
        );
      case 29:
        return AdminDriverChampionshipPage(
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
              _Header(
                title: 'Express Delivery',
                subtitle: 'Bienvenido al panel de control de tu empresa.',
                badge: 'Activa',
                action: FilledButton.icon(
                  onPressed: () => _goTo(1),
                  icon: const Icon(Icons.bolt_rounded, size: 17),
                  label: const Text('Ver en vivo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(.16),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  // Cuatro indicadores en fila desde el ancho del diseño (≈984 px).
                  final cardWidth = width < 480
                      ? width
                      : width < 760
                          ? (width - 14) / 2
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

        Map<String, dynamic>? selectedTrip;
        if (selectedLiveTripId != null) {
          for (final trip in trips) {
            if ((trip['id'] ?? '').toString() == selectedLiveTripId) {
              selectedTrip = trip;
              break;
            }
          }
          if (selectedTrip == null) {
            selectedLiveTripId = null;
          }
        }

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
                    selectedLiveTripId = null;
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
                      selectedTripId: selectedLiveTripId,
                      onTripSelected: (value) {
                        setState(() {
                          selectedLiveTripId =
                              value == selectedLiveTripId ? null : value;
                        });
                      },
                      onShowDrivers: () {
                        if (selectedLiveTripId == null) return;
                        setState(() => selectedLiveTripId = null);
                      },
                    );
                    final map = _OperationsMap(
                      key: ValueKey(
                        'live-map-' +
                            (liveZoneId ?? 'all') +
                            '-' +
                            (selectedLiveTripId ?? 'overview'),
                      ),
                      drivers: drivers,
                      trips: trips,
                      deliveries: deliveries,
                      emergencies: emergencies,
                      selectedZone: selectedZone,
                      selectedTrip: selectedTrip,
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
                friendlyAddress((row['pickup_address'] ?? 'Origen').toString()) +
                ' → ' +
                friendlyAddress(
                  (row['destination_address'] ?? 'Destino').toString(),
                ),
            subtitle:
                friendlyStatus((row['status'] ?? '—').toString()) +
                ' · ' +
                friendlyService((row['category'] ?? 'economy').toString()) +
                ' · ' +
                adminMoney(
                  row['final_fare'],
                  (row['currency'] ?? row['currency_code'])?.toString(),
                ),
            details: [
              'Pasajero: ' + (row['passenger_name'] ?? '—').toString(),
              'Conductor: ' + (row['driver_name'] ?? '—').toString(),
              'Pago: ' +
                  friendlyStatus((row['payment_status'] ?? '—').toString()),
              'Creado: ' + _formatDate(row['created_at']),
            ],
            onTap: _readOnly
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
                friendlyAddress((row['pickup_address'] ?? 'Origen').toString()) +
                ' → ' +
                friendlyAddress(
                  (row['dropoff_address'] ?? 'Destino').toString(),
                ),
            subtitle:
                friendlyStatus((row['status'] ?? '—').toString()) +
                ' · ' +
                friendlyPackage((row['package_type'] ?? '').toString()) +
                ' · ' +
                adminMoney(
                  row['proposed_fare'],
                  (row['currency'] ?? row['currency_code'])?.toString(),
                ),
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

                  final Widget actions = _readOnly
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
            child: Material(type: MaterialType.transparency, child: ListTile(
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
                    friendlyStatus((row['active_mode'] ?? 'passenger').toString()) +
                    ' · ' +
                    friendlyStatus((row['account_status'] ?? 'active').toString()),
              ),
              trailing: _readOnly
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
            )),
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
              trailing: _readOnly
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

class _PermissionRestricted extends StatelessWidget {
  const _PermissionRestricted();

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
              'Módulo no habilitado para esta cuenta',
              style: TextStyle(
                color: adminDark,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Tu rol o tus permisos no incluyen este módulo.',
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
  final Set<int> allowedSections;
  final ValueChanged<int> onSelected;
  final VoidCallback onExit;

  const _Navigation({
    required this.selected,
    required this.channel,
    this.readOnly = false,
    required this.allowedSections,
    required this.onSelected,
    required this.onExit,
  });

  List<(String, List<int>)> get groups {
    final source = readOnly
        ? const <(String, List<int>)>[
            ('GENERAL', [0]),
            ('OPERACIONES', [1, 2, 3, 26, 4, 5, 6]),
          ]
        : const <(String, List<int>)>[
            ('GENERAL', [0]),
            ('OPERACIONES', [1, 2, 13, 4, 5, 6]),
            ('MÓDULOS', [23, 25, 29]),
            ('FINANZAS', [9, 8, 22]),
            ('ANÁLISIS', [10, 14]),
            ('COMUNICACIÓN', [15]),
            ('CONFIGURACIÓN', [16, 7, 11, 19, 12, 28, 32]),
            ('HERRAMIENTAS DE PRUEBA', [20, 21]),
          ];

    return source
        .map(
          (group) => (
            group.$1,
            group.$2.where(allowedSections.contains).toList(),
          ),
        )
        .where((group) => group.$2.isNotEmpty)
        .toList();
  }

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
  // Acción opcional (por ejemplo «Ver en vivo») dentro del banner, a la derecha.
  final Widget? action;

  const _Header({
    required this.title,
    required this.subtitle,
    this.badge,
    this.action,
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
          if (action != null) ...[const SizedBox(width: 16), action!],
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
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.72),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(action.$3, color: action.$5, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  action.$1,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: adminDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    height: 1.3,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
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
              // Tres mosaicos en fila como en el diseño; apilados solo en pantallas estrechas.
              if (constraints.maxWidth < 430) {
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

              // Los tres mosaicos comparten la altura del más alto, sin altura fija que recorte el texto.
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      Expanded(child: actionCard(actions[i])),
                      if (i != actions.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
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

    // Material (no Container) como fondo: las fichas usan Ink, que se pinta sobre el
    // Material más cercano; con un Container blanco encima, el fondo de cada ficha
    // quedaba tapado y solo se veían el texto y el punto.
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4EAF2)),
      ),
      child: Container(
      height: 68,
      padding: const EdgeInsets.all(10),
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
                final name =
                    (zone['name'] ?? zone['city'] ?? '').toString().trim();
                return chip(
                  label: name.isEmpty ? 'Zona ${index + 1}' : name,
                  selected: id.isNotEmpty && id == selectedZoneId,
                  dot: palette[index % palette.length],
                  onTap: () => onSelected(id.isEmpty ? null : id),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _LiveSidePanel extends StatefulWidget {
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> drivers;
  final String? selectedTripId;
  final ValueChanged<String?> onTripSelected;
  final VoidCallback onShowDrivers;

  const _LiveSidePanel({
    required this.trips,
    required this.drivers,
    required this.selectedTripId,
    required this.onTripSelected,
    required this.onShowDrivers,
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
                      if (!showDrivers) {
                        setState(() => showDrivers = true);
                        widget.onShowDrivers();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (!showDrivers && widget.selectedTripId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
              color: const Color(0xFFEFF6FF),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_center_focus_rounded,
                    size: 16,
                    color: adminBlue,
                  ),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'Vista enfocada en un solo viaje',
                      style: TextStyle(
                        color: adminBlue,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => widget.onTripSelected(null),
                    icon: const Icon(Icons.close_rounded, size: 15),
                    label: const Text('Mostrar todo'),
                    style: TextButton.styleFrom(
                      foregroundColor: adminBlue,
                      textStyle: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
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
                : _LiveTripList(
                    trips: widget.trips,
                    selectedTripId: widget.selectedTripId,
                    onSelected: widget.onTripSelected,
                  ),
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
  final String? selectedTripId;
  final ValueChanged<String?> onSelected;

  const _LiveTripList({
    required this.trips,
    required this.selectedTripId,
    required this.onSelected,
  });

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
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final row = trips[index];
        final id = (row['id'] ?? '').toString();
        final selected = id.isNotEmpty && id == selectedTripId;
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

        return Material(
          color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: id.isEmpty ? null : () => onSelected(id),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF93C5FD)
                      : const Color(0x00FFFFFF),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF0B57D0)
                          : const Color(0xFF246BFD),
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
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: selected ? adminBlue : adminDark,
                                ),
                              ),
                            ),
                            if (selected)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.visibility_rounded,
                                  size: 15,
                                  color: adminBlue,
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
                                friendlyStatus(status),
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
                          friendlyAddress(pickup) +
                              '  →  ' +
                              friendlyAddress(destination),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: adminMuted,
                            fontSize: 8,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          selected
                              ? 'Seleccionado · el mapa muestra solo este viaje'
                              : 'Toca para ver este recorrido en el mapa',
                          style: TextStyle(
                            color: selected ? adminBlue : const Color(0xFF98A2B3),
                            fontSize: 8,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
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

class _OperationsMap extends StatefulWidget {
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> deliveries;
  final List<Map<String, dynamic>> emergencies;
  final Map<String, dynamic>? selectedZone;
  final Map<String, dynamic>? selectedTrip;
  final bool fullScreen;

  const _OperationsMap({
    super.key,
    required this.drivers,
    required this.trips,
    required this.deliveries,
    required this.emergencies,
    this.selectedZone,
    this.selectedTrip,
    this.fullScreen = false,
  });

  @override
  State<_OperationsMap> createState() => _OperationsMapState();
}

class _OperationsMapState extends State<_OperationsMap> {
  String? _selectedDriverId;
  Future<List<LatLng>>? _routeFuture;
  String? _routeTripId;

  @override
  void initState() {
    super.initState();
    _syncRoute();
  }

  @override
  void didUpdateWidget(covariant _OperationsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.selectedTrip?['id']?.toString();
    final newId = widget.selectedTrip?['id']?.toString();
    if (oldId != newId) {
      _selectedDriverId = null;
      _syncRoute();
    }
  }

  void _syncRoute() {
    final trip = widget.selectedTrip;
    final id = trip?['id']?.toString();
    if (trip == null || id == null || id.isEmpty) {
      _routeTripId = null;
      _routeFuture = null;
      return;
    }
    if (_routeTripId == id && _routeFuture != null) return;
    _routeTripId = id;
    _routeFuture = _fetchTripRoute(trip);
  }

  static LatLng? _point(
    Map<String, dynamic>? row,
    String latKey,
    String lngKey,
  ) {
    final lat = _toDouble(row?[latKey]);
    final lng = _toDouble(row?[lngKey]);
    if (lat == null || lng == null) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  static String _driverId(Map<String, dynamic> row) =>
      (row['user_id'] ?? row['driver_id'] ?? row['id'] ?? '').toString();

  Map<String, dynamic>? _driverForTrip(Map<String, dynamic> trip) {
    final tripDriverId =
        (trip['driver_id'] ?? trip['driver_user_id'] ?? '').toString();
    if (tripDriverId.isEmpty) return null;
    for (final driver in widget.drivers) {
      if (_driverId(driver) == tripDriverId) return driver;
    }
    return null;
  }

  Map<String, dynamic>? _selectedDriver() {
    final id = _selectedDriverId;
    if (id == null || id.isEmpty) return null;
    for (final driver in widget.drivers) {
      if (_driverId(driver) == id) return driver;
    }
    return null;
  }

  Future<List<LatLng>> _fetchTripRoute(Map<String, dynamic> trip) async {
    final from = _point(trip, 'pickup_latitude', 'pickup_longitude');
    final to = _point(
      trip,
      'destination_latitude',
      'destination_longitude',
    );
    if (from == null || to == null) return const <LatLng>[];

    final fallback = <LatLng>[from, to];
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/' +
            from.longitude.toString() +
            ',' +
            from.latitude.toString() +
            ';' +
            to.longitude.toString() +
            ',' +
            to.latitude.toString() +
            '?overview=full&geometries=geojson',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return fallback;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['routes'] is! List) return fallback;
      final routes = decoded['routes'] as List;
      if (routes.isEmpty || routes.first is! Map) return fallback;
      final geometry = (routes.first as Map)['geometry'];
      if (geometry is! Map || geometry['coordinates'] is! List) {
        return fallback;
      }

      final points = <LatLng>[];
      for (final raw in geometry['coordinates'] as List) {
        if (raw is! List || raw.length < 2) continue;
        final lng = _toDouble(raw[0]);
        final lat = _toDouble(raw[1]);
        if (lat == null || lng == null) continue;
        if (!lat.isFinite ||
            !lng.isFinite ||
            lat < -90 ||
            lat > 90 ||
            lng < -180 ||
            lng > 180) {
          continue;
        }
        points.add(LatLng(lat, lng));
      }
      return points.length >= 2 ? points : fallback;
    } catch (_) {
      return fallback;
    }
  }

  static ({LatLng center, double zoom}) _cameraFor(
    List<LatLng> points,
    LatLng fallback,
  ) {
    if (points.isEmpty) return (center: fallback, zoom: 13);
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    final spanLat = maxLat - minLat;
    final spanLng = maxLng - minLng;
    final span = spanLat > spanLng ? spanLat : spanLng;

    final zoom = span < .004
        ? 16.0
        : span < .008
            ? 15.0
            : span < .018
                ? 14.0
                : span < .04
                    ? 13.0
                    : span < .08
                        ? 12.0
                        : span < .16
                            ? 11.0
                            : 10.0;

    return (
      center: LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
      zoom: zoom,
    );
  }

  Marker _driverMarker(
    Map<String, dynamic> row,
    String status, {
    String? tooltip,
  }) {
    final point = _point(row, 'latitude', 'longitude');
    if (point == null) {
      return Marker(
        point: const LatLng(0, 0),
        width: 0,
        height: 0,
        child: const SizedBox.shrink(),
      );
    }

    final id = _driverId(row);
    final name = (row['full_name'] ??
            row['name'] ??
            row['driver_name'] ??
            'Conductor')
        .toString();
    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: Tooltip(
        message: tooltip ?? (name + ' · ' + _driverStatusLabel(status)),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (id.isEmpty) return;
              setState(() {
                _selectedDriverId = _selectedDriverId == id ? null : id;
              });
            },
            child: _MapDot(
              icon: Icons.drive_eta_rounded,
              color: _driverStatusColor(status),
            ),
          ),
        ),
      ),
    );
  }

  Marker _entityMarker({
    required LatLng point,
    required Widget child,
    required String tooltip,
    double width = 48,
    double height = 48,
  }) {
    return Marker(
      point: point,
      width: width,
      height: height,
      child: Tooltip(message: tooltip, child: child),
    );
  }

  Widget _buildMap(List<LatLng> routePoints) {
    final focusedTrip = widget.selectedTrip;
    final focused = focusedTrip != null;
    final markers = <Marker>[];
    final polylines = <Polyline>[];
    final cameraPoints = <LatLng>[];

    Map<String, dynamic>? focusedDriver;
    LatLng? driverPoint;
    LatLng? pickupPoint;
    LatLng? destinationPoint;

    if (focused && focusedTrip != null) {
      pickupPoint = _point(
        focusedTrip,
        'pickup_latitude',
        'pickup_longitude',
      );
      destinationPoint = _point(
        focusedTrip,
        'destination_latitude',
        'destination_longitude',
      );
      focusedDriver = _driverForTrip(focusedTrip);
      driverPoint = _point(focusedDriver, 'latitude', 'longitude');

      if (routePoints.length >= 2) {
        polylines.add(
          Polyline(
            points: routePoints,
            strokeWidth: 5,
            color: adminBlue,
          ),
        );
        cameraPoints.addAll(routePoints);
      } else {
        if (pickupPoint != null) cameraPoints.add(pickupPoint);
        if (destinationPoint != null) cameraPoints.add(destinationPoint);
      }

      if (pickupPoint != null) {
        markers.add(
          _entityMarker(
            point: pickupPoint,
            tooltip: 'Punto A · ' +
                (focusedTrip['pickup_address'] ?? 'Origen').toString(),
            child: const _TripPointMarker(
              label: 'A',
              color: Color(0xFF12B76A),
            ),
          ),
        );
      }

      if (destinationPoint != null) {
        markers.add(
          _entityMarker(
            point: destinationPoint,
            tooltip: 'Punto B · ' +
                (focusedTrip['destination_address'] ?? 'Destino').toString(),
            child: const _TripPointMarker(
              label: 'B',
              color: Color(0xFFE5484D),
            ),
          ),
        );
      }

      final status =
          (focusedTrip['status'] ?? 'activo').toString().toLowerCase();
      final passengerPoint =
          (status == 'in_progress' || status == 'emergency') &&
                  driverPoint != null
              ? driverPoint
              : pickupPoint;
      final passengerName =
          (focusedTrip['passenger_name'] ?? 'Pasajero').toString();

      if (driverPoint != null && focusedDriver != null) {
        cameraPoints.add(driverPoint);
        final driverStatus = _driverLiveStatus(focusedDriver, widget.trips);
        final samePartyPoint = passengerPoint != null &&
            (passengerPoint.latitude - driverPoint.latitude).abs() < .000001 &&
            (passengerPoint.longitude - driverPoint.longitude).abs() < .000001;

        if (samePartyPoint) {
          final id = _driverId(focusedDriver);
          markers.add(
            _entityMarker(
              point: driverPoint,
              width: 66,
              height: 54,
              tooltip: 'Conductor + ' + passengerName,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    if (id.isEmpty) return;
                    setState(() {
                      _selectedDriverId =
                          _selectedDriverId == id ? null : id;
                    });
                  },
                  child: _TripPartyMarker(
                    driverColor: _driverStatusColor(driverStatus),
                  ),
                ),
              ),
            ),
          );
        } else {
          markers.add(
            _driverMarker(
              focusedDriver,
              driverStatus,
              tooltip: (focusedTrip['driver_name'] ?? 'Conductor').toString() +
                  ' · ' +
                  _driverStatusLabel(driverStatus),
            ),
          );
        }
      }

      if (passengerPoint != null &&
          (driverPoint == null ||
              (passengerPoint.latitude - driverPoint.latitude).abs() >=
                  .000001 ||
              (passengerPoint.longitude - driverPoint.longitude).abs() >=
                  .000001)) {
        markers.add(
          _entityMarker(
            point: passengerPoint,
            tooltip: passengerName + ' · Pasajero',
            child: const _PassengerMapMarker(),
          ),
        );
        cameraPoints.add(passengerPoint);
      }
    } else {
      for (final row in widget.drivers) {
        final status = _driverLiveStatus(row, widget.trips);
        final point = _point(row, 'latitude', 'longitude');
        if (point == null) continue;
        markers.add(_driverMarker(row, status));
        cameraPoints.add(point);
      }

      for (final row in widget.trips) {
        final point = _point(row, 'pickup_latitude', 'pickup_longitude');
        if (point == null) continue;
        markers.add(
          _entityMarker(
            point: point,
            tooltip:
                'Viaje · ' + (row['pickup_address'] ?? 'Origen').toString(),
            child: const _MapDot(
              icon: Icons.local_taxi_rounded,
              color: adminBlue,
            ),
          ),
        );
      }

      for (final row in widget.deliveries) {
        final point = _point(row, 'pickup_latitude', 'pickup_longitude');
        if (point == null) continue;
        markers.add(
          _entityMarker(
            point: point,
            tooltip:
                'Delivery · ' + (row['pickup_address'] ?? 'Origen').toString(),
            child: const _MapDot(
              icon: Icons.local_shipping_rounded,
              color: adminDark,
            ),
          ),
        );
      }

      for (final row in widget.emergencies) {
        final point = _point(row, 'latitude', 'longitude');
        if (point == null) continue;
        markers.add(
          _entityMarker(
            point: point,
            tooltip:
                'SOS · ' + (row['user_name'] ?? 'Usuario').toString(),
            child: const _MapDot(
              icon: Icons.sos_rounded,
              color: Color(0xFFD92D20),
            ),
          ),
        );
      }
    }

    final zoneLat = _toDouble(widget.selectedZone?['center_latitude']);
    final zoneLng = _toDouble(widget.selectedZone?['center_longitude']);
    final zoneRadiusKm = _toDouble(widget.selectedZone?['radius_km']);
    final fallback = zoneLat != null && zoneLng != null
        ? LatLng(zoneLat, zoneLng)
        : _center(
            widget.drivers,
            widget.trips,
            widget.deliveries,
            widget.emergencies,
          );

    final camera = focused
        ? _cameraFor(cameraPoints, fallback)
        : (
            center: fallback,
            zoom: widget.selectedZone != null
                ? 13.5
                : (widget.fullScreen ? 13.0 : 12.0),
          );

    final available = widget.drivers
        .where((d) => _driverLiveStatus(d, widget.trips) == 'available')
        .length;
    final noSignal = widget.drivers
        .where((d) => _driverLiveStatus(d, widget.trips) == 'signal')
        .length;
    final inTrip = widget.drivers
        .where((d) => _driverLiveStatus(d, widget.trips) == 'trip')
        .length;
    final offline = widget.drivers
        .where((d) => _driverLiveStatus(d, widget.trips) == 'offline')
        .length;

    final selectedDriver = _selectedDriver();
    final map = FlutterMap(
      key: ValueKey(
        focused
            ? 'focused-' +
                (focusedTrip?['id'] ?? '').toString() +
                '-' +
                routePoints.length.toString()
            : 'overview-' + (widget.selectedZone?['id'] ?? 'all').toString(),
      ),
      options: MapOptions(
        initialCenter: camera.center,
        initialZoom: camera.zoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.express.delivery',
        ),
        if (!focused &&
            zoneLat != null &&
            zoneLng != null &&
            zoneRadiusKm != null)
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
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
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
          if (!widget.fullScreen) ...[
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
                if (focused && focusedTrip != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: selectedDriver == null ? 12 : 320,
                    child: _FocusedTripMapBanner(trip: focusedTrip),
                  )
                else if (widget.selectedZone != null)
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
                        (widget.selectedZone?['name'] ?? 'Zona').toString(),
                        style: const TextStyle(
                          color: adminDark,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                if (selectedDriver != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _DriverMapCard(
                      driver: selectedDriver,
                      status: _driverLiveStatus(
                        selectedDriver,
                        widget.trips,
                      ),
                      onClose: () => setState(() => _selectedDriverId = null),
                    ),
                  ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: focused
                      ? const _FocusedTripLegend()
                      : _MapStatusLegend(
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

  @override
  Widget build(BuildContext context) {
    final trip = widget.selectedTrip;
    if (trip == null) return _buildMap(const <LatLng>[]);

    final fallback = <LatLng>[
      if (_point(trip, 'pickup_latitude', 'pickup_longitude') case final p?)
        p,
      if (_point(
        trip,
        'destination_latitude',
        'destination_longitude',
      ) case final p?)
        p,
    ];

    return FutureBuilder<List<LatLng>>(
      future: _routeFuture,
      initialData: fallback,
      builder: (context, snapshot) {
        return _buildMap(snapshot.data ?? fallback);
      },
    );
  }
}

class _TripPointMarker extends StatelessWidget {
  final String label;
  final Color color;

  const _TripPointMarker({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
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
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PassengerMapMarker extends StatelessWidget {
  const _PassengerMapMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF7A2CF3),
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
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
    );
  }
}

class _TripPartyMarker extends StatelessWidget {
  final Color driverColor;

  const _TripPartyMarker({required this.driverColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 52,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 42,
              height: 42,
              child: _MapDot(
                icon: Icons.drive_eta_rounded,
                color: driverColor,
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(
              width: 36,
              height: 36,
              child: _PassengerMapMarker(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusedTripMapBanner extends StatelessWidget {
  final Map<String, dynamic> trip;

  const _FocusedTripMapBanner({required this.trip});

  @override
  Widget build(BuildContext context) {
    final id = (trip['id'] ?? '').toString();
    final shortId = id.length > 7 ? id.substring(0, 7).toUpperCase() : id;
    final passenger = (trip['passenger_name'] ?? 'Pasajero').toString();
    final driver = (trip['driver_name'] ?? 'Sin conductor').toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A101828),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_center_focus_rounded,
            size: 18,
            color: adminBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Viaje #' +
                  (shortId.isEmpty ? 'ACTIVO' : shortId) +
                  ' · ' +
                  passenger +
                  ' · ' +
                  driver,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: adminDark,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverMapCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final String status;
  final VoidCallback onClose;

  const _DriverMapCard({
    required this.driver,
    required this.status,
    required this.onClose,
  });

  String _value(String key, {String fallback = '—'}) {
    final value = driver[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    final updated = DateTime.tryParse(_value('location_updated_at'));
    final updatedLabel = updated == null
        ? 'Sin hora de ubicación'
        : 'Ubicación: ' + _formatDate(updated.toIso8601String());

    return Container(
      width: 295,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.97),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFDDE6F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24101828),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _driverStatusColor(status).withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.drive_eta_rounded,
                  size: 18,
                  color: _driverStatusColor(status),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _value('full_name', fallback: 'Conductor'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: adminDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
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
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 17),
                tooltip: 'Cerrar',
              ),
            ],
          ),
          const Divider(height: 18),
          _DriverInfoLine(icon: Icons.phone_outlined, text: _value('phone')),
          const SizedBox(height: 6),
          _DriverInfoLine(icon: Icons.mail_outline_rounded, text: _value('email')),
          const SizedBox(height: 6),
          _DriverInfoLine(
            icon: Icons.directions_car_outlined,
            text: _value('vehicle_summary', fallback: 'Vehículo sin detalle'),
          ),
          const SizedBox(height: 6),
          _DriverInfoLine(
            icon: Icons.star_outline_rounded,
            text: 'Calificación ' +
                _value('rating', fallback: '—') +
                ' · ' +
                _value('completed_trips', fallback: '0') +
                ' viajes',
          ),
          const SizedBox(height: 6),
          _DriverInfoLine(
            icon: Icons.my_location_rounded,
            text: updatedLabel,
          ),
        ],
      ),
    );
  }
}

class _DriverInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DriverInfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: adminMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: adminMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FocusedTripLegend extends StatelessWidget {
  const _FocusedTripLegend();

  @override
  Widget build(BuildContext context) {
    final rows = <(String, Color)>[
      ('A · Origen', const Color(0xFF12B76A)),
      ('B · Destino', const Color(0xFFE5484D)),
      ('Conductor', const Color(0xFFF79009)),
      ('Pasajero', const Color(0xFF7A2CF3)),
      ('Recorrido', adminBlue),
    ];

    return Container(
      width: 160,
      padding: const EdgeInsets.all(10),
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
            'Viaje seleccionado',
            style: TextStyle(
              color: adminDark,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: row.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    row.$1,
                    style: const TextStyle(
                      color: adminMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
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

  final locationUpdatedAt =
      DateTime.tryParse(driver['location_updated_at']?.toString() ?? '');
  final latitude = _toDouble(driver['latitude']);
  final longitude = _toDouble(driver['longitude']);
  final locationStale = locationUpdatedAt == null
      ? latitude == null || longitude == null
      : DateTime.now().toUtc().difference(locationUpdatedAt.toUtc()) >
          const Duration(minutes: 2);

  final noSignal = signal.contains('no_signal') ||
      signal.contains('no signal') ||
      signal.contains('lost') ||
      signal.contains('stale') ||
      signal.contains('offline') ||
      locationStale;
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
                                    friendlyAddress(
                                      row['subtitle']?.toString() ?? '',
                                    ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fila 1: periodo, búsqueda y Exportar al extremo derecho, como en el diseño.
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (widget.serverFilters != null) widget.serverFilters!,
                        SizedBox(
                          width: 240,
                          height: 40,
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'La exportación todavía no está disponible en esta pantalla.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('Exportar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fila 2: estado, QA y categorías.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AdminPillChoice(
                    label: 'Todos (' + widget.rows.length.toString() + ')',
                    selected: status == null,
                    showCheck: true,
                    onSelected: (_) => setState(() => status = null),
                  ),
                  for (final value in statuses.take(5))
                    AdminPillChoice(
                      label: friendlyStatus(value),
                      selected: status == value,
                      dotColor: adminStatusColor(value),
                      onSelected: (_) => setState(() => status = value),
                    ),
                  if (widget.showQaFilter) ...[
                    const SizedBox(width: 4),
                    AdminPillChoice(
                      label: 'Reales',
                      selected: qaFilter == 'real',
                      onSelected: (_) => setState(() => qaFilter = 'real'),
                    ),
                    AdminPillChoice(
                      label: 'Pruebas',
                      selected: qaFilter == 'qa',
                      onSelected: (_) => setState(() => qaFilter = 'qa'),
                    ),
                    if (qaFilter != 'all')
                      TextButton(
                        onPressed: () => setState(() => qaFilter = 'all'),
                        child: const Text('Quitar filtro de pruebas'),
                      ),
                  ],
                ],
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

  // «Pasajero: María» se muestra como etiqueta «Pasajero» y valor «María».
  static String _labelOf(String detail) {
    final cut = detail.indexOf(': ');
    return cut < 0 ? '' : detail.substring(0, cut);
  }

  static String _valueOf(String detail) {
    final cut = detail.indexOf(': ');
    return cut < 0 ? detail : detail.substring(cut + 2);
  }

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: adminUiInk,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: adminUiMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    final cells = Wrap(
      spacing: 22,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final detail in details)
          AdminDetailCell(label: _labelOf(detail), value: _valueOf(detail)),
      ],
    );
    final row = Row(
      children: [
        AdminIconTile(icon: icon),
        const SizedBox(width: 12),
        Expanded(flex: 5, child: heading),
        const SizedBox(width: 16),
        Expanded(
          flex: 5,
          child: Align(alignment: Alignment.centerRight, child: cells),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 12),
          const Tooltip(
            message: 'Ver detalle completo',
            child: AdminIconTile(icon: Icons.open_in_new_rounded, size: 34),
          ),
        ],
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: adminUiLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: row,
        ),
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
        friendlyStatus(text),
        style: TextStyle(
          color: fg,
          fontSize: 11,
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
                  'No se pudo cargar esta sección',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  friendlyError(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: adminMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
