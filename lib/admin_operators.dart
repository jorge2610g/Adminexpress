import 'dart:async';

import 'package:flutter/material.dart';

import 'core/admin_dropdown_field.dart';
import 'core/admin_friendly_error.dart';
import 'core/admin_hero.dart';
import 'core/supabase_client.dart';

/// Módulo que el administrador puede dar a un operador de zona.
/// [ready]: las funciones del servidor ya lo permiten a un operador.
/// Los módulos no habilitados se muestran, pero no pueden asignarse.
class OperatorModule {
  const OperatorModule(this.key, this.label, this.group, {this.ready = false});

  final String key;
  final String label;
  final String group;
  final bool ready;
}

/// Usuarios siempre va incluido: es lo mínimo que ve cualquier operador.
const String operatorBaseModule = 'users';

/// Orden y agrupación del menú. Auditoría, Builds, configuración general, pruebas y
/// Operadores no se pueden dar: quedan solo para el administrador central.
const List<OperatorModule> operatorSelectorModules = [
  OperatorModule('dashboard', 'Dashboard', 'General', ready: true),
  OperatorModule('live_operations', 'Operación en vivo', 'Operaciones', ready: true),
  OperatorModule('trips', 'Viajes', 'Operaciones', ready: true),
  OperatorModule('manual_dispatch', 'Despacho manual', 'Operaciones'),
  OperatorModule('drivers', 'Conductores', 'Operaciones', ready: true),
  OperatorModule('users', 'Usuarios', 'Operaciones', ready: true),
  OperatorModule('safety_sos', 'Seguridad / SOS', 'Operaciones', ready: true),
  OperatorModule('delivery', 'Delivery', 'Módulos', ready: true),
  OperatorModule('delivery_orders', 'Pedidos Delivery', 'Módulos'),
  OperatorModule('delivery_phase2', 'Delivery Fase 2 / Express Plus', 'Módulos'),
  OperatorModule('marketplace', 'Restaurantes', 'Módulos'),
  OperatorModule('driver_priority', 'Prioridad conductores', 'Módulos'),
  OperatorModule('payments', 'Pagos / Billetera', 'Finanzas'),
  OperatorModule('fares', 'Tarifas', 'Finanzas'),
  OperatorModule('subscriptions', 'Suscripciones', 'Finanzas'),
  OperatorModule('dynamic_pricing', 'Demanda y precios', 'Finanzas'),
  OperatorModule('reports', 'Reportes', 'Análisis'),
  OperatorModule('notifications', 'Notificaciones / Avisos', 'Comunicación'),
  OperatorModule('zones', 'Zonas y cobertura', 'Configuración'),
  OperatorModule('services', 'Servicios', 'Configuración'),
  OperatorModule('geo_safety', 'Cobertura y seguridad', 'Configuración'),
];


Set<String> operatorNormalizedModules(Iterable<String> source) {
  final ready = operatorSelectorModules.where((module) => module.ready).map((module) => module.key).toSet();
  final result = <String>{operatorBaseModule, ...source.where(ready.contains)};
  if (result.contains('live_operations') || result.contains('safety_sos')) {
    result.addAll(const ['dashboard', 'drivers']);
  }
  return result;
}

Set<String> operatorToggledModules(Iterable<String> current, String key, bool enabled) {
  final result = operatorNormalizedModules(current);
  if (enabled) {
    result.add(key);
    return operatorNormalizedModules(result);
  }
  result.remove(key);
  if (key == 'dashboard' || key == 'drivers') {
    result.remove('live_operations');
    result.remove('safety_sos');
  }
  return operatorNormalizedModules(result);
}

const List<String> _groupOrder = [
  'General',
  'Operaciones',
  'Módulos',
  'Finanzas',
  'Análisis',
  'Comunicación',
  'Configuración',
];

const Color _dark = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

String _roleLabel(String role) => switch (role) {
      'operator' => 'Operador de zona',
      'super_admin' => 'Administrador central',
      'zone_monitor' => 'Monitor de zona',
      _ => role,
    };

