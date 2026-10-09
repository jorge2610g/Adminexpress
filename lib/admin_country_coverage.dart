import 'package:flutter/material.dart';

import 'admin_environment_store.dart';
import 'core/supabase_client.dart';

const Color _countryBlue = Color(0xFF2563EB);
const Color _countryMuted = Color(0xFF64748B);

class AdminCountryCoveragePage extends StatefulWidget {
  final String channel;

  const AdminCountryCoveragePage({
    super.key,
    required this.channel,
  });

  @override
  State<AdminCountryCoveragePage> createState() =>
      _AdminCountryCoveragePageState();
}

class _AdminCountryCoveragePageState
    extends State<AdminCountryCoveragePage> {
  int revision = 0;

  AdminEnvironmentStore get _environment =>
      AdminEnvironmentStore(widget.channel);

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
      : <Map<String, dynamic>>[];

  Future<List<Map<String, dynamic>>> _load() async {
    if (_environment.isPreview) {
      final rows = await _environment.previewList('service_countries');
      rows.sort(
        (a, b) => (a['name'] ?? a['country_code'] ?? '')
            .toString()
            .compareTo((b['name'] ?? b['country_code'] ?? '').toString()),
      );
      return rows;
    }
    return _list(await supabase.rpc('admin_country_list'));
  }

  /// Seed only the QA shadow store with non-sensitive country references.
  /// Existing Preview records are preserved; this never edits service_countries.
  Future<void> _seedPreviewCountryReferences() async {
    if (!_environment.isPreview) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Preparar países de prueba'),
        content: const Text(
          'Se copiarán únicamente nombre, código de país, moneda y prefijo '
          'a la configuración QA de Preview. Todos los países y registros de '
          'conductores quedarán desactivados por defecto. No se modificarán '
          'los países reales de Producción.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Preparar QA'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_environment.isPreview) return;

    try {
      final existing = await _environment.previewList('service_countries');
      final existingCodes = existing
          .map((row) => row['country_code']?.toString().toUpperCase())
          .whereType<String>()
          .toSet();
      final source = _list(await supabase.rpc('admin_country_list'));
      var created = 0;
      for (final country in source) {
        if (!mounted || !_environment.isPreview) return;
        final code = country['country_code']?.toString().trim().toUpperCase();
        final currency = country['currency_code']?.toString().trim().toUpperCase();
        if (code == null || code.length != 2 || existingCodes.contains(code)) {
          continue;
        }
        if (currency == null || currency.length != 3) continue;
        await _environment.previewUpsert(
          'service_countries',
          code,
          <String, dynamic>{
            'country_code': code,
            'name': country['name']?.toString() ?? code,
            'currency_code': currency,
            'calling_code': country['calling_code']?.toString() ?? '',
            'active': false,
            'driver_registration_enabled': false,
            'didit_enabled': false,
            'manual_fallback_enabled': true,
          },
        );
        existingCodes.add(code);
        created++;
      }
      if (mounted) {
        setState(() => revision++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QA preparado: $created países de prueba. '
              'Producción permanece sin cambios.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error))),
        );
      }
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('Código ISO de país inválido')) {
      return 'Usa el código ISO de 2 letras, por ejemplo CL, BO, BR o AR.';
    }
    if (raw.contains('Código de moneda inválido')) {
      return 'Usa un código de moneda de 3 letras, por ejemplo CLP, BOB, BRL o ARS.';
    }
    if (raw.contains('Prefijo telefónico internacional inválido')) {
      return 'Usa el prefijo internacional con +, por ejemplo +56, +591, +55 o +54.';
    }
    return raw.replaceFirst('PostgrestException(message: ', '');
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final code = TextEditingController(
      text: row?['country_code']?.toString() ?? '',
    );
    final name = TextEditingController(
      text: row?['name']?.toString() ?? '',
    );
    final currency = TextEditingController(
      text: row?['currency_code']?.toString() ?? '',
    );
    final callingCode = TextEditingController(
      text: row?['calling_code']?.toString() ?? '',
    );
    final productionWorkflow = TextEditingController();
    final sandboxWorkflow = TextEditingController();

    var active = row?['active'] == true;
    var driverRegistration =
        row?['driver_registration_enabled'] != false;
    var diditEnabled = row?['didit_enabled'] == true;
    var manualFallback =
        row?['manual_fallback_enabled'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Nuevo país' : 'Editar país'),
          content: SizedBox(
            width: 590,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Un país activo no habilita todo su territorio: Express solo funciona dentro de ciudades / zonas activas creadas en el panel. Así puedes preparar Brasil o Argentina sin abrir servicio hasta que actives una ciudad.',
                      style: TextStyle(fontSize: 11, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: code,
                    enabled: row == null,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 2,
                    decoration: const InputDecoration(
                      labelText: 'Código ISO del país',
                      hintText: 'CL / BO / BR / AR',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del país',
                      hintText: 'Brasil',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: currency,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 3,
                    decoration: const InputDecoration(
                      labelText: 'Moneda',
                      hintText: 'BRL',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: callingCode,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Prefijo telefónico internacional',
                      hintText: '+55',
                      helperText:
                          'Se usa para el contacto y registro. No se envían códigos SMS.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setLocal(() => active = value),
                    title: const Text('País habilitado'),
                    subtitle: const Text(
                      'Si está apagado, ninguna ciudad de este país queda disponible para la app.',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: driverRegistration,
                    onChanged: active
                        ? (value) =>
                            setLocal(() => driverRegistration = value)
                        : null,
                    title: const Text('Registro de conductores'),
                    subtitle: const Text(
                      'Permite registro solo dentro de ciudades activas del país.',
                    ),
                  ),
                  const Divider(height: 28),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.verified_user_rounded,
                        color: Color(0xFF14804A)),
                    title: Text('Identidad: verificación manual'),
                    subtitle: Text(
                      'Carné frontal, reverso y selfie. La revisión '
                      'se gestiona en Verificación de identidad. '
                      'Didit y la verificación SMS están retirados.',
                    ),
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
      currency.dispose();
      callingCode.dispose();
      productionWorkflow.dispose();
      sandboxWorkflow.dispose();
      return;
    }

    try {
      final countryCode = code.text.trim().toUpperCase();
      if (_environment.isPreview) {
        await _environment.previewUpsert(
          'service_countries',
          countryCode,
          <String, dynamic>{
            ...?row,
            'country_code': countryCode,
            'name': name.text.trim(),
            'currency_code': currency.text.trim().toUpperCase(),
            'calling_code': callingCode.text.trim(),
            'active': active,
            'driver_registration_enabled': driverRegistration,
            'didit_enabled': diditEnabled,
            'manual_fallback_enabled': manualFallback,
          },
        );
      } else {
        await supabase.rpc(
          'admin_upsert_country_coverage_v2',
          params: {
            'p_country_code': countryCode,
            'p_name': name.text.trim(),
            'p_currency_code': currency.text.trim().toUpperCase(),
            'p_calling_code': callingCode.text.trim(),
            'p_active': active,
            'p_driver_registration_enabled': driverRegistration,
            'p_didit_enabled': false,
            'p_manual_fallback_enabled': true,
            'p_production_workflow_id':
                productionWorkflow.text.trim().isEmpty
                    ? null
                    : productionWorkflow.text.trim(),
            'p_sandbox_workflow_id': sandboxWorkflow.text.trim().isEmpty
                ? null
                : sandboxWorkflow.text.trim(),
          },
        );
      }
      if (mounted) {
        setState(() => revision++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active
                  ? 'País guardado. Ahora puedes crear y activar sus ciudades.'
                  : 'País guardado como inactivo. La app bloqueará sus zonas.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error))),
        );
      }
    } finally {
      code.dispose();
      name.dispose();
      currency.dispose();
      callingCode.dispose();
      productionWorkflow.dispose();
      sandboxWorkflow.dispose();
    }
  }

  Widget _status(String text, bool positive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: positive
            ? const Color(0xFFE8F8EF)
            : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: positive
              ? const Color(0xFF14804A)
              : const Color(0xFF667085),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(
          _environment.isPreview
              ? 'Países y cobertura · Preview'
              : 'Países y cobertura · Producción',
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(revision),
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _friendlyError(snapshot.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Países de operación',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Activa países y registro de conductores. Identidad es manual; la cobertura depende de las ciudades activas.',
                          style: TextStyle(
                            color: _countryMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_environment.isPreview)
                    OutlinedButton.icon(
                      onPressed: _seedPreviewCountryReferences,
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Preparar países QA'),
                    ),
                  FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuevo país'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (rows.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay países configurados. Crea el primero antes de crear zonas.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...rows.map((row) {
                  final active = row['active'] == true;
                  final registration =
                      row['driver_registration_enabled'] != false;
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 9),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: active
                            ? const Color(0xFFEAF2FF)
                            : const Color(0xFFF2F4F7),
                        child: Icon(
                          active
                              ? Icons.public_rounded
                              : Icons.public_off_rounded,
                          color: active ? _countryBlue : _countryMuted,
                        ),
                      ),
                      title: Text(
                        (row['name'] ?? row['country_code'] ?? 'País')
                            .toString(),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        (row['country_code'] ?? '—').toString() +
                            ' · ' +
                            (row['currency_code'] ?? '—').toString() +
                            ' · ' +
                            (row['calling_code'] ?? 'sin prefijo').toString() +
                            ' · ' +
                            (row['zones_active'] ?? 0).toString() +
                            '/' +
                            (row['zones_total'] ?? 0).toString() +
                            ' zonas activas',
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _status(active ? 'País ON' : 'País OFF', active),
                          _status(
                            registration ? 'Registro ON' : 'Registro OFF',
                            active && registration,
                          ),
                          _status('Verificación manual', true),
                          IconButton(
                            tooltip: 'Editar país',
                            onPressed: () => _edit(row),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
