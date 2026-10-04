import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_control_sections.dart';
import 'admin_environment_store.dart';
import 'core/supabase_client.dart';

int _adminSubscriptionInt(Object? raw) {
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

class AdminDriverSubscriptionsPage extends StatefulWidget {
  final String channel;

  const AdminDriverSubscriptionsPage({
    super.key,
    this.channel = 'production',
  });

  @override
  State<AdminDriverSubscriptionsPage> createState() =>
      _AdminDriverSubscriptionsPageState();
}

class _AdminDriverSubscriptionsPageState
    extends State<AdminDriverSubscriptionsPage> {
  AdminEnvironmentStore get _environment =>
      AdminEnvironmentStore(widget.channel);
  bool loading = true;
  bool savingSettings = false;
  bool providerSaving = false;
  bool providerVerifying = false;
  String? error;
  List<Map<String, dynamic>> plans = const [];
  List<Map<String, dynamic>> drivers = const [];
  List<Map<String, dynamic>> payments = const [];
  List<Map<String, dynamic>> zones = const [];
  String? selectedZoneKey;
  String paymentPeriod = 'today';
  DateTimeRange? paymentCustomRange;
  Map<String, dynamic> settings = const {};
  Map<String, dynamic> provider = const {};
  final search = TextEditingController();
  Timer? clock;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    search.dispose();
    clock?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _maps(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  bool _isQaDriver(Map<String, dynamic> driver) {
    final email = (driver['email']?.toString() ?? '').trim().toLowerCase();
    final name = (driver['full_name']?.toString() ?? '').trim().toLowerCase();

    // Los usuarios QA usan el prefijo "qa-" en correo o "QA " en nombre.
    // Esto cubre tanto qa-driver@... como qa-load-driver-###@...
    // sin afectar perfiles reales como "conductor prueba".
    final qaEmail =
        email.startsWith('qa-') && email.endsWith('@expressdelivery.pro');
    final qaName = name == 'qa' || name.startsWith('qa ');

    return qaEmail || qaName;
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = plans.isEmpty && settings.isEmpty;
        error = null;
      });
    }

    String? loadError;
    List<Map<String, dynamic>> zoneRows = zones;
    String? zoneKey = selectedZoneKey;

    if (_environment.isPreview) {
      try {
        zoneRows = await _environment.previewList('service_zones');
        if (zoneRows.isNotEmpty &&
            (zoneKey == null ||
                !zoneRows.any(
                  (row) => row['zone_key']?.toString() == zoneKey,
                ))) {
          final trinidad = zoneRows.where(
            (row) => row['zone_key']?.toString() == 'trinidad',
          );
          zoneKey = trinidad.isNotEmpty
              ? 'trinidad'
              : zoneRows.first['zone_key']?.toString();
        }

        final allPlans =
            await _environment.previewList('driver_subscription_plans');
        final zonePlans = allPlans
            .where((row) => row['zone_key']?.toString() == zoneKey)
            .toList()
          ..sort((a, b) =>
              ((a['sort_order'] as num?)?.toInt() ?? 100)
                  .compareTo((b['sort_order'] as num?)?.toInt() ?? 100));

        Map<String, dynamic> zoneSettings = {};
        if (zoneKey != null && zoneKey.isNotEmpty) {
          zoneSettings = await _environment.previewGet(
            'driver_subscription_settings',
            recordKey: zoneKey,
          );
          if (zoneSettings.isEmpty) {
            zoneSettings = await _environment.previewGet(
              'driver_subscription_settings',
            );
          }
        }

        final rawDrivers = await supabase.rpc(
          'admin_driver_subscriptions',
          params: {
            'p_search': search.text.trim(),
            'p_zone_key': zoneKey,
          },
        );
        final qaDrivers = _maps(rawDrivers)
            .where(
              (row) => row['is_qa'] == true || _isQaDriver(row),
            )
            .toList();
        final assignments =
            await _environment.previewList('driver_subscriptions');
        final mergedDrivers = qaDrivers.map((driver) {
          final driverId =
              (driver['driver_id'] ?? driver['user_id'])?.toString();
          Map<String, dynamic>? assignment;
          for (final row in assignments) {
            if (row['driver_id']?.toString() == driverId) {
              assignment = row;
              break;
            }
          }
          return <String, dynamic>{
            ...driver,
            if (assignment != null) ...assignment,
          };
        }).toList();

        final range = _paymentBounds();
        final allPayments =
            await _environment.previewList('subscription_payments');
        final zonePayments = allPayments.where((row) {
          if (zoneKey != null &&
              row['zone_key']?.toString() != zoneKey) {
            return false;
          }
          final created =
              DateTime.tryParse(row['created_at']?.toString() ?? '');
          if (created == null) return true;
          final local = created.toLocal();
          return !local.isBefore(range.from) && local.isBefore(range.to);
        }).toList();

        final providerSettings =
            await _environment.previewGet('driver_subscription_provider');

        if (mounted) {
          setState(() {
            zones = zoneRows;
            selectedZoneKey = zoneKey;
            plans = zonePlans;
            settings = zoneSettings;
            drivers = mergedDrivers;
            payments = zonePayments;
            provider = providerSettings.isEmpty
                ? <String, dynamic>{
                    'connected': false,
                    'settings': <String, dynamic>{},
                  }
                : providerSettings;
            loading = false;
            error = null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            loading = false;
            error = 'Preview: ' + e.toString();
          });
        }
      }
      return;
    }

    try {
      final rawZones = await supabase.rpc('admin_zone_list_v2');
      zoneRows = _maps(rawZones);
      if (zoneRows.isNotEmpty &&
          (zoneKey == null ||
              !zoneRows.any(
                (row) => row['zone_key']?.toString() == zoneKey,
              ))) {
        final trinidad = zoneRows.where(
          (row) => row['zone_key']?.toString() == 'trinidad',
        );
        zoneKey = trinidad.isNotEmpty
            ? 'trinidad'
            : zoneRows.first['zone_key']?.toString();
      }
      if (mounted) {
        setState(() {
          zones = zoneRows;
          selectedZoneKey = zoneKey;
        });
      }
    } catch (e) {
      loadError = 'Zonas: ' + e.toString();
    }

    if (zoneKey != null && zoneKey.isNotEmpty) {
      try {
        final planRows = await supabase
            .from('driver_subscription_plans')
            .select('*')
            .eq('zone_key', zoneKey)
            .order('sort_order');
        if (mounted) {
          setState(() => plans = _maps(planRows));
        }
      } catch (e) {
        loadError ??= 'Planes: ' + e.toString();
      }

      try {
        final settingsRow = await supabase.rpc(
          'admin_zone_subscription_settings',
          params: {'p_zone_key': zoneKey},
        );
        if (mounted && settingsRow is Map) {
          setState(() {
            settings = Map<String, dynamic>.from(settingsRow);
          });
        }
      } catch (e) {
        loadError ??= 'Configuración: ' + e.toString();
      }

      try {
        final driverRows = await supabase.rpc(
          'admin_driver_subscriptions',
          params: {
            'p_search': search.text.trim(),
            'p_zone_key': zoneKey,
          },
        );
        if (mounted) {
          setState(() => drivers = _maps(driverRows));
        }
      } catch (e) {
        loadError ??= 'Conductores: ' + e.toString();
      }

      try {
        final range = _paymentBounds();
        final paymentRows = await supabase.rpc(
          'admin_subscription_payment_list_v2',
          params: {
            'p_zone_key': zoneKey,
            'p_from': range.from.toUtc().toIso8601String(),
            'p_to': range.to.toUtc().toIso8601String(),
            'p_status': null,
            'p_limit': 100,
            'p_offset': 0,
          },
        );
        if (mounted) {
          setState(() => payments = _maps(paymentRows));
        }
      } catch (e) {
        loadError ??= 'Pagos: ' + e.toString();
      }
    } else {
      if (mounted) {
        setState(() {
          plans = const [];
          drivers = const [];
          payments = const [];
          settings = const {};
        });
      }
    }

    try {
      final response = await supabase.functions.invoke(
        'driver-subscription-admin',
        body: const {'action': 'get'},
      );
      if (response.data is Map && mounted) {
        setState(() {
          provider = Map<String, dynamic>.from(response.data as Map);
        });
      }
    } catch (e) {
      loadError ??= 'VeriPagos: ' + e.toString();
    }

    if (!mounted) return;
    setState(() {
      loading = false;
      error = loadError;
    });
  }

  ({DateTime from, DateTime to}) _paymentBounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (paymentPeriod) {
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
        final range = paymentCustomRange;
        if (range != null) {
          final from = DateTime(
            range.start.year,
            range.start.month,
            range.start.day,
          );
          final end = DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
          );
          return (from: from, to: end.add(const Duration(days: 1)));
        }
        return (from: today, to: today.add(const Duration(days: 1)));
      default:
        return (from: today, to: today.add(const Duration(days: 1)));
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String _money(Object? raw, [String? currency]) {
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;
    final code =
        (currency ?? settings['currency_code']?.toString() ?? 'BOB')
            .toUpperCase();
    final prefix = code == 'BOB' ? 'Bs' : code;
    return prefix +
        ' ' +
        (value == value.roundToDouble()
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(2));
  }

  String _date(Object? raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (value == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return two(value.day) +
        '/' +
        two(value.month) +
        '/' +
        value.year.toString() +
        ' · ' +
        two(value.hour) +
        ':' +
        two(value.minute);
  }

  String _remaining(Object? raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '');
    if (value == null) return 'Sin plan';
    final left = value.toUtc().difference(DateTime.now().toUtc());
    if (left.isNegative) return 'Vencido';
    final d = left.inDays;
    final h = left.inHours.remainder(24);
    final m = left.inMinutes.remainder(60);
    final s = left.inSeconds.remainder(60);
    return d.toString().padLeft(2, '0') +
        'd ' +
        h.toString().padLeft(2, '0') +
        'h ' +
        m.toString().padLeft(2, '0') +
        'm ' +
        s.toString().padLeft(2, '0') +
        's';
  }

  List<String> _benefits(Map<String, dynamic> plan) {
    final raw = plan['benefits'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList();
  }

  Future<void> _editPlan([Map<String, dynamic>? plan]) async {
    final zoneKey = selectedZoneKey;
    if (zoneKey == null) {
      _snack('Selecciona una zona.');
      return;
    }

    Map<String, dynamic>? selectedZone;
    for (final zone in zones) {
      if (zone['zone_key']?.toString() == zoneKey) {
        selectedZone = zone;
        break;
      }
    }
    final isBolivia =
        (selectedZone?['country']?.toString() ?? '').toLowerCase() == 'bolivia';

    final code = TextEditingController(text: plan?['code']?.toString() ?? '');
    final name = TextEditingController(text: plan?['name']?.toString() ?? '');
    final amount =
        TextEditingController(text: plan?['amount']?.toString() ?? '');
    final days = TextEditingController(text: plan?['days']?.toString() ?? '');
    final benefits =
        TextEditingController(text: plan == null ? '' : _benefits(plan).join('\n'));
    var active = plan?['active'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(plan == null ? 'Nuevo plan' : 'Editar plan'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: code,
                    enabled: plan == null,
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      hintText: 'Ej. daily, weekly, monthly',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText:
                          'Precio (' + (settings['currency_code'] ?? 'BOB').toString() + ')',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: days,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Días de acceso',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: benefits,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Beneficios',
                      hintText: 'Un beneficio por línea',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Plan visible y activo'),
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      code.dispose();
      name.dispose();
      amount.dispose();
      days.dispose();
      benefits.dispose();
      return;
    }

    final parsedAmount =
        double.tryParse(amount.text.trim().replaceAll(',', '.'));
    final parsedDays = int.tryParse(days.text.trim());
    final benefitList = benefits.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (code.text.trim().isEmpty ||
        name.text.trim().isEmpty ||
        parsedAmount == null ||
        parsedAmount < 0 ||
        parsedDays == null ||
        parsedDays < 1) {
      _snack('Revisa código, nombre, precio y duración.');
      return;
    }

    try {
      await supabase.rpc(
        'admin_upsert_driver_subscription_plan',
        params: {
          'p_id': plan?['id'],
          'p_zone_key': zoneKey,
          'p_code': code.text.trim(),
          'p_name': name.text.trim(),
          'p_amount': parsedAmount,
          'p_days': parsedDays,
          'p_benefits': benefitList,
          'p_active': active,
          'p_sort_order': plan?['sort_order'] ?? (plans.length + 1) * 10,
        },
      );
      _snack(plan == null ? 'Plan creado.' : 'Plan actualizado.');
      await _load();
    } catch (e) {
      _snack('No se pudo guardar: ' + e.toString());
    } finally {
      code.dispose();
      name.dispose();
      amount.dispose();
      days.dispose();
      benefits.dispose();
    }
  }

  Future<void> _saveSettings({
    required bool enabled,
    required bool enforce,
    required bool providerEnabled,
    required String qrValidity,
  }) async {
    final zoneKey = selectedZoneKey;
    if (zoneKey == null) {
      _snack('Selecciona una zona.');
      return;
    }

    Map<String, dynamic>? selectedZone;
    for (final zone in zones) {
      if (zone['zone_key']?.toString() == zoneKey) {
        selectedZone = zone;
        break;
      }
    }
    final isBolivia =
        (selectedZone?['country']?.toString() ?? '').toLowerCase() == 'bolivia';

    if (enforce && settings['enforce_access'] != true) {
      final zoneName = settings['zone_name']?.toString() ?? zoneKey;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Exigir suscripción · $zoneName'),
          content: Text(
            'Solo los conductores de $zoneName sin una suscripción vigente '
            'serán puestos offline. Las demás zonas no se modificarán.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Activar exigencia'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    if (isBolivia && providerEnabled && provider['configured'] != true) {
      _snack('Configura y verifica primero VeriPagos.');
      return;
    }
    if (isBolivia &&
        providerEnabled &&
        provider['status_endpoint_ready'] != true) {
      _snack(
        'Falta conectar el endpoint de verificación de estado QR antes de habilitar cobros.',
      );
      return;
    }

    setState(() => savingSettings = true);
    try {
      await supabase.rpc(
        'admin_set_driver_subscription_zone_settings',
        params: {
          'p_zone_key': zoneKey,
          'p_enabled': enabled,
          'p_enforce_access': enforce,
        },
      );
      if (isBolivia) {
        await supabase.rpc(
          'admin_set_driver_subscription_provider_settings',
          params: {
            'p_provider_enabled': providerEnabled,
            'p_qr_validity': qrValidity,
          },
        );
      }
      _snack('Configuración de la zona guardada.');
      await _load();
    } catch (e) {
      _snack('No se pudo guardar: ' + e.toString());
    } finally {
      if (mounted) setState(() => savingSettings = false);
    }
  }

  Future<void> _assignPlan(Map<String, dynamic> driver) async {
    if (plans.isEmpty) return;
    final validPlanIds =
        plans.map((plan) => _adminSubscriptionInt(plan['id'])).toSet();
    final currentPlanId = _adminSubscriptionInt(driver['plan_id']);
    int selected = validPlanIds.contains(currentPlanId)
        ? currentPlanId
        : _adminSubscriptionInt(plans.first['id']);
    int customDays = 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            'Asignar plan · ' +
                (driver['full_name']?.toString().trim().isNotEmpty == true
                    ? driver['full_name'].toString()
                    : driver['email']?.toString() ?? 'Conductor'),
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: [
                    for (final plan in plans)
                      DropdownMenuItem<int>(
                        value: _adminSubscriptionInt(plan['id']),
                        child: Text(
                          (plan['name']?.toString() ?? 'Plan') +
                              ' · ' +
                              _money(plan['amount']) +
                              ' · ' +
                              plan['days'].toString() +
                              ' días',
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => selected = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '0',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Días personalizados (opcional)',
                    helperText: '0 usa la duración normal del plan.',
                  ),
                  onChanged: (v) => customDays = int.tryParse(v) ?? 0,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Activar plan'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    DateTime? expiry;
    if (customDays > 0) {
      expiry = DateTime.now().toUtc().add(Duration(days: customDays));
    }
    try {
      await supabase.rpc(
        'admin_set_driver_subscription',
        params: {
          'p_driver_id': driver['driver_id'],
          'p_plan_id': selected,
          'p_expires_at': expiry?.toIso8601String(),
          'p_notes': 'Asignado desde Adminexpress',
        },
      );
      _snack('Suscripción activada.');
      await _load();
    } catch (e) {
      _snack('No se pudo asignar: ' + e.toString());
    }
  }

  Future<void> _configureProvider() async {
    final data = provider['settings'] is Map
        ? Map<String, dynamic>.from(provider['settings'] as Map)
        : <String, dynamic>{};

    final user = TextEditingController(
      text: data['username']?.toString() ?? '',
    );
    final password = TextEditingController();
    final secret = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conectar VeriPagos'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Express ya tiene configuradas internamente las rutas oficiales '
                  'de VeriPagos. Solo ingresa las credenciales de API.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: user,
                  decoration: const InputDecoration(
                    labelText: 'Usuario Basic Auth',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: data['has_password'] == true
                        ? 'Contraseña · dejar vacía para conservar'
                        : 'Contraseña Basic Auth',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: secret,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: data['has_secret_key'] == true
                        ? 'Secret Key · dejar vacía para conservar'
                        : 'Secret Key',
                  ),
                ),
                const SizedBox(height: 14),
                const _AdminSubNotice(
                  text:
                      'Al verificar, Express generará un QR de prueba por Bs 0 '
                      'con vigencia de 1 minuto. No genera un cobro real.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.verified_rounded),
            label: const Text('Guardar y verificar conexión'),
          ),
        ],
      ),
    );

    if (ok != true) {
      user.dispose();
      password.dispose();
      secret.dispose();
      return;
    }

    setState(() => providerSaving = true);
    try {
      final response = await supabase.functions.invoke(
        'driver-subscription-admin',
        body: {
          'action': 'save_and_verify',
          'username': user.text.trim(),
          'password': password.text,
          'secret_key': secret.text,
        },
      );
      final responseData = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      if (responseData['ok'] != true ||
          responseData['connected'] != true) {
        throw StateError(
          responseData['error']?.toString() ??
              'No se pudo verificar la conexión',
        );
      }

      _snack(
        'VeriPagos conectado: generación y verificación de pagos operativas.',
      );
      await _load();
    } catch (e) {
      _snack('No se pudo conectar con VeriPagos: ' + e.toString());
    } finally {
      user.dispose();
      password.dispose();
      secret.dispose();
      if (mounted) setState(() => providerSaving = false);
    }
  }

  Future<void> _verifyProvider() async {
    setState(() => providerVerifying = true);
    try {
      final response = await supabase.functions.invoke(
        'driver-subscription-admin',
        body: const {'action': 'verify'},
      );
      final responseData = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      if (responseData['ok'] != true ||
          responseData['connected'] != true) {
        throw StateError(
          responseData['error']?.toString() ??
              'No se pudo verificar la conexión',
        );
      }

      _snack('Conexión VeriPagos verificada correctamente.');
      await _load();
    } catch (e) {
      _snack('VeriPagos no responde correctamente: ' + e.toString());
    } finally {
      if (mounted) setState(() => providerVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final providerConfigured = provider['configured'] == true;
    final providerCredentialsConfigured =
        provider['credentials_configured'] == true;
    final enabled = settings['enabled'] == true;
    final enforce = settings['enforce_access'] == true;
    final providerEnabled = settings['provider_enabled'] == true;
    final qrValidity = settings['qr_validity']?.toString() ?? '0/00:15';
    final zoneName =
        settings['zone_name']?.toString() ?? selectedZoneKey ?? 'Zona';
    Map<String, dynamic>? selectedZone;
    for (final zone in zones) {
      if (zone['zone_key']?.toString() == selectedZoneKey) {
        selectedZone = zone;
        break;
      }
    }
    final zoneMethods = _maps(selectedZone?['payment_methods']);
    final subscriptionMethods = zoneMethods
        .where(
          (method) =>
              method['enabled'] != false &&
              method['use_subscriptions'] == true,
        )
        .toList();
    final hasVeriPagosSubscription = subscriptionMethods.any(
      (method) => method['provider_key']?.toString() == 'veripagos_qr',
    );
    final hasMercadoPagoSubscription = subscriptionMethods.any(
      (method) => method['provider_key']?.toString() == 'mercado_pago',
    );
    final realDrivers = drivers.where((driver) => !_isQaDriver(driver)).toList();
    final qaDrivers = drivers.where(_isQaDriver).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suscripciones de conductores',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Planes, vigencias y pagos por zona.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            _AdminSubNotice(text: error!, warning: true),
          ],
          const SizedBox(height: 14),
          if (zones.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.location_city_rounded),
                    const SizedBox(width: 10),
                    const Text(
                      'Zona',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedZoneKey,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Administrar suscripciones de',
                        ),
                        items: [
                          for (final zone in zones)
                            DropdownMenuItem<String>(
                              value: zone['zone_key']?.toString(),
                              child: Text(
                                (zone['name'] ?? 'Zona').toString() +
                                    ' · ' +
                                    (zone['currency_code'] ?? 'BOB').toString(),
                              ),
                            ),
                        ],
                        onChanged: savingSettings
                            ? null
                            : (value) {
                                if (value == null ||
                                    value == selectedZoneKey) {
                                  return;
                                }
                                setState(() {
                                  selectedZoneKey = value;
                                  plans = const [];
                                  drivers = const [];
                                  payments = const [];
                                  settings = const {};
                                  loading = true;
                                });
                                unawaited(_load());
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          _AdminSubNotice(
            text: subscriptionMethods.isEmpty
                ? 'Configurando ' +
                    zoneName +
                    '. Todavía no hay métodos habilitados para pagar suscripciones.'
                : 'Configurando ' +
                    zoneName +
                    '. Métodos de suscripción: ' +
                    subscriptionMethods
                        .map(
                          (method) =>
                              method['display_name']?.toString() ??
                              method['provider_key']?.toString() ??
                              'Método',
                        )
                        .join(', ') +
                    '.',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: selectedZone == null
                  ? null
                  : () async {
                      final changed =
                          await showAdminZonePaymentMethodsEditor(
                        context,
                        selectedZone!,
                      );
                      if (changed && mounted) await _load();
                    },
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Editar métodos de suscripción'),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            enabled: enabled,
            enforce: enforce,
            providerEnabled: providerEnabled,
            providerConfigured: providerConfigured,
            qrValidity: qrValidity,
            showQrProvider: hasVeriPagosSubscription,
            saving: savingSettings,
            onSave: _saveSettings,
          ),
          if (hasVeriPagosSubscription) ...[
            const SizedBox(height: 14),
            _ProviderCard(
              configured: providerConfigured,
              credentialsConfigured: providerCredentialsConfigured,
              enabled: providerEnabled,
              saving: providerSaving,
              verifying: providerVerifying,
              onConfigure: _configureProvider,
              onVerify: _verifyProvider,
            ),
          ],
          if (hasMercadoPagoSubscription) ...[
            const SizedBox(height: 14),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      child: Icon(Icons.account_balance_wallet_rounded),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mercado Pago · Suscripciones',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Método habilitado para esta zona. Las credenciales se administran en Pagos / Billetera y pueden convivir con otros métodos.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Planes · $zoneName',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: selectedZoneKey == null ? null : () => _editPlan(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo plan'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (plans.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'No se pudieron cargar los planes en esta vista. '
                        'El resto del módulo seguirá funcionando mientras se reintenta.',
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Recargar planes'),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final plan in plans)
                  SizedBox(
                    width: 280,
                    child: _AdminPlanCard(
                      plan: plan,
                      price: _money(
                        plan['amount'],
                        plan['currency_code']?.toString(),
                      ),
                      benefits: _benefits(plan),
                      onEdit: () => _editPlan(plan),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Conductores reales (' + realDrivers.length.toString() + ')',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Buscar conductor',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            qaDrivers.isEmpty
                ? 'Los usuarios de prueba no se mezclan con los conductores reales.'
                : qaDrivers.length.toString() +
                    ' conductores QA están separados y no cuentan como reales.',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          if (realDrivers.isEmpty)
            const _AdminSubNotice(text: 'No hay conductores reales para mostrar.')
          else
            for (final driver in realDrivers)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.two_wheeler_rounded),
                  ),
                  title: Text(
                    driver['full_name']?.toString().trim().isNotEmpty == true
                        ? driver['full_name'].toString()
                        : driver['email']?.toString() ?? 'Conductor',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    (driver['plan_name']?.toString() ?? 'Sin plan') +
                        ' · ' +
                        _remaining(driver['expires_at']) +
                        '\n' +
                        (driver['email']?.toString() ?? ''),
                  ),
                  isThreeLine: true,
                  trailing: FilledButton(
                    onPressed: () => _assignPlan(driver),
                    child: Text(
                      driver['plan_id'] == null ? 'Asignar' : 'Editar',
                    ),
                  ),
                ),
              ),
          if (qaDrivers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.science_outlined),
                title: Text(
                  'Conductores de prueba (' + qaDrivers.length.toString() + ')',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'Usuarios QA del laboratorio de carga. No cuentan como conductores reales.',
                ),
                children: [
                  for (final driver in qaDrivers)
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.science_outlined),
                      ),
                      title: Text(
                        driver['full_name']?.toString().trim().isNotEmpty == true
                            ? driver['full_name'].toString()
                            : driver['email']?.toString() ?? 'Conductor QA',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        (driver['plan_name']?.toString() ?? 'Sin plan') +
                            ' · ' +
                            _remaining(driver['expires_at']) +
                            '\n' +
                            (driver['email']?.toString() ?? ''),
                      ),
                      isThreeLine: true,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pagos de suscripciones',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Hoy'),
                    selected: paymentPeriod == 'today',
                    onSelected: (_) {
                      setState(() => paymentPeriod = 'today');
                      unawaited(_load());
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Semana'),
                    selected: paymentPeriod == 'week',
                    onSelected: (_) {
                      setState(() => paymentPeriod = 'week');
                      unawaited(_load());
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Mes'),
                    selected: paymentPeriod == 'month',
                    onSelected: (_) {
                      setState(() => paymentPeriod = 'month');
                      unawaited(_load());
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(now.year - 3),
                        lastDate: DateTime(now.year + 1, 12, 31),
                        initialDateRange: paymentCustomRange ??
                            DateTimeRange(
                              start: DateTime(now.year, now.month, now.day),
                              end: DateTime(now.year, now.month, now.day),
                            ),
                      );
                      if (picked == null || !mounted) return;
                      setState(() {
                        paymentCustomRange = picked;
                        paymentPeriod = 'custom';
                      });
                      await _load();
                    },
                    icon: const Icon(Icons.date_range_outlined, size: 17),
                    label: const Text('Fecha'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (payments.isEmpty)
            const _AdminSubNotice(text: 'Todavía no hay pagos registrados.')
          else
            for (final payment in payments.take(30))
              Card(
                margin: const EdgeInsets.only(bottom: 7),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_rounded),
                  title: Text(
                    _money(
                      payment['amount'],
                      payment['currency_code']?.toString(),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    _date(payment['created_at']) +
                        ' · ' +
                        (payment['provider']?.toString() ?? 'veripagos'),
                  ),
                  trailing: Text(
                    payment['status']?.toString() ?? 'pending',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatefulWidget {
  final bool enabled;
  final bool enforce;
  final bool providerEnabled;
  final bool providerConfigured;
  final String qrValidity;
  final bool showQrProvider;
  final bool saving;
  final Future<void> Function({
    required bool enabled,
    required bool enforce,
    required bool providerEnabled,
    required String qrValidity,
  }) onSave;

  const _SettingsCard({
    required this.enabled,
    required this.enforce,
    required this.providerEnabled,
    required this.providerConfigured,
    required this.qrValidity,
    required this.showQrProvider,
    required this.saving,
    required this.onSave,
  });

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  late bool enabled;
  late bool enforce;
  late bool providerEnabled;
  late TextEditingController validity;

  @override
  void initState() {
    super.initState();
    enabled = widget.enabled;
    enforce = widget.enforce;
    providerEnabled = widget.providerEnabled;
    validity = TextEditingController(text: widget.qrValidity);
  }

  @override
  void didUpdateWidget(covariant _SettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) enabled = widget.enabled;
    if (oldWidget.enforce != widget.enforce) enforce = widget.enforce;
    if (oldWidget.providerEnabled != widget.providerEnabled) {
      providerEnabled = widget.providerEnabled;
    }
    if (oldWidget.qrValidity != widget.qrValidity) {
      validity.text = widget.qrValidity;
    }
  }

  @override
  void dispose() {
    validity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuración',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar suscripciones al conductor'),
              subtitle: const Text(
                'Permite ver planes y contador sin bloquear la operación.',
              ),
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exigir suscripción para trabajar'),
              subtitle: const Text(
                'Déjalo apagado durante QA. Al activarlo, solo conductores con plan vigente podrán ponerse online u ofertar.',
              ),
              value: enforce,
              onChanged: (v) => setState(() => enforce = v),
            ),
            if (widget.showQrProvider) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Habilitar QR Bolivia'),
                subtitle: Text(
                  widget.providerConfigured
                      ? 'VeriPagos tiene configuración guardada.'
                      : 'Primero completa la conexión con VeriPagos.',
                ),
                value: providerEnabled,
                onChanged: widget.providerConfigured
                    ? (v) => setState(() => providerEnabled = v)
                    : null,
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: validity,
                  decoration: const InputDecoration(
                    labelText: 'Vigencia QR',
                    helperText: 'Ej.: 0/00:15',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.saving
                  ? null
                  : () => widget.onSave(
                        enabled: enabled,
                        enforce: enforce,
                        providerEnabled: providerEnabled,
                        qrValidity: validity.text.trim(),
                      ),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar configuración'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final bool configured;
  final bool credentialsConfigured;
  final bool enabled;
  final bool saving;
  final bool verifying;
  final VoidCallback onConfigure;
  final VoidCallback onVerify;

  const _ProviderCard({
    required this.configured,
    required this.credentialsConfigured,
    required this.enabled,
    required this.saving,
    required this.verifying,
    required this.onConfigure,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final serviceActive = configured && enabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: configured
                  ? const Color(0xFFE8F8EF)
                  : const Color(0xFFFFF3E0),
              child: const Icon(Icons.qr_code_2_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'QR Bolivia · VeriPagos',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    configured
                        ? 'Credenciales guardadas y conexión verificada.'
                        : credentialsConfigured
                            ? 'Credenciales guardadas. Falta verificar la conexión.'
                            : 'Ingresa tus credenciales para conectar VeriPagos.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        avatar: Icon(
                          configured
                              ? Icons.verified_rounded
                              : Icons.error_outline_rounded,
                          size: 17,
                        ),
                        label: Text(
                          configured
                              ? 'Conexión verificada'
                              : 'Conexión sin verificar',
                        ),
                      ),
                      Chip(
                        avatar: Icon(
                          serviceActive
                              ? Icons.check_circle_rounded
                              : Icons.pause_circle_outline_rounded,
                          size: 17,
                        ),
                        label: Text(
                          serviceActive
                              ? 'Servicio activo'
                              : 'Servicio inactivo',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (credentialsConfigured)
                  OutlinedButton.icon(
                    onPressed: saving || verifying ? null : onVerify,
                    icon: verifying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering_rounded),
                    label: const Text('Verificar conexión'),
                  ),
                FilledButton.icon(
                  onPressed: saving || verifying ? null : onConfigure,
                  icon: const Icon(Icons.manage_accounts_rounded),
                  label: Text(
                    credentialsConfigured
                        ? 'Editar credenciales'
                        : 'Conectar',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminPlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final String price;
  final List<String> benefits;
  final VoidCallback onEdit;

  const _AdminPlanCard({
    required this.plan,
    required this.price,
    required this.benefits,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan['name']?.toString() ?? 'Plan',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (plan['active'] != true)
                  const Chip(label: Text('Inactivo')),
              ],
            ),
            Text(
              price + ' · ' + plan['days'].toString() + ' días',
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final benefit in benefits.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Color(0xFF12B76A),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        benefit,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 17),
              label: const Text('Editar plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSubNotice extends StatelessWidget {
  final String text;
  final bool warning;
  const _AdminSubNotice({required this.text, this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              warning ? Icons.warning_amber_rounded : Icons.info_outline,
              color: warning
                  ? const Color(0xFFD97706)
                  : const Color(0xFF2563EB),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