String _userLabel(Map<String, dynamic> row) {
  final name = (row['full_name'] ?? '').toString().trim();
  final email = (row['email'] ?? '').toString().trim();
  if (name.isNotEmpty && email.isNotEmpty) return '$name · $email';
  if (name.isNotEmpty) return name;
  if (email.isNotEmpty) return email;
  return 'Cuenta sin nombre';
}

String _zoneLabel(Map<String, dynamic> row) {
  final zone = (row['zone_name'] ?? row['name'] ?? '').toString();
  final country = (row['country'] ?? '').toString();
  return [zone, country].where((value) => value.isNotEmpty).join(' · ');
}

class AdminOperatorsPage extends StatefulWidget {
  const AdminOperatorsPage({super.key});

  @override
  State<AdminOperatorsPage> createState() => _AdminOperatorsPageState();
}

class _AdminOperatorsPageState extends State<AdminOperatorsPage> {
  bool loading = true;
  bool busy = false;
  String? notice;
  List<Map<String, dynamic>> accesses = const [];

  final search = TextEditingController();
  final newEmail = TextEditingController();
  final newPassword = TextEditingController();
  final newName = TextEditingController();
  List<Map<String, dynamic>> results = const [];
  Map<String, dynamic>? selectedUser;
  List<Map<String, dynamic>> countries = const [];
  String? countryCode;
  List<Map<String, dynamic>> zones = const [];
  String? zoneId;
  final Set<String> modules = {operatorBaseModule};

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
  }

  @override
  void dispose() {
    search.dispose();
    newEmail.dispose();
    newPassword.dispose();
    newName.dispose();
    super.dispose();
  }

  String _friendly(Object error) {
    final text = error.toString();
    if (text.contains('admin_panel_access_list') ||
        text.contains('Rol administrativo inválido')) {
      return 'Falta activar la función de operadores en la base. '
          'Avisa al administrador técnico.';
    }
    return friendlyError(error);
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      notice = null;
    });
    try {
      final country = await supabase.rpc('admin_country_list_scoped');
      if (!mounted) return;
      setState(() => countries = _rows(country));
    } catch (e) {
      if (!mounted) return;
      setState(() => notice = _friendly(e));
    }
    try {
      final access = await supabase.rpc('admin_panel_access_list');
      if (!mounted) return;
      setState(() => accesses = _rows(access));
    } catch (e) {
      if (!mounted) return;
      setState(() => notice = _friendly(e));
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _loadZones(String country) async {
    try {
      final value = await supabase.rpc(
        'admin_zone_list_for_country',
        params: {'p_country_code': country},
      );
      if (!mounted) return;
      setState(() {
        zones = _rows(value);
        zoneId = null;
        selectedUser = null;
        results = const [];
        search.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => notice = _friendly(e));
    }
  }

  /// Busca usuarios dentro de la zona elegida: el operador solo puede regir esa zona.
  Future<void> _searchUsers(String query) async {
    final text = query.trim();
    if (zoneId == null) {
      setState(() => notice = 'Elige primero la zona del operador.');
      return;
    }
    if (text.length < 3) {
      setState(() => results = const []);
      return;
    }
    try {
      final value = await supabase.rpc(
        'admin_user_list_v4',
        params: {
          'p_channel': 'production',
          'p_zone_id': zoneId,
          'p_search': text,
          'p_limit': 25,
          'p_offset': 0,
        },
      );
      if (!mounted) return;
      setState(() => results = _rows(value));
    } catch (e) {
      if (!mounted) return;
      setState(() => notice = _friendly(e));
    }
  }

  Future<bool> _confirm({required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _save({
    required String userId,
    required String zone,
    required bool active,
    required Iterable<String> allowed,
  }) async {
    setState(() => busy = true);
    try {
      await supabase.rpc(
        'admin_set_panel_access_v2',
        params: {
          'p_user_id': userId,
          'p_access_role': 'operator',
          'p_zone_id': zone,
          'p_active': active,
          'p_environment': 'production',
          'p_allowed_modules': operatorNormalizedModules(allowed).toList(),
        },
      );
      if (!mounted) return;
      setState(() {
        busy = false;
        notice = active ? 'Acceso guardado.' : 'Acceso desactivado.';
        selectedUser = null;
        results = const [];
        search.clear();
      });
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        notice = _friendly(e);
      });
    }
  }

  Future<void> _assign() async {
    final user = selectedUser;
    final zone = zoneId;
    if (user == null || zone == null) return;
    // No convertir cuentas de superadmin o monitor al asignar un operador.
    if (accesses.any((entry) =>
        entry['user_id']?.toString() == user['user_id']?.toString() &&
        entry['access_role']?.toString() != 'operator')) {
      setState(() => notice =
          'Esta cuenta ya tiene otro rol administrativo. No se puede convertir en operador.');
      return;
    }
    final zoneRow = zones.firstWhere(
      (row) => row['id']?.toString() == zone,
      orElse: () => <String, dynamic>{},
    );
    final ok = await _confirm(
      title: 'Dar acceso de operador',
      message: 'Vas a dar acceso a ${_userLabel(user)} a ${_zoneLabel(zoneRow)}. '
          'Solo verá esa zona y los módulos marcados. ¿Continuar?',
    );
    if (!ok || !mounted) return;
    await _save(
      userId: user['user_id'].toString(),
      zone: zone,
      active: true,
      allowed: modules,
    );
  }

  // Abre la ventana «Editar operador»: estado de acceso y módulos que verá.
  Future<void> _openEditor(Map<String, dynamic> row) async {
    final result = await showDialog<OperatorEditResult>(
      context: context,
      builder: (_) => OperatorEditDialog(
        userLabel: _userLabel(row),
        zoneLabel: _zoneLabel(row),
        initialActive: row['active'] == true,
        initialModules: _modulesOf(row),
      ),
    );
    if (result == null || !mounted) return;
    if (row['active'] == true && !result.active) {
      final ok = await _confirm(
        title: 'Desactivar operador',
        message: '${_userLabel(row)} dejará de entrar al panel.',
      );
      if (!ok || !mounted) return;
    }
    await _save(
      userId: row['user_id'].toString(),
      zone: (row['zone_id'] ?? '').toString(),
      active: result.active,
      allowed: result.modules,
    );
  }

  Set<String> _modulesOf(Map<String, dynamic> row) {
    if (row['allowed_modules'] is List) {
      return operatorNormalizedModules((row['allowed_modules'] as List).map((e) => e.toString()));
    }
    return operatorNormalizedModules(operatorSelectorModules.where((m) => m.ready).map((m) => m.key));
  }

  // Crea la cuenta con correo y contraseña en el servidor y le da acceso de operador.
  Future<void> _createOperator() async {
    final email = newEmail.text.trim().toLowerCase();
    final password = newPassword.text;
    final zone = zoneId;
    if (zone == null) {
      setState(() => notice = 'Elige primero el país y la zona del operador.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => notice = 'Escribe un correo válido para el operador.');
      return;
    }
    if (password.length < 8) {
      setState(() => notice = 'La contraseña inicial debe tener al menos 8 caracteres.');
      return;
    }
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final response = await supabase.functions.invoke(
        'admin-create-operator',
        body: {
          'email': email,
          'password': password,
          'full_name': newName.text.trim(),
          'zone_id': zone,
          'allowed_modules': operatorNormalizedModules(modules).toList(),
        },
      );
      if (!mounted) return;
      final data = response.data;
      if (data is Map && data['ok'] == true) {
        newEmail.clear();
        newPassword.clear();
        newName.clear();
        setState(() {
          busy = false;
          notice = 'Operador creado. Ya puede entrar con su correo y su contraseña.';
        });
        await _loadAll();
        return;
      }
      setState(() {
        busy = false;
        notice = data is Map && data['error'] != null
            ? data['error'].toString()
            : 'No se pudo crear el operador.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        notice = _friendlyCreate(e);
      });
    }
  }

  String _friendlyCreate(Object error) {
    final text = error.toString();
    if (text.contains('404') || text.contains('NOT_FOUND') || text.contains('not found')) {
      return 'La función para crear operadores todavía no está publicada en Supabase.';
    }
    return friendlyError(error);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      children: [
        const AdminHero(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Operadores por zona',
          subtitle:
              'Cada operador ve solo la zona que se le asigna y los módulos que elijas.',
        ),
        const SizedBox(height: 14),
        if (notice != null) _noticeCard(notice!),
        _card(
          title: 'Accesos asignados',
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              : accesses.isEmpty
                  ? const Text(
                      'Todavía no hay accesos asignados.',
                      style: TextStyle(color: _muted),
                    )
                  : Column(
                      children: [
                        for (final row in accesses) _accessRow(row),
                      ],
                    ),
        ),
        const SizedBox(height: 14),
        _card(title: 'Dar acceso a un operador', child: _assignForm()),
      ],
    );
  }

  Widget _accessRow(Map<String, dynamic> row) {
    final role = (row['access_role'] ?? '').toString();
    final active = row['active'] == true;
    final zone = _zoneLabel(row);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userLabel(row),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  zone.isEmpty ? _roleLabel(role) : '${_roleLabel(role)} · $zone',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          Text(
            active ? 'Activo' : 'Inactivo',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: active ? const Color(0xFF15803D) : _muted,
            ),
          ),
          if (role == 'operator') ...[
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: busy ? null : () => _openEditor(row),
              child: const Text('Editar'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _assignForm() {
    final user = selectedUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminDropdownField<String?>(
          value: countryCode,
          decoration: const InputDecoration(labelText: 'País'),
          hint: const Text('Selecciona un país'),
          items: [
            for (final row in countries)
              DropdownMenuItem<String?>(
                value: (row['country_code'] ?? '').toString().trim().toUpperCase(),
                child: Text((row['country'] ?? row['country_code'] ?? '').toString()),
              ),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => countryCode = value);
                  _loadZones(value);
                },
        ),
        const SizedBox(height: 10),
        AdminDropdownField<String?>(
          value: zoneId,
          decoration: const InputDecoration(labelText: 'Zona asignada'),
          hint: const Text('Selecciona una zona'),
          items: [
            for (final row in zones)
              DropdownMenuItem<String?>(
                value: row['id']?.toString(),
                child: Text(_zoneLabel(row)),
              ),
          ],
          onChanged: busy
              ? null
              : (value) => setState(() {
                    zoneId = value;
                    selectedUser = null;
                    results = const [];
                    search.clear();
                  }),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: search,
          enabled: zoneId != null && !busy,
          onChanged: _searchUsers,
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search_rounded, size: 18),
            labelText: 'Buscar usuario de la zona (mínimo 3 letras)',
            border: OutlineInputBorder(),
          ),
        ),
        if (user == null && results.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final row in results)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_userLabel(row)),
              subtitle: Text((row['account_status'] ?? '').toString()),
              onTap: () => setState(() {
                selectedUser = row;
                results = const [];
              }),
            ),
        ],
        if (user != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Usuario: ${_userLabel(user)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: _dark),
                ),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                          selectedUser = null;
                        }),
                child: const Text('Cambiar'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 12),
        const Text(
          'O crea una cuenta nueva con correo y contraseña',
          style: TextStyle(fontWeight: FontWeight.w900, color: _dark),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: newName,
          enabled: !busy,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Nombre completo (opcional)',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: newEmail,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Correo del operador',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: newPassword,
          enabled: !busy,
          obscureText: true,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Contraseña inicial (mínimo 8 caracteres)',
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Módulos que verá el operador',
          style: TextStyle(fontWeight: FontWeight.w900, color: _dark),
        ),
        const Text(
          'Solo aparecen en su menú los módulos marcados. Lo que no marques queda oculto.',
          style: TextStyle(fontSize: 12, color: _muted),
        ),
        _moduleSelector(),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy || user == null || zoneId == null ? null : _assign,
          icon: const Icon(Icons.verified_user_rounded),
          label: const Text('Guardar acceso de operador'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy || zoneId == null ? null : _createOperator,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Crear operador con este correo'),
        ),
      ],
    );
  }

  Widget _moduleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in _groupOrder) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Text(
              group.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: _muted,
                letterSpacing: .5,
              ),
            ),
          ),
          for (final module in operatorSelectorModules.where((m) => m.group == group))
            _moduleTile(module),
        ],
      ],
    );
  }

  Widget _moduleTile(OperatorModule module) {
    final locked = module.key == operatorBaseModule;
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: modules.contains(module.key),
      title: Text(module.label),
      subtitle: locked
          ? const Text(
              'Siempre incluido',
              style: TextStyle(fontSize: 11, color: _muted),
            )
          : module.key == 'live_operations'
              ? const Text('Incluye Dashboard y Conductores',
                  style: TextStyle(fontSize: 11, color: _muted))
              : module.key == 'safety_sos'
                  ? const Text('Solo lectura; incluye Dashboard y Conductores',
                      style: TextStyle(fontSize: 11, color: _muted))
                  : module.key == 'delivery'
                  ? const Text('Consulta de entregas por zona',
                      style: TextStyle(fontSize: 11, color: _muted))
                  : module.ready
                      ? null
                      : const Text(
                          'Pendiente de habilitar',
                          style: TextStyle(fontSize: 11, color: Color(0xFFB54708)),
                        ),
      onChanged: busy || locked || !module.ready
          ? null
          : (value) => setState(() {
                final next = operatorToggledModules(modules, module.key, value == true);
                modules..clear()..addAll(next);
              }),
    );
  }

  Widget _noticeCard(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEDF89)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7A2E0E),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // Material (no Container) para que las filas de selección puedan pintar su fondo.
  Widget _card({required String title, required Widget child}) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDDE6F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _dark,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Resultado de la ventana «Editar operador».
