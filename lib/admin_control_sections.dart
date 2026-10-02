import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/supabase_client.dart';

const Color _blue = Color(0xFF2563EB);
const Color _dark = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);

class AdminDispatchPage extends StatefulWidget {
  const AdminDispatchPage({super.key});

  @override
  State<AdminDispatchPage> createState() => _AdminDispatchPageState();
}

class _AdminDispatchPageState extends State<AdminDispatchPage> {
  int revision = 0;

  Future<({
    List<Map<String, dynamic>> rides,
    List<Map<String, dynamic>> deliveries,
    List<Map<String, dynamic>> drivers,
  })> _load() async {
    final values = await Future.wait([
      supabase.rpc('admin_open_service_requests'),
      supabase.rpc('admin_available_drivers'),
    ]);
    final requests = _map(values[0]);
    return (
      rides: _list(requests['rides']),
      deliveries: _list(requests['deliveries']),
      drivers: _list(values[1]),
    );
  }

  Future<void> _assignRide(
    Map<String, dynamic> ride,
    List<Map<String, dynamic>> drivers,
  ) async {
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay conductores disponibles.')),
      );
      return;
    }

    String? driverId = drivers.first['id']?.toString();
    final fare = TextEditingController(
      text: ride['proposed_fare']?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Asignar viaje'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (ride['pickup_address'] ?? 'Origen').toString() +
                      ' → ' +
                      (ride['destination_address'] ?? 'Destino').toString(),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: driverId,
                  decoration:
                      const InputDecoration(labelText: 'Conductor disponible'),
                  items: drivers
                      .map(
                        (driver) => DropdownMenuItem(
                          value: driver['id'].toString(),
                          child: Text(
                            (driver['name'] ?? 'Conductor').toString() +
                                ' · ★ ' +
                                (driver['rating'] ?? '—').toString(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setLocal(() => driverId = value),
                ),
                const SizedBox(height: 10),
                _NumberField(
                  controller: fare,
                  label: 'Tarifa final',
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
              onPressed: driverId == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && driverId != null) {
      try {
        await supabase.rpc(
          'admin_assign_ride',
          params: {
            'p_ride_request_id': ride['id'],
            'p_driver_id': driverId,
            'p_final_fare': _num(fare.text),
          },
        );
        if (mounted) {
          setState(() => revision++);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Viaje asignado.')),
          );
        }
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }

    fare.dispose();
  }

  Future<void> _assignDelivery(
    Map<String, dynamic> delivery,
    List<Map<String, dynamic>> drivers,
  ) async {
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay conductores disponibles.')),
      );
      return;
    }

    String? driverId = drivers.first['id']?.toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Asignar delivery'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (delivery['pickup_address'] ?? 'Origen').toString() +
                      ' → ' +
                      (delivery['dropoff_address'] ?? 'Destino').toString(),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: driverId,
                  decoration:
                      const InputDecoration(labelText: 'Repartidor disponible'),
                  items: drivers
                      .map(
                        (driver) => DropdownMenuItem(
                          value: driver['id'].toString(),
                          child: Text(
                            (driver['name'] ?? 'Conductor').toString() +
                                ' · ★ ' +
                                (driver['rating'] ?? '—').toString(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setLocal(() => driverId = value),
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
              onPressed: driverId == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && driverId != null) {
      try {
        await supabase.rpc(
          'admin_assign_delivery',
          params: {
            'p_delivery_id': delivery['id'],
            'p_driver_id': driverId,
          },
        );
        if (mounted) {
          setState(() => revision++);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery asignado.')),
          );
        }
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          List<Map<String, dynamic>> rides,
          List<Map<String, dynamic>> deliveries,
          List<Map<String, dynamic>> drivers,
        })>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading(title: 'Cargando despacho');
        }
        if (snapshot.hasError) {
          return _Error(
            error: snapshot.error,
            onRetry: () => setState(() => revision++),
          );
        }

        final data = snapshot.data ??
            (
              rides: <Map<String, dynamic>>[],
              deliveries: <Map<String, dynamic>>[],
              drivers: <Map<String, dynamic>>[],
            );

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const _Header(
              title: 'Despacho manual',
              subtitle:
                  'Asigna un conductor disponible cuando el despacho automático no resuelva el servicio.',
            ),
            const SizedBox(height: 14),
            Card(
              color: const Color(0xFFEAF2FF),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Conductores disponibles ahora: ' +
                      data.drivers.length.toString(),
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Solicitudes de viaje',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (data.rides.isEmpty)
              const _Empty(text: 'No hay viajes esperando asignación.')
            else
              ...data.rides.map(
                (row) => _DispatchItem(
                  icon: Icons.local_taxi_rounded,
                  title:
                      (row['pickup_address'] ?? 'Origen').toString() +
                      ' → ' +
                      (row['destination_address'] ?? 'Destino').toString(),
                  subtitle:
                      (row['passenger_name'] ?? 'Pasajero').toString() +
                      ' · Bs ' +
                      (row['proposed_fare'] ?? '—').toString(),
                  onAssign: () => _assignRide(row, data.drivers),
                ),
              ),
            const SizedBox(height: 22),
            const Text(
              'Delivery esperando',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (data.deliveries.isEmpty)
              const _Empty(text: 'No hay delivery esperando asignación.')
            else
              ...data.deliveries.map(
                (row) => _DispatchItem(
                  icon: Icons.local_shipping_rounded,
                  title:
                      (row['pickup_address'] ?? 'Origen').toString() +
                      ' → ' +
                      (row['dropoff_address'] ?? 'Destino').toString(),
                  subtitle:
                      (row['customer_name'] ?? 'Cliente').toString() +
                      ' · Bs ' +
                      (row['proposed_fare'] ?? '—').toString(),
                  onAssign: () => _assignDelivery(row, data.drivers),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  int revision = 0;

  String _actionLabel(Object? raw) {
    return switch (raw?.toString()) {
      'update_user_profile' => 'Perfil de usuario actualizado',
      'update_driver_profile' => 'Perfil de conductor actualizado',
      'upsert_driver_document' => 'Documento de conductor actualizado',
      'send_announcement' => 'Aviso / promoción enviada',
      'set_driver_approval' => 'Estado de conductor cambiado',
      'set_account_status' => 'Estado de cuenta cambiado',
      'service_zone_polygon' => 'Polígono de cobertura actualizado',
      'upsert_service_zone_polygon' => 'Polígono de cobertura actualizado',
      'update_service_zone_polygon' => 'Polígono de cobertura actualizado',
      'upsert_zone' => 'Zona actualizada',
      'set_zone_service' => 'Servicio de zona actualizado',
      'update_fare_rule' => 'Tarifa actualizada',
      'set_fare_rule' => 'Tarifa actualizada',
      final value when value != null && value.isNotEmpty =>
        value.replaceAll('_', ' '),
      _ => 'Acción administrativa',
    };
  }

  String _entityLabel(Object? raw) {
    return switch (raw?.toString()) {
      'driver_profile' => 'Conductor',
      'driver_document' => 'Documento',
      'user' => 'Usuario',
      'notifications' => 'Notificaciones',
      'service_zone_polygon' => 'Polígono de zona',
      'service_zone' => 'Zona',
      'fare_rule' => 'Tarifa',
      'zone_service' => 'Servicio',
      'driver_subscription' => 'Suscripción',
      final value when value != null && value.isNotEmpty =>
        value.replaceAll('_', ' '),
      _ => 'Sistema',
    };
  }

  List<String> _detailLines(Object? raw) {
    if (raw is! Map || raw.isEmpty) return const [];
    final map = Map<String, dynamic>.from(raw);
    return map.entries
        .map((entry) {
          final key = entry.key
              .replaceAll('_', ' ')
              .replaceFirstMapped(
                RegExp(r'^[a-z]'),
                (m) => m.group(0)!.toUpperCase(),
              );
          final value = entry.value;
          final rendered = value is Map || value is List
              ? value.toString()
              : (value?.toString() ?? '—');
          return '$key: $rendered';
        })
        .toList();
  }

  Future<void> _showDetail(Map<String, dynamic> row) async {
    final lines = _detailLines(row['details']);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_actionLabel(row['action'])),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReadOnlyRow('Módulo', _entityLabel(row['entity_type'])),
                _ReadOnlyRow(
                  'Administrador',
                  (row['admin_name'] ?? 'Administrador').toString(),
                ),
                _ReadOnlyRow('Fecha', _formatDate(row['created_at'])),
                _ReadOnlyRow('ID', (row['entity_id'] ?? '—').toString()),
                if (lines.isNotEmpty) ...[
                  const Divider(height: 26),
                  const Text(
                    'Cambios registrados',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  ...lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SelectableText(
                        line,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final value = await supabase.rpc(
      'admin_audit_list',
      params: {'p_limit': 300},
    );
    return _list(value);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading(title: 'Cargando auditoría');
        }
        if (snapshot.hasError) {
          return _Error(
            error: snapshot.error,
            onRetry: () => setState(() => revision++),
          );
        }

        final rows = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const _Header(
              title: 'Auditoría',
              subtitle:
                  'Registro de cambios sensibles realizados desde Express Admin.',
            ),
            const SizedBox(height: 18),
            if (rows.isEmpty)
              const _Empty(text: 'Todavía no hay acciones auditadas.')
            else
              ...rows.map(
                (row) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading:
                        const Icon(Icons.history_rounded, color: _blue),
                    title: Text(
                      _actionLabel(row['action']),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      _entityLabel(row['entity_type']) +
                          ' · ' +
                          (row['admin_name'] ?? 'Administrador').toString() +
                          ' · ' +
                          _formatDate(row['created_at']) +
                          '\nID: ' +
                          (row['entity_id'] ?? '—').toString(),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showDetail(row),
                    isThreeLine: true,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AdminZonesPage extends StatefulWidget {
  const AdminZonesPage({super.key});

  @override
  State<AdminZonesPage> createState() => _AdminZonesPageState();
}

class _AdminZonesPageState extends State<AdminZonesPage> {
  int revision = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final value = await supabase.rpc('admin_zone_list');
    return _list(value);
  }

  Future<List<Map<String, dynamic>>> _loadPartners(String zoneId) async {
    final value = await supabase.rpc(
      'admin_partner_list',
      params: {'p_zone_id': zoneId},
    );
    return _list(value);
  }

  Future<bool> _editPartner(
    Map<String, dynamic> zone, [
    Map<String, dynamic>? row,
  ]) async {
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final code =
        TextEditingController(text: row?['partner_code']?.toString() ?? '');
    final commission = TextEditingController(
      text: row?['commission_percent']?.toString() ?? '0',
    );
    final contactName =
        TextEditingController(text: row?['contact_name']?.toString() ?? '');
    final contactPhone =
        TextEditingController(text: row?['contact_phone']?.toString() ?? '');
    final contactEmail =
        TextEditingController(text: row?['contact_email']?.toString() ?? '');
    final notes =
        TextEditingController(text: row?['notes']?.toString() ?? '');
    var type = row?['organization_type']?.toString() ?? 'syndicate';
    var status = row?['status']?.toString() ?? 'active';

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            row == null
                ? 'Nuevo sindicato · ${zone['name'] ?? 'Zona'}'
                : 'Editar aliado · ${zone['name'] ?? 'Zona'}',
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del sindicato o aliado',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(
                      labelText: 'Código interno',
                      hintText: 'Se genera automáticamente si queda vacío',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration:
                        const InputDecoration(labelText: 'Tipo de organización'),
                    items: const [
                      DropdownMenuItem(
                        value: 'syndicate',
                        child: Text('Sindicato'),
                      ),
                      DropdownMenuItem(
                        value: 'allied_company',
                        child: Text('Empresa aliada'),
                      ),
                      DropdownMenuItem(
                        value: 'cooperative',
                        child: Text('Cooperativa'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocal(() => type = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Activo')),
                      DropdownMenuItem(
                        value: 'suspended',
                        child: Text('Suspendido'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactivo'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocal(() => status = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: commission,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Comisión para el aliado (%)',
                      helperText:
                          'Se calcula solo sobre pagos de sus conductores.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contactName,
                    decoration:
                        const InputDecoration(labelText: 'Responsable / presidente'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contactPhone,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contactEmail,
                    decoration: const InputDecoration(labelText: 'Correo'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notas'),
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

    var saved = false;
    if (save == true) {
      try {
        await supabase.rpc(
          'admin_upsert_partner',
          params: {
            'p_id': row?['id'],
            'p_zone_id': zone['id'],
            'p_partner_code': code.text.trim(),
            'p_name': name.text.trim(),
            'p_organization_type': type,
            'p_status': status,
            'p_commission_percent':
                double.tryParse(commission.text.trim()) ?? 0,
            'p_contact_name': contactName.text.trim(),
            'p_contact_phone': contactPhone.text.trim(),
            'p_contact_email': contactEmail.text.trim(),
            'p_notes': notes.text.trim(),
          },
        );
        saved = true;
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }

    name.dispose();
    code.dispose();
    commission.dispose();
    contactName.dispose();
    contactPhone.dispose();
    contactEmail.dispose();
    notes.dispose();
    return saved;
  }

  Future<void> _showPartners(Map<String, dynamic> zone) async {
    var localRevision = 0;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.groups_2_outlined, color: _blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aliados y sindicatos · ${zone['name'] ?? 'Zona'}',
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final saved = await _editPartner(zone);
                  if (saved) setLocal(() => localRevision++);
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo'),
              ),
            ],
          ),
          content: SizedBox(
            width: 920,
            height: 560,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(localRevision),
              future: _loadPartners(zone['id'].toString()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const _Loading(title: 'Cargando aliados');
                }
                if (snapshot.hasError) {
                  return _Error(
                    error: snapshot.error,
                    onRetry: () => setLocal(() => localRevision++),
                  );
                }
                final rows =
                    snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) {
                  return const _Empty(
                    text:
                        'Esta zona todavía no tiene sindicatos o empresas aliadas.',
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final active = row['status']?.toString() == 'active';
                    final generated =
                        row['commission_generated']?.toString() ?? '0';
                    final paid = row['commission_paid']?.toString() ?? '0';
                    final payments =
                        row['payments_approved']?.toString() ?? '0';
                    return Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFEAF2FF),
                              child: Icon(
                                row['organization_type'] == 'syndicate'
                                    ? Icons.groups_2_rounded
                                    : Icons.business_outlined,
                                color: _blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row['name']?.toString() ?? 'Aliado',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Comisión: ${row['commission_percent'] ?? 0}% · '
                                    'Conductores activos: ${row['drivers_active'] ?? 0}',
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Pagos de conductores: $payments · '
                                    'Comisión generada: $generated · '
                                    'Liquidada: $paid',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _MiniStatus(
                              text: active ? 'Activo' : 'No activo',
                              positive: active,
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Editar aliado',
                              onPressed: () async {
                                final saved = await _editPartner(zone, row);
                                if (saved) {
                                  setLocal(() => localRevision++);
                                }
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final city =
        TextEditingController(text: row?['city']?.toString() ?? '');
    final country =
        TextEditingController(text: row?['country']?.toString() ?? '');
    final zoneKey =
        TextEditingController(text: row?['zone_key']?.toString() ?? '');
    final currency = TextEditingController(
      text: row?['currency_code']?.toString() ?? '',
    );
    final lat = TextEditingController(
      text: row?['center_latitude']?.toString() ?? '',
    );
    final lng = TextEditingController(
      text: row?['center_longitude']?.toString() ?? '',
    );
    final radius = TextEditingController(
      text: row?['radius_km']?.toString() ?? '25',
    );
    var active = row?['active'] != false;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Nueva zona' : 'Editar zona'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hub_outlined, color: _blue),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Cada zona puede tener servicios, tarifas y planes de suscripción propios. Las integraciones como VeriPagos siguen siendo globales.',
                            style: TextStyle(fontSize: 11, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: zoneKey,
                    enabled: row == null,
                    decoration: const InputDecoration(
                      labelText: 'Clave de zona',
                      hintText: 'Ej. trinidad, iquique, santa_cruz',
                      helperText:
                          'Se genera desde la ciudad si la dejas vacía. No cambia después de crearla.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: city,
                    decoration: const InputDecoration(labelText: 'Ciudad'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: country,
                    decoration: const InputDecoration(labelText: 'País'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: currency,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Moneda',
                      hintText: 'BOB / CLP',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: lat,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration:
                              const InputDecoration(labelText: 'Latitud'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: lng,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration:
                              const InputDecoration(labelText: 'Longitud'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.map_outlined,
                              color: _blue,
                              size: 19,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Seleccionar centro en el mapa',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Toca el punto que será el centro de la ciudad. La latitud y longitud se completan automáticamente.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 270,
                          child: FlutterMap(
                            key: ValueKey(
                              'zone-map-' + lat.text + '-' + lng.text,
                            ),
                            options: MapOptions(
                              initialCenter: LatLng(
                                _num(lat.text)?.toDouble() ?? -18.0,
                                _num(lng.text)?.toDouble() ?? -66.0,
                              ),
                              initialZoom:
                                  _num(lat.text) != null &&
                                          _num(lng.text) != null
                                      ? 12
                                      : 4.2,
                              onTap: (_, point) {
                                setLocal(() {
                                  lat.text =
                                      point.latitude.toStringAsFixed(6);
                                  lng.text =
                                      point.longitude.toStringAsFixed(6);
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.express.admin',
                              ),
                              if (_num(lat.text) != null &&
                                  _num(lng.text) != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(
                                        _num(lat.text)!.toDouble(),
                                        _num(lng.text)!.toDouble(),
                                      ),
                                      width: 44,
                                      height: 44,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Color(0xFFD92D20),
                                        size: 42,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: radius,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Radio de cobertura km'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setLocal(() => active = value),
                    title: const Text('Zona activa'),
                    subtitle: const Text(
                      'La app puede detectarla automáticamente por GPS.',
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

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_upsert_zone',
          params: {
            'p_id': row?['id'],
            'p_name': name.text.trim(),
            'p_city': city.text.trim(),
            'p_country': country.text.trim(),
            'p_active': active,
            'p_center_latitude': _num(lat.text),
            'p_center_longitude': _num(lng.text),
            'p_radius_km': _num(radius.text) ?? 25,
            'p_zone_key': row?['zone_key']?.toString() ?? zoneKey.text.trim(),
            'p_currency_code': currency.text.trim().toUpperCase(),
          },
        );
        if (mounted) {
          setState(() => revision++);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Zona guardada. Sus servicios y suscripciones ya pueden configurarse por separado.',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }

    name.dispose();
    city.dispose();
    country.dispose();
    zoneKey.dispose();
    currency.dispose();
    lat.dispose();
    lng.dispose();
    radius.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading(title: 'Cargando zonas');
        }
        if (snapshot.hasError) {
          return _Error(
            error: snapshot.error,
            onRetry: () => setState(() => revision++),
          );
        }

        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _Header(
              title: 'Zonas de operación',
              subtitle:
                  'Cada ciudad funciona como una unidad independiente de servicios, tarifas y suscripciones.',
              action: FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nueva zona'),
              ),
            ),
            const SizedBox(height: 18),
            if (rows.isEmpty)
              const _Empty(text: 'No hay zonas configuradas.')
            else
              ...rows.map(
                (row) => Container(
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
                      vertical: 5,
                    ),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFEAF2FF),
                      child: Icon(
                        row['active'] == true
                            ? Icons.location_on_rounded
                            : Icons.location_off_outlined,
                        color: _blue,
                      ),
                    ),
                    title: Text(
                      row['name']?.toString() ?? 'Zona',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      (row['city'] ?? '—').toString() +
                          ' · ' +
                          (row['country'] ?? '—').toString() +
                          ' · ' +
                          (row['currency_code'] ?? 'BOB').toString() +
                          ' · radio ' +
                          (row['radius_km'] ?? '—').toString() +
                          ' km\nClave: ' +
                          (row['zone_key'] ?? '—').toString(),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniStatus(
                          text: row['active'] == true ? 'Activa' : 'Inactiva',
                          positive: row['active'] == true,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Aliados / sindicatos',
                          onPressed: () => _showPartners(row),
                          icon: const Icon(Icons.groups_2_outlined, size: 19),
                        ),
                        IconButton(
                          tooltip: 'Editar zona',
                          onPressed: () => _edit(row),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}


class AdminServicesPage extends StatefulWidget {
  const AdminServicesPage({super.key});

  @override
  State<AdminServicesPage> createState() => _AdminServicesPageState();
}

class _AdminServicesPageState extends State<AdminServicesPage> {
  int revision = 0;
  String? selectedZoneId;

  Future<({
    List<Map<String, dynamic>> zones,
    List<Map<String, dynamic>> services,
    Map<String, dynamic>? zone,
  })> _load() async {
    final zoneRows = _list(await supabase.rpc('admin_zone_list'));
    if (zoneRows.isEmpty) {
      return (
        zones: zoneRows,
        services: <Map<String, dynamic>>[],
        zone: null,
      );
    }

    var zoneId = selectedZoneId;
    if (zoneId == null ||
        !zoneRows.any((row) => row['id']?.toString() == zoneId)) {
      final trinidad = zoneRows.where(
        (row) => row['zone_key']?.toString() == 'trinidad',
      );
      zoneId = trinidad.isNotEmpty
          ? trinidad.first['id'].toString()
          : zoneRows.first['id'].toString();
      selectedZoneId = zoneId;
    }

    final zone = zoneRows.firstWhere(
      (row) => row['id']?.toString() == zoneId,
    );
    final serviceRows = _list(
      await supabase.rpc(
        'admin_zone_service_list',
        params: {'p_zone_id': zoneId},
      ),
    );

    return (zones: zoneRows, services: serviceRows, zone: zone);
  }

  Future<void> _edit(
    List<Map<String, dynamic>> zones, [
    Map<String, dynamic>? row,
  ]) async {
    final zoneId = selectedZoneId;
    if (zoneId == null) {
      _snack(context, 'Primero crea o selecciona una zona.');
      return;
    }

    final key =
        TextEditingController(text: row?['service_key']?.toString() ?? '');
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final description =
        TextEditingController(text: row?['description']?.toString() ?? '');
    final order =
        TextEditingController(text: row?['sort_order']?.toString() ?? '100');
    var vehicle = row?['vehicle_type']?.toString() ?? 'motorcycle';
    var enabled = row?['enabled'] == true;
    var bidding = row?['allow_bidding'] != false;
    var fixed = row?['allow_fixed_price'] != false;
    var passengerVisible = row?['passenger_visible'] == true;
    var driverVisible = row?['driver_visible'] == true;
    var scheduled = row?['scheduled_enabled'] != false;

    final zone = zones.firstWhere(
      (item) => item['id']?.toString() == zoneId,
    );
    final zoneName = zone['name']?.toString() ?? 'Zona';

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            (row == null ? 'Crear servicio' : 'Editar servicio') +
                ' · ' +
                zoneName,
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.location_city_rounded, color: _blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Disponibilidad en $zoneName. El nombre, descripción y tipo de vehículo forman parte del catálogo base; la activación y visibilidad se controlan por zona.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _dark,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nombre visible',
                      hintText: 'Ej. Moto Express',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: key,
                    enabled: row == null,
                    decoration: const InputDecoration(
                      labelText: 'Clave interna',
                      hintText: 'motorcycle',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: vehicle,
                    decoration:
                        const InputDecoration(labelText: 'Vehículo requerido'),
                    items: const [
                      DropdownMenuItem(value: 'car', child: Text('Auto')),
                      DropdownMenuItem(
                        value: 'motorcycle',
                        child: Text('Moto'),
                      ),
                      DropdownMenuItem(value: 'xl', child: Text('XL')),
                      DropdownMenuItem(
                        value: 'any',
                        child: Text('Cualquiera'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocal(() => vehicle = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Orden en la app'),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    onChanged: (value) => setLocal(() => enabled = value),
                    title: Text('Servicio activo en $zoneName'),
                    subtitle: const Text(
                      'Al apagarlo desaparece solo de esta zona.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: passengerVisible,
                    onChanged: enabled
                        ? (value) => setLocal(() => passengerVisible = value)
                        : null,
                    title: const Text('Visible para pasajeros'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: driverVisible,
                    onChanged: enabled
                        ? (value) => setLocal(() => driverVisible = value)
                        : null,
                    title: const Text('Visible para conductores'),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: bidding,
                    onChanged: (value) => setLocal(() => bidding = value),
                    title: const Text('Permitir ofertas'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: fixed,
                    onChanged: (value) => setLocal(() => fixed = value),
                    title: const Text('Permitir precio fijo'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: scheduled,
                    onChanged: (value) => setLocal(() => scheduled = value),
                    title: const Text('Permitir viajes programados'),
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
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar servicio'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_upsert_service',
          params: {
            'p_id': row?['id'],
            'p_service_key': key.text.trim(),
            'p_name': name.text.trim(),
            'p_description': description.text.trim(),
            'p_icon_key': 'local_taxi',
            'p_vehicle_type': vehicle,
            'p_enabled': true,
            'p_allow_bidding': bidding,
            'p_allow_fixed_price': fixed,
            'p_passenger_visible': true,
            'p_driver_visible': true,
            'p_scheduled_enabled': scheduled,
            'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
          },
        );

        await supabase.rpc(
          'admin_set_zone_service',
          params: {
            'p_zone_id': zoneId,
            'p_service_key': key.text.trim(),
            'p_enabled': enabled,
            'p_passenger_visible': enabled && passengerVisible,
            'p_driver_visible': enabled && driverVisible,
            'p_allow_bidding': bidding,
            'p_allow_fixed_price': fixed,
            'p_scheduled_enabled': scheduled,
            'p_sort_order': int.tryParse(order.text.trim()) ?? 100,
          },
        );

        if (mounted) {
          setState(() => revision++);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Servicio guardado para $zoneName.')),
          );
        }
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }

    key.dispose();
    name.dispose();
    description.dispose();
    order.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          List<Map<String, dynamic>> zones,
          List<Map<String, dynamic>> services,
          Map<String, dynamic>? zone,
        })>(
      key: ValueKey('$revision-$selectedZoneId'),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading(title: 'Cargando servicios por zona');
        }
        if (snapshot.hasError) {
          return _Error(
            error: snapshot.error,
            onRetry: () => setState(() => revision++),
          );
        }

        final data = snapshot.data ??
            (
              zones: <Map<String, dynamic>>[],
              services: <Map<String, dynamic>>[],
              zone: null,
            );
        final rows = data.services;
        final active = rows.where((row) => row['enabled'] == true).length;
        final bidding =
            rows.where((row) => row['allow_bidding'] == true).length;
        final zoneName = data.zone?['name']?.toString() ?? 'Sin zona';

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _Header(
              title: 'Servicios por zona',
              subtitle:
                  'Decide qué servicios verá cada ciudad sin afectar a las demás.',
              action: data.zones.isEmpty
                  ? null
                  : FilledButton.icon(
                      onPressed: () => _edit(data.zones),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Crear servicio'),
                    ),
            ),
            const SizedBox(height: 14),
            if (data.zones.isEmpty)
              const _Empty(
                text: 'Primero crea una zona de operación.',
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: _blue),
                      const SizedBox(width: 10),
                      const Text(
                        'Zona que estás editando',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedZoneId,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Zona',
                          ),
                          items: data.zones
                              .map(
                                (zone) => DropdownMenuItem<String>(
                                  value: zone['id'].toString(),
                                  child: Text(
                                    (zone['name'] ?? 'Zona').toString() +
                                        ' · ' +
                                        (zone['city'] ?? '—').toString(),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedZoneId = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _AdminHero(
                icon: Icons.apps_rounded,
                title: 'Catálogo · $zoneName',
                subtitle:
                    'Activar o apagar un servicio aquí solo cambia esta zona.',
                stats: [
                  ('Servicios', rows.length.toString()),
                  ('Activos', active.toString()),
                  ('Con ofertas', bidding.toString()),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final cardWidth = width < 680
                      ? width
                      : width < 1050
                          ? (width - 12) / 2
                          : (width - 24) / 3;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: rows.map((row) {
                      final enabled = row['enabled'] == true;
                      return SizedBox(
                        width: cardWidth,
                        child: _AdminModuleCard(
                          icon: _serviceIcon(
                            row['vehicle_type']?.toString(),
                          ),
                          title: row['name']?.toString() ?? 'Servicio',
                          subtitle: row['description']?.toString() ??
                              'Sin descripción',
                          accent: enabled ? _blue : _muted,
                          chips: [
                            enabled ? 'Activo en $zoneName' : 'Inactivo',
                            row['vehicle_type']?.toString() ?? 'car',
                            if (row['allow_bidding'] == true) 'Ofertas',
                            if (row['allow_fixed_price'] == true) 'Precio fijo',
                            if (row['passenger_visible'] == true) 'Pasajero',
                            if (row['driver_visible'] == true) 'Conductor',
                            if (row['scheduled_enabled'] == true) 'Programados',
                          ],
                          onTap: () => _edit(data.zones, row),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}


class AdminGeoSafetyPage extends StatefulWidget {
  const AdminGeoSafetyPage({super.key});

  @override
  State<AdminGeoSafetyPage> createState() => _AdminGeoSafetyPageState();
}

class _AdminGeoSafetyPageState extends State<AdminGeoSafetyPage> {
  int revision = 0;

  Future<({
    List<Map<String, dynamic>> zones,
    List<Map<String, dynamic>> coverage,
    List<Map<String, dynamic>> safety,
  })> _load() async {
    final values = await Future.wait([
      supabase.rpc('admin_zone_list'),
      supabase.rpc('admin_zone_polygon_list'),
      supabase.rpc('admin_security_zone_list'),
    ]);
    return (
      zones: _list(values[0]),
      coverage: _list(values[1]),
      safety: _list(values[2]),
    );
  }

  List<LatLng> _points(Object? raw) {
    if (raw is! List) return <LatLng>[];
    return raw
        .whereType<Map>()
        .map((row) {
          final lat = _double(row['lat']);
          final lng = _double(row['lng']);
          if (lat == null || lng == null) return null;
          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList();
  }

  List<Map<String, double>> _jsonPoints(List<LatLng> points) => points
      .map((point) => {'lat': point.latitude, 'lng': point.longitude})
      .toList();

  Future<void> _editCoverage(
    List<Map<String, dynamic>> zones, [
    Map<String, dynamic>? row,
  ]) async {
    if (zones.isEmpty) {
      _snack(context, 'Primero crea una zona de operación.');
      return;
    }
    var zoneId = row?['zone_id']?.toString() ?? zones.first['id'].toString();
    var active = row?['active'] != false;
    final name = TextEditingController(
      text: row?['name']?.toString() ?? 'Cobertura principal',
    );
    var points = _points(row?['polygon']);

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Dibujar cobertura' : 'Editar cobertura'),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: zoneId,
                          decoration: const InputDecoration(labelText: 'Zona'),
                          items: zones
                              .map(
                                (zone) => DropdownMenuItem(
                                  value: zone['id'].toString(),
                                  child: Text(zone['name']?.toString() ?? 'Zona'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) setLocal(() => zoneId = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: name,
                          decoration: const InputDecoration(labelText: 'Nombre del polígono'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PolygonEditor(
                    points: points,
                    tone: _blue,
                    title: 'Toca el mapa para marcar la cobertura',
                    onAdd: (point) => setLocal(() => points = [...points, point]),
                    onUndo: () {
                      if (points.isNotEmpty) {
                        setLocal(() => points = points.sublist(0, points.length - 1));
                      }
                    },
                    onClear: () => setLocal(() => points = <LatLng>[]),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setLocal(() => active = value),
                    title: const Text('Polígono activo'),
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
            FilledButton.icon(
              onPressed: points.length < 3
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar polígono'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_upsert_zone_polygon',
          params: {
            'p_id': row?['id'],
            'p_zone_id': zoneId,
            'p_name': name.text.trim(),
            'p_polygon': _jsonPoints(points),
            'p_active': active,
          },
        );
        if (mounted) setState(() => revision++);
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }
    name.dispose();
  }

  Future<void> _editSafety([Map<String, dynamic>? row]) async {
    var type = row?['zone_type']?.toString() ?? 'red';
    var applies = row?['applies_to']?.toString() ?? 'both';
    var severity = ((row?['severity'] as num?)?.toInt() ?? 3).clamp(1, 5);
    var active = row?['active'] != false;
    var points = _points(row?['polygon']);
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final message = TextEditingController(text: row?['message']?.toString() ?? '');
    final city = TextEditingController(text: row?['city']?.toString() ?? 'Trinidad');
    final country = TextEditingController(text: row?['country']?.toString() ?? 'Bolivia');

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Crear zona de seguridad' : 'Editar zona de seguridad'),
          content: SizedBox(
            width: 780,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ej. Zona roja nocturna',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration: const InputDecoration(labelText: 'Tipo'),
                          items: const [
                            DropdownMenuItem(value: 'red', child: Text('Zona roja')),
                            DropdownMenuItem(value: 'caution', child: Text('Precaución')),
                            DropdownMenuItem(value: 'safe', child: Text('Zona segura')),
                          ],
                          onChanged: (value) {
                            if (value != null) setLocal(() => type = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: applies,
                          decoration: const InputDecoration(labelText: 'Aplica a'),
                          items: const [
                            DropdownMenuItem(value: 'both', child: Text('Pasajero y conductor')),
                            DropdownMenuItem(value: 'driver', child: Text('Solo conductor')),
                            DropdownMenuItem(value: 'passenger', child: Text('Solo pasajero')),
                          ],
                          onChanged: (value) {
                            if (value != null) setLocal(() => applies = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: city,
                          decoration: const InputDecoration(labelText: 'Ciudad'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: country,
                          decoration: const InputDecoration(labelText: 'País'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: message,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Mensaje preventivo',
                      hintText: 'Este sector requiere mayor precaución.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Nivel de riesgo', style: TextStyle(fontWeight: FontWeight.w800)),
                      Expanded(
                        child: Slider(
                          value: severity.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: severity.toString(),
                          onChanged: (value) => setLocal(() => severity = value.round()),
                        ),
                      ),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _securityTone(type).withOpacity(.12),
                        child: Text(
                          severity.toString(),
                          style: TextStyle(
                            color: _securityTone(type),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _PolygonEditor(
                    points: points,
                    tone: _securityTone(type),
                    title: 'Dibuja el perímetro de seguridad',
                    onAdd: (point) => setLocal(() => points = [...points, point]),
                    onUndo: () {
                      if (points.isNotEmpty) {
                        setLocal(() => points = points.sublist(0, points.length - 1));
                      }
                    },
                    onClear: () => setLocal(() => points = <LatLng>[]),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setLocal(() => active = value),
                    title: const Text('Zona activa'),
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
            FilledButton.icon(
              onPressed: points.length < 3
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Guardar zona'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_upsert_security_zone',
          params: {
            'p_id': row?['id'],
            'p_name': name.text.trim(),
            'p_zone_type': type,
            'p_applies_to': applies,
            'p_severity': severity,
            'p_polygon': _jsonPoints(points),
            'p_message': message.text.trim(),
            'p_active': active,
            'p_city': city.text.trim(),
            'p_country': country.text.trim(),
          },
        );
        if (mounted) setState(() => revision++);
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }

    name.dispose();
    message.dispose();
    city.dispose();
    country.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          List<Map<String, dynamic>> zones,
          List<Map<String, dynamic>> coverage,
          List<Map<String, dynamic>> safety,
        })>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const _Loading(title: 'Cargando cobertura y seguridad');
        }
        if (snapshot.hasError) {
          return _Error(error: snapshot.error, onRetry: () => setState(() => revision++));
        }
        final data = snapshot.data ??
            (
              zones: <Map<String, dynamic>>[],
              coverage: <Map<String, dynamic>>[],
              safety: <Map<String, dynamic>>[],
            );

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                child: _AdminHero(
                  icon: Icons.gpp_good_rounded,
                  title: 'Cobertura y seguridad',
                  subtitle:
                      'Controla dónde opera Express y qué sectores necesitan reglas especiales.',
                  stats: [
                    ('Zonas', data.zones.length.toString()),
                    ('Polígonos', data.coverage.length.toString()),
                    ('Seguridad', data.safety.length.toString()),
                  ],
                ),
              ),
              const Material(
                color: Colors.white,
                child: TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.polyline_rounded), text: 'Cobertura'),
                    Tab(icon: Icon(Icons.shield_outlined), text: 'Zonas de seguridad'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(22),
                      children: [
                        _Header(
                          title: 'Polígonos de cobertura',
                          subtitle:
                              'Dibuja áreas reales en el mapa. El radio circular queda como respaldo.',
                          action: FilledButton.icon(
                            onPressed: () => _editCoverage(data.zones),
                            icon: const Icon(Icons.draw_rounded),
                            label: const Text('Dibujar polígono'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (data.coverage.isEmpty)
                          const _Empty(text: 'Todavía no hay polígonos de cobertura.')
                        else
                          ...data.coverage.map(
                            (row) => _GeoRow(
                              tone: _blue,
                              icon: Icons.polyline_rounded,
                              title: row['name']?.toString() ?? 'Cobertura',
                              subtitle:
                                  (row['zone_name'] ?? 'Zona').toString() +
                                      ' · ' +
                                      (row['city'] ?? 'Trinidad').toString(),
                              badge: row['active'] == true ? 'Activa' : 'Inactiva',
                              onTap: () => _editCoverage(data.zones, row),
                            ),
                          ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(22),
                      children: [
                        _Header(
                          title: 'Zonas rojas y prevención',
                          subtitle:
                              'Marca sectores de riesgo, precaución o zonas seguras para conductor y pasajero.',
                          action: FilledButton.icon(
                            onPressed: () => _editSafety(),
                            icon: const Icon(Icons.add_moderator_outlined),
                            label: const Text('Crear zona'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (data.safety.isEmpty)
                          const _Empty(text: 'Todavía no hay zonas de seguridad.')
                        else
                          ...data.safety.map(
                            (row) => _GeoRow(
                              tone: _securityTone(row['zone_type']?.toString()),
                              icon: row['zone_type'] == 'safe'
                                  ? Icons.verified_user_outlined
                                  : Icons.warning_amber_rounded,
                              title: row['name']?.toString() ?? 'Zona de seguridad',
                              subtitle:
                                  _securityLabel(row['zone_type']?.toString()) +
                                      ' · nivel ' +
                                      (row['severity'] ?? 3).toString() +
                                      ' · ' +
                                      (row['applies_to'] ?? 'both').toString(),
                              badge: row['active'] == true ? 'Activa' : 'Inactiva',
                              onTap: () => _editSafety(row),
                            ),
                          ),
                      ],
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

class AdminIdentitySecurityPage extends StatefulWidget {
  const AdminIdentitySecurityPage({super.key});

  @override
  State<AdminIdentitySecurityPage> createState() => _AdminIdentitySecurityPageState();
}

class _AdminIdentitySecurityPageState extends State<AdminIdentitySecurityPage> {
  int revision = 0;

  Future<({
    Map<String, dynamic> settings,
    List<Map<String, dynamic>> verifications,
  })> _load() async {
    final values = await Future.wait([
      supabase.rpc('admin_identity_settings_get'),
      supabase.rpc('admin_identity_verification_list', params: {'p_limit': 200}),
    ]);
    return (
      settings: _map(values[0]),
      verifications: _list(values[1]),
    );
  }

  Future<void> _configure(Map<String, dynamic> row) async {
    var provider = row['provider']?.toString() ?? 'manual';
    var document = row['document_enabled'] != false;
    var face = row['face_enabled'] != false;
    var match = row['face_match_enabled'] != false;
    var liveness = row['liveness_enabled'] == true;
    var driver = row['require_driver'] != false;
    var passenger = row['require_passenger'] == true;
    var review = row['manual_review_on_fail'] != false;
    var faceScore = _double(row['min_face_score']) ?? .75;
    var liveScore = _double(row['min_liveness_score']) ?? .70;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Política de verificación'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEAF2FF), Color(0xFFF7F5FF)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: _blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'La política ya queda preparada. La conexión con un proveedor externo se activa aparte para no enviar documentos a un servicio sin credenciales.',
                            style: TextStyle(fontSize: 11, color: _dark, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: provider,
                    decoration: const InputDecoration(labelText: 'Motor actual'),
                    items: const [
                      DropdownMenuItem(value: 'manual', child: Text('Revisión manual segura')),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocal(() => provider = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: document,
                    onChanged: (value) => setLocal(() => document = value),
                    title: const Text('Revisar documento'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: face,
                    onChanged: (value) => setLocal(() => face = value),
                    title: const Text('Capturar rostro'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: match,
                    onChanged: (value) => setLocal(() => match = value),
                    title: const Text('Comparar rostro con documento'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: liveness,
                    onChanged: (value) => setLocal(() => liveness = value),
                    title: const Text('Prueba de vida'),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: driver,
                    onChanged: (value) => setLocal(() => driver = value),
                    title: const Text('Obligatorio para conductores'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: passenger,
                    onChanged: (value) => setLocal(() => passenger = value),
                    title: const Text('Obligatorio para pasajeros'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: review,
                    onChanged: (value) => setLocal(() => review = value),
                    title: const Text('Enviar a revisión manual si falla'),
                  ),
                  const SizedBox(height: 8),
                  Text('Coincidencia facial mínima · ' + (faceScore * 100).round().toString() + '%'),
                  Slider(
                    value: faceScore.clamp(0, 1),
                    min: 0,
                    max: 1,
                    divisions: 20,
                    onChanged: (value) => setLocal(() => faceScore = value),
                  ),
                  Text('Prueba de vida mínima · ' + (liveScore * 100).round().toString() + '%'),
                  Slider(
                    value: liveScore.clamp(0, 1),
                    min: 0,
                    max: 1,
                    divisions: 20,
                    onChanged: (value) => setLocal(() => liveScore = value),
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
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.security_rounded),
              label: const Text('Guardar política'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_identity_settings_update',
          params: {
            'p_provider': provider,
            'p_document_enabled': document,
            'p_face_enabled': face,
            'p_face_match_enabled': match,
            'p_liveness_enabled': liveness,
            'p_require_driver': driver,
            'p_require_passenger': passenger,
            'p_min_face_score': faceScore,
            'p_min_liveness_score': liveScore,
            'p_manual_review_on_fail': review,
          },
        );
        if (mounted) setState(() => revision++);
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }
  }


  Future<void> _reviewVerification(Map<String, dynamic> row) async {
    var status = row['status']?.toString() ?? 'review';
    if (!const ['review', 'verified', 'rejected'].contains(status)) {
      status = 'review';
    }
    final note = TextEditingController();

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Revisar verificación'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Resultado'),
                  items: const [
                    DropdownMenuItem(
                      value: 'review',
                      child: Text('Mantener en revisión'),
                    ),
                    DropdownMenuItem(
                      value: 'verified',
                      child: Text('Verificado'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rechazado'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setLocal(() => status = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nota administrativa',
                    hintText: 'Opcional',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Guardar revisión'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_identity_resolve',
          params: {
            'p_verification_id': row['id'],
            'p_status': status,
            'p_review_note': note.text.trim(),
          },
        );
        if (mounted) {
          setState(() => revision++);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verificación actualizada.')),
          );
        }
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }

    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          Map<String, dynamic> settings,
          List<Map<String, dynamic>> verifications,
        })>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const _Loading(title: 'Cargando seguridad de identidad');
        }
        if (snapshot.hasError) {
          return _Error(error: snapshot.error, onRetry: () => setState(() => revision++));
        }

        final data = snapshot.data ??
            (settings: <String, dynamic>{}, verifications: <Map<String, dynamic>>[]);
        final pending = data.verifications
            .where((row) => ['pending', 'processing', 'review'].contains(row['status']))
            .length;
        final verified =
            data.verifications.where((row) => row['status'] == 'verified').length;

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _Header(
              title: 'Verificación de identidad',
              subtitle:
                  'Documento, rostro, coincidencia facial y prueba de vida para proteger a pasajeros y conductores.',
              action: FilledButton.icon(
                onPressed: () => _configure(data.settings),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Configurar política'),
              ),
            ),
            const SizedBox(height: 16),
            _AdminHero(
              icon: Icons.verified_user_rounded,
              title: 'Centro de identidad',
              subtitle:
                  'La política queda centralizada y preparada para conectar un proveedor automático.',
              stats: [
                ('Motor', (data.settings['provider'] ?? 'manual').toString()),
                ('Pendientes', pending.toString()),
                ('Verificados', verified.toString()),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cardWidth = width < 760 ? width : (width - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _AdminModuleCard(
                        icon: Icons.badge_outlined,
                        title: 'Documento oficial',
                        subtitle:
                            'Captura y revisión del documento. La automatización OCR se conectará por proveedor.',
                        accent: const Color(0xFF6941C6),
                        chips: [
                          data.settings['document_enabled'] == true ? 'Activo' : 'Inactivo',
                          data.settings['require_driver'] == true ? 'Conductor obligatorio' : 'Opcional',
                        ],
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _AdminModuleCard(
                        icon: Icons.face_retouching_natural_rounded,
                        title: 'Rostro y coincidencia',
                        subtitle:
                            'Compara la selfie con la identidad y permite exigir prueba de vida.',
                        accent: const Color(0xFF0E9384),
                        chips: [
                          data.settings['face_match_enabled'] == true ? 'Comparación activa' : 'Comparación inactiva',
                          data.settings['liveness_enabled'] == true ? 'Liveness activo' : 'Liveness pendiente',
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Solicitudes de verificación',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _dark),
            ),
            const SizedBox(height: 10),
            if (data.verifications.isEmpty)
              const _Empty(
                text:
                    'Todavía no hay verificaciones. El módulo está listo para recibirlas cuando conectemos el flujo de registro.',
              )
            else
              ...data.verifications.map(
                (row) => _GeoRow(
                  tone: row['status'] == 'verified'
                      ? const Color(0xFF12B76A)
                      : row['status'] == 'rejected'
                          ? const Color(0xFFD92D20)
                          : const Color(0xFFF79009),
                  icon: Icons.person_search_rounded,
                  title: row['full_name']?.toString() ?? 'Usuario Express',
                  subtitle:
                      (row['subject_role'] ?? 'driver').toString() +
                          ' · ' +
                          (row['provider'] ?? 'manual').toString(),
                  badge: row['status']?.toString() ?? 'pending',
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PolygonEditor extends StatelessWidget {
  final List<LatLng> points;
  final Color tone;
  final String title;
  final ValueChanged<LatLng> onAdd;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const _PolygonEditor({
    required this.points,
    required this.tone,
    required this.title,
    required this.onAdd,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final center = points.isNotEmpty ? points.first : const LatLng(-14.8333, -64.9000);
    return Container(
      height: 430,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE3EC)),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              onTap: (_, point) => onAdd(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.express.delivery.admin',
              ),
              if (points.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: points,
                      color: tone.withOpacity(.16),
                      borderColor: tone,
                      borderStrokeWidth: 3,
                    ),
                  ],
                )
              else if (points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(points: points, color: tone, strokeWidth: 3),
                  ],
                ),
              if (points.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < points.length; i++)
                      Marker(
                        point: points[i],
                        width: 24,
                        height: 24,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tone,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text(
                            (i + 1).toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.95),
                borderRadius: BorderRadius.circular(11),
                boxShadow: const [
                  BoxShadow(color: Color(0x1A101828), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: tone, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title + ' · ' + points.length.toString() + ' puntos',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: points.isEmpty ? null : onUndo,
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: const Text('Deshacer'),
                  ),
                  TextButton.icon(
                    onPressed: points.isEmpty ? null : onClear,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: const Text('Limpiar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminHero extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<(String, String)> stats;

  const _AdminHero({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B57D0), Color(0xFF5B74F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x2A0B57D0), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final info = Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFE7EEFF),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final statRow = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: stats
                .map(
                  (stat) => Container(
                    constraints: const BoxConstraints(minWidth: 105),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.13),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(.14)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          stat.$1,
                          style: const TextStyle(color: Color(0xFFE7EEFF), fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          );

          if (constraints.maxWidth < 780) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 14), statRow],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 20),
              statRow,
            ],
          );
        },
      ),
    );
  }
}

class _AdminModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final List<String> chips;
  final VoidCallback? onTap;

  const _AdminModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.chips,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4EAF2)),
          boxShadow: const [
            BoxShadow(color: Color(0x0D101828), blurRadius: 18, offset: Offset(0, 7)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const Spacer(),
                if (onTap != null)
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _muted),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _dark),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: _muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chips
                  .map(
                    (chip) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE7ECF3)),
                      ),
                      child: Text(
                        chip,
                        style: const TextStyle(
                          color: _dark,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeoRow extends StatelessWidget {
  final Color tone;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback? onTap;

  const _GeoRow({
    required this.tone,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tone.withOpacity(.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: tone, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _dark),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 9, color: _muted)),
        trailing: Wrap(
          spacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tone.withOpacity(.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: TextStyle(color: tone, fontSize: 8.5, fontWeight: FontWeight.w900),
              ),
            ),
            if (onTap != null)
              IconButton(
                onPressed: onTap,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

IconData _serviceIcon(String? vehicle) {
  switch (vehicle) {
    case 'motorcycle':
      return Icons.two_wheeler_rounded;
    case 'any':
      return Icons.commute_rounded;
    default:
      return Icons.local_taxi_rounded;
  }
}

Color _securityTone(String? type) {
  switch (type) {
    case 'safe':
      return const Color(0xFF12B76A);
    case 'caution':
      return const Color(0xFFF79009);
    default:
      return const Color(0xFFD92D20);
  }
}

String _securityLabel(String? type) {
  switch (type) {
    case 'safe':
      return 'Zona segura';
    case 'caution':
      return 'Precaución';
    default:
      return 'Zona roja';
  }
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}


class AdminFaresPage extends StatefulWidget {
  const AdminFaresPage({super.key});

  @override
  State<AdminFaresPage> createState() => _AdminFaresPageState();
}

class _AdminFaresPageState extends State<AdminFaresPage> {
  int revision = 0;
  String? selectedZoneId;

  Future<({
    List<Map<String, dynamic>> fares,
    List<Map<String, dynamic>> zones,
    List<Map<String, dynamic>> services,
    Map<String, dynamic>? zone,
  })> _load() async {
    final values = await Future.wait([
      supabase.rpc('admin_fare_list'),
      supabase.rpc('admin_zone_list'),
      supabase.rpc('admin_service_list'),
    ]);
    final zones = _list(values[1]);

    if (zones.isEmpty) {
      return (
        fares: _list(values[0]),
        zones: zones,
        services: _list(values[2]),
        zone: null,
      );
    }

    var zoneId = selectedZoneId;
    if (zoneId == null ||
        !zones.any((row) => row['id']?.toString() == zoneId)) {
      final trinidad =
          zones.where((row) => row['zone_key']?.toString() == 'trinidad');
      zoneId = trinidad.isNotEmpty
          ? trinidad.first['id'].toString()
          : zones.first['id'].toString();
      selectedZoneId = zoneId;
    }

    return (
      fares: _list(values[0]),
      zones: zones,
      services: _list(values[2]),
      zone: zones.firstWhere((row) => row['id']?.toString() == zoneId),
    );
  }

  Future<void> _edit(
    List<Map<String, dynamic>> zones,
    List<Map<String, dynamic>> services, [
    Map<String, dynamic>? row,
  ]) async {
    var scope = row?['scope_type']?.toString() ?? 'zone_service';
    var service = row?['service_key']?.toString() ??
        (services.isNotEmpty
            ? services.first['service_key']?.toString() ?? 'motorcycle'
            : 'motorcycle');
    String? zoneId =
        row?['zone_id']?.toString() ?? selectedZoneId;
    var active = row?['active'] != false;

    final base = TextEditingController(
      text: row?['base_fare']?.toString() ?? '5',
    );
    final km = TextEditingController(
      text: row?['per_km']?.toString() ?? '1',
    );
    final minute = TextEditingController(
      text: row?['per_minute']?.toString() ?? '0',
    );
    final minimum = TextEditingController(
      text: row?['minimum_fare']?.toString() ?? '5',
    );
    final surge = TextEditingController(
      text: row?['surge_multiplier']?.toString() ?? '1',
    );
    final commission = TextEditingController(
      text: row?['commission_percent']?.toString() ?? '0',
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Nueva tarifa' : 'Editar tarifa'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Usa “Zona + servicio” para que una tarifa afecte solo a una ciudad. Global y Por servicio quedan como reglas de respaldo.',
                      style: TextStyle(fontSize: 11, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: scope,
                    decoration: const InputDecoration(labelText: 'Jerarquía'),
                    items: const [
                      DropdownMenuItem(
                        value: 'zone_service',
                        child: Text('Zona + servicio · recomendado'),
                      ),
                      DropdownMenuItem(
                        value: 'service',
                        child: Text('Por servicio · respaldo'),
                      ),
                      DropdownMenuItem(
                        value: 'global',
                        child: Text('Global · respaldo general'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocal(() => scope = value);
                    },
                  ),
                  if (scope != 'global') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: service,
                      decoration:
                          const InputDecoration(labelText: 'Servicio'),
                      items: services
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item['service_key']?.toString(),
                              child: Text(
                                item['name']?.toString() ??
                                    item['service_key']?.toString() ??
                                    'Servicio',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setLocal(() => service = value);
                      },
                    ),
                  ],
                  if (scope == 'zone_service') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: zoneId,
                      decoration: const InputDecoration(labelText: 'Zona'),
                      items: zones
                          .map(
                            (zone) => DropdownMenuItem<String>(
                              value: zone['id'].toString(),
                              child: Text(
                                (zone['name'] ?? 'Zona').toString() +
                                    ' · ' +
                                    (zone['currency_code'] ?? 'BOB').toString(),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setLocal(() => zoneId = value),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _NumberField(controller: base, label: 'Tarifa base'),
                  const SizedBox(height: 10),
                  _NumberField(controller: km, label: 'Precio por km'),
                  const SizedBox(height: 10),
                  _NumberField(controller: minute, label: 'Precio por minuto'),
                  const SizedBox(height: 10),
                  _NumberField(controller: minimum, label: 'Tarifa mínima'),
                  const SizedBox(height: 10),
                  _NumberField(
                    controller: surge,
                    label: 'Multiplicador dinámico',
                  ),
                  const SizedBox(height: 10),
                  _NumberField(
                    controller: commission,
                    label: 'Comisión %',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setLocal(() => active = value),
                    title: const Text('Regla activa'),
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

    if (save == true) {
      try {
        await supabase.rpc(
          'admin_upsert_fare_rule',
          params: {
            'p_id': row?['id'],
            'p_scope_type': scope,
            'p_service_key': scope == 'global' ? null : service,
            'p_zone_id': scope == 'zone_service' ? zoneId : null,
            'p_base_fare': _num(base.text) ?? 0,
            'p_per_km': _num(km.text) ?? 0,
            'p_per_minute': _num(minute.text) ?? 0,
            'p_minimum_fare': _num(minimum.text) ?? 0,
            'p_surge_multiplier': _num(surge.text) ?? 1,
            'p_commission_percent': _num(commission.text) ?? 0,
            'p_active': active,
          },
        );
        if (mounted) {
          setState(() => revision++);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tarifa guardada.')),
          );
        }
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }

    base.dispose();
    km.dispose();
    minute.dispose();
    minimum.dispose();
    surge.dispose();
    commission.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          List<Map<String, dynamic>> fares,
          List<Map<String, dynamic>> zones,
          List<Map<String, dynamic>> services,
          Map<String, dynamic>? zone,
        })>(
      key: ValueKey('$revision-$selectedZoneId'),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading(title: 'Cargando tarifas por zona');
        }
        if (snapshot.hasError) {
          return _Error(
            error: snapshot.error,
            onRetry: () => setState(() => revision++),
          );
        }

        final data = snapshot.data ??
            (
              fares: <Map<String, dynamic>>[],
              zones: <Map<String, dynamic>>[],
              services: <Map<String, dynamic>>[],
              zone: null,
            );
        final zoneId = data.zone?['id']?.toString();
        final visibleFares = data.fares.where((row) {
          final scope = row['scope_type']?.toString();
          if (scope == 'global' || scope == 'service') return true;
          return row['zone_id']?.toString() == zoneId;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _Header(
              title: 'Tarifas por zona',
              subtitle:
                  'Las reglas de la zona tienen prioridad sobre las reglas globales y de servicio.',
              action: data.zones.isEmpty
                  ? null
                  : FilledButton.icon(
                      onPressed: () => _edit(data.zones, data.services),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nueva tarifa'),
                    ),
            ),
            const SizedBox(height: 14),
            if (data.zones.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.location_city_rounded, color: _blue),
                      const SizedBox(width: 10),
                      const Text(
                        'Zona',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedZoneId,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Editar tarifas de',
                          ),
                          items: data.zones
                              .map(
                                (zone) => DropdownMenuItem<String>(
                                  value: zone['id'].toString(),
                                  child: Text(
                                    (zone['name'] ?? 'Zona').toString() +
                                        ' · ' +
                                        (zone['currency_code'] ?? 'BOB')
                                            .toString(),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedZoneId = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            if (visibleFares.isEmpty)
              const _Empty(text: 'No hay reglas de tarifa configuradas.')
            else
              ...visibleFares.map(
                (row) => Container(
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
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEAF2FF),
                      child: Icon(Icons.payments_outlined, color: _blue),
                    ),
                    title: Text(
                      _fareTitle(row),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      'Base ' +
                          (row['base_fare'] ?? 0).toString() +
                          ' · km ' +
                          (row['per_km'] ?? 0).toString() +
                          ' · min ' +
                          (row['per_minute'] ?? 0).toString() +
                          ' · mínimo ' +
                          (row['minimum_fare'] ?? 0).toString() +
                          ' · comisión ' +
                          (row['commission_percent'] ?? 0).toString() +
                          '%',
                    ),
                    trailing: IconButton(
                      onPressed: () =>
                          _edit(data.zones, data.services, row),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  int revision = 0;

  Future<({
    Map<String, dynamic> overview,
    List<Map<String, dynamic>> topups,
  })> _load() async {
    final values = await Future.wait([
      supabase.rpc('admin_payment_overview'),
      supabase.rpc(
        'admin_topup_requests',
        params: {'p_status': 'pending'},
      ),
    ]);
    return (
      overview: _map(values[0]),
      topups: _list(values[1]),
    );
  }

  Future<void> _resolveTopup(
    Map<String, dynamic> row,
    String status,
  ) async {
    final approved = status == 'approved';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approved ? 'Aprobar recarga' : 'Rechazar recarga'),
        content: Text(
          (approved
                  ? 'Se acreditará '
                  : 'Se rechazará la solicitud de ') +
              'Bs ' +
              (row['amount'] ?? 0).toString() +
              ' para ' +
              (row['full_name'] ?? 'este usuario').toString() +
              '.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: approved
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD92D20),
                  ),
            child: Text(approved ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await supabase.rpc(
        'admin_resolve_wallet_topup',
        params: {
          'p_request_id': row['id'],
          'p_status': status,
        },
      );
      if (!mounted) return;
      setState(() => revision++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Recarga aprobada y saldo acreditado.'
                : 'Recarga rechazada.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          Map<String, dynamic> overview,
          List<Map<String, dynamic>> topups,
        })>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading(title: 'Cargando pagos');
        }
        if (snapshot.hasError) {
          return _Error(
            error: snapshot.error,
            onRetry: () => setState(() => revision++),
          );
        }

        final data = snapshot.data ??
            (
              overview: <String, dynamic>{},
              topups: <Map<String, dynamic>>[],
            );
        final summary = _map(data.overview['summary']);
        final recent = _list(data.overview['recent']);
        final topups = data.topups;

        return RefreshIndicator(
          onRefresh: () async => setState(() => revision++),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const _Header(
                title: 'Pagos y Billetera',
                subtitle:
                    'Cobros, recargas pendientes, saldos y movimientos.',
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Kpi(
                    'Cobrado hoy',
                    'Bs ' + (summary['paid_today'] ?? 0).toString(),
                  ),
                  _Kpi(
                    'Pendiente',
                    'Bs ' + (summary['pending_total'] ?? 0).toString(),
                  ),
                  _Kpi(
                    'Pagos hoy',
                    (summary['paid_count_today'] ?? 0).toString(),
                  ),
                  _Kpi(
                    'Saldo wallet',
                    'Bs ' +
                        (summary['wallet_balance_total'] ?? 0).toString(),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recargas pendientes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _MiniStatus(
                    text: topups.length.toString(),
                    positive: topups.isEmpty,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (topups.isEmpty)
                const _Empty(text: 'No hay recargas pendientes.')
              else
                ...topups.map(
                  (row) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE7ECF3)),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFF4E5),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xFFB54708),
                        ),
                      ),
                      title: Text(
                        (row['full_name'] ?? 'Usuario Express').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        'Bs ' +
                            (row['amount'] ?? 0).toString() +
                            ' · ' +
                            _formatDate(row['created_at']) +
                            (row['phone'] == null
                                ? ''
                                : ' · ' + row['phone'].toString()),
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          OutlinedButton(
                            onPressed: () => _resolveTopup(row, 'rejected'),
                            child: const Text('Rechazar'),
                          ),
                          FilledButton(
                            onPressed: () => _resolveTopup(row, 'approved'),
                            child: const Text('Aprobar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Movimientos recientes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (recent.isEmpty)
                const _Empty(text: 'No hay movimientos.')
              else
                ...recent.map(
                  (row) => Container(
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
                      leading: Icon(
                        row['method'] == 'wallet'
                            ? Icons.account_balance_wallet_rounded
                            : row['method'] == 'cash'
                                ? Icons.payments_outlined
                                : Icons.credit_card_rounded,
                        color: _blue,
                      ),
                      title: Text(
                        (row['currency'] ?? 'BOB').toString() +
                            ' ' +
                            (row['amount'] ?? 0).toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        (row['method'] ?? '—').toString() +
                            ' · ' +
                            (row['status'] ?? '—').toString() +
                            ' · ' +
                            _formatDate(row['created_at']),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}


class AdminCommunicationsPage extends StatefulWidget {
  const AdminCommunicationsPage({super.key});

  @override
  State<AdminCommunicationsPage> createState() =>
      _AdminCommunicationsPageState();
}

class _AdminCommunicationsPageState
    extends State<AdminCommunicationsPage> {
  int revision = 0;
  String? selectedUserId;
  String? selectedUserName;
  final replyController = TextEditingController();
  final announcementTitle = TextEditingController();
  final announcementBody = TextEditingController();
  String audience = 'drivers';
  bool sendingReply = false;
  bool sendingAnnouncement = false;
  bool loadingCampaignTargets = true;
  List<Map<String, dynamic>> campaignZones = const [];
  List<Map<String, dynamic>> campaignPartners = const [];
  String? campaignZoneId;
  String? campaignPartnerId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCampaignTargets());
  }

  Future<void> _loadCampaignTargets() async {
    try {
      final values = await Future.wait([
        supabase.rpc('admin_zone_list'),
        supabase.rpc('admin_partner_list'),
      ]);
      if (!mounted) return;
      setState(() {
        campaignZones = _list(values[0]);
        campaignPartners = _list(values[1]);
        loadingCampaignTargets = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingCampaignTargets = false);
    }
  }

  @override
  void dispose() {
    replyController.dispose();
    announcementTitle.dispose();
    announcementBody.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _threads() async {
    final value = await supabase.rpc('admin_support_threads');
    return _list(value);
  }

  Future<List<Map<String, dynamic>>> _messages(String userId) async {
    final value = await supabase.rpc(
      'admin_support_messages',
      params: {'p_user_id': userId},
    );
    return _list(value);
  }

  Future<void> _reply() async {
    final userId = selectedUserId;
    final text = replyController.text.trim();
    if (userId == null || text.isEmpty || sendingReply) return;

    setState(() => sendingReply = true);
    try {
      await supabase.rpc(
        'admin_support_reply',
        params: {
          'p_user_id': userId,
          'p_body': text,
        },
      );
      replyController.clear();
      if (mounted) setState(() => revision++);
    } catch (e) {
      if (mounted) _snack(context, e);
    } finally {
      if (mounted) setState(() => sendingReply = false);
    }
  }

  Future<void> _sendAnnouncement() async {
    final title = announcementTitle.text.trim();
    final body = announcementBody.text.trim();
    if (title.isEmpty || body.isEmpty || sendingAnnouncement) return;

    final audienceLabel = switch (audience) {
      'drivers' => 'conductores',
      'passengers' => 'pasajeros',
      _ => 'todos los usuarios',
    };
    Map<String, dynamic>? zone;
    for (final row in campaignZones) {
      if (row['id']?.toString() == campaignZoneId) {
        zone = row;
        break;
      }
    }
    Map<String, dynamic>? partner;
    for (final row in campaignPartners) {
      if (row['id']?.toString() == campaignPartnerId) {
        partner = row;
        break;
      }
    }
    final targetLabel = partner != null
        ? audienceLabel + ' de ' + (partner['name'] ?? 'la organización').toString()
        : zone != null
            ? audienceLabel + ' de ' + (zone['name'] ?? 'la zona').toString()
            : audienceLabel;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enviar aviso'),
        content: Text(
          'Se enviará “' + title + '” a ' + targetLabel + '.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => sendingAnnouncement = true);
    try {
      final result = await supabase.rpc(
        'admin_send_announcement_v2',
        params: {
          'p_title': title,
          'p_body': body,
          'p_audience': audience,
          'p_zone_id': campaignZoneId,
          'p_partner_id': campaignPartnerId,
        },
      );
      announcementTitle.clear();
      announcementBody.clear();
      if (!mounted) return;
      final resultMap = _map(result);
      final recipients = resultMap['recipients'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aviso push enviado a ' +
                recipients.toString() +
                ' destinatarios.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) _snack(context, e);
    } finally {
      if (mounted) setState(() => sendingAnnouncement = false);
    }
  }

  Widget _supportTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('threads-' + revision.toString()),
      future: _threads(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading(title: 'Cargando soporte');
        }
        if (snapshot.hasError) {
          return _Error(
            error: snapshot.error,
            onRetry: () => setState(() => revision++),
          );
        }

        final threads = snapshot.data ?? const <Map<String, dynamic>>[];
        if (threads.isEmpty) {
          return const Center(
            child: _Empty(
              text: 'No hay conversaciones de soporte todavía.',
            ),
          );
        }

        final currentId = selectedUserId ??
            threads.first['user_id']?.toString();
        final current = threads.firstWhere(
          (row) => row['user_id']?.toString() == currentId,
          orElse: () => threads.first,
        );
        final effectiveId = current['user_id']?.toString();
        if (selectedUserId == null && effectiveId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && selectedUserId == null) {
              setState(() {
                selectedUserId = effectiveId;
                selectedUserName =
                    current['full_name']?.toString() ?? 'Usuario Express';
              });
            }
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 850;

            final threadList = ListView(
              padding: const EdgeInsets.all(12),
              children: threads.map((row) {
                final userId = row['user_id']?.toString();
                final selected = userId == currentId;
                final unread =
                    (row['unread_count'] as num?)?.toInt() ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFF4F8FF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFCFE0FF)
                          : const Color(0xFFE7ECF3),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline_rounded),
                    ),
                    title: Text(
                      row['full_name']?.toString() ?? 'Usuario Express',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      row['last_message']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: unread > 0
                        ? CircleAvatar(
                            radius: 12,
                            backgroundColor: _blue,
                            child: Text(
                              unread.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => setState(() {
                      selectedUserId = userId;
                      selectedUserName =
                          row['full_name']?.toString() ?? 'Usuario Express';
                      revision++;
                    }),
                  ),
                );
              }).toList(),
            );

            final chat = effectiveId == null
                ? const Center(child: Text('Selecciona una conversación.'))
                : FutureBuilder<List<Map<String, dynamic>>>(
                    key: ValueKey(
                      'messages-' +
                          effectiveId +
                          '-' +
                          revision.toString(),
                    ),
                    future: _messages(effectiveId),
                    builder: (context, messagesSnapshot) {
                      if (messagesSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !messagesSnapshot.hasData) {
                        return const _Loading(
                          title: 'Cargando conversación',
                        );
                      }
                      if (messagesSnapshot.hasError) {
                        return _Error(
                          error: messagesSnapshot.error,
                          onRetry: () =>
                              setState(() => revision++),
                        );
                      }
                      final messages = messagesSnapshot.data ??
                          const <Map<String, dynamic>>[];

                      return Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFFE7ECF3),
                                ),
                              ),
                            ),
                            child: Text(
                              selectedUserName ??
                                  current['full_name']?.toString() ??
                                  'Usuario Express',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Expanded(
                            child: messages.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Sin mensajes.',
                                      style: TextStyle(color: _muted),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final row = messages[index];
                                      final admin =
                                          row['sender_role'] == 'admin';
                                      return Align(
                                        alignment: admin
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          constraints:
                                              const BoxConstraints(
                                            maxWidth: 430,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 13,
                                            vertical: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            color: admin
                                                ? const Color(0xFFEAF2FF)
                                                : const Color(0xFFF2F4F7),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                row['body']?.toString() ??
                                                    '',
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                _formatDate(
                                                  row['created_at'],
                                                ),
                                                style: const TextStyle(
                                                  color: _muted,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: replyController,
                                    minLines: 1,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Responder desde soporte...',
                                    ),
                                    onSubmitted: (_) => _reply(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed:
                                      sendingReply ? null : _reply,
                                  icon: sendingReply
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );

            if (compact) {
              return Column(
                children: [
                  SizedBox(height: 210, child: threadList),
                  const Divider(height: 1),
                  Expanded(child: chat),
                ],
              );
            }

            return Row(
              children: [
                SizedBox(width: 330, child: threadList),
                const VerticalDivider(width: 1),
                Expanded(child: chat),
              ],
            );
          },
        );
      },
    );
  }

  Widget _announcementsTab() {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const _Header(
          title: 'Enviar avisos',
          subtitle:
              'Estos son los únicos mensajes que aparecen en “Avisos” dentro de la app.',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE7ECF3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: audience,
                decoration: const InputDecoration(
                  labelText: 'Destinatarios',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'drivers',
                    child: Text('Conductores'),
                  ),
                  DropdownMenuItem(
                    value: 'passengers',
                    child: Text('Pasajeros'),
                  ),
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Todos'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      audience = value;
                      if (value != 'drivers') campaignPartnerId = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: campaignZoneId,
                decoration: const InputDecoration(
                  labelText: 'Zona',
                  helperText:
                      'Déjalo en Todas para enviar a todas las zonas.',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas las zonas'),
                  ),
                  ...campaignZones.map(
                    (zone) => DropdownMenuItem<String?>(
                      value: zone['id']?.toString(),
                      child: Text(
                        (zone['name'] ?? 'Zona').toString() +
                            ' · ' +
                            (zone['currency_code'] ?? '').toString(),
                      ),
                    ),
                  ),
                ],
                onChanged: loadingCampaignTargets
                    ? null
                    : (value) => setState(() {
                          campaignZoneId = value;
                          if (campaignPartnerId != null) {
                            final selected = campaignPartners.where(
                              (partner) =>
                                  partner['id']?.toString() ==
                                  campaignPartnerId,
                            );
                            if (selected.isNotEmpty &&
                                value != null &&
                                selected.first['zone_id']?.toString() !=
                                    value) {
                              campaignPartnerId = null;
                            }
                          }
                        }),
              ),
              if (audience == 'drivers' && campaignPartners.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: campaignPartnerId,
                  decoration: const InputDecoration(
                    labelText: 'Empresa / sindicato / cooperativa',
                    helperText:
                        'Opcional: limita el aviso a los conductores afiliados.',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todas las organizaciones'),
                    ),
                    ...campaignPartners
                        .where(
                          (partner) =>
                              campaignZoneId == null ||
                              partner['zone_id']?.toString() ==
                                  campaignZoneId,
                        )
                        .map(
                          (partner) => DropdownMenuItem<String?>(
                            value: partner['id']?.toString(),
                            child: Text(
                              (partner['name'] ?? 'Organización').toString() +
                                  ' · ' +
                                  (partner['organization_type'] ?? '')
                                      .toString(),
                            ),
                          ),
                        ),
                  ],
                  onChanged: (value) =>
                      setState(() => campaignPartnerId = value),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD5E3FF)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, color: _blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Este aviso se guarda en la bandeja de la app y también se despacha como notificación push.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: announcementTitle,
                maxLength: 90,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ej. Actualización de Express',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: announcementBody,
                maxLength: 1000,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    sendingAnnouncement ? null : _sendAnnouncement,
                icon: sendingAnnouncement
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.campaign_rounded),
                label: const Text('Enviar aviso'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Material(
            color: Colors.white,
            child: TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.support_agent_rounded),
                  text: 'Soporte',
                ),
                Tab(
                  icon: Icon(Icons.campaign_outlined),
                  text: 'Avisos',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _supportTab(),
                _announcementsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  DateTime from = DateTime.now().subtract(const Duration(days: 30));
  DateTime to = DateTime.now().add(const Duration(days: 1));
  int revision = 0;

  Future<Map<String, dynamic>> _load() async {
    final value = await supabase.rpc(
      'admin_report_summary',
      params: {
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      },
    );
    return _map(value);
  }

  Future<void> _pickFrom() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: from,
    );
    if (selected != null) {
      setState(() {
        from = selected;
        revision++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading(title: 'Generando reporte');
        }
        if (snapshot.hasError) {
          return _Error(error: snapshot.error, onRetry: () => setState(() => revision++));
        }

        final data = snapshot.data ?? const {};
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _Header(
              title: 'Reportes',
              subtitle:
                  'Resumen operativo y financiero del período seleccionado.',
              action: OutlinedButton.icon(
                onPressed: _pickFrom,
                icon: const Icon(Icons.date_range_outlined),
                label: Text('Desde ' + _dateOnly(from)),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Kpi('Viajes', (data['trips_total'] ?? 0).toString()),
                _Kpi(
                  'Viajes completados',
                  (data['trips_completed'] ?? 0).toString(),
                ),
                _Kpi(
                  'Viajes cancelados',
                  (data['trips_cancelled'] ?? 0).toString(),
                ),
                _Kpi('Delivery', (data['delivery_total'] ?? 0).toString()),
                _Kpi(
                  'Delivery completados',
                  (data['delivery_completed'] ?? 0).toString(),
                ),
                _Kpi(
                  'Cobrado',
                  'Bs ' + (data['paid_volume'] ?? 0).toString(),
                ),
                _Kpi('Usuarios nuevos', (data['new_users'] ?? 0).toString()),
                _Kpi('Emergencias', (data['emergencies'] ?? 0).toString()),
              ],
            ),
          ],
        );
      },
    );
  }
}

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  Map<String, dynamic>? settings;
  bool loading = true;
  bool saving = false;
  int settingsTab = 0;

  late final TextEditingController currency;
  late final TextEditingController rideMin;
  late final TextEditingController deliveryMin;
  late final TextEditingController commission;
  late final TextEditingController radius;
  late final TextEditingController dispatchRadius;
  late final TextEditingController timeout;
  late final TextEditingController radiusStep;
  late final TextEditingController timezone;
  late final TextEditingController country;
  late final TextEditingController supportPhone;
  late final TextEditingController supportWhatsapp;

  bool cash = true;
  bool card = false;
  bool wallet = false;
  bool rideEnabled = true;
  bool deliveryEnabled = true;
  String dispatchMode = 'broadcast';

  @override
  void initState() {
    super.initState();
    currency = TextEditingController();
    rideMin = TextEditingController();
    deliveryMin = TextEditingController();
    commission = TextEditingController();
    radius = TextEditingController();
    dispatchRadius = TextEditingController();
    timeout = TextEditingController();
    radiusStep = TextEditingController();
    timezone = TextEditingController();
    country = TextEditingController();
    supportPhone = TextEditingController();
    supportWhatsapp = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await supabase.rpc('admin_settings_get');
      final row = _map(value);
      settings = row;
      currency.text = (row['currency'] ?? 'BOB').toString();
      rideMin.text = (row['min_ride_fare'] ?? 5).toString();
      deliveryMin.text = (row['min_delivery_fare'] ?? 5).toString();
      commission.text = (row['commission_percent'] ?? 0).toString();
      radius.text = (row['service_radius_km'] ?? 30).toString();
      dispatchRadius.text = (row['dispatch_radius_km'] ?? 5).toString();
      timeout.text = (row['offer_timeout_seconds'] ?? 45).toString();
      radiusStep.text =
          (row['progressive_radius_step_km'] ?? 2).toString();
      timezone.text =
          (row['timezone'] ?? 'America/Santiago').toString();
      country.text = (row['default_country'] ?? 'Chile').toString();
      supportPhone.text = row['support_phone']?.toString() ?? '';
      supportWhatsapp.text = row['support_whatsapp']?.toString() ?? '';
      cash = row['allow_cash'] != false;
      card = row['allow_card'] == true;
      wallet = row['allow_wallet'] == true;
      rideEnabled = row['ride_enabled'] != false;
      deliveryEnabled = row['delivery_enabled'] != false;
      dispatchMode = (row['dispatch_mode'] ?? 'broadcast').toString();
    } catch (e) {
      if (mounted) _snack(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final value = await supabase.rpc(
        'admin_settings_update',
        params: {
          'p_currency': currency.text.trim(),
          'p_min_ride_fare': _num(rideMin.text) ?? 0,
          'p_min_delivery_fare': _num(deliveryMin.text) ?? 0,
          'p_commission_percent': _num(commission.text) ?? 0,
          'p_service_radius_km': _num(radius.text) ?? 30,
          'p_allow_cash': cash,
          'p_allow_card': card,
          'p_allow_wallet': wallet,
          'p_ride_enabled': rideEnabled,
          'p_delivery_enabled': deliveryEnabled,
          'p_dispatch_mode': dispatchMode,
          'p_dispatch_radius_km': _num(dispatchRadius.text) ?? 5,
          'p_offer_timeout_seconds': int.tryParse(timeout.text) ?? 45,
          'p_progressive_radius_step_km': _num(radiusStep.text) ?? 2,
          'p_timezone': timezone.text.trim(),
          'p_default_country': country.text.trim(),
          'p_support_phone': supportPhone.text.trim(),
          'p_support_whatsapp': supportWhatsapp.text.trim(),
        },
      );
      settings = _map(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada.')),
        );
      }
    } catch (e) {
      if (mounted) _snack(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      currency,
      rideMin,
      deliveryMin,
      commission,
      radius,
      dispatchRadius,
      timeout,
      radiusStep,
      timezone,
      country,
      supportPhone,
      supportWhatsapp,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Loading(title: 'Cargando configuración');

    const tabs = [
      'General',
      'Servicios',
      'Pagos',
      'Operación',
      'Tarifas',
      'Soporte',
    ];

    Widget content;
    switch (settingsTab) {
      case 1:
        content = _SettingsCard(
          title: 'Servicios',
          subtitle: 'Activa o desactiva verticales sin eliminar sus datos.',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: rideEnabled,
              onChanged: (value) => setState(() => rideEnabled = value),
              title: const Text('Taxi / Viajes habilitados'),
              subtitle: const Text('Permite solicitar viajes desde Express Rider.'),
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: deliveryEnabled,
              onChanged: (value) => setState(() => deliveryEnabled = value),
              title: const Text('Delivery habilitado'),
              subtitle: const Text('Permite crear y operar entregas.'),
            ),
          ],
        );
        break;
      case 2:
        content = _SettingsCard(
          title: 'Métodos de pago',
          subtitle: 'Controla qué medios pueden usar los clientes.',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: cash,
              onChanged: (value) => setState(() => cash = value),
              title: const Text('Efectivo'),
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: card,
              onChanged: (value) => setState(() => card = value),
              title: const Text('Tarjeta'),
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: wallet,
              onChanged: (value) => setState(() => wallet = value),
              title: const Text('Billetera Express'),
            ),
          ],
        );
        break;
      case 3:
        content = _SettingsCard(
          title: 'Operación y dispatch',
          subtitle: 'Define cómo se distribuyen las solicitudes a conductores.',
          children: [
            DropdownButtonFormField<String>(
              initialValue: dispatchMode,
              decoration: const InputDecoration(labelText: 'Modo de dispatch'),
              items: const [
                DropdownMenuItem(value: 'broadcast', child: Text('Broadcast')),
                DropdownMenuItem(value: 'progressive', child: Text('Progresivo')),
                DropdownMenuItem(value: 'manual', child: Text('Manual')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => dispatchMode = value);
              },
            ),
            const SizedBox(height: 12),
            _NumberField(
              controller: dispatchRadius,
              label: 'Radio inicial de dispatch km',
            ),
            const SizedBox(height: 12),
            _NumberField(
              controller: radiusStep,
              label: 'Aumento progresivo de radio km',
            ),
            const SizedBox(height: 12),
            _NumberField(
              controller: timeout,
              label: 'Duración de oferta en segundos',
            ),
          ],
        );
        break;
      case 4:
        content = _SettingsCard(
          title: 'Tarifas globales y alcance',
          subtitle: 'Valores generales antes de aplicar reglas por servicio o zona.',
          children: [
            _NumberField(controller: rideMin, label: 'Mínimo Viaje'),
            const SizedBox(height: 12),
            _NumberField(controller: deliveryMin, label: 'Mínimo Delivery'),
            const SizedBox(height: 12),
            _NumberField(controller: commission, label: 'Comisión global %'),
            const SizedBox(height: 12),
            _NumberField(controller: radius, label: 'Radio máximo km'),
            const SizedBox(height: 12),
            TextField(
              controller: currency,
              decoration: const InputDecoration(labelText: 'Moneda'),
            ),
          ],
        );
        break;
      case 5:
        content = _SettingsCard(
          title: 'Localización y soporte',
          subtitle: 'Datos regionales y canales de atención.',
          children: [
            TextField(
              controller: timezone,
              decoration: const InputDecoration(labelText: 'Zona horaria'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: country,
              decoration: const InputDecoration(labelText: 'País'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: supportPhone,
              decoration: const InputDecoration(labelText: 'Teléfono de soporte'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: supportWhatsapp,
              decoration: const InputDecoration(labelText: 'WhatsApp de soporte'),
            ),
          ],
        );
        break;
      default:
        content = Column(
          children: [
            _SettingsCard(
              title: 'Módulos',
              subtitle: 'Configuración rápida de la plataforma.',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: rideEnabled,
                  onChanged: (value) => setState(() => rideEnabled = value),
                  title: const Text('Taxi habilitado'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: deliveryEnabled,
                  onChanged: (value) => setState(() => deliveryEnabled = value),
                  title: const Text('Delivery habilitado'),
                ),
              ],
            ),
            _SettingsCard(
              title: 'Resumen operativo',
              subtitle: 'Parámetros principales de la empresa.',
              children: [
                _ReadOnlyRow(label: 'Empresa', value: 'Express Delivery'),
                _ReadOnlyRow(label: 'País', value: country.text),
                _ReadOnlyRow(label: 'Moneda', value: currency.text),
                _ReadOnlyRow(label: 'Dispatch', value: dispatchMode),
              ],
            ),
          ],
        );
    }

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        _Header(
          title: 'Configuración',
          subtitle: 'Administra los parámetros generales de Express Delivery.',
          action: FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Guardar configuración'),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7ECF3)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(tabs.length, (index) {
                final selected = settingsTab == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () => setState(() => settingsTab = index),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFEAF2FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        tabs[index],
                        style: TextStyle(
                          color: selected ? _blue : _muted,
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }
}


class AdminAdvancedSettingsPage extends StatefulWidget {
  const AdminAdvancedSettingsPage({super.key});

  @override
  State<AdminAdvancedSettingsPage> createState() => _AdminAdvancedSettingsPageState();
}

class _AdminAdvancedSettingsPageState extends State<AdminAdvancedSettingsPage> {
  int revision = 0;

  Future<Map<String, dynamic>> _load() async {
    final value = await supabase.rpc('admin_settings_get');
    return _map(value);
  }

  Future<void> _save(Map<String, dynamic> current, Map<String, dynamic> patch) async {
    final next = <String, dynamic>{...current, ...patch};
    await supabase.rpc(
      'admin_advanced_settings_update',
      params: {
        'p_allow_pagorut': next['allow_pagorut'] == true,
        'p_allow_mercadopago': next['allow_mercadopago'] == true,
        'p_allow_santander': next['allow_santander'] == true,
        'p_allow_mach': next['allow_mach'] == true,
        'p_allow_tenpo': next['allow_tenpo'] == true,
        'p_search_timeout_seconds': (next['search_timeout_seconds'] as num?)?.toInt() ?? 180,
        'p_request_visible_seconds': (next['request_visible_seconds'] as num?)?.toInt() ?? 180,
        'p_scheduled_rides_enabled': next['scheduled_rides_enabled'] != false,
        'p_scheduled_publish_before_minutes':
            (next['scheduled_publish_before_minutes'] as num?)?.toInt() ?? 30,
        'p_max_driver_request_radius_km': next['max_driver_request_radius_km'] ?? 15,
        'p_max_visible_requests_driver':
            (next['max_visible_requests_driver'] as num?)?.toInt() ?? 20,
        'p_allow_counteroffers': next['allow_counteroffers'] != false,
        'p_min_driver_offer': next['min_driver_offer'] ?? 1,
        'p_max_driver_offer': next['max_driver_offer'] ?? 9999,
        'p_chat_enabled': next['chat_enabled'] != false,
        'p_calls_enabled': next['calls_enabled'] != false,
        'p_share_trip_enabled': next['share_trip_enabled'] != false,
        'p_sos_enabled': next['sos_enabled'] != false,
        'p_saved_places_enabled': next['saved_places_enabled'] != false,
        'p_ratings_enabled': next['ratings_enabled'] != false,
        'p_rating_comment_enabled': next['rating_comment_enabled'] != false,
        'p_rating_min': (next['rating_min'] as num?)?.toInt() ?? 1,
        'p_rating_max': (next['rating_max'] as num?)?.toInt() ?? 5,
        'p_maintenance_mode': next['maintenance_mode'] == true,
        'p_maintenance_message': next['maintenance_message']?.toString(),
        'p_minimum_app_version': next['minimum_app_version']?.toString(),
      },
    );
    if (mounted) {
      setState(() => revision++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración avanzada guardada.')),
      );
    }
  }

  Future<void> _payments(Map<String, dynamic> row) async {
    var pagorut = row['allow_pagorut'] == true;
    var mp = row['allow_mercadopago'] == true;
    var santander = row['allow_santander'] == true;
    var mach = row['allow_mach'] == true;
    var tenpo = row['allow_tenpo'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Pagos digitales'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _InlineNotice(
                  icon: Icons.payments_outlined,
                  text:
                      'Activa solo los medios que realmente quieras mostrar. Las credenciales de cada pasarela se gestionan aparte.',
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: pagorut,
                  onChanged: (v) => setLocal(() => pagorut = v),
                  title: const Text('PagoRUT'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: mp,
                  onChanged: (v) => setLocal(() => mp = v),
                  title: const Text('Mercado Pago'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: santander,
                  onChanged: (v) => setLocal(() => santander = v),
                  title: const Text('Santander'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: mach,
                  onChanged: (v) => setLocal(() => mach = v),
                  title: const Text('MACH'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: tenpo,
                  onChanged: (v) => setLocal(() => tenpo = v),
                  title: const Text('Tenpo'),
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
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await _save(row, {
        'allow_pagorut': pagorut,
        'allow_mercadopago': mp,
        'allow_santander': santander,
        'allow_mach': mach,
        'allow_tenpo': tenpo,
      });
    }
  }

  Future<void> _offers(Map<String, dynamic> row) async {
    final search = TextEditingController(text: (row['search_timeout_seconds'] ?? 180).toString());
    final visible = TextEditingController(text: (row['request_visible_seconds'] ?? 180).toString());
    final before = TextEditingController(
      text: (row['scheduled_publish_before_minutes'] ?? 30).toString(),
    );
    final radius = TextEditingController(
      text: (row['max_driver_request_radius_km'] ?? 15).toString(),
    );
    final maxVisible = TextEditingController(
      text: (row['max_visible_requests_driver'] ?? 20).toString(),
    );
    final minOffer = TextEditingController(text: (row['min_driver_offer'] ?? 1).toString());
    final maxOffer = TextEditingController(text: (row['max_driver_offer'] ?? 9999).toString());
    var scheduled = row['scheduled_rides_enabled'] != false;
    var counteroffers = row['allow_counteroffers'] != false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Búsqueda y ofertas'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const _InlineNotice(
                    icon: Icons.radar_rounded,
                    text:
                        'Estos valores controlan cuánto dura la búsqueda, cuántas solicitudes ve el conductor y el rango de ofertas.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _NumberField(controller: search, label: 'Búsqueda máxima · segundos')),
                      const SizedBox(width: 10),
                      Expanded(child: _NumberField(controller: visible, label: 'Solicitud visible · segundos')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _NumberField(controller: radius, label: 'Radio máx. conductor · km')),
                      const SizedBox(width: 10),
                      Expanded(child: _NumberField(controller: maxVisible, label: 'Máx. solicitudes visibles')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _NumberField(controller: minOffer, label: 'Oferta mínima')),
                      const SizedBox(width: 10),
                      Expanded(child: _NumberField(controller: maxOffer, label: 'Oferta máxima')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _NumberField(
                    controller: before,
                    label: 'Publicar viaje programado antes · minutos',
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: scheduled,
                    onChanged: (v) => setLocal(() => scheduled = v),
                    title: const Text('Viajes programados'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: counteroffers,
                    onChanged: (v) => setLocal(() => counteroffers = v),
                    title: const Text('Permitir contraofertas'),
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

    if (ok == true) {
      await _save(row, {
        'search_timeout_seconds': int.tryParse(search.text.trim()) ?? 180,
        'request_visible_seconds': int.tryParse(visible.text.trim()) ?? 180,
        'scheduled_publish_before_minutes': int.tryParse(before.text.trim()) ?? 30,
        'max_driver_request_radius_km': _num(radius.text) ?? 15,
        'max_visible_requests_driver': int.tryParse(maxVisible.text.trim()) ?? 20,
        'min_driver_offer': _num(minOffer.text) ?? 1,
        'max_driver_offer': _num(maxOffer.text) ?? 9999,
        'scheduled_rides_enabled': scheduled,
        'allow_counteroffers': counteroffers,
      });
    }

    for (final c in [search, visible, before, radius, maxVisible, minOffer, maxOffer]) {
      c.dispose();
    }
  }

  Future<void> _safety(Map<String, dynamic> row) async {
    var chat = row['chat_enabled'] != false;
    var calls = row['calls_enabled'] != false;
    var share = row['share_trip_enabled'] != false;
    var sos = row['sos_enabled'] != false;
    var saved = row['saved_places_enabled'] != false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Funciones de seguridad y contacto'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: sos,
                  onChanged: (v) => setLocal(() => sos = v),
                  title: const Text('Botón SOS'),
                  secondary: const Icon(Icons.sos_rounded),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: share,
                  onChanged: (v) => setLocal(() => share = v),
                  title: const Text('Compartir viaje'),
                  secondary: const Icon(Icons.share_location_outlined),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: chat,
                  onChanged: (v) => setLocal(() => chat = v),
                  title: const Text('Chat pasajero ↔ conductor'),
                  secondary: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: calls,
                  onChanged: (v) => setLocal(() => calls = v),
                  title: const Text('Llamadas'),
                  secondary: const Icon(Icons.call_outlined),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: saved,
                  onChanged: (v) => setLocal(() => saved = v),
                  title: const Text('Lugares guardados'),
                  secondary: const Icon(Icons.bookmark_outline_rounded),
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
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await _save(row, {
        'chat_enabled': chat,
        'calls_enabled': calls,
        'share_trip_enabled': share,
        'sos_enabled': sos,
        'saved_places_enabled': saved,
      });
    }
  }

  Future<void> _ratings(Map<String, dynamic> row) async {
    var enabled = row['ratings_enabled'] != false;
    var comments = row['rating_comment_enabled'] != false;
    var min = ((row['rating_min'] as num?)?.toInt() ?? 1).clamp(1, 5);
    var max = ((row['rating_max'] as num?)?.toInt() ?? 5).clamp(1, 5);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Calificaciones'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _InlineNotice(
                  icon: Icons.star_outline_rounded,
                  text:
                      'Las calificaciones continúan siendo privadas. Aquí solo controlas la política general.',
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: enabled,
                  onChanged: (v) => setLocal(() => enabled = v),
                  title: const Text('Calificaciones habilitadas'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: comments,
                  onChanged: (v) => setLocal(() => comments = v),
                  title: const Text('Permitir comentario'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: min,
                        decoration: const InputDecoration(labelText: 'Mínimo'),
                        items: [1, 2, 3, 4, 5]
                            .map((v) => DropdownMenuItem(value: v, child: Text(v.toString())))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => min = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: max,
                        decoration: const InputDecoration(labelText: 'Máximo'),
                        items: [1, 2, 3, 4, 5]
                            .map((v) => DropdownMenuItem(value: v, child: Text(v.toString())))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => max = v);
                        },
                      ),
                    ),
                  ],
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
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await _save(row, {
        'ratings_enabled': enabled,
        'rating_comment_enabled': comments,
        'rating_min': min,
        'rating_max': max < min ? min : max,
      });
    }
  }

  Future<void> _maintenance(Map<String, dynamic> row) async {
    var enabled = row['maintenance_mode'] == true;
    final message = TextEditingController(
      text: row['maintenance_message']?.toString() ?? '',
    );

    List<Map<String, dynamic>> builds = const [];
    try {
      builds = _list(await supabase.rpc('admin_build_list'));
    } catch (_) {}

    final seen = <String>{};
    final versions = <Map<String, dynamic>>[];
    for (final build in builds) {
      if (build['platform']?.toString() != 'android') continue;
      if (build['status']?.toString() != 'ready') continue;
      final value = build['version_name']?.toString().trim() ?? '';
      if (value.isEmpty || !seen.add(value)) continue;
      versions.add({
        'version': value,
        'build': build['build_number'],
        'created_at': build['created_at'],
      });
    }
    versions.sort((a, b) {
      final aBuild = a['build'] is num
          ? (a['build'] as num).toInt()
          : int.tryParse(a['build']?.toString() ?? '') ?? 0;
      final bBuild = b['build'] is num
          ? (b['build'] as num).toInt()
          : int.tryParse(b['build']?.toString() ?? '') ?? 0;
      return bBuild.compareTo(aBuild);
    });

    final currentMinimum =
        row['minimum_app_version']?.toString().trim() ?? '';
    if (currentMinimum.isNotEmpty &&
        !versions.any((v) => v['version'] == currentMinimum)) {
      versions.add({
        'version': currentMinimum,
        'build': null,
        'created_at': null,
      });
    }

    String selectedVersion = currentMinimum;
    final latestVersion =
        versions.isEmpty ? null : versions.first['version']?.toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Mantenimiento y versión mínima'),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    onChanged: (v) => setLocal(() => enabled = v),
                    title: const Text('Modo mantenimiento'),
                    subtitle: const Text(
                      'Úsalo solo cuando quieras bloquear temporalmente la operación.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: message,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mensaje de mantenimiento',
                      hintText:
                          'Estamos actualizando Express. Vuelve en unos minutos.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedVersion,
                    decoration: const InputDecoration(
                      labelText: 'Versión mínima permitida',
                      helperText:
                          'Las versiones inferiores a la elegida quedan bloqueadas.',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Permitir todas las versiones'),
                      ),
                      ...versions.map((entry) {
                        final value = entry['version']?.toString() ?? '';
                        final build = entry['build'];
                        final latest = value == latestVersion;
                        return DropdownMenuItem(
                          value: value,
                          child: Text(
                            latest
                                ? 'v$value · Bloquear todas las anteriores'
                                : 'v$value' +
                                    (build == null
                                        ? ''
                                        : ' · build ' + build.toString()),
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setLocal(() => selectedVersion = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F8FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD5E3FF)),
                    ),
                    child: Text(
                      selectedVersion.isEmpty
                          ? 'No se forzará una actualización por versión.'
                          : 'Solo podrán operar v' +
                              selectedVersion +
                              ' o una versión superior.',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (versions.isEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Todavía no hay builds Android listos registrados en el panel.',
                      style: TextStyle(
                        color: Color(0xFFB54708),
                        fontSize: 11,
                      ),
                    ),
                  ],
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

    if (ok == true) {
      await _save(row, {
        'maintenance_mode': enabled,
        'maintenance_message': message.text.trim(),
        'minimum_app_version': selectedVersion,
      });
    }
    message.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const _Loading(title: 'Cargando configuración avanzada');
        }
        if (snapshot.hasError) {
          return _Error(error: snapshot.error, onRetry: () => setState(() => revision++));
        }
        final row = snapshot.data ?? const <String, dynamic>{};
        final paymentCount = [
          row['allow_pagorut'],
          row['allow_mercadopago'],
          row['allow_santander'],
          row['allow_mach'],
          row['allow_tenpo'],
        ].where((v) => v == true).length;

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const _Header(
              title: 'Configuración avanzada',
              subtitle:
                  'Controla funciones de la app sin modificar código ni generar un APK por cada cambio.',
            ),
            const SizedBox(height: 16),
            _AdminHero(
              icon: Icons.tune_rounded,
              title: 'Centro de control',
              subtitle:
                  'Cambios operativos centralizados para pasajero, conductor y administración.',
              stats: [
                ('Pagos extra', paymentCount.toString()),
                ('Ofertas', row['allow_counteroffers'] != false ? 'Activas' : 'Off'),
                ('Mantenimiento', row['maintenance_mode'] == true ? 'Activo' : 'Normal'),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cardWidth = width < 720
                    ? width
                    : width < 1120
                        ? (width - 12) / 2
                        : (width - 24) / 3;
                final cards = <Widget>[
                  _AdminModuleCard(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Pagos digitales',
                    subtitle: 'PagoRUT, Mercado Pago, Santander, MACH y Tenpo.',
                    accent: const Color(0xFF6941C6),
                    chips: ['$paymentCount activos', 'Credenciales separadas'],
                    onTap: () => _payments(row),
                  ),
                  _AdminModuleCard(
                    icon: Icons.radar_rounded,
                    title: 'Búsqueda y ofertas',
                    subtitle: 'Tiempos, radio, viajes programados y contraofertas.',
                    accent: _blue,
                    chips: [
                      (row['search_timeout_seconds'] ?? 180).toString() + ' s',
                      (row['max_driver_request_radius_km'] ?? 15).toString() + ' km',
                    ],
                    onTap: () => _offers(row),
                  ),
                  _AdminModuleCard(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Seguridad del viaje',
                    subtitle: 'SOS, compartir viaje, chat, llamadas y lugares guardados.',
                    accent: const Color(0xFF0E9384),
                    chips: [
                      row['sos_enabled'] != false ? 'SOS activo' : 'SOS off',
                      row['share_trip_enabled'] != false ? 'Compartir activo' : 'Compartir off',
                    ],
                    onTap: () => _safety(row),
                  ),
                  _AdminModuleCard(
                    icon: Icons.star_outline_rounded,
                    title: 'Calificaciones',
                    subtitle: 'Política privada de estrellas y comentarios.',
                    accent: const Color(0xFFF79009),
                    chips: [
                      row['ratings_enabled'] != false ? 'Activas' : 'Inactivas',
                      (row['rating_min'] ?? 1).toString() + '–' + (row['rating_max'] ?? 5).toString() + ' ★',
                    ],
                    onTap: () => _ratings(row),
                  ),
                  _AdminModuleCard(
                    icon: Icons.construction_rounded,
                    title: 'Mantenimiento',
                    subtitle: 'Bloqueo temporal y versión mínima permitida.',
                    accent: row['maintenance_mode'] == true
                        ? const Color(0xFFD92D20)
                        : const Color(0xFF667085),
                    chips: [
                      row['maintenance_mode'] == true ? 'Mantenimiento activo' : 'Operación normal',
                      row['minimum_app_version']?.toString().isNotEmpty == true
                          ? 'Min v' + row['minimum_app_version'].toString()
                          : 'Sin versión mínima',
                    ],
                    onTap: () => _maintenance(row),
                  ),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards.map((card) => SizedBox(width: cardWidth, child: card)).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InlineNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _blue, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _muted, fontSize: 10, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}


class AdminBuildsPage extends StatefulWidget {
  const AdminBuildsPage({super.key});

  @override
  State<AdminBuildsPage> createState() => _AdminBuildsPageState();
}

class _AdminBuildsPageState extends State<AdminBuildsPage> {
  int revision = 0;
  Timer? poller;

  @override
  void initState() {
    super.initState();
    poller = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted) setState(() => revision++);
    });
  }

  @override
  void dispose() {
    poller?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final value = await supabase.rpc('admin_build_list');
    return _list(value);
  }

  Future<void> _openUrl(String? value) async {
    if (value == null || value.trim().isEmpty) return;
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _create() async {
    List<Map<String, dynamic>> existing = const [];
    try {
      existing = await _load();
    } catch (_) {}

    final android = existing
        .where((row) => row['platform']?.toString() == 'android')
        .toList();
    final latestBuild = android.fold<int>(
      56,
      (value, row) {
        final raw = row['build_number'];
        final n = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
        return n != null && n > value ? n : value;
      },
    );
    final latestVersion = android.isNotEmpty
        ? android.first['version_name']?.toString() ?? '1.5.19'
        : '1.5.19';

    final version = TextEditingController(text: latestVersion);
    final build = TextEditingController(text: (latestBuild + 1).toString());
    final changelog = TextEditingController();

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Compilar Express para Android'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BuildCloudNotice(),
              const SizedBox(height: 14),
              TextField(
                controller: version,
                decoration: const InputDecoration(
                  labelText: 'Versión',
                  hintText: 'Ej. 1.6.0',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: build,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Build number',
                  hintText: 'Debe ser mayor al anterior',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: changelog,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notas de actualización',
                  hintText: 'Describe los cambios de esta versión',
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.android_rounded, size: 18, color: Color(0xFF14804A)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se generarán automáticamente APK + AAB en GitHub Actions.',
                      style: TextStyle(fontSize: 11, color: _muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Enviar a compilar'),
          ),
        ],
      ),
    );

    if (save == true) {
      final buildNumber = int.tryParse(build.text.trim());
      if (version.text.trim().isEmpty || buildNumber == null || buildNumber < 1) {
        if (mounted) {
          _snack(context, 'Versión o build number no válido.');
        }
      } else {
        try {
          await supabase.rpc(
            'admin_create_build_job',
            params: {
              'p_platform': 'android',
              'p_artifact_type': 'apk+aab',
              'p_version_name': version.text.trim(),
              'p_build_number': buildNumber,
              'p_changelog': changelog.text.trim(),
              'p_commit_sha': null,
            },
          );
          if (mounted) {
            setState(() => revision++);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Build enviado. El compilador en la nube lo tomará automáticamente.',
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) _snack(context, e);
        }
      }
    }

    version.dispose();
    build.dispose();
    changelog.dispose();
  }

  Future<void> _publish(Map<String, dynamic> row) async {
    bool mandatory = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Publicar actualización'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Express v' +
                      (row['version_name'] ?? '—').toString() +
                      ' · build ' +
                      (row['build_number'] ?? '—').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: mandatory,
                  onChanged: (value) => setLocal(() => mandatory = value),
                  title: const Text('Actualización obligatoria'),
                  subtitle: const Text(
                    'Si la activas, más adelante la app podrá impedir continuar con una versión antigua.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Publicar versión'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase.rpc(
        'admin_publish_build',
        params: {
          'p_build_id': row['id'].toString(),
          'p_mandatory': mandatory,
        },
      );
      if (!mounted) return;
      setState(() => revision++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Actualización publicada para Express.'),
        ),
      );
    } catch (e) {
      if (mounted) _snack(context, e);
    }
  }

  Widget _buildRow(Map<String, dynamic> row) {
    final status = (row['status'] ?? 'queued').toString();
    final apkUrl = row['apk_url']?.toString();
    final aabUrl = row['aab_url']?.toString();
    final runUrl = row['run_url']?.toString();
    final signing = row['signing_mode']?.toString() ?? 'test';
    final error = row['error_message']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.android_rounded,
                  color: Color(0xFF14804A),
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APK + AAB · v' +
                          (row['version_name'] ?? '—').toString() +
                          ' (' +
                          (row['build_number'] ?? '—').toString() +
                          ')',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(row['created_at']),
                      style: const TextStyle(fontSize: 10, color: _muted),
                    ),
                    if (status == 'ready') ...[
                      const SizedBox(height: 4),
                      Text(
                        signing == 'production'
                            ? 'Firmado con certificado de producción'
                            : 'Firma de prueba · configura el keystore antes de publicar en Play Store',
                        style: TextStyle(
                          fontSize: 10,
                          color: signing == 'production'
                              ? const Color(0xFF14804A)
                              : const Color(0xFFA15C07),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (error != null && error.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        error,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFD92D20),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _BuildStatus(status: status),
            ],
          ),
          if (status == 'ready' || runUrl?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (apkUrl?.isNotEmpty == true)
                  FilledButton.icon(
                    onPressed: () => _openUrl(apkUrl),
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('Descargar APK'),
                  ),
                if (aabUrl?.isNotEmpty == true)
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(aabUrl),
                    icon: const Icon(Icons.inventory_2_outlined, size: 17),
                    label: const Text('Descargar AAB'),
                  ),
                if (runUrl?.isNotEmpty == true)
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(runUrl),
                    icon: const Icon(Icons.terminal_rounded, size: 17),
                    label: const Text('Ver compilación'),
                  ),
                if (status == 'ready' && signing == 'production')
                  FilledButton.icon(
                    onPressed: () => _publish(row),
                    icon: const Icon(Icons.publish_rounded, size: 17),
                    label: const Text('Publicar actualización'),
                  ),
                if (status == 'ready' && signing != 'production')
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.key_off_outlined, size: 17),
                    label: const Text('Falta firma de producción'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(revision),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Loading(title: 'Cargando builds');
        }
        if (snapshot.hasError) {
          return _Error(
            error: snapshot.error,
            onRetry: () => setState(() => revision++),
          );
        }

        final rows = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _Header(
              title: 'App Builder',
              subtitle:
                  'Compila Express Android en la nube. No necesitas Visual Studio Code ni tener Flutter instalado en tu computador.',
              action: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.android_rounded),
                label: const Text('Compilar Android'),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cardWidth = width < 680
                    ? width
                    : width < 1040
                        ? (width - 14) / 2
                        : (width - 28) / 3;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _BuildProductCard(
                      width: cardWidth,
                      icon: Icons.android_rounded,
                      title: 'Android',
                      badge: 'Automático',
                      description:
                          'Genera APK instalable + AAB para Google Play usando GitHub Actions.',
                      primaryLabel: 'Compilar APK + AAB',
                      secondaryLabel: 'Publicación desde historial',
                      accent: const Color(0xFF14804A),
                      soft: const Color(0xFFE8F8EF),
                      onPrimary: _create,
                    ),
                    _BuildProductCard(
                      width: cardWidth,
                      icon: Icons.cloud_done_outlined,
                      title: 'Compilación Cloud',
                      badge: 'Activa',
                      description:
                          'GitHub levanta un runner, instala Flutter, firma, compila y crea el Release automáticamente.',
                      primaryLabel: 'Sin VS Code',
                      secondaryLabel: 'Cola automática',
                      accent: _blue,
                      soft: const Color(0xFFEAF2FF),
                    ),
                    _BuildProductCard(
                      width: cardWidth,
                      icon: Icons.storefront_outlined,
                      title: 'Google Play',
                      badge: 'Siguiente etapa',
                      description:
                          'El AAB queda preparado. La publicación automática en Play Store se habilitará con sus credenciales.',
                      primaryLabel: 'AAB listo para Play',
                      secondaryLabel: 'Pendiente credenciales',
                      accent: const Color(0xFF6941C6),
                      soft: const Color(0xFFF1EBFF),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCE7B2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: Color(0xFFA15C07),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'El código se compila en GitHub. Los APK/AAB terminados se publican en GitHub Releases. La firma de producción usa un keystore privado persistente y contraseñas cifradas en Supabase Vault.',
                      style: TextStyle(
                        color: Color(0xFF7A4A0B),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Historial de Builds',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _dark,
              ),
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const _Empty(text: 'Todavía no hay builds registrados.')
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE7ECF3)),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      _buildRow(rows[i]),
                      if (i != rows.length - 1)
                        const Divider(height: 1, indent: 60),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BuildCloudNotice extends StatelessWidget {
  const _BuildCloudNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_queue_rounded, color: _blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Adminexpress crea el trabajo; GitHub Actions compila Express, lo firma y publica APK/AAB en GitHub Releases.',
              style: TextStyle(fontSize: 11, color: _dark, height: 1.35),
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
  final Widget? action;

  const _Header({
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -.35,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFFD7E7FA),
            height: 1.4,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A56), Color(0xFF174B91), Color(0xFF0D6B8D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B174B91),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (action == null) {
            return Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withOpacity(.16)),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(child: copy),
              ],
            );
          }

          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 14),
                action!,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white.withOpacity(.16)),
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(child: copy),
              const SizedBox(width: 16),
              action!,
            ],
          );
        },
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String title;
  final String value;

  const _Kpi(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE6F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE1ECFF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: _blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 23,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: _dark,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
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

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _NumberField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SettingsCard({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_settingsIcon(title), color: _blue, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEF1F5)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

IconData _settingsIcon(String title) {
  final value = title.toLowerCase();
  if (value.contains('pago')) return Icons.account_balance_wallet_outlined;
  if (value.contains('servicio') || value.contains('módulo')) return Icons.apps_rounded;
  if (value.contains('operación') || value.contains('dispatch')) return Icons.alt_route_rounded;
  if (value.contains('tarifa') || value.contains('alcance')) return Icons.payments_outlined;
  if (value.contains('soporte') || value.contains('localización')) return Icons.support_agent_rounded;
  return Icons.tune_rounded;
}

class _ReadOnlyRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _dark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildProductCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String badge;
  final String description;
  final String primaryLabel;
  final String secondaryLabel;
  final Color accent;
  final Color soft;
  final VoidCallback? onPrimary;

  const _BuildProductCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.badge,
    required this.description,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.accent,
    required this.soft,
    this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 238),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 23),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _dark,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              height: 1.35,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              child: Text(primaryLabel),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: null,
              child: Text(secondaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildStatus extends StatelessWidget {
  final String status;
  const _BuildStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    final ok = status == 'success';
    final failed = status == 'failed';
    final bg = ok
        ? const Color(0xFFE8F8EF)
        : failed
            ? const Color(0xFFFFE8E8)
            : const Color(0xFFFFF3E7);
    final fg = ok
        ? const Color(0xFF14804A)
        : failed
            ? const Color(0xFFD92D20)
            : const Color(0xFFC76B16);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DispatchItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onAssign;

  const _DispatchItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7ECF3)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final info = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: _blue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: onAssign,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                  label: const Text('Asignar conductor'),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onAssign,
                child: const Text('Asignar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  final String text;
  final bool positive;

  const _MiniStatus({
    required this.text,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        positive ? const Color(0xFFE8F8EF) : const Color(0xFFF2F4F7);
    final fg =
        positive ? const Color(0xFF14804A) : const Color(0xFF667085);
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
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(text, style: const TextStyle(color: _muted)),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  final String title;
  const _Loading({required this.title});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        const LinearProgressIndicator(),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _Error({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 46),
              const SizedBox(height: 10),
              Text(error.toString()),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
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

num? _num(String value) {
  return num.tryParse(value.trim().replaceAll(',', '.'));
}

void _snack(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: ' + error.toString())),
  );
}

String _fareTitle(Map<String, dynamic> row) {
  final scope = row['scope_type']?.toString();
  if (scope == 'global') return 'Global';
  if (scope == 'service') {
    return 'Servicio · ' + (row['service_key'] ?? '—').toString();
  }
  return (row['zone_name'] ?? 'Zona').toString() +
      ' · ' +
      (row['service_key'] ?? '—').toString();
}

String _formatDate(Object? raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (date == null) return '—';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return day +
      '/' +
      month +
      '/' +
      date.year.toString() +
      ' · ' +
      hour +
      ':' +
      minute;
}

String _dateOnly(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return day + '/' + month + '/' + value.year.toString();
}
