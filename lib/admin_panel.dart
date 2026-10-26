Warning: truncated output (original token count: 51668)
Total output lines: 6282

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import 'admin_control_sections.dart';
import 'admin_debt_management.dart';
import 'admin_operators.dart';
import 'admin_operator_fares.dart';
import 'admin_operator_payments.dart';
import 'admin_operator_subscriptions.dart';
import 'admin_single_app_release.dart';
import 'admin_audit_sandbox.dart';
import 'admin_load_lab.dart';
import 'admin_driver_subscriptions.dart';
import 'admin_marketplace.dart';
import 'admin_marketplace_requirements.dart';
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
    textTheme: base.textTheme.apply(fontFamily: 'Plus Jakarta Sans').copyWith(
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: const TextStyle(color: adminMuted, fontSize: 11),
      hintStyle: const TextStyle(color: Color(0xFF98A2B3), fontSize: 11),
      border: inputBorder(const Color(0xFFD0D5DD)),
      enabledBorder: inputBorder(const Color(0xFFD0D5DD)),
      focusedBorder: inputBorder(adminBlue),
      errorBorder: inputBorder(const Color(0xFFD92D20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        side: const BorderSide(color: Color(0xFFD0D5DD)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        foregroundColor: adminDark,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(38, 38),
        maximumSize: const Size(42, 42),
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

class ExpressAdminPanel extends StatefulWidget {
  final VoidCallback onExit;

  const ExpressAdminPanel({
    super.key,
    required this.onExit,
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
  final Map<int, String> _sectionEnvironmentFilters = <int, String>{};
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
  static const Set<int> _environmentFilteredSections = <int>{
    0, 1, 2, 3, 4, 5, 6, 9, 13, 15, 18, 21, 22, 23, 24, 25, 26, 29, 30,
    31, 33,
  };

  String _sectionChannel(int sectionIndex) {
    if (!_environmentFilteredSections.contains(sectionIndex)) {
      // Operational configuration has one shared source of truth.
      return 'production';
    }
    return _sectionEnvironmentFilters[sectionIndex] ?? adminChannel;
  }

  List<String> get _availableEnvironmentFilters => <String>[
        if (allowPreview && adminAccess['role'] == 'super_admin') 'preview',
        if (allowProduction) 'production',
      ];
  bool get _zoneScoped =>
      (adminAccess['zone_id'] ?? '').toString().trim().isNotEmpty;

  Widget _assignedZoneLabel() {
    final zone = (adminAccess['zone_name'] ?? '').toString();
    final country = (adminAccess['country'] ?? '').toString();
    final text = [zone, country].where((value) => value.isNotEmpty).join(' · ');
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
    33: 'payments',
    34: 'marketplace',
  };

  bool _sectionAllowed(int index) {
    // Identity review is already part of the driver record. The old standalone
    // identity entries are deliberately unreachable.
    if (index == 18 || index == 27) return false;
    // Builds (Android) solo se usa en Producción; en Prueba no aparece en el menú.
    if (index == 12 && !allowProduction) return false;
    if (index == 32 && adminAccess['role'] != 'super_admin') return false;
    // El panel Delivery unificado requiere funciones centrales. Para operadores
    // se autoriza solo el listado de entregas (sección 3), restringido por zona.
    if (index == 23 && adminAccess['role'] == 'operator') return false;
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
  static const Set<int> _globalSections = {
    10,
    12,
    14,
    32,
  }; // Reports, Builds, Audit, Operadores
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
    adminChannel = 'production';
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
    ('Cuentas de prueba', Icons.science_rounded),
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
    ('Deudas y ajustes', Icons.account_balance_wallet_outlined),
    ('Requisitos de restaurantes', Icons.fact_check_outlined),
  ];

  Future<bool> _authorized() async {
    final value = await supabase.rpc('admin_access_context');
    if (value is! Map) return false;
    final access = Map<String, dynamic>.from(value);
    if (access['allowed'] != true) return false;

    final runtime = access['runtime_environment']?.toString();
    if (runtime != 'preview' && runtime != 'production') return false;
    // The account's runtime is the default data filter, not a panel-wide lock.
    // Allowed channels are available inside each operational section.

    adminAccess = access;
    adminChannel = runtime!;
    allowPreview = access['allow_preview'] == true &&
        access['role'] == 'super_admin';
    allowProduction = access['allow_production'] == true;
    final availableEnvironments = _availableEnvironmentFilters;
    if (availableEnvironments.isEmpty) {
      return false;
    }
    for (final environment in availableEnvironments) {
      if (await supabase.rpc(
            'admin_environment_allowed',
            params: {'p_channel': environment},
          ) !=
          true) {
        return false;
      }
    }
    final defaultFilter = availableEnvironments.contains(adminChannel)
        ? adminChannel
        : availableEnvironments.first;
    for (final index in _environmentFilteredSections) {
      _sectionEnvironmentFilters[index] = defaultFilter;
    }

    final assignedZone = access['zone_id']?.toString();
    if (assignedZone != null && assignedZone.isNotEmpty) {
      adminCountryCode =
          access['country_code']?.toString().trim().toUpperCase();
      adminZoneId = assignedZone;
      liveZoneId = adminZoneId;
    }
    // Un operador con solo Usuarios no debe aterrizar en Dashboard sin permiso.
    if (!_sectionAllowed(section)) {
      final available = _allowedSections.toList()..sort();
      if (available.isEmpty) return false;
      section = available.first;
    }
    return true;
  }

  Future<Map<String, dynamic>> _dashboardState(int sectionIndex) async {
    if (!_scopeReady) return <String, dynamic>{};
    final value = await supabase.rpc(
      'admin_dashboard_state_v2',
      params: {
        'p_channel': _sectionChannel(sectionIndex),
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
      return (state: <String, dynamic>{}, zones: <Map<String, dynamic>>[]);
    }
    final state = await _dashboardState(1);
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
        'p_channel': _sectionChannel(4),
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
        'p_channel': _sectionChannel(5),
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
        'p_channel': _sectionChannel(2),
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
        'p_channel': _sectionChannel(3),
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
    if (_zoneScoped) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFFF0FDF4),
          border: Border(bottom: BorderSide(color: Color(0xFFBBF7D0))),
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
              child: Row(
                children: [
                  Text(
                    _readOnly ? 'Monitor de zona' : 'Operador de zona',
                    style: const TextStyle(
                      color: Color(0xFF166534),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _assignedZoneLabel(),
                ],
              ),
            ),
            if (_readOnly)
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
              final zones = zoneSnapshot.data ?? const <Map<String, dynamic>>[];
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
                      _liveFuture = value == null ? null : _liveState();
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
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
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
      _liveFuture = _scopeReady && section == 1 ? _liveState() : null;
    });
  }

  /// Per-section data filter. Shared configuration pages deliberately do not
  /// expose a Preview/Production selector.
  Widget _sectionEnvironmentFilter() {
    if (!_environmentFilteredSections.contains(section)) {
      return const SizedBox.shrink();
    }
    final channel = _sectionChannel(section);
    final preview = channel == 'preview';
    final environments = _availableEnvironmentFilters;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      color: const Color(0xFFF1F4FA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final filter = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_alt_outlined, size: 19, color: adminBlue),
              const SizedBox(width: 8),
              const Text(
                'Mostrar datos:',
                style: TextStyle(
                  color: adminInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 7),
              DropdownButton<String>(
                value: channel,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(12),
                items: environments
                    .map(
                      (environment) => DropdownMenuItem(
                        value: environment,
                        child: Text(
                          environment == 'preview' ? 'Prueba' : 'Producción',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: environments.length < 2
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _sectionEnvironmentFilters[section] = value;
                          selectedLiveTripId = null;
                          revision++;
                          _liveFuture = section == 1 ? _liveState() : null;
                        });
                      },
              ),
            ],
          );
          final status = Text(
            preview ? 'Solo registros de prueba' : 'Solo registros reales',
            style: const TextStyle(
              color: adminMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          );
          if (constraints.maxWidth < 510) {
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 2,
              children: [filter, status],
            );
          }
          return Row(
            children: [filter, const Spacer(), status],
          );
        },
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
          'p_channel': _sectionChannel(4),
        },
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Conductor: ' + status)));
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
          'p_channel': _sectionChannel(5),
        },
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Cuenta: ' + status)));
    } catch (e) {
      if (!mounted) return;
      _errorSnack(e);
    }
  }

  void _errorSnack(Object error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(friendlyError(error))));
  }

  Future<void> _resolveEmergency(String id) async {
    try {
      await supabase.rpc(
        'admin_resolve_emergency_v2',
        params: {'p_emergency_id': id, 'p_channel': _sectionChannel(6)},
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
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
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
                          _sectionEnvironmentFilter(),
                          if (_requiresZoneScope(section))
                            _globalGeoScopeSwitcher(),
                          Expanded(
                            child: KeyedSubtree(
                              key: ValueKey(
                                AdminRuntimeScope(
                                environment: AdminEnvironment.parse(
                                    _sectionChannel(section),
                                  ),
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
          key: ValueKey('unified-zones-$adminZoneId-shared'),
          length: 2,
          child: Column(
            children: [
              const Material(
                color: Colors.white,
                child: TabBar(
                  tabs: [
                    Tab(
                      icon: Icon(Icons.location_city_outlined),
                      text: 'Zonas y cobertura',
                    ),
                    Tab(icon: Icon(Icons.shield_outlined), text: 'Seguridad'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    AdminZonesPage(
                      channel: 'production',
                      countryCode: adminCountryCode,
                      zoneId: adminZoneId,
                    ),
                    AdminGeoSafetyPage(
                      channel: 'production',
                      countryCode: adminCountryCode,
                      zoneId: adminZoneId,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 8:
        if (adminAccess['role'] == 'operator') {
          return AdminOperatorFaresPage(
            zoneId: adminZoneId ?? '',
            zoneName: (adminAccess['zone_name'] ?? 'Mi zona').toString(),
          );
        }
        return AdminFaresPage(
          channel: 'production',
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 9:
        if (adminAccess['role'] == 'operator') {
          return AdminOperatorPaymentsPage(
            zoneId: adminZoneId ?? '',
            zoneName: (adminAccess['zone_name'] ?? 'Mi zona').toString(),
          );
        }
        return AdminPaymentsPage(
          channel: _sectionChannel(9),
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 10:
        return AdminEnvironmentReportsPage(
          includePreview: allowPreview,
          includeProduction: allowProduction,
        );
      case 11:
        return AdminSettingsPage(channel: 'production');
      case 12:
        return AdminSingleAppReleasePage(
          productionAccess: allowProduction,
          zoneId: adminZoneId,
        );
      case 13:
        return AdminDispatchPage(
          channel: _sectionChannel(13),
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
          channel: _sectionChannel(15),
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
          operatorOnly: adminAccess['role'] == 'operator',
        );
      case 16:
        return AdminServicesPage(
          channel: 'production',
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 17:
        return AdminGeoSafetyPage(
          channel: 'production',
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 18:
        return DefaultTabController(
          key: ValueKey('unified-identity-$adminZoneId-${_sectionChannel(18)}'),
          length: 2,
          child: Column(
            children: [
              const Material(
                color: Colors.white,
                child: TabBar(
                  tabs: [
                    Tab(
                      icon: Icon(Icons.fact_check_outlined),
                      text: 'Revisión de documentos',
                    ),
                    Tab(
                      icon: Icon(Icons.settings_outlined),
                      text: 'Requisitos de identidad',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    AdminManualIdentityPage(
                      channel: _sectionChannel(18),
                      countryCode: adminCountryCode,
                      zoneId: adminZoneId,
                    ),
                    AdminIdentitySecurityPage(
                      channel: 'production',
                      countryCode: adminCountryCode,
                      zoneId: adminZoneId,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 19:
        return AdminAdvancedSettingsPage(channel: 'production');
      case 20:
        return const AdminAuditSandboxPage();
      case 21:
        return AdminLoadLabPage(channel: _sectionChannel(21));
      case 22:
        if (adminAccess['role'] == 'operator') {
          return AdminOperatorSubscriptionsPage(
            zoneId: adminZoneId ?? '',
            zoneName: (adminAccess['zone_name'] ?? 'Mi zona').toString(),
          );
        }
        return AdminDriverSubscriptionsPage(
          channel: _sectionChannel(22),
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 23:
        return AdminDeliveryUnifiedPage(
          channel: _sectionChannel(23),
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
          readOnly: _readOnly,
          buildDirectDeliveries: _deliveryList,
        );
      case 24:
        return AdminMarketplacePhase2Page(
          channel: _sectionChannel(24),
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 25:
        return AdminDriverPriorityPage(
          channel: _sectionChannel(25),
          configChannel: 'production',
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 26:
        return AdminMarketplacePhase2Page(
          ordersOnly: true,
          channel: _sectionChannel(26),
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 27:
        return AdminManualIdentityPage(
          channel: _sectionChannel(27),
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 30:
        return AdminMarketplacePage(
          channel: _sectionChannel(30),
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 34:
        return AdminMarketplaceRequirementsPage(
          channel: 'production',
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 32:
        return const AdminOperatorsPage();
      case 33:
        return AdminDebtManagementPage(
          zoneId: adminZoneId ?? '',
          zoneName:
              (adminAccess['zone_name'] ?? 'Zona seleccionada').toString(),
        );
      case 31:
        return AdminDeliverySettlementsPage(
          channel: _sectionChannel(31),
          zoneId: adminZoneId,
        );
      case 29:
        return AdminDriverChampionshipPage(
          channel: _sectionChannel(29),
          countryCode: adminCountryCode,
          zoneId: adminZoneId,
        );
      case 28:
        return AdminDynamicPricingPage(
          channel: 'production',
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
      future: _dashboardState(0),
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
                          footnote: 'de ' +
                              (metrics['drivers_total'] ?? 0).toString() +
                              ' conectados',
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
                      children: [quick, const SizedBox(height: 14), system],
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
    …21668 tokens truncated…yle(
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
    final to = _point(trip, 'destination_latitude', 'destination_longitude');
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
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
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
    final name =
        (row['full_name'] ?? row['name'] ?? row['driver_name'] ?? 'Conductor')
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

    if (focused) {
      pickupPoint = _point(focusedTrip, 'pickup_latitude', 'pickup_longitude');
      destinationPoint = _point(
        focusedTrip,
        'destination_latitude',
        'destination_longitude',
      );
      focusedDriver = _driverForTrip(focusedTrip);
      driverPoint = _point(focusedDriver, 'latitude', 'longitude');

      if (routePoints.length >= 2) {
        polylines.add(
          Polyline(points: routePoints, strokeWidth: 5, color: adminBlue),
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
            child: const _TripPointMarker(label: 'A', color: Color(0xFF12B76A)),
          ),
        );
      }

      if (destinationPoint != null) {
        markers.add(
          _entityMarker(
            point: destinationPoint,
            tooltip: 'Punto B · ' +
                (focusedTrip['destination_address'] ?? 'Destino').toString(),
            child: const _TripPointMarker(label: 'B', color: Color(0xFFE5484D)),
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
                      _selectedDriverId = _selectedDriverId == id ? null : id;
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
            tooltip: 'SOS · ' + (row['user_name'] ?? 'Usuario').toString(),
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
                (focusedTrip['id'] ?? '').toString() +
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
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
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
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
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
                if (focused)
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
                      status: _driverLiveStatus(selectedDriver, widget.trips),
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
      if (_point(trip, 'pickup_latitude', 'pickup_longitude') case final p?) p,
      if (_point(trip, 'destination_latitude', 'destination_longitude')
          case final p?)
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

  const _TripPointMarker({required this.label, required this.color});

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
              child: _MapDot(icon: Icons.drive_eta_rounded, color: driverColor),
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
          _DriverInfoLine(
            icon: Icons.mail_outline_rounded,
            text: _value('email'),
          ),
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
          _DriverInfoLine(icon: Icons.my_location_rounded, text: updatedLabel),
        ],
      ),
    );
  }
}

class _DriverInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DriverInfoLine({required this.icon, required this.text});

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
                      style: const TextStyle(color: adminMuted, fontSize: 8),
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

  const _MapDot({required this.icon, required this.color});

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
  final online = (driver['online_status'] ?? driver['status'] ?? 'offline')
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

  final locationUpdatedAt = DateTime.tryParse(
    driver['location_updated_at']?.toString() ?? '',
  );
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
                                color:
                                    alert ? const Color(0xFFD92D20) : adminBlue,
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
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
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
              style: const TextStyle(color: adminMuted, fontSize: 12),
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

  const _ErrorView({required this.error, required this.onRetry});

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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
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
