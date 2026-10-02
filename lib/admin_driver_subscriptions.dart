import 'dart:async';

import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

int _adminSubscriptionInt(Object? raw) {
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

class AdminDriverSubscriptionsPage extends StatefulWidget {
  const AdminDriverSubscriptionsPage({super.key});

  @override
  State<AdminDriverSubscriptionsPage> createState() =>
      _AdminDriverSubscriptionsPageState();
}

class _AdminDriverSubscriptionsPageState
    extends State<AdminDriverSubscriptionsPage> {
  bool loading = true;
  bool savingSettings = false;
  bool providerSaving = false;
  bool providerVerifying = false;
  String? error;
  List<Map<String, dynamic>> plans = const [];
  List<Map<String, dynamic>> drivers = const [];
  List<Map<String, dynamic>> payments = const [];
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

    try {
      final planRows = await supabase
          .from('driver_subscription_plans')
          .select('*')
          .order('sort_order');
      if (mounted) {
        setState(() => plans = _maps(planRows));
      }
    } catch (e) {
      loadError = 'Planes: ' + e.toString();
    }

    try {
      final settingsRow = await supabase
          .from('driver_subscription_settings')
          .select('*')
          .eq('id', true)
          .single();
      if (mounted) {
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
        params: {'p_search': search.text.trim()},
      );
      if (mounted) {
        setState(() => drivers = _maps(driverRows));
      }
    } catch (e) {
      loadError ??= 'Conductores: ' + e.toString();
    }

    try {
      final paymentRows = await supabase
          .from('driver_subscription_payments')
          .select(
            'id,driver_id,plan_id,amount,currency_code,provider,status,created_at,paid_at,expires_at',
          )
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() => payments = _maps(paymentRows));
      }
    } catch (e) {
      loadError ??= 'Pagos: ' + e.toString();
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

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String _money(Object? raw) {
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;
    return 'Bs ' +
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

  Future<void> _editPlan(Map<String, dynamic> plan) async {
    final name = TextEditingController(text: plan['name']?.toString() ?? '');
    final amount = TextEditingController(text: plan['amount']?.toString() ?? '');
    final days = TextEditingController(text: plan['days']?.toString() ?? '');
    final benefits = TextEditingController(text: _benefits(plan).join('\n'));
    var active = plan['active'] == true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Editar plan'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Precio (Bs)',
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

    if (name.text.trim().isEmpty ||
        parsedAmount == null ||
        parsedAmount < 0 ||
        parsedDays == null ||
        parsedDays < 1) {
      _snack('Revisa nombre, precio y duración.');
      return;
    }

    try {
      await supabase
          .from('driver_subscription_plans')
          .update({
            'name': name.text.trim(),
            'amount': parsedAmount,
            'days': parsedDays,
            'benefits': benefitList,
            'active': active,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', plan['id']);
      _snack('Plan actualizado.');
      await _load();
    } catch (e) {
      _snack('No se pudo guardar: ' + e.toString());
    } finally {
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
    if (enforce && settings['enforce_access'] != true) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exigir suscripción'),
          content: const Text(
            'Al activar esta regla, los conductores sin una suscripción vigente '
            'serán puestos offline y no podrán ofertar hasta tener un plan activo.',
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

    if (providerEnabled && provider['configured'] != true) {
      _snack('Configura y verifica primero VeriPagos.');
      return;
    }
    if (providerEnabled && provider['status_endpoint_ready'] != true) {
      _snack(
        'Falta conectar el endpoint de verificación de estado QR antes de habilitar cobros.',
      );
      return;
    }

    setState(() => savingSettings = true);
    try {
      await supabase.rpc(
        'admin_set_driver_subscription_settings',
        params: {
          'p_enabled': enabled,
          'p_enforce_access': enforce,
          'p_provider_enabled': providerEnabled,
          'p_qr_validity': qrValidity,
        },
      );
      _snack('Configuración guardada.');
      await _load();
    } catch (e) {
      _snack('No se pudo guardar: ' + e.toString());
    } finally {
      if (mounted) setState(() => savingSettings = false);
    }
  }

  Future<void> _assignPlan(Map<String, dynamic> driver) async {
    if (plans.isEmpty) return;
    int selected = _adminSubscriptionInt(driver['plan_id'] ?? plans.first['id']);
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
                      'Planes, vigencias, pagos y QR Bolivia.',
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
          const SizedBox(height: 16),
          _SettingsCard(
            enabled: enabled,
            enforce: enforce,
            providerEnabled: providerEnabled,
            providerConfigured: providerConfigured,
            qrValidity: qrValidity,
            saving: savingSettings,
            onSave: _saveSettings,
          ),
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
          const SizedBox(height: 20),
          const Text(
            'Planes',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
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
                      price: _money(plan['amount']),
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
          const Text(
            'Pagos recientes',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
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
                    _money(payment['amount']),
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