class OperatorEditResult {
  const OperatorEditResult({required this.active, required this.modules});

  final bool active;
  final Set<String> modules;
}

/// Ventana «Editar operador»: activar o desactivar el acceso y elegir los módulos.
/// La zona no cambia desde aquí. Usuarios siempre va incluido.
class OperatorEditDialog extends StatefulWidget {
  const OperatorEditDialog({
    super.key,
    required this.userLabel,
    required this.zoneLabel,
    required this.initialActive,
    required this.initialModules,
  });

  final String userLabel;
  final String zoneLabel;
  final bool initialActive;
  final Set<String> initialModules;

  @override
  State<OperatorEditDialog> createState() => _OperatorEditDialogState();
}

class _OperatorEditDialogState extends State<OperatorEditDialog> {
  late bool active = widget.initialActive;
  late final Set<String> modules = operatorNormalizedModules(widget.initialModules);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar operador'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userLabel,
                style: const TextStyle(fontWeight: FontWeight.w800, color: _dark),
              ),
              const SizedBox(height: 2),
              Text(
                widget.zoneLabel,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Acceso activo'),
                subtitle: const Text(
                  'Si lo desactivas, no podrá entrar al panel.',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
                value: active,
                onChanged: (value) => setState(() => active = value),
              ),
              const Divider(height: 20),
              const Text(
                'Módulos que verá el operador',
                style: TextStyle(fontWeight: FontWeight.w900, color: _dark),
              ),
              const Text(
                'Lo que no marques queda oculto. Usuarios siempre va incluido.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
              for (final group in _groupOrder) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: Text(
                    group.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: _muted,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                for (final module in operatorSelectorModules.where((m) => m.group == group))
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: modules.contains(module.key),
                    title: Text(module.label),
                    subtitle: module.key == operatorBaseModule
                        ? const Text(
                            'Siempre incluido',
                            style: TextStyle(fontSize: 11, color: _muted),
                          )
                        : null,
                    onChanged: module.key == operatorBaseModule || !module.ready
                        ? null
                        : (value) => setState(() {
                              final next = operatorToggledModules(modules, module.key, value == true);
                              modules..clear()..addAll(next);
                            }),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            OperatorEditResult(active: active, modules: modules),
          ),
          child: const Text('Guardar cambios'),
        ),
      ],
    );
  }
}
