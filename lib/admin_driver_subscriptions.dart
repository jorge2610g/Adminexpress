import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'core/supabase_client.dart';

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

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        supabase
            .from('driver_subscription_plans')
            .select('*')
            .order('sort_order'),
        supabase
            .from('driver_subscription_settings')
            .select('*')
            .eq('id', true)
            .single(),
        supabase.rpc(
          'admin_driver_subscriptions',
          params: {'p_search': search.text.trim()},
        ),
        supabase
            .from('driver_subscription_payments')
            .select(
              'id,driver_id,plan_id,amount,currency_code,provider,status,created_at,paid_at,expires_at',
            )
            .order('created_at', ascending: false)
            .limit(100),
      ]);

      Map<String, dynamic> providerState = const {};
      try {
        final response = await supabase.functions.invoke(
          'driver-subscription-admin',
          body: const {'action': 'get'},
        );
        if (response.data is Map) {
          providerState = Map<String, dynamic>.from(response.data as Map);
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        plans = _maps(results[0]);
        settings = results[1] is Map
            ? Map<String, dynamic>.from(results[1] as Map)
            : <String, dynamic>{};
        drivers = _maps(results[2]);
        payments = _maps(results[3]);
        provider = providerState;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
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
    int selected = Number(driver['plan_id'] ?? plans.first['id']).toInt();
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
                        value: Number(plan['id']).toInt(),
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
    final base = TextEditingController(
      text: data['api_base_url']?.toString() ?? '',
    );
    final create = TextEditingController(
      text: data['create_path']?.toString() ?? '',
    );
    final status = TextEditingController(
      text: data['status_path']?.toString() ?? '',
    );
    final user = TextEditingController(
      text: data['username']?.toString() ?? '',
    );
    final password = TextEditingController();
    final secret = TextEditingController();
    final extra = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(
        data['extra_config'] is Map
            ? data['extra_config']
            : <String, dynamic>{},
      ),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar VeriPagos'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  'Las credenciales se guardan solo en el backend privado. '
                  'No se envían a la app del conductor.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: base,
                  decoration:
                      const InputDecoration(labelText: 'API base URL'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: create,
                  decoration: const InputDecoration(
                    labelText: 'Ruta para generar QR',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: status,
                  decoration: const InputDecoration(
                    labelText: 'Ruta para verificar movimiento',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: user,
                  decoration:
                      const InputDecoration(labelText: 'Usuario Basic Auth'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: data['has_password'] == true
                        ? 'Contraseña · dejar vacía para conservar'
                        : 'Contraseña Basic Auth',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: secret,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: data['has_secret_key'] == true
                        ? 'Secret Key · dejar vacía para conservar'
                        : 'Secret Key',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: extra,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Mapeo avanzado JSON',
                    helperText:
                        'Permite adaptar los nombres de campos de VeriPagos sin cambiar la app.',
                  ),
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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar configuración'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    Map<String, dynamic> extraJson = const {};
    try {
      final decoded = jsonDecode(extra.text.trim().isEmpty ? '{}' : extra.text);
      if (decoded is Map) extraJson = Map<String, dynamic>.from(decoded);
    } catch (_) {
      _snack('El JSON avanzado no es válido.');
      return;
    }

    setState(() => providerSaving = true);
    try {
      final response = await supabase.functions.invoke(
        'driver-subscription-admin',
        body: {
          'action': 'save',
          'api_base_url': base.text.trim(),
          'create_path': create.text.trim(),
          'status_path': status.text.trim(),
          'username': user.text.trim(),
          'password': password.text,
          'secret_key': secret.text,
          'extra_config': extraJson,
        },
      );
      final responseData = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      if (responseData['ok'] != true) {
        throw StateError(responseData['error']?.toString() ?? 'Error');
      }
      _snack('Configuración VeriPagos guardada.');
      await _load();
    } catch (e) {
      _snack('No se pudo guardar VeriPagos: ' + e.toString());
    } finally {
      base.dispose();
      create.dispose();
      status.dispose();
      user.dispose();
      password.dispose();
      secret.dispose();
      extra.dispose();
      if (mounted) setState(() => providerSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final providerConfigured = provider['configured'] == true;
    final enabled = settings['enabled'] == true;
    final enforce = settings['enforce_access'] == true;
    final providerEnabled = settings['provider_enabled'] == true;
    final qrValidity = settings['qr_validity']?.toString() ?? '0/00:15';

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
            enabled: providerEnabled,
            saving: providerSaving,
            onConfigure: _configureProvider,
          ),
          const SizedBox(height: 20),
          const Text(
            'Planes',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
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
              const Expanded(
                child: Text(
                  'Conductores',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
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
          const SizedBox(height: 10),
          if (drivers.isEmpty)
            const _AdminSubNotice(text: 'No hay conductores para mostrar.')
          else
            for (final driver in drivers)
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
  final bool enabled;
  final bool saving;
  final VoidCallback onConfigure;

  const _ProviderCard({
    required this.configured,
    required this.enabled,
    required this.saving,
    required this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: CircleAvatar(
          backgroundColor: configured
              ? const Color(0xFFE8F8EF)
              : const Color(0xFFFFF3E0),
          child: const Icon(Icons.qr_code_2_rounded),
        ),
        title: const Text(
          'QR Bolivia · VeriPagos',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          configured
              ? (enabled
                  ? 'Configurado y habilitado para pagos.'
                  : 'Configurado. Falta habilitar cobros.')
              : 'Faltan endpoint y/o credenciales de VeriPagos.',
        ),
        trailing: FilledButton.icon(
          onPressed: saving ? null : onConfigure,
          icon: const Icon(Icons.settings_rounded),
          label: const Text('Configurar'),
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
