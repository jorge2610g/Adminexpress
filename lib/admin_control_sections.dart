import 'dart:async';

import 'package:flutter/material.dart';

import 'core/admin_design_tokens.dart';
import 'core/admin_widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'core/supabase_client.dart';
import 'admin_environment_store.dart';
import 'admin_driver_document_requirements.dart';
import 'admin_country_coverage.dart';
import 'admin_admob_settings.dart';
import 'admin_distance_fares.dart';
import 'admin_zone_coverage_editor.dart';
import 'core/admin_zone_coverage_label.dart';

const Color _blue = AdminColors.blue;
const Color _dark = AdminColors.ink;
const Color _muted = AdminColors.muted;

class AdminDispatchPage extends StatefulWidget {
  final String channel;
  final String? countryCode;
  final String? zoneId;

  const AdminDispatchPage({
    super.key,
    this.channel = 'preview',
    this.countryCode,
    this.zoneId,
  });

  @override
  State<AdminDispatchPage> createState() => _AdminDispatchPageState();
}

class _AdminDispatchPageState extends State<AdminDispatchPage> {
  int revision = 0;

  String _countryCode(Map<String, dynamic> row) {
    final direct = row['country_code']?.toString().trim().toUpperCase();
    if (direct != null && direct.isNotEmpty) return direct;
    final country = row['country']?.toString().trim().toLowerCase() ?? '';
    if (country == 'chile') return 'CL';
    if (country == 'bolivia') return 'BO';
    return country.toUpperCase();
  }

  bool _vehicleCompatible(
    Map<String, dynamic> ride,
    Map<String, dynamic> driver,
  ) {
    final category = ride['category']?.toString() ?? '';
    final raw = driver['vehicle_types'];
    final vehicleTypes = raw is List
        ? raw.map((value) => value.toString()).toSet()
        : <String>{};
    if (vehicleTypes.isEmpty) return false;
    switch (category) {
      case 'motorcycle':
        return vehicleTypes.contains('motorcycle');
      case 'xl':
        return vehicleTypes.contains('xl');
      case 'economy':
      case 'comfort':
        return vehicleTypes.contains('car') || vehicleTypes.contains('xl');
      default:
        return true;
    }
  }

  List<Map<String, dynamic>> _driversForService(
    Map<String, dynamic> service,
    List<Map<String, dynamic>> drivers, {
    required bool ride,
  }) {
    final zoneId = service['zone_id']?.toString();
    return drivers.where((driver) {
      final driverZone = driver['zone_id']?.toString();
      if (zoneId != null && zoneId.isNotEmpty && driverZone != zoneId) {
        return false;
      }
      return !ride || _vehicleCompatible(service, driver);
    }).toList();
  }

  Future<({
    List<Map<String, dynamic>> rides,
    List<Map<String, dynamic>> deliveries,
    List<Map<String, dynamic>> drivers,
  })> _load() async {
    final values = await Future.wait([
      supabase.rpc(
        'admin_open_service_requests_v2',
        params: {'p_channel': widget.channel},
      ),
      supabase.rpc(
        'admin_available_drivers_v2',
        params: {'p_channel': widget.channel},
      ),
      supabase.rpc(
        'admin_zone_list_for_country',
        params: {'p_country_code': widget.countryCode},
      ),
    ]);
    final requests = _map(values[0]);
    final zones = _list(values[2]);
    final scopedZoneIds = <String>{};

    if (widget.zoneId != null && widget.zoneId!.isNotEmpty) {
      scopedZoneIds.add(widget.zoneId!);
    } else if (widget.countryCode != null &&
        widget.countryCode!.isNotEmpty) {
      scopedZoneIds.addAll(
        zones
            .where((row) => _countryCode(row) == widget.countryCode)
            .map((row) => row['id']?.toString())
            .whereType<String>()
            .where((value) => value.isNotEmpty),
      );
    }

    bool inScope(Map<String, dynamic> row) {
      if (widget.zoneId == null && widget.countryCode == null) return true;
      final zoneId = row['zone_id']?.toString();
      return zoneId != null && scopedZoneIds.contains(zoneId);
    }

    return (
      rides: _list(requests['rides']).where(inScope).toList(),
      deliveries: _list(requests['deliveries']).where(inScope).toList(),
      drivers: _list(values[1]).where(inScope).toList(),
    );
  }

  Future<void> _assignRide(
    Map<String, dynamic> ride,
    List<Map<String, dynamic>> drivers,
  ) async {
    final compatibleDrivers = _driversForService(
      ride,
      drivers,
      ride: true,
    );
    if (compatibleDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay conductores compatibles con la zona y categoría del viaje.',
          ),
        ),
      );
      return;
    }

    String? driverId = compatibleDrivers.first['id']?.toString();
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
                  items: compatibleDrivers
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
          'admin_assign_ride_v2',
          params: {
            'p_ride_request_id': ride['id'],
            'p_driver_id': driverId,
            'p_final_fare': _num(fare.text),
            'p_channel': widget.channel,
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
    final compatibleDrivers = _driversForService(
      delivery,
      drivers,
      ride: false,
    );
    if (compatibleDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay repartidores disponibles en esta zona.'),
        ),
      );
      return;
    }

    String? driverId = compatibleDrivers.first['id']?.toString();

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
                  items: compatibleDrivers
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
          'admin_assign_delivery_v2',
          params: {
            'p_delivery_id': delivery['id'],
            'p_driver_id': driverId,
            'p_channel': widget.channel,
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
            _Header(
              title: widget.channel == 'preview'
                  ? 'Despacho manual · Prueba'
                  : 'Despacho manual · Producción',
              subtitle: widget.channel == 'preview'
                  ? 'Solo solicitudes y conductores del entorno Preview / QA.'
                  : 'Solo servicios reales de clientes en Producción.',
            ),
            const SizedBox(height: 14),
            Card(
              color: AdminColors.blueSoft,
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

  String _actionLabel(Object? raw, [Object? entityType]) {
    final action = raw?.toString();
    final entity = entityType?.toString();

    if (action == 'upsert' && entity == 'service_zone_polygon') {
      return 'Polígono de cobertura actualizado';
    }
    if (action == 'resolve' && entity == 'emergency') {
      return 'Emergencia resuelta';
    }
    if (action == 'create' && entity == 'build_job') {
      return 'Compilación solicitada';
    }
    if (action == 'update' && entity == 'app_settings') {
      return 'Configuración actualizada';
    }

    return switch (action) {
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
        title: Text(_actionLabel(row['action'], row['entity_type'])),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReadOnlyRow(
                  label: 'Módulo',
                  value: _entityLabel(row['entity_type']),
                ),
                _ReadOnlyRow(
                  label: 'Administrador',
                  value: (row['admin_name'] ?? 'Administrador').toString(),
                ),
                _ReadOnlyRow(
                  label: 'Fecha',
                  value: _formatDate(row['created_at']),
                ),
                _ReadOnlyRow(
                  label: 'ID',
                  value: (row['entity_id'] ?? '—').toString(),
                ),
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
                      _actionLabel(row['action'], row['entity_type']),
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
  final String channel;
  final String? countryCode;
  final String? zoneId;

  const AdminZonesPage({
    super.key,
    this.channel = 'production',
    this.countryCode,
    this.zoneId,
  });

  @override
  State<AdminZonesPage> createState() => _AdminZonesPageState();
}

class _AdminZonesPageState extends State<AdminZonesPage> {
  int revision = 0;

  AdminEnvironmentStore get _environment =>
      AdminEnvironmentStore(widget.channel);

  Future<List<Map<String, dynamic>>> _load() async {
    final selectedZoneId = widget.zoneId;
    if (selectedZoneId == null || selectedZoneId.isEmpty) return const [];

    if (_environment.isPreview) {
      final zones = (await _environment.previewList('service_zones'))
          .where((zone) => zone['id']?.toString() == selectedZoneId)
          .toList();
      final methods = await _environment.previewList('zone_payment_methods');
      return zones.map((zone) {
        final id = zone['id']?.toString();
        return <String, dynamic>{
          ...zone,
          'payment_methods': methods
              .where((method) => method['zone_id']?.toString() == id)
              .toList(),
        };
      }).toList();
    }

    final countryCode = widget.countryCode;
    if (countryCode == null || countryCode.isEmpty) return const [];
    final value = await supabase.rpc(
      'admin_zone_list_for_country',
      params: {'p_country_code': countryCode},
    );
    return _list(value)
        .where((row) => row['id']?.toString() == selectedZoneId)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadCountries() async {
    final countryCode = widget.countryCode;
    if (countryCode == null || countryCode.isEmpty) return const [];
    if (_environment.isPreview) {
      return (await _environment.previewList('service_countries'))
          .where(
            (row) =>
                row['country_code']?.toString().trim().toUpperCase() ==
                countryCode.trim().toUpperCase(),
          )
          .toList();
    }
    // This form needs the full country name and its real currency.
    // admin_country_list_scoped returns only country_code/country and led
    // to misleading labels like "País · BO" and missing currency defaults.
    // Still filter to the currently authorized country scope.
    return _list(await supabase.rpc('admin_country_list'))
        .where(
          (row) =>
              row['country_code']?.toString().trim().toUpperCase() ==
              countryCode.trim().toUpperCase(),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadPartners(String zoneId) async {
    if (_environment.isPreview) {
      return (await _environment.previewList('partners'))
          .where((row) => row['zone_id']?.toString() == zoneId)
          .toList();
    }
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
        if (_environment.isPreview) {
          final key = row == null
              ? _environment.createRecordKey('partner')
              : AdminEnvironmentStore.recordKey(row);
          await _environment.previewUpsert(
            'partners',
            key,
            <String, dynamic>{
              ...?row,
              'id': row?['id'] ?? key,
              'zone_id': zone['id'],
              'partner_code': code.text.trim().isEmpty ? key : code.text.trim(),
              'name': name.text.trim(),
              'organization_type': type,
              'status': status,
              'commission_percent':
                  double.tryParse(commission.text.trim()) ?? 0,
              'contact_name': contactName.text.trim(),
              'contact_phone': contactPhone.text.trim(),
              'contact_email': contactEmail.text.trim(),
              'notes': notes.text.trim(),
            },
          );
        } else {
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
        }
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

  Future<List<Map<String, dynamic>>> _loadPartnerMembers(
    String partnerId,
  ) async {
    if (_environment.isPreview) {
      return (await _environment.previewList('partner_members'))
          .where((row) => row['partner_id']?.toString() == partnerId)
          .toList();
    }
    final value = await supabase.rpc(
      'admin_partner_member_list',
      params: {'p_partner_id': partnerId},
    );
    return _list(value);
  }

  Future<void> _managePartnerAccess(
    Map<String, dynamic> partner,
  ) async {
    var localRevision = 0;

    Future<void> addAccess(
      BuildContext dialogContext,
      void Function(VoidCallback) setLocal,
    ) async {
      final email = TextEditingController();
      var role = 'manager';
      final save = await showDialog<bool>(
        context: dialogContext,
        builder: (accessContext) => StatefulBuilder(
          builder: (context, setAccess) => AlertDialog(
            title: const Text('Asignar acceso al panel'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'La persona debe tener una cuenta Express registrada. '
                    'Usará el mismo correo y contraseña, pero verá solo el '
                    'panel de esta organización.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo de la cuenta Express',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: const [
                      DropdownMenuItem(
                        value: 'owner',
                        child: Text('Propietario / presidente'),
                      ),
                      DropdownMenuItem(
                        value: 'manager',
                        child: Text('Administrador'),
                      ),
                      DropdownMenuItem(
                        value: 'operator',
                        child: Text('Operador'),
                      ),
                      DropdownMenuItem(
                        value: 'treasurer',
                        child: Text('Tesorería'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setAccess(() => role = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(accessContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(accessContext, true),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Asignar'),
              ),
            ],
          ),
        ),
      );

      if (save == true && email.text.trim().isNotEmpty) {
        try {
          if (_environment.isPreview) {
            final key = _environment.createRecordKey('partner-member');
            await _environment.previewUpsert(
              'partner_members',
              key,
              <String, dynamic>{
                'id': key,
                'partner_id': partner['id'],
                'email': email.text.trim(),
                'full_name': email.text.trim(),
                'role': role,
                'active': true,
              },
            );
          } else {
            await supabase.rpc(
              'admin_assign_partner_member_by_email',
              params: {
                'p_partner_id': partner['id'],
                'p_email': email.text.trim(),
                'p_role': role,
                'p_active': true,
              },
            );
          }
          setLocal(() => localRevision++);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Acceso asignado. Ya puede iniciar sesión en Adminexpress.',
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) _snack(context, e);
        }
      }
      email.dispose();
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.admin_panel_settings_outlined, color: _blue),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Accesos · ' + (partner['name'] ?? 'Organización').toString(),
                ),
              ),
              FilledButton.icon(
                onPressed: () => addAccess(dialogContext, setLocal),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Asignar acceso'),
              ),
            ],
          ),
          content: SizedBox(
            width: 760,
            height: 430,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(localRevision),
              future: _loadPartnerMembers(partner['id'].toString()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const _Loading(title: 'Cargando accesos');
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
                        'Esta organización todavía no tiene usuarios con acceso al panel.',
                  );
                }

                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final active = row['active'] == true;
                    final roleLabel = switch (row['role']?.toString()) {
                      'owner' => 'Propietario / presidente',
                      'manager' => 'Administrador',
                      'operator' => 'Operador',
                      'treasurer' => 'Tesorería',
                      _ => row['role']?.toString() ?? 'Usuario',
                    };
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AdminColors.blueSoft,
                          child: Icon(
                            active
                                ? Icons.verified_user_outlined
                                : Icons.person_off_outlined,
                            color: _blue,
                          ),
                        ),
                        title: Text(
                          (row['full_name']?.toString().trim().isNotEmpty ==
                                      true
                                  ? row['full_name']
                                  : row['email'])
                              .toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          (row['email'] ?? '—').toString() +
                              ' · ' +
                              roleLabel,
                        ),
                        trailing: Switch.adaptive(
                          value: active,
                          onChanged: (value) async {
                            try {
                              if (_environment.isPreview) {
                                await _environment.previewUpsert(
                                  'partner_members',
                                  AdminEnvironmentStore.recordKey(row),
                                  <String, dynamic>{
                                    ...row,
                                    'active': value,
                                  },
                                );
                              } else {
                                await supabase.rpc(
                                  'admin_set_partner_member_active',
                                  params: {
                                    'p_partner_id': partner['id'],
                                    'p_user_id': row['user_id'],
                                    'p_active': value,
                                  },
                                );
                              }
                              setLocal(() => localRevision++);
                            } catch (e) {
                              if (mounted) _snack(context, e);
                            }
                          },
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

  Future<void> _showPartnerDashboard(Map<String, dynamic> partner) async {
    var localRevision = 0;
    final now = DateTime.now();
    var range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day),
    );

    Future<Map<String, dynamic>> load() async {
      final endExclusive = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
      ).add(const Duration(days: 1));
      if (_environment.isPreview) {
        final partnerId = partner['id']?.toString();
        final payments = (await _environment.previewList('partner_payments'))
            .where((row) => row['partner_id']?.toString() == partnerId)
            .toList();
        final settlements =
            (await _environment.previewList('partner_settlements'))
                .where((row) => row['partner_id']?.toString() == partnerId)
                .toList();
        num sum(String key, Iterable<Map<String, dynamic>> rows) =>
            rows.fold<num>(
              0,
              (total, row) => total + ((row[key] as num?) ?? 0),
            );
        final paid = settlements.where((row) => row['status'] == 'paid');
        final pending = settlements.where((row) => row['status'] != 'paid');
        return <String, dynamic>{
          'partner': partner,
          'metrics': <String, dynamic>{
            'drivers_total': 0,
            'drivers_online': 0,
            'payments_count': payments.length,
            'gross_amount': sum('amount', payments),
            'commission_generated':
                sum('partner_commission_amount', payments),
            'commission_pending': sum('commission_amount', pending),
            'commission_paid': sum('commission_amount', paid),
          },
          'payments': payments,
          'settlements': settlements,
        };
      }
      final value = await supabase.rpc(
        'admin_partner_dashboard',
        params: {
          'p_partner_id': partner['id'],
          'p_from': range.start.toUtc().toIso8601String(),
          'p_to': endExclusive.toUtc().toIso8601String(),
        },
      );
      return _map(value);
    }

    Future<void> createSettlement(StateSetter setLocal) async {
      try {
        final endExclusive = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        );
        if (_environment.isPreview) {
          final key = _environment.createRecordKey('settlement');
          await _environment.previewUpsert(
            'partner_settlements',
            key,
            <String, dynamic>{
              'id': key,
              'partner_id': partner['id'],
              'period_start': range.start.toUtc().toIso8601String(),
              'period_end': endExclusive.toUtc().toIso8601String(),
              'gross_amount': 0,
              'commission_amount': 0,
              'status': 'pending',
              'notes': 'Liquidación creada desde Adminexpress Preview',
              'created_at': DateTime.now().toUtc().toIso8601String(),
            },
          );
        } else {
          await supabase.rpc(
            'admin_create_partner_settlement',
            params: {
              'p_partner_id': partner['id'],
              'p_period_start': range.start.toUtc().toIso8601String(),
              'p_period_end': endExclusive.toUtc().toIso8601String(),
              'p_notes': 'Liquidación creada desde Adminexpress',
            },
          );
        }
        setLocal(() => localRevision++);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Liquidación creada.')),
          );
        }
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }

    Future<void> markPaid(
      Map<String, dynamic> settlement,
      StateSetter setLocal,
    ) async {
      final reference = TextEditingController();
      final notes = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Marcar liquidación como pagada'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'Referencia / comprobante',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nota opcional',
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
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar pago'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        reference.dispose();
        notes.dispose();
        return;
      }
      try {
        if (_environment.isPreview) {
          await _environment.previewUpsert(
            'partner_settlements',
            AdminEnvironmentStore.recordKey(settlement),
            <String, dynamic>{
              ...settlement,
              'status': 'paid',
              'reference': reference.text.trim(),
              'notes': notes.text.trim(),
              'paid_at': DateTime.now().toUtc().toIso8601String(),
            },
          );
        } else {
          await supabase.rpc(
            'admin_mark_partner_settlement_paid',
            params: {
              'p_settlement_id': settlement['id'],
              'p_reference': reference.text.trim(),
              'p_notes': notes.text.trim(),
            },
          );
        }
        setLocal(() => localRevision++);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Liquidación marcada como pagada.')),
          );
        }
      } catch (e) {
        if (mounted) _snack(context, e);
      } finally {
        reference.dispose();
        notes.dispose();
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.dashboard_customize_outlined, color: _blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dashboard · ' + (partner['name'] ?? 'Aliado').toString(),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 3),
                    lastDate: DateTime(now.year + 1, 12, 31),
                    initialDateRange: range,
                  );
                  if (picked != null) {
                    setLocal(() {
                      range = picked;
                      localRevision++;
                    });
                  }
                },
                icon: const Icon(Icons.date_range_outlined, size: 17),
                label: const Text('Período'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => createSettlement(setLocal),
                icon: const Icon(Icons.receipt_long_outlined, size: 17),
                label: const Text('Crear liquidación'),
              ),
            ],
          ),
          content: SizedBox(
            width: 1020,
            height: 650,
            child: FutureBuilder<Map<String, dynamic>>(
              key: ValueKey(localRevision),
              future: load(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const _Loading(title: 'Cargando dashboard del aliado');
                }
                if (snapshot.hasError) {
                  return _Error(
                    error: snapshot.error,
                    onRetry: () => setLocal(() => localRevision++),
                  );
                }
                final data = snapshot.data ?? const <String, dynamic>{};
                final info = _map(data['partner']);
                final metrics = _map(data['metrics']);
                final payments = _list(data['payments']);
                final settlements = _list(data['settlements']);
                final currency =
                    (info['currency_code'] ?? '').toString();

                Widget metric(String label, Object? value) {
                  return Container(
                    width: 180,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AdminColors.surfaceSoft,
                      border: Border.all(color: const Color(0xFFE7ECF3)),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value?.toString() ?? '0',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          label,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        metric('Conductores', metrics['drivers_total']),
                        metric('Conductores online', metrics['drivers_online']),
                        metric('Pagos aprobados', metrics['payments_count']),
                        metric(
                          'Facturación ' + currency,
                          metrics['gross_amount'],
                        ),
                        metric(
                          'Comisión generada ' + currency,
                          metrics['commission_generated'],
                        ),
                        metric(
                          'Comisión pendiente ' + currency,
                          metrics['commission_pending'],
                        ),
                        metric(
                          'Comisión liquidada ' + currency,
                          metrics['commission_paid'],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Liquidaciones',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (settlements.isEmpty)
                      const _Empty(text: 'Todavía no hay liquidaciones.')
                    else
                      for (final settlement in settlements)
                        Card(
                          elevation: 0,
                          child: ListTile(
                            leading: const Icon(
                              Icons.account_balance_outlined,
                              color: _blue,
                            ),
                            title: Text(
                              currency +
                                  ' ' +
                                  (settlement['commission_amount'] ?? 0)
                                      .toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              'Bruto: ' +
                                  currency +
                                  ' ' +
                                  (settlement['gross_amount'] ?? 0).toString() +
                                  ' · ' +
                                  _formatDate(settlement['created_at']),
                            ),
                            trailing: settlement['status'] == 'paid'
                                ? _MiniStatus(
                                    text: 'Pagada',
                                    positive: true,
                                  )
                                : FilledButton(
                                    onPressed: () =>
                                        markPaid(settlement, setLocal),
                                    child: const Text('Marcar pagada'),
                                  ),
                          ),
                        ),
                    const SizedBox(height: 18),
                    const Text(
                      'Pagos de conductores',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (payments.isEmpty)
                      const _Empty(text: 'No hay pagos en este período.')
                    else
                      for (final payment in payments.take(30))
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.receipt_long_rounded,
                            color: _blue,
                          ),
                          title: Text(
                            (payment['driver_name'] ?? 'Conductor').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            (payment['provider'] ?? '—').toString() +
                                ' · ' +
                                _formatDate(
                                  payment['paid_at'] ?? payment['created_at'],
                                ),
                          ),
                          trailing: Text(
                            (payment['currency_code'] ?? currency).toString() +
                                ' ' +
                                (payment['amount'] ?? 0).toString() +
                                '\nComisión ' +
                                (payment['partner_commission_amount'] ?? 0)
                                    .toString(),
                            textAlign: TextAlign.right,
                          ),
                        ),
                  ],
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
                              backgroundColor: AdminColors.blueSoft,
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
                              tooltip: 'Dashboard financiero',
                              onPressed: () => _showPartnerDashboard(row),
                              icon: const Icon(
                                Icons.dashboard_customize_outlined,
                                size: 19,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Usuarios del panel',
                              onPressed: () => _managePartnerAccess(row),
                              icon: const Icon(
                                Icons.admin_panel_settings_outlined,
                                size: 19,
                              ),
                            ),
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
    var countries = await _loadCountries();
    if (!mounted) return;
    if (countries.isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminCountryCoveragePage(channel: widget.channel),
        ),
      );
      if (!mounted) return;
      countries = await _loadCountries();
      if (countries.isEmpty) {
        _snack(context, 'Primero crea un país antes de crear una ciudad.');
        return;
      }
    }

    // Read the actual persisted mode and polygon before editing other fields.
    var coverageMode = row?['coverage_mode'] == 'polygon' ? 'polygon' : 'radius';
    var polygonPoints = <LatLng>[];
    if (_environment.isPreview && row?['polygon'] is List) {
      final rawPoints = row!['polygon'] as List;
      polygonPoints = rawPoints.whereType<Map>().map((point) {
        final y = double.tryParse(point['lat']?.toString() ?? '');
        final x = double.tryParse(point['lng']?.toString() ?? '');
        return y == null || x == null ? null : LatLng(y, x);
      }).whereType<LatLng>().toList();
    }
    if (row?['id'] != null && !_environment.isPreview) {
      try {
        final raw = await supabase.rpc('admin_zone_coverage_get', params: {
          'p_zone_id': row!['id'],
          'p_channel': widget.channel,
        });
        if (!mounted) return;
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          coverageMode = data['coverage_mode'] == 'polygon' ? 'polygon' : 'radius';
          final rawPoints = data['polygon'];
          if (rawPoints is List) {
            polygonPoints = rawPoints.whereType<Map>().map((point) {
              final y = double.tryParse(point['lat']?.toString() ?? '');
              final x = double.tryParse(point['lng']?.toString() ?? '');
              return y == null || x == null ? null : LatLng(y, x);
            }).whereType<LatLng>().toList();
          }
        }
      } catch (error) {
        if (mounted) _snack(context, 'No se pudo cargar la cobertura: $error');
        return;
      }
    }

    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final city =
        TextEditingController(text: row?['city']?.toString() ?? '');
    final regionDepartment = TextEditingController(
      text: row?['region_department']?.toString() ?? '',
    );
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
    final landingTitle = TextEditingController(
      text: row?['passenger_landing_title']?.toString() ??
          '¿Qué necesitas hoy?',
    );
    final landingSubtitle = TextEditingController(
      text: row?['passenger_landing_subtitle']?.toString() ??
          'Elige un servicio de Express',
    );
    final rawLandingOrder = row?['passenger_landing_order'];
    final landingOrder = rawLandingOrder is List
        ? rawLandingOrder.map((item) => item.toString()).toList()
        : <String>['ride', 'delivery', 'market'];
    int landingPosition(String key) {
      final index = landingOrder.indexOf(key);
      return index < 0 ? 99 : index + 1;
    }

    final rideLandingOrder =
        TextEditingController(text: landingPosition('ride').toString());
    final deliveryLandingOrder =
        TextEditingController(text: landingPosition('delivery').toString());
    final marketLandingOrder =
        TextEditingController(text: landingPosition('market').toString());
    var landingMode = row?['passenger_landing_mode']?.toString() ??
        (row == null ? 'auto' : 'direct');
    var landingDefault =
        row?['passenger_default_module']?.toString() ?? 'ride';
    var active = row?['active'] != false;
    var driverRegistrationEnabled =
        row?['driver_registration_enabled'] != false;
    var selectedCountryCode = row?['country_code']?.toString().toUpperCase();
    if (selectedCountryCode == null ||
        !countries.any(
          (countryRow) =>
              countryRow['country_code']?.toString().toUpperCase() ==
              selectedCountryCode,
        )) {
      final activeCountries =
          countries.where((countryRow) => countryRow['active'] == true);
      final selected = activeCountries.isNotEmpty
          ? activeCountries.first
          : countries.first;
      selectedCountryCode =
          selected['country_code']?.toString().toUpperCase();
    }

    Map<String, dynamic>? selectedCountry() {
      for (final countryRow in countries) {
        if (countryRow['country_code']?.toString().toUpperCase() ==
            selectedCountryCode) {
          return countryRow;
        }
      }
      return null;
    }

    if (currency.text.trim().isEmpty) {
      currency.text =
          selectedCountry()?['currency_code']?.toString().toUpperCase() ?? '';
    }

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
                      color: AdminColors.blueSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hub_outlined, color: _blue),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Cada zona puede tener servicios, tarifas, suscripciones y varios métodos de pago propios. Las credenciales sensibles se administran de forma segura por integración.',
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
                  DropdownButtonFormField<String>(
                    initialValue: selectedCountryCode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'País',
                      prefixIcon: Icon(Icons.public_rounded),
                    ),
                    items: countries
                        .map(
                          (countryRow) => DropdownMenuItem<String>(
                            value: countryRow['country_code']
                                ?.toString()
                                .toUpperCase(),
                            child: Text(
                              (countryRow['name'] ?? 'País').toString() +
                                  ' · ' +
                                  (countryRow['country_code'] ?? '').toString(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setLocal(() {
                        selectedCountryCode = value;
                        final selected = selectedCountry();
                        final suggestedCurrency =
                            selected?['currency_code']?.toString();
                        if (suggestedCurrency != null &&
                            suggestedCurrency.isNotEmpty) {
                          currency.text = suggestedCurrency.toUpperCase();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminCountryCoveragePage(
                              channel: widget.channel,
                            ),
                          ),
                        );
                        final refreshed = await _loadCountries();
                        if (!context.mounted || refreshed.isEmpty) return;
                        setLocal(() {
                          countries = refreshed;
                          final stillExists = countries.any(
                            (countryRow) =>
                                countryRow['country_code']
                                    ?.toString()
                                    .toUpperCase() ==
                                selectedCountryCode,
                          );
                          if (!stillExists) {
                            selectedCountryCode = countries.first['country_code']
                                ?.toString()
                                .toUpperCase();
                            currency.text = countries.first['currency_code']
                                    ?.toString()
                                    .toUpperCase() ??
                                currency.text;
                          }
                        });
                      },
                      icon: const Icon(Icons.settings_outlined, size: 17),
                      label: const Text('Administrar países'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: regionDepartment,
                    decoration: const InputDecoration(
                      labelText: 'Región / departamento',
                      hintText: 'Ej. Tarapacá / Beni',
                    ),
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
                  const SizedBox(height: 14),
                  AdminZoneCoverageEditor(
                    mode: coverageMode,
                    latitude: lat,
                    longitude: lng,
                    radiusKm: radius,
                    polygonPoints: polygonPoints,
                    onModeChanged: (mode) => setLocal(() => coverageMode = mode),
                    onPositionChanged: () => setLocal(() {}),
                    onPolygonChanged: (points) => setLocal(() {
                      polygonPoints = points;
                    }),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AdminColors.surfaceSoft,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.dashboard_customize_outlined,
                                color: _blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pantalla inicial del pasajero',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Decide si esta zona entra directo a un servicio o muestra un panel para elegir entre Viajes, Envíos y Express Market.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: landingMode,
                          decoration: const InputDecoration(
                            labelText: 'Comportamiento de inicio',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'auto',
                              child: Text('Automático'),
                            ),
                            DropdownMenuItem(
                              value: 'always',
                              child: Text('Mostrar siempre el panel'),
                            ),
                            DropdownMenuItem(
                              value: 'direct',
                              child: Text('Entrada directa'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setLocal(() => landingMode = value);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: landingDefault,
                          decoration: const InputDecoration(
                            labelText: 'Servicio predeterminado',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'ride',
                              child: Text('Viajes'),
                            ),
                            DropdownMenuItem(
                              value: 'delivery',
                              child: Text('Envíos / Delivery'),
                            ),
                            DropdownMenuItem(
                              value: 'market',
                              child: Text('Express Market'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setLocal(() => landingDefault = value);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: landingTitle,
                          decoration: const InputDecoration(
                            labelText: 'Título del panel',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: landingSubtitle,
                          decoration: const InputDecoration(
                            labelText: 'Subtítulo del panel',
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Orden de tarjetas',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: rideLandingOrder,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Viajes',
                                  hintText: '1',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: deliveryLandingOrder,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Envíos',
                                  hintText: '2',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: marketLandingOrder,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Market',
                                  hintText: '3',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          landingMode == 'auto'
                              ? 'Automático: con varios módulos visibles muestra el panel; con uno solo entra directo.'
                              : landingMode == 'always'
                                  ? 'Siempre: muestra el panel aunque haya un solo módulo visible.'
                                  : 'Directo: abre el servicio predeterminado sin mostrar el panel.',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: driverRegistrationEnabled,
                    onChanged: active
                        ? (value) => setLocal(
                              () => driverRegistrationEnabled = value,
                            )
                        : null,
                    title: const Text('Registro de conductores en esta zona'),
                    subtitle: const Text(
                      'Si está apagado, un conductor ubicado aquí verá que Express todavía no está disponible para registrarse.',
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
              child: const Text('Guardar zona y cobertura'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      if (coverageMode == 'polygon' && polygonPoints.length < 3) {
        _snack(context, 'Dibuja tres o más puntos para el polígono.');
        return;
      }
      if (coverageMode == 'radius' &&
          (_num(lat.text) == null || _num(lng.text) == null ||
           (_num(radius.text) ?? 0) <= 0)) {
        _snack(context, 'Selecciona un centro y un radio válido.');
        return;
      }
      try {
        Object? savedZoneId;
        final zoneRecordKey = row == null
            ? _environment.createRecordKey('zone')
            : AdminEnvironmentStore.recordKey(row);
        if (_environment.isPreview) {
          savedZoneId = row?['id'] ?? zoneRecordKey;
        } else {
          savedZoneId = await supabase.rpc(
            'admin_zone_coverage_save',
            params: {
              'p_channel': widget.channel,
              'p_coverage_mode': coverageMode,
              'p_polygon': coverageMode == 'polygon'
                  ? polygonPoints.map((point) => <String, double>{
                      'lat': point.latitude, 'lng': point.longitude,
                    }).toList()
                  : null,
              'p_id': row?['id'],
              'p_name': name.text.trim(),
              'p_city': city.text.trim(),
              'p_region_department': regionDepartment.text.trim(),
              'p_country_code': selectedCountryCode,
              'p_active': active,
              'p_driver_registration_enabled':
                  driverRegistrationEnabled,
              'p_center_latitude': _num(lat.text),
              'p_center_longitude': _num(lng.text),
              'p_radius_km': _num(radius.text) ?? 25,
              'p_zone_key':
                  row?['zone_key']?.toString() ?? zoneKey.text.trim(),
              'p_currency_code': currency.text.trim().toUpperCase(),
            },
          );
        }
        final landingModules = <Map<String, Object>>[
          <String, Object>{
            'key': 'ride',
            'order': int.tryParse(rideLandingOrder.text.trim()) ?? 1,
          },
          <String, Object>{
            'key': 'delivery',
            'order': int.tryParse(deliveryLandingOrder.text.trim()) ?? 2,
          },
          <String, Object>{
            'key': 'market',
            'order': int.tryParse(marketLandingOrder.text.trim()) ?? 3,
          },
        ]..sort(
            (a, b) =>
                (a['order'] as int).compareTo(b['order'] as int),
          );

        if (_environment.isPreview) {
          await _environment.previewUpsert(
            'service_zones',
            zoneRecordKey,
            <String, dynamic>{
              ...?row,
              'id': savedZoneId?.toString(),
              'name': name.text.trim(),
              'city': city.text.trim(),
              'region_department': regionDepartment.text.trim(),
              'country': selectedCountry()?['name']?.toString() ?? '',
              'country_code': selectedCountryCode,
              'active': active,
              'driver_registration_enabled':
                  driverRegistrationEnabled,
              'center_latitude': _num(lat.text),
              'center_longitude': _num(lng.text),
              'radius_km': _num(radius.text) ?? 25,
              'coverage_mode': coverageMode,
              'polygon': coverageMode == 'polygon'
                  ? polygonPoints.map((point) => <String, double>{
                      'lat': point.latitude,
                      'lng': point.longitude,
                    }).toList()
                  : null,
              'zone_key': row?['zone_key']?.toString() ?? zoneKey.text.trim(),
              'currency_code': currency.text.trim().toUpperCase(),
              'passenger_landing_mode': landingMode,
              'passenger_default_module': landingDefault,
              'passenger_landing_title': landingTitle.text.trim(),
              'passenger_landing_subtitle': landingSubtitle.text.trim(),
              'passenger_landing_order': landingModules
                  .map((item) => item['key'].toString())
                  .toList(),
            },
          );
        } else {
          await supabase.rpc(
            'admin_update_zone_landing',
            params: {
              'p_zone_id': savedZoneId,
              'p_mode': landingMode,
              'p_default_module': landingDefault,
              'p_title': landingTitle.text.trim(),
              'p_subtitle': landingSubtitle.text.trim(),
              'p_order': landingModules
                  .map((item) => item['key'].toString())
                  .toList(),
            },
          );
        }

        if (mounted) {
          setState(() => revision++);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Zona y cobertura guardadas. Solo se usará el método seleccionado.',
              ),
            ),
          );
          final zoneForPayments = <String, dynamic>{
            ...?row,
            'id': savedZoneId?.toString(),
            'name': name.text.trim(),
            'city': city.text.trim(),
            'region_department': regionDepartment.text.trim(),
            'country': selectedCountry()?['name']?.toString() ?? '',
            'country_code': selectedCountryCode,
            'currency_code': currency.text.trim().toUpperCase(),
          };
          await showAdminZonePaymentMethodsEditor(context, zoneForPayments, channel: widget.channel);
          if (mounted) setState(() => revision++);
        }
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }

    name.dispose();
    city.dispose();
    regionDepartment.dispose();
    zoneKey.dispose();
    currency.dispose();
    lat.dispose();
    lng.dispose();
    radius.dispose();
    landingTitle.dispose();
    landingSubtitle.dispose();
    rideLandingOrder.dispose();
    deliveryLandingOrder.dispose();
    marketLandingOrder.dispose();
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
              action: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminCountryCoveragePage(
                            channel: widget.channel,
                          ),
                        ),
                      );
                      if (mounted) setState(() => revision++);
                    },
                    icon: const Icon(Icons.public_rounded),
                    label: const Text('Países'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nueva zona'),
                  ),
                ],
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
                      backgroundColor: AdminColors.blueSoft,
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
                          ' · Cobertura: ' +
                          adminZoneCoverageSummary(row) +
                          '\nClave: ' +
                          (row['zone_key'] ?? '—').toString() +
                          ' · Registro: ' +
                          (row['driver_registration_enabled'] == false
                              ? 'OFF'
                              : 'ON') +
                          ' · Inicio: ' +
                          ((row['passenger_landing_mode'] ?? 'direct')
                                      .toString() ==
                                  'auto'
                              ? 'Automático'
                              : (row['passenger_landing_mode'] ?? 'direct')
                                          .toString() ==
                                      'always'
                                  ? 'Panel'
                                  : 'Directo'),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniStatus(
                          text: row['country_active'] == false
                              ? 'País OFF'
                              : row['active'] == true
                                  ? 'Activa'
                                  : 'Inactiva',
                          positive: row['active'] == true &&
                              row['country_active'] != false,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Aliados / sindicatos',
                          onPressed: () => _showPartners(row),
                          icon: const Icon(Icons.groups_2_outlined, size: 19),
                        ),
                        IconButton(
                          tooltip: 'Métodos de pago',
                          onPressed: () async {
                            final changed =
                                await showAdminZonePaymentMethodsEditor(
                              context,
                              row,
                              channel: widget.channel,
                            );
                            if (changed && mounted) {
                              setState(() => revision++);
                            }
                          },
                          icon: const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 18,
                          ),
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
  final String channel;
  final String? countryCode;
  final String? zoneId;

  const AdminServicesPage({
    super.key,
    this.channel = 'production',
    this.countryCode,
    this.zoneId,
  });

  @override
  State<AdminServicesPage> createState() => _AdminServicesPageState();
}

class _AdminServicesPageState extends State<AdminServicesPage> {
  int revision = 0;

  AdminEnvironmentStore get _environment =>
      AdminEnvironmentStore(widget.channel);
  String? selectedZoneId;

  Future<({
    List<Map<String, dynamic>> zones,
    List<Map<String, dynamic>> services,
    Map<String, dynamic>? zone,
  })> _load() async {
    final selectedScopeZoneId = widget.zoneId;
    final countryCode = widget.countryCode;
    if (selectedScopeZoneId == null ||
        selectedScopeZoneId.isEmpty ||
        countryCode == null ||
        countryCode.isEmpty) {
      return (
        zones: <Map<String, dynamic>>[],
        services: <Map<String, dynamic>>[],
        zone: null,
      );
    }

    final zoneRows = _environment.isPreview
        ? (await _environment.previewList('service_zones'))
            .where((row) => row['id']?.toString() == selectedScopeZoneId)
            .toList()
        : _list(
            await supabase.rpc(
              'admin_zone_list_for_country',
              params: {'p_country_code': countryCode},
            ),
          )
            .where((row) => row['id']?.toString() == selectedScopeZoneId)
            .toList();
    if (zoneRows.isEmpty) {
      return (
        zones: zoneRows,
        services: <Map<String, dynamic>>[],
        zone: null,
      );
    }

    var zoneId = selectedScopeZoneId;
    selectedZoneId = zoneId;

    final zone = zoneRows.firstWhere(
      (row) => row['id']?.toString() == zoneId,
    );
    List<Map<String, dynamic>> serviceRows;
    if (_environment.isPreview) {
      final catalog = await _environment.previewList('service_catalog');
      final overrides = (await _environment.previewList('zone_services'))
          .where((row) => row['zone_id']?.toString() == zoneId)
          .toList();
      final byKey = <String, Map<String, dynamic>>{
        for (final row in catalog)
          if (row['service_key'] != null)
            row['service_key'].toString(): Map<String, dynamic>.from(row),
      };
      for (final override in overrides) {
        final key = override['service_key']?.toString();
        if (key == null || key.isEmpty) continue;
        byKey[key] = <String, dynamic>{
          ...?byKey[key],
          ...override,
        };
      }
      serviceRows = byKey.values.toList()
        ..sort((a, b) =>
            ((a['sort_order'] as num?)?.toInt() ?? 100)
                .compareTo((b['sort_order'] as num?)?.toInt() ?? 100));
    } else {
      serviceRows = _list(
        await supabase.rpc(
          'admin_zone_service_list',
          params: {'p_zone_id': zoneId},
        ),
      );
    }

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
                      color: AdminColors.blueSoft,
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
                    title: Text('Disponible en $zoneName'),
                    subtitle: const Text(
                      'Activa o bloquea solicitudes. La visibilidad se controla por separado.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: passengerVisible,
                    onChanged: (value) =>
                        setLocal(() => passengerVisible = value),
                    title: const Text('Visible para pasajeros'),
                    subtitle: const Text(
                      'Si está visible pero no disponible, aparecerá como “No disponible”.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: driverVisible,
                    onChanged: (value) =>
                        setLocal(() => driverVisible = value),
                    title: const Text('Visible para conductores'),
                    subtitle: const Text(
                      'Controla si el servicio aparece en la interfaz del conductor.',
                    ),
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
        final serviceKey = key.text.trim();
        final sortOrder = int.tryParse(order.text.trim()) ?? 100;
        if (_environment.isPreview) {
          final base = <String, dynamic>{
            ...?row,
            'service_key': serviceKey,
            'name': name.text.trim(),
            'description': description.text.trim(),
            'icon_key': row?['icon_key'] ?? 'local_taxi',
            'vehicle_type': vehicle,
            'enabled': true,
            'allow_bidding': bidding,
            'allow_fixed_price': fixed,
            'passenger_visible': true,
            'driver_visible': true,
            'scheduled_enabled': scheduled,
            'sort_order': sortOrder,
          };
          await _environment.previewUpsert(
            'service_catalog',
            serviceKey,
            base,
          );
          await _environment.previewUpsert(
            'zone_services',
            zoneId + ':' + serviceKey,
            <String, dynamic>{
              'zone_id': zoneId,
              'service_key': serviceKey,
              'enabled': enabled,
              'passenger_visible': passengerVisible,
              'driver_visible': driverVisible,
              'allow_bidding': bidding,
              'allow_fixed_price': fixed,
              'scheduled_enabled': scheduled,
              'sort_order': sortOrder,
            },
          );
        } else {
          await supabase.rpc(
            'admin_upsert_service',
            params: {
              'p_id': row?['id'],
              'p_service_key': serviceKey,
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
              'p_sort_order': sortOrder,
            },
          );

          await supabase.rpc(
            'admin_set_zone_service',
            params: {
              'p_zone_id': zoneId,
              'p_service_key': serviceKey,
              'p_enabled': enabled,
              'p_passenger_visible': passengerVisible,
              'p_driver_visible': driverVisible,
              'p_allow_bidding': bidding,
              'p_allow_fixed_price': fixed,
              'p_scheduled_enabled': scheduled,
              'p_sort_order': sortOrder,
            },
          );
        }

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
                    'Disponibilidad y visibilidad se controlan por separado y se sincronizan con las apps.',
                stats: [
                  ('Servicios', rows.length.toString()),
                  ('Disponibles', active.toString()),
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
                            enabled
                                ? 'Disponible en $zoneName'
                                : 'No disponible',
                            row['vehicle_type']?.toString() ?? 'car',
                            if (row['allow_bidding'] == true) 'Ofertas',
                            if (row['allow_fixed_price'] == true) 'Precio fijo',
                            if (row['passenger_visible'] == true)
                              'Visible pasajero',
                            if (row['driver_visible'] == true)
                              'Visible conductor',
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
  final String channel;
  final String? countryCode;
  final String? zoneId;

  const AdminGeoSafetyPage({
    super.key,
    this.channel = 'production',
    this.countryCode,
    this.zoneId,
  });

  @override
  State<AdminGeoSafetyPage> createState() => _AdminGeoSafetyPageState();
}

class _AdminGeoSafetyPageState extends State<AdminGeoSafetyPage> {
  int revision = 0;

  AdminEnvironmentStore get _environment =>
      AdminEnvironmentStore(widget.channel);

  Future<({
    List<Map<String, dynamic>> zones,
    List<Map<String, dynamic>> coverage,
    List<Map<String, dynamic>> safety,
  })> _load() async {
    final selectedZoneId = widget.zoneId;
    final countryCode = widget.countryCode;
    if (selectedZoneId == null ||
        selectedZoneId.isEmpty ||
        countryCode == null ||
        countryCode.isEmpty) {
      return (
        zones: <Map<String, dynamic>>[],
        coverage: <Map<String, dynamic>>[],
        safety: <Map<String, dynamic>>[],
      );
    }

    if (_environment.isPreview) {
      final values = await Future.wait([
        _environment.previewList('service_zones'),
        _environment.previewList('service_zone_polygons'),
        _environment.previewList('security_zones'),
      ]);
      return (
        zones: values[0]
            .where((row) => row['id']?.toString() == selectedZoneId)
            .toList(),
        coverage: values[1]
            .where((row) => row['zone_id']?.toString() == selectedZoneId)
            .toList(),
        safety: values[2]
            .where((row) => row['zone_id']?.toString() == selectedZoneId)
            .toList(),
      );
    }

    final values = await Future.wait([
      supabase.rpc(
        'admin_zone_list_for_country',
        params: {'p_country_code': countryCode},
      ),
      supabase.rpc('admin_zone_polygon_list'),
      supabase.rpc('admin_security_zone_list'),
    ]);
    return (
      zones: _list(values[0])
          .where((row) => row['id']?.toString() == selectedZoneId)
          .toList(),
      coverage: _list(values[1])
          .where((row) => row['zone_id']?.toString() == selectedZoneId)
          .toList(),
      safety: _list(values[2])
          .where((row) => row['zone_id']?.toString() == selectedZoneId)
          .toList(),
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
        if (_environment.isPreview) {
          final key = row == null
              ? _environment.createRecordKey('coverage')
              : AdminEnvironmentStore.recordKey(row);
          await _environment.previewUpsert(
            'service_zone_polygons',
            key,
            <String, dynamic>{
              ...?row,
              'zone_id': zoneId,
              'name': name.text.trim(),
              'polygon': _jsonPoints(points),
              'active': active,
            },
          );
        } else {
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
        }
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
        if (_environment.isPreview) {
          final key = row == null
              ? _environment.createRecordKey('safety')
              : AdminEnvironmentStore.recordKey(row);
          await _environment.previewUpsert(
            'security_zones',
            key,
            <String, dynamic>{
              ...?row,
              'name': name.text.trim(),
              'zone_type': type,
              'applies_to': applies,
              'severity': severity,
              'polygon': _jsonPoints(points),
              'message': message.text.trim(),
              'active': active,
              'city': city.text.trim(),
              'country': country.text.trim(),
            },
          );
        } else {
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
        }
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

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _AdminHero(
              icon: Icons.shield_outlined,
              title: 'Seguridad de zonas',
              subtitle: 'La cobertura por radio o polígono se configura '
                  'directamente al crear o editar la zona. Aquí solo se '
                  'administran sectores de seguridad, precaución o riesgo.',
              stats: [
                ('Zonas', data.zones.length.toString()),
                ('Sectores de seguridad', data.safety.length.toString()),
              ],
            ),
            const SizedBox(height: 16),
            _Header(
              title: 'Zonas rojas y prevención',
              subtitle: 'Sectores de riesgo y zonas seguras para '
                  'conductores y pasajeros.',
              action: FilledButton.icon(
                onPressed: () => _editSafety(),
                icon: const Icon(Icons.add_moderator_outlined),
                label: const Text('Crear sector'),
              ),
            ),
            const SizedBox(height: 14),
            if (data.safety.isEmpty)
              const _Empty(text: 'Todavía no hay sectores de seguridad.')
            else
              ...data.safety.map((row) => _GeoRow(
                tone: _securityTone(row['zone_type']?.toString()),
                icon: row['zone_type'] == 'safe'
                    ? Icons.verified_user_outlined
                    : Icons.warning_amber_rounded,
                title: row['name']?.toString() ?? 'Zona de seguridad',
                subtitle:
                    _securityLabel(row['zone_type']?.toString()) +
                    ' · nivel ' + (row['severity'] ?? 3).toString(),
                badge: row['active'] == true ? 'Activa' : 'Inactiva',
                onTap: () => _editSafety(row),
              )),
          ],
        );
      },
    );
  }
}

/// Admin identity configuration is document-based and manual-only.
///
/// Historical third-party sessions live in the audit trail, not in active
/// driver verification. Never query legacy identity_verifications here:
/// old provider records (including test sessions) must not appear as
/// production requests or count towards pending reviews.
class AdminIdentitySecurityPage extends StatelessWidget {
  final String channel;
  final String? countryCode;
  final String? zoneId;

  const AdminIdentitySecurityPage({
    super.key,
    this.channel = 'production',
    this.countryCode,
    this.zoneId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const _Header(
          title: 'Verificación de identidad',
          subtitle: 'Documentos de conductores y revisión manual de fotografías. '
              'Los servicios de identidad automáticos y la verificación por SMS '
              'están deshabilitados.',
        ),
        const SizedBox(height: 16),
        const _AdminHero(
          icon: Icons.verified_user_rounded,
          title: 'Centro de identidad',
          subtitle: 'Las aprobaciones se realizan manualmente desde la pestaña '
              'Revisión de documentos. Los registros históricos de servicios '
              'anteriores no son solicitudes activas.',
          stats: [
            ('Motor', 'Manual'),
            ('Proveedor externo', 'Deshabilitado'),
          ],
        ),
        const SizedBox(height: 16),
        AdminDriverDocumentRequirementsPanel(
          channel: channel,
          countryCode: countryCode,
          zoneId: zoneId,
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.fact_check_outlined, color: _blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Para revisar, aprobar, rechazar o reactivar por separado '
                    'el frente, reverso y la selfie de un conductor, '
                    'usa la pestaña «Revisión de documentos». '
                    'Las solicitudes de Prueba y Producción se gestionan '
                    'por separado.',
                    style: TextStyle(color: _dark, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PolygonEditor extends StatelessWidget {
  final List<LatLng> points;
  final Color tone;
  final String title;
  final LatLng? initialCenter;
  final ValueChanged<LatLng> onAdd;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const _PolygonEditor({
    required this.points,
    required this.tone,
    required this.title,
    this.initialCenter,
    required this.onAdd,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final center = points.isNotEmpty
        ? points.first
        : initialCenter ?? const LatLng(-14.8333, -64.9000);
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
    final statRow = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final stat in stats)
          Container(
            constraints: const BoxConstraints(minWidth: 98),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.$2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  stat.$1,
                  style: const TextStyle(
                    color: AdminColors.headerMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return AdminPageHero(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: stats.isEmpty ? null : statRow,
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
      borderRadius: BorderRadius.circular(AdminRadius.card),
      child: AdminCard(
        elevated: true,
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const Spacer(),
                if (onTap != null)
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AdminColors.muted,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AdminColors.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AdminText.caption,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in chips)
                  AdminStatusChip(chip, dot: false),
              ],
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
      return AdminColors.danger;
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
  final String channel;
  final String? countryCode;
  final String? zoneId;

  const AdminFaresPage({
    super.key,
    this.channel = 'production',
    this.countryCode,
    this.zoneId,
  });

  @override
  State<AdminFaresPage> createState() => _AdminFaresPageState();
}

class _AdminFaresPageState extends State<AdminFaresPage> {
  int revision = 0;

  AdminEnvironmentStore get _environment =>
      AdminEnvironmentStore(widget.channel);
  String? selectedZoneId;

  Future<({
    List<Map<String, dynamic>> fares,
    List<Map<String, dynamic>> zones,
    List<Map<String, dynamic>> services,
    Map<String, dynamic>? zone,
  })> _load() async {
    final selectedScopeZoneId = widget.zoneId;
    final countryCode = widget.countryCode;
    if (selectedScopeZoneId == null ||
        selectedScopeZoneId.isEmpty ||
        countryCode == null ||
        countryCode.isEmpty) {
      return (
        fares: <Map<String, dynamic>>[],
        zones: <Map<String, dynamic>>[],
        services: <Map<String, dynamic>>[],
        zone: null,
      );
    }

    final List<Map<String, dynamic>> fares;
    final List<Map<String, dynamic>> zones;
    final List<Map<String, dynamic>> services;
    if (_environment.isPreview) {
      fares = (await _environment.previewList('fare_rules'))
          .where(
            (row) =>
                row['zone_id']?.toString() == selectedScopeZoneId ||
                row['zone_id'] == null,
          )
          .toList();
      zones = (await _environment.previewList('service_zones'))
          .where((row) => row['id']?.toString() == selectedScopeZoneId)
          .toList();
      services = await _environment.previewList('service_catalog');
    } else {
      final values = await Future.wait([
        supabase.rpc('admin_fare_list'),
        supabase.rpc(
          'admin_zone_list_for_country',
          params: {'p_country_code': countryCode},
        ),
        supabase.rpc('admin_service_list'),
      ]);
      fares = _list(values[0])
          .where(
            (row) =>
                row['zone_id']?.toString() == selectedScopeZoneId ||
                row['zone_id'] == null,
          )
          .toList();
      zones = _list(values[1])
          .where((row) => row['id']?.toString() == selectedScopeZoneId)
          .toList();
      services = _list(values[2]);
    }

    if (zones.isEmpty) {
      return (
        fares: fares,
        zones: zones,
        services: services,
        zone: null,
      );
    }

    selectedZoneId = selectedScopeZoneId;
    return (
      fares: fares,
      zones: zones,
      services: services,
      zone: zones.first,
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
                      color: AdminColors.blueSoft,
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
        if (_environment.isPreview) {
          final key = row == null
              ? _environment.createRecordKey('fare')
              : AdminEnvironmentStore.recordKey(row);
          await _environment.previewUpsert(
            'fare_rules',
            key,
            <String, dynamic>{
              ...?row,
              'id': row?['id'] ?? key,
              'scope_type': scope,
              'service_key': scope == 'global' ? null : service,
              'zone_id': scope == 'zone_service' ? zoneId : null,
              'base_fare': _num(base.text) ?? 0,
              'per_km': _num(km.text) ?? 0,
              'per_minute': _num(minute.text) ?? 0,
              'minimum_fare': _num(minimum.text) ?? 0,
              'surge_multiplier': _num(surge.text) ?? 1,
              'commission_percent': _num(commission.text) ?? 0,
              'active': active,
            },
          );
        } else {
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
        }
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


  List<LatLng> _specialPoints(Object? raw) {
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

  List<Map<String, double>> _specialJsonPoints(List<LatLng> points) =>
      points
          .map(
            (point) => {
              'lat': point.latitude,
              'lng': point.longitude,
            },
          )
          .toList();

  Future<bool> _editSpecialFare(
    Map<String, dynamic> zone,
    List<Map<String, dynamic>> services, [
    Map<String, dynamic>? row,
  ]) async {
    if (services.isEmpty) {
      _snack(context, 'No hay servicios disponibles.');
      return false;
    }

    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final fare = TextEditingController(
      text: row?['fixed_fare']?.toString() ?? '',
    );
    final priority = TextEditingController(
      text: row?['priority']?.toString() ?? '100',
    );
    var type = row?['zone_type']?.toString() ?? 'airport';
    var service = row?['service_key']?.toString() ??
        services.first['service_key']?.toString() ??
        'motorcycle';
    var active = row?['active'] != false;
    var points = _specialPoints(row?['polygon']);
    final centerLat = _double(zone['center_latitude']);
    final centerLng = _double(zone['center_longitude']);

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            row == null ? 'Nueva tarifa fija por sector' : 'Editar tarifa fija',
          ),
          content: SizedBox(
            width: 820,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.blueSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Si el origen O el destino entra en este polígono, esta tarifa fija tiene prioridad sobre la tarifa normal de ' +
                          (zone['name'] ?? 'la zona').toString() +
                          '. Si dos polígonos coinciden, manda el de mayor prioridad.',
                      style: const TextStyle(fontSize: 11, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText:
                          'Ej. Aeropuerto Teniente Jorge Henrich Arauz',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de sector',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'airport',
                              child: Text('Aeropuerto'),
                            ),
                            DropdownMenuItem(
                              value: 'terminal',
                              child: Text('Terminal'),
                            ),
                            DropdownMenuItem(
                              value: 'custom',
                              child: Text('Otro sector especial'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setLocal(() => type = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: service,
                          decoration: const InputDecoration(
                            labelText: 'Servicio',
                          ),
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
                            if (value != null) {
                              setLocal(() => service = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          controller: fare,
                          label: 'Tarifa fija · ' +
                              (zone['currency_code'] ?? '').toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NumberField(
                          controller: priority,
                          label: 'Prioridad',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PolygonEditor(
                    points: points,
                    tone: type == 'airport'
                        ? const Color(0xFF7F56D9)
                        : type == 'terminal'
                            ? const Color(0xFF0E9384)
                            : _blue,
                    title:
                        'Dibuja el perímetro de ' +
                        (type == 'airport'
                            ? 'aeropuerto'
                            : type == 'terminal'
                                ? 'terminal'
                                : 'la zona especial'),
                    initialCenter: centerLat != null && centerLng != null
                        ? LatLng(centerLat, centerLng)
                        : null,
                    onAdd: (point) =>
                        setLocal(() => points = [...points, point]),
                    onUndo: () {
                      if (points.isNotEmpty) {
                        setLocal(
                          () => points =
                              points.sublist(0, points.length - 1),
                        );
                      }
                    },
                    onClear: () =>
                        setLocal(() => points = <LatLng>[]),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) =>
                        setLocal(() => active = value),
                    title: const Text('Tarifa especial activa'),
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
              onPressed: points.length < 3 ||
                      (_num(fare.text) ?? 0) <= 0 ||
                      name.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar tarifa'),
            ),
          ],
        ),
      ),
    );

    var saved = false;
    if (save == true) {
      try {
        if (_environment.isPreview) {
          final key = row == null
              ? _environment.createRecordKey('special-fare')
              : AdminEnvironmentStore.recordKey(row);
          await _environment.previewUpsert(
            'special_fare_zones',
            key,
            <String, dynamic>{
              ...?row,
              'id': row?['id'] ?? key,
              'zone_id': zone['id'],
              'name': name.text.trim(),
              'zone_type': type,
              'service_key': service,
              'polygon': _specialJsonPoints(points),
              'fixed_fare': _num(fare.text),
              'priority': int.tryParse(priority.text.trim()) ?? 100,
              'active': active,
            },
          );
        } else {
          await supabase.rpc(
            'admin_upsert_special_fare_zone',
            params: {
              'p_id': row?['id'],
              'p_zone_id': zone['id'],
              'p_name': name.text.trim(),
              'p_zone_type': type,
              'p_service_key': service,
              'p_polygon': _specialJsonPoints(points),
              'p_fixed_fare': _num(fare.text),
              'p_priority': int.tryParse(priority.text.trim()) ?? 100,
              'p_active': active,
            },
          );
        }
        saved = true;
      } catch (e) {
        if (mounted) _snack(context, e);
      }
    }

    name.dispose();
    fare.dispose();
    priority.dispose();
    return saved;
  }

  Future<void> _showSpecialFares(
    Map<String, dynamic> zone,
    List<Map<String, dynamic>> services,
  ) async {
    var localRevision = 0;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.place_rounded, color: _blue),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Tarifas fijas · ' +
                      (zone['name'] ?? 'Zona').toString(),
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final saved = await _editSpecialFare(zone, services);
                  if (saved) setLocal(() => localRevision++);
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nueva'),
              ),
            ],
          ),
          content: SizedBox(
            width: 860,
            height: 520,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(localRevision),
              future: () async {
                if (_environment.isPreview) {
                  return (await _environment.previewList('special_fare_zones'))
                      .where(
                        (row) =>
                            row['zone_id']?.toString() ==
                            zone['id']?.toString(),
                      )
                      .toList();
                }
                final value = await supabase.rpc(
                  'admin_special_fare_list',
                  params: {'p_zone_id': zone['id']},
                );
                return _list(value);
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const _Loading(
                    title: 'Cargando tarifas especiales',
                  );
                }
                if (snapshot.hasError) {
                  return _Error(
                    error: snapshot.error,
                    onRetry: () =>
                        setLocal(() => localRevision++),
                  );
                }
                final rows =
                    snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) {
                  return const _Empty(
                    text:
                        'No hay sectores con tarifa fija. Crea Aeropuerto, Terminal u otro sector especial.',
                  );
                }

                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final type = row['zone_type']?.toString();
                    final label = type == 'airport'
                        ? 'Aeropuerto'
                        : type == 'terminal'
                            ? 'Terminal'
                            : 'Especial';
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AdminColors.blueSoft,
                          child: Icon(
                            type == 'airport'
                                ? Icons.flight_rounded
                                : type == 'terminal'
                                    ? Icons.directions_bus_rounded
                                    : Icons.place_outlined,
                            color: _blue,
                          ),
                        ),
                        title: Text(
                          row['name']?.toString() ?? label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          label +
                              ' · ' +
                              (row['service_key'] ?? 'servicio')
                                  .toString() +
                              ' · ' +
                              (zone['currency_code'] ?? '').toString() +
                              ' ' +
                              (row['fixed_fare'] ?? '—').toString() +
                              ' · prioridad ' +
                              (row['priority'] ?? 100).toString(),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MiniStatus(
                              text: row['active'] == true
                                  ? 'Activa'
                                  : 'Inactiva',
                              positive: row['active'] == true,
                            ),
                            IconButton(
                              tooltip: 'Editar',
                              onPressed: () async {
                                final saved = await _editSpecialFare(
                                  zone,
                                  services,
                                  row,
                                );
                                if (saved) {
                                  setLocal(() => localRevision++);
                                }
                              },
                              icon: const Icon(Icons.edit_outlined),
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
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (data.zone != null)
                          OutlinedButton.icon(
                            onPressed: () => _showSpecialFares(
                              data.zone!,
                              data.services,
                            ),
                            icon: const Icon(Icons.place_outlined),
                            label: const Text('Aeropuerto / Terminal'),
                          ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () =>
                              _edit(data.zones, data.services),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Nueva tarifa'),
                        ),
                      ],
                    ),
            ),
            if (data.zone != null)
              AdminDistanceFaresEditor(
                key: ValueKey('distance-steps-${data.zone!['id']}-${widget.channel}'),
                channel: widget.channel,
                zone: data.zone!,
                services: data.services,
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
                      backgroundColor: AdminColors.blueSoft,
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


Future<bool> showAdminZonePaymentMethodsEditor(
  BuildContext context,
  Map<String, dynamic> zone, {
  String channel = 'production',
}) async {
  final environment = AdminEnvironmentStore(channel);
  final zoneId = zone['id']?.toString();
  if (zoneId == null || zoneId.isEmpty) return false;

  try {
    final catalog =
        _list(await supabase.rpc('admin_payment_method_catalog_list'));
    final existing = environment.isPreview
        ? (await environment.previewList('zone_payment_methods'))
            .where((row) => row['zone_id']?.toString() == zoneId)
            .toList()
        : _list(
            await supabase.rpc(
              'admin_zone_payment_methods',
              params: {'p_zone_id': zoneId},
            ),
          );
    final state = <String, Map<String, dynamic>>{};

    for (final provider in catalog) {
      final key = provider['provider_key']?.toString() ?? '';
      if (key.isEmpty) continue;
      Map<String, dynamic> current = <String, dynamic>{};
      for (final item in existing) {
        if (item['provider_key']?.toString() == key) {
          current = item;
          break;
        }
      }
      state[key] = <String, dynamic>{
        'selected': current.isNotEmpty,
        'enabled': current.isEmpty ? true : current['enabled'] != false,
        'use_rides': current.isEmpty
            ? provider['supports_rides'] == true
            : current['use_rides'] == true,
        'use_delivery': current.isEmpty
            ? provider['supports_delivery'] == true
            : current['use_delivery'] == true,
        'use_subscriptions': current.isEmpty
            ? provider['supports_subscriptions'] == true
            : current['use_subscriptions'] == true,
        'use_wallet': current.isEmpty
            ? provider['supports_wallet'] == true
            : current['use_wallet'] == true,
        'is_primary': current['is_primary'] == true,
        'sort_order': current['sort_order'] ?? 100,
      };
    }

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            'Métodos de pago · ' + (zone['name'] ?? 'Zona').toString(),
          ),
          content: SizedBox(
            width: 720,
            height: 590,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AdminPaymentNotice(
                  text:
                      'Puedes habilitar varios métodos en una misma zona y decidir si cada uno se usa en Viajes, Delivery, Suscripciones y/o Billetera. “Principal” mantiene compatibilidad con la app móvil publicada.',
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: catalog.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final provider = catalog[index];
                      final key = provider['provider_key']?.toString() ?? '';
                      final row = state[key]!;
                      final selected = row['selected'] == true;
                      final supportedRides =
                          provider['supports_rides'] == true;
                      final supportedDelivery =
                          provider['supports_delivery'] == true;
                      final supportedSubscriptions =
                          provider['supports_subscriptions'] == true;
                      final supportedWallet =
                          provider['supports_wallet'] == true;

                      void setFlag(String name, bool value) {
                        setLocal(() => row[name] = value);
                      }

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFF8FAFF)
                              : Colors.white,
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFB8CDF8)
                                : const Color(0xFFE7ECF3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: selected,
                              onChanged: (value) {
                                setLocal(() {
                                  row['selected'] = value == true;
                                  if (value != true) {
                                    row['is_primary'] = false;
                                  }
                                });
                              },
                              title: Text(
                                provider['display_name']?.toString() ?? key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                (provider['provider_type'] ?? 'gateway')
                                        .toString() +
                                    ' · credenciales ' +
                                    (provider['credential_scope'] ?? 'zone')
                                        .toString(),
                                style: const TextStyle(fontSize: 10),
                              ),
                              secondary: Switch(
                                value: row['enabled'] == true,
                                onChanged: selected
                                    ? (value) => setFlag('enabled', value)
                                    : null,
                              ),
                            ),
                            if (selected)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: [
                                    FilterChip(
                                      label: const Text('Viajes'),
                                      selected: row['use_rides'] == true,
                                      onSelected: supportedRides
                                          ? (value) =>
                                              setFlag('use_rides', value)
                                          : null,
                                    ),
                                    FilterChip(
                                      label: const Text('Delivery'),
                                      selected: row['use_delivery'] == true,
                                      onSelected: supportedDelivery
                                          ? (value) =>
                                              setFlag('use_delivery', value)
                                          : null,
                                    ),
                                    FilterChip(
                                      label: const Text('Suscripciones'),
                                      selected:
                                          row['use_subscriptions'] == true,
                                      onSelected: supportedSubscriptions
                                          ? (value) => setFlag(
                                                'use_subscriptions',
                                                value,
                                              )
                                          : null,
                                    ),
                                    FilterChip(
                                      label: const Text('Billetera'),
                                      selected: row['use_wallet'] == true,
                                      onSelected: supportedWallet
                                          ? (value) =>
                                              setFlag('use_wallet', value)
                                          : null,
                                    ),
                                    ChoiceChip(
                                      avatar: const Icon(
                                        Icons.star_outline_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Principal'),
                                      selected: row['is_primary'] == true,
                                      onSelected: (value) {
                                        setLocal(() {
                                          for (final item in state.values) {
                                            item['is_primary'] = false;
                                          }
                                          row['is_primary'] = value;
                                        });
                                      },
                                    ),
                                  ],
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar métodos'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return false;

    final selected = <MapEntry<String, Map<String, dynamic>>>[
      for (final entry in state.entries)
        if (entry.value['selected'] == true) entry,
    ];
    if (selected.isNotEmpty &&
        !selected.any((entry) => entry.value['is_primary'] == true)) {
      selected.first.value['is_primary'] = true;
    }
    selected.sort(
      (a, b) => (b.value['is_primary'] == true ? 1 : 0)
          .compareTo(a.value['is_primary'] == true ? 1 : 0),
    );

    final selectedKeys = selected.map((entry) => entry.key).toSet();
    for (final entry in selected) {
      final row = entry.value;
      if (environment.isPreview) {
        Map<String, dynamic>? previous;
        for (final item in existing) {
          if (item['provider_key']?.toString() == entry.key) {
            previous = item;
            break;
          }
        }
        final recordKey = previous == null
            ? zoneId + ':' + entry.key
            : AdminEnvironmentStore.recordKey(previous);
        await environment.previewUpsert(
          'zone_payment_methods',
          recordKey,
          <String, dynamic>{
            ...?previous,
            'id': previous?['id'] ?? recordKey,
            'zone_id': zoneId,
            'provider_key': entry.key,
            'enabled': row['enabled'] == true,
            'use_rides': row['use_rides'] == true,
            'use_delivery': row['use_delivery'] == true,
            'use_subscriptions': row['use_subscriptions'] == true,
            'use_wallet': row['use_wallet'] == true,
            'is_primary': row['is_primary'] == true,
            'sort_order': row['sort_order'] ?? 100,
          },
        );
      } else {
        await supabase.rpc(
          'admin_upsert_zone_payment_method',
          params: {
            'p_zone_id': zoneId,
            'p_provider_key': entry.key,
            'p_enabled': row['enabled'] == true,
            'p_use_rides': row['use_rides'] == true,
            'p_use_delivery': row['use_delivery'] == true,
            'p_use_subscriptions': row['use_subscriptions'] == true,
            'p_use_wallet': row['use_wallet'] == true,
            'p_is_primary': row['is_primary'] == true,
            'p_sort_order': row['sort_order'] ?? 100,
          },
        );
      }
    }

    for (final row in existing) {
      final key = row['provider_key']?.toString() ?? '';
      if (key.isEmpty || selectedKeys.contains(key)) continue;
      if (environment.isPreview) {
        await environment.previewSoftDelete('zone_payment_methods', row);
      } else {
        await supabase.rpc(
          'admin_delete_zone_payment_method',
          params: {
            'p_zone_id': zoneId,
            'p_provider_key': key,
          },
        );
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Métodos de pago actualizados para ' +
                (zone['name'] ?? 'la zona').toString() +
                '.',
          ),
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) _snack(context, e);
    return false;
  }
}

class AdminPaymentsPage extends StatefulWidget {
  final String channel;
  final String? countryCode;
  final String? zoneId;

  const AdminPaymentsPage({
    super.key,
    this.channel = 'production',
    this.countryCode,
    this.zoneId,
  });

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  int revision = 0;

  AdminEnvironmentStore get _environment =>
      const AdminEnvironmentStore('production');
  String paymentPeriod = 'today';
  DateTimeRange? paymentCustomRange;
  String? selectedPaymentZoneId;
  final Set<String> savingZonePayments = <String>{};
  final Set<String> savingMercadoPagoZones = <String>{};

  @override
  void initState() {
    super.initState();
    selectedPaymentZoneId = widget.zoneId;
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

  String _currencyTotals(Object? raw) {
    final values = _map(raw);
    if (values.isEmpty) return '0';
    return values.entries
        .map((entry) => entry.key.toString() + ' ' + entry.value.toString())
        .join(' · ');
  }

  bool _zoneHasMethod(Map<String, dynamic> zone, String providerKey) {
    final methods = _list(zone['payment_methods']);
    return methods.any(
      (row) =>
          row['provider_key']?.toString() == providerKey &&
          row['enabled'] != false,
    );
  }

  Future<({
    Map<String, dynamic> overview,
    List<Map<String, dynamic>> topups,
    List<Map<String, dynamic>> zones,
    Map<String, Map<String, dynamic>> mercadoPago,
  })> _load() async {
    final range = _paymentBounds();

    if (_environment.isPreview) {
      final zoneBase = (await _environment.previewList('service_zones'))
          .where((row) => row['id']?.toString() == widget.zoneId)
          .toList();
      final methods = await _environment.previewList('zone_payment_methods');
      final zoneRows = zoneBase.map((zone) {
        final zoneId = zone['id']?.toString();
        return <String, dynamic>{
          ...zone,
          'payment_methods': methods
              .where((row) => row['zone_id']?.toString() == zoneId)
              .toList(),
        };
      }).toList();

      final allTopups = await _environment.previewList('wallet_topups');
      final topups = allTopups
          .where((row) => (row['status'] ?? 'pending') == 'pending')
          .toList();

      final allRecent =
          await _environment.previewList('payment_transactions');
      final recent = allRecent.where((row) {
        final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
        if (created == null) return true;
        final local = created.toLocal();
        return !local.isBefore(range.from) && local.isBefore(range.to);
      }).where((row) {
        if (selectedPaymentZoneId == null) return true;
        return row['zone_id']?.toString() == selectedPaymentZoneId;
      }).toList();

      final totals = <String, num>{};
      final pendingTotals = <String, num>{};
      var paidCount = 0;
      var pendingCount = 0;
      for (final row in recent) {
        final currency = (row['currency'] ?? row['currency_code'] ?? 'BOB')
            .toString();
        final amount = (row['amount'] as num?) ?? 0;
        totals[currency] = (totals[currency] ?? 0) + amount;
        if (row['status'] == 'paid' || row['status'] == 'approved') {
          paidCount++;
        } else {
          pendingCount++;
          pendingTotals[currency] = (pendingTotals[currency] ?? 0) + amount;
        }
      }

      final credentials =
          await _environment.previewList('zone_payment_credentials');
      final mercadoPago = <String, Map<String, dynamic>>{};
      for (final zone in zoneRows) {
        final zoneId = zone['id']?.toString();
        if (zoneId == null || zoneId.isEmpty) continue;
        Map<String, dynamic>? stored;
        for (final row in credentials) {
          if (row['zone_id']?.toString() == zoneId &&
              row['provider_key']?.toString() == 'mercado_pago') {
            stored = row;
            break;
          }
        }
        if (stored != null) {
          mercadoPago[zoneId] = <String, dynamic>{
            'ok': true,
            'configured': stored['configured'] == true,
            'credentials_configured':
                stored['credentials_configured'] == true,
            'settings': <String, dynamic>{
              'public_key': stored['public_key'] ?? '',
              'has_access_token': stored['has_access_token'] == true,
              'nickname': stored['nickname'] ?? 'Preview',
              'account_email': stored['account_email'] ?? '',
            },
          };
        }
      }

      return (
        overview: <String, dynamic>{
          'summary': <String, dynamic>{
            'totals_by_currency': totals,
            'pending_by_currency': pendingTotals,
            'paid_count': paidCount,
            'pending_count': pendingCount,
          },
          'recent': recent,
        },
        topups: topups,
        zones: zoneRows,
        mercadoPago: mercadoPago,
      );
    }

    final values = await Future.wait([
      supabase.rpc(
        'admin_payment_overview_v2',
        params: {
          'p_from': range.from.toUtc().toIso8601String(),
          'p_to': range.to.toUtc().toIso8601String(),
          'p_zone_id': selectedPaymentZoneId,
          'p_limit': 150,
          'p_offset': 0,
        },
      ),
      supabase.rpc(
        'admin_topup_requests',
        params: {'p_status': 'pending'},
      ),
      supabase.rpc(
        'admin_zone_list_for_country',
        params: {'p_country_code': widget.countryCode},
      ),
    ]);
    final zoneRows = _list(values[2])
        .where((row) => row['id']?.toString() == widget.zoneId)
        .toList();
    final mercadoPago = <String, Map<String, dynamic>>{};
    for (final zone in zoneRows) {
      if (!_zoneHasMethod(zone, 'mercado_pago') &&
          zone['payment_provider']?.toString() != 'mercado_pago') {
        continue;
      }
      final zoneId = zone['id']?.toString();
      if (zoneId == null || zoneId.isEmpty) continue;
      try {
        final response = await supabase.functions.invoke(
          'zone-payment-admin',
          body: {'action': 'get', 'zone_id': zoneId},
        );
        if (response.data is Map) {
          mercadoPago[zoneId] =
              Map<String, dynamic>.from(response.data as Map);
        }
      } catch (e) {
        mercadoPago[zoneId] = {
          'ok': false,
          'configured': false,
          'error': e.toString(),
        };
      }
    }
    return (
      overview: _map(values[0]),
      topups: _list(values[1]),
      zones: zoneRows,
      mercadoPago: mercadoPago,
    );
  }

  String _zonePaymentProvider(Map<String, dynamic> zone) {
    final methods = _list(zone['payment_methods']);
    for (final method in methods) {
      if (method['is_primary'] == true && method['enabled'] != false) {
        return method['provider_key']?.toString() ?? '';
      }
    }
    final configured = zone['payment_provider']?.toString();
    return configured ?? '';
  }

  String _zonePaymentLabel(Map<String, dynamic> zone) {
    final methods = _list(zone['payment_methods'])
        .where((row) => row['enabled'] != false)
        .toList();
    if (methods.isEmpty) return 'Sin métodos activos';
    return methods
        .map(
          (row) =>
              row['display_name']?.toString() ??
              row['provider_key']?.toString() ??
              'Método',
        )
        .join(' · ');
  }

  Future<void> _setZonePaymentEnabled(
    Map<String, dynamic> zone,
    bool enabled,
  ) async {
    final id = zone['id']?.toString();
    if (id == null || id.isEmpty || savingZonePayments.contains(id)) return;
    final methods = _list(zone['payment_methods']);
    if (methods.isEmpty) {
      _snack(context, 'Esta zona todavía no tiene métodos configurados.');
      return;
    }

    setState(() => savingZonePayments.add(id));
    try {
      for (final method in methods) {
        if (_environment.isPreview) {
          await _environment.previewUpsert(
            'zone_payment_methods',
            AdminEnvironmentStore.recordKey(
              method,
              fallback: id + ':' + (method['provider_key'] ?? '').toString(),
            ),
            <String, dynamic>{
              ...method,
              'zone_id': id,
              'enabled': enabled,
            },
          );
        } else {
          await supabase.rpc(
            'admin_upsert_zone_payment_method',
            params: {
              'p_zone_id': id,
              'p_provider_key': method['provider_key'],
              'p_enabled': enabled,
              'p_use_rides': method['use_rides'] == true,
              'p_use_delivery': method['use_delivery'] == true,
              'p_use_subscriptions': method['use_subscriptions'] == true,
              'p_use_wallet': method['use_wallet'] == true,
              'p_is_primary': method['is_primary'] == true,
              'p_sort_order': method['sort_order'] ?? 100,
            },
          );
        }
      }
      if (!mounted) return;
      setState(() => revision++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Método de pago habilitado para ${zone['name'] ?? 'la zona'}.'
                : 'Método de pago deshabilitado para ${zone['name'] ?? 'la zona'}.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) _snack(context, e);
    } finally {
      if (mounted) setState(() => savingZonePayments.remove(id));
    }
  }

  Future<void> _configureMercadoPago(
    Map<String, dynamic> zone,
    Map<String, dynamic> state,
  ) async {
    final zoneId = zone['id']?.toString();
    if (zoneId == null || zoneId.isEmpty) return;

    final settings = state['settings'] is Map
        ? Map<String, dynamic>.from(state['settings'] as Map)
        : <String, dynamic>{};
    final publicKey = TextEditingController(
      text: settings['public_key']?.toString() ?? '',
    );
    final accessToken = TextEditingController();
    final hasToken = settings['has_access_token'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Mercado Pago · ${zone['name'] ?? 'Zona'}',
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Las credenciales se verifican desde el backend y el Access Token no se expone en la aplicación.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: publicKey,
                  decoration: const InputDecoration(
                    labelText: 'Public Key',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: accessToken,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: hasToken
                        ? 'Access Token · dejar vacío para conservar'
                        : 'Access Token',
                  ),
                ),
                const SizedBox(height: 12),
                const _AdminPaymentNotice(
                  text:
                      'Usa las credenciales de producción de Mercado Pago Chile. Al guardar, Express verificará la cuenta antes de marcarlas como conectadas.',
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
            icon: const Icon(Icons.verified_rounded),
            label: const Text('Guardar y verificar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      publicKey.dispose();
      accessToken.dispose();
      return;
    }

    setState(() => savingMercadoPagoZones.add(zoneId));
    try {
      if (_environment.isPreview) {
        await _environment.previewUpsert(
          'zone_payment_credentials',
          zoneId + ':mercado_pago',
          <String, dynamic>{
            'zone_id': zoneId,
            'provider_key': 'mercado_pago',
            'configured': true,
            'credentials_configured': true,
            'public_key': publicKey.text.trim(),
            'has_access_token':
                accessToken.text.trim().isNotEmpty || hasToken,
            'verified': true,
            'nickname': 'Mercado Pago Preview',
          },
        );
      } else {
        final response = await supabase.functions.invoke(
          'zone-payment-admin',
          body: {
            'action': 'save_and_verify',
            'zone_id': zoneId,
            'public_key': publicKey.text.trim(),
            'access_token': accessToken.text.trim(),
          },
        );
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : <String, dynamic>{};
        if (data['ok'] != true) {
          throw StateError(
            data['error']?.toString() ??
                'Mercado Pago no pudo verificar las credenciales.',
          );
        }
      }
      if (!mounted) return;
      setState(() => revision++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mercado Pago conectado y verificado para esta zona.'),
        ),
      );
    } catch (e) {
      if (mounted) _snack(context, e);
    } finally {
      publicKey.dispose();
      accessToken.dispose();
      if (mounted) setState(() => savingMercadoPagoZones.remove(zoneId));
    }
  }

  Future<void> _verifyMercadoPago(Map<String, dynamic> zone) async {
    final zoneId = zone['id']?.toString();
    if (zoneId == null ||
        zoneId.isEmpty ||
        savingMercadoPagoZones.contains(zoneId)) {
      return;
    }
    setState(() => savingMercadoPagoZones.add(zoneId));
    try {
      if (_environment.isPreview) {
        final current = await _environment.previewGet(
          'zone_payment_credentials',
          recordKey: zoneId + ':mercado_pago',
        );
        await _environment.previewUpsert(
          'zone_payment_credentials',
          zoneId + ':mercado_pago',
          <String, dynamic>{
            ...current,
            'zone_id': zoneId,
            'provider_key': 'mercado_pago',
            'configured': true,
            'credentials_configured': true,
            'verified': true,
          },
        );
      } else {
        final response = await supabase.functions.invoke(
          'zone-payment-admin',
          body: {'action': 'verify', 'zone_id': zoneId},
        );
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : <String, dynamic>{};
        if (data['ok'] != true) {
          throw StateError(
            data['error']?.toString() ?? 'No se pudo verificar Mercado Pago.',
          );
        }
      }
      if (!mounted) return;
      setState(() => revision++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conexión Mercado Pago verificada.')),
      );
    } catch (e) {
      if (mounted) _snack(context, e);
    } finally {
      if (mounted) setState(() => savingMercadoPagoZones.remove(zoneId));
    }
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
                    backgroundColor: AdminColors.danger,
                  ),
            child: Text(approved ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      if (_environment.isPreview) {
        await _environment.previewUpsert(
          'wallet_topups',
          AdminEnvironmentStore.recordKey(row),
          <String, dynamic>{
            ...row,
            'status': status,
            'resolved_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
      } else {
        await supabase.rpc(
          'admin_resolve_wallet_topup',
          params: {
            'p_request_id': row['id'],
            'p_status': status,
          },
        );
      }
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
          List<Map<String, dynamic>> zones,
          Map<String, Map<String, dynamic>> mercadoPago,
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
              zones: <Map<String, dynamic>>[],
              mercadoPago: <String, Map<String, dynamic>>{},
            );
        final summary = _map(data.overview['summary']);
        final recent = _list(data.overview['recent']);
        final topups = data.topups;
        final zones = data.zones;
        final mercadoPago = data.mercadoPago;

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
              const Text(
                'Método de pago por zona',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cada zona puede tener uno o varios métodos. Puedes activarlos, desactivarlos y decidir si sirven para Viajes, Delivery, Suscripciones y Billetera.',
                style: TextStyle(color: Color(0xFF667085)),
              ),
              const SizedBox(height: 12),
              if (zones.isEmpty)
                const _Empty(text: 'No hay zonas configuradas.')
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: zones.map((zone) {
                    final id = zone['id']?.toString() ?? '';
                    final busy = savingZonePayments.contains(id);
                    final zoneMethods = _list(zone['payment_methods']);
                    final enabled = zoneMethods.isNotEmpty
                        ? zoneMethods.any((method) => method['enabled'] != false)
                        : zone['payment_enabled'] != false;
                    final currency =
                        (zone['currency_code'] ?? '—').toString();
                    final country = (zone['country'] ?? '—').toString();
                    final provider = _zonePaymentProvider(zone);
                    final mpState =
                        mercadoPago[id] ?? const <String, dynamic>{};
                    final mpConfigured = mpState['configured'] == true;
                    final mpSettings = mpState['settings'] is Map
                        ? Map<String, dynamic>.from(
                            mpState['settings'] as Map,
                          )
                        : <String, dynamic>{};
                    final mpBusy = savingMercadoPagoZones.contains(id);
                    return SizedBox(
                      width: 360,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE7ECF3)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (zone['name'] ?? 'Zona').toString(),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: enabled,
                                  onChanged: busy
                                      ? null
                                      : (value) =>
                                          _setZonePaymentEnabled(zone, value),
                                ),
                              ],
                            ),
                            Text(
                              '$country · $currency',
                              style: const TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.payments_outlined,
                                  color: _blue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _zonePaymentLabel(zone),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                _MiniStatus(
                                  text: enabled ? 'Activos' : 'Pausados',
                                  positive: enabled,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                for (final method
                                    in _list(zone['payment_methods']))
                                  _MiniStatus(
                                    text:
                                        (method['display_name'] ??
                                                method['provider_key'] ??
                                                'Método')
                                            .toString(),
                                    positive: method['enabled'] != false,
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final changed =
                                        await showAdminZonePaymentMethodsEditor(
                                      context,
                                      zone,
                                      channel: widget.channel,
                                    );
                                    if (changed && mounted) {
                                      setState(() => revision++);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.tune_rounded,
                                    size: 17,
                                  ),
                                  label: const Text('Configurar métodos'),
                                ),
                              ],
                            ),
                            if (_zoneHasMethod(zone, 'veripagos_qr') ||
                                provider == 'veripagos_qr') ...[
                              const SizedBox(height: 10),
                              const Text(
                                'VeriPagos está disponible en esta zona. Sus credenciales se administran de forma segura y el método puede convivir con otras pasarelas.',
                                style: TextStyle(
                                  color: Color(0xFF667085),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (_zoneHasMethod(zone, 'mercado_pago') ||
                                provider == 'mercado_pago') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _MiniStatus(
                                    text: mpConfigured
                                        ? 'Credenciales verificadas'
                                        : 'Falta conectar',
                                    positive: mpConfigured,
                                  ),
                                  const Spacer(),
                                  if (mpConfigured)
                                    Text(
                                      (mpSettings['nickname'] ??
                                              mpSettings['account_email'] ??
                                              '')
                                          .toString(),
                                      style: const TextStyle(
                                        color: Color(0xFF667085),
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed: mpBusy
                                        ? null
                                        : () => _configureMercadoPago(
                                              zone,
                                              mpState,
                                            ),
                                    icon: const Icon(
                                      Icons.manage_accounts_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      mpConfigured
                                          ? 'Editar credenciales'
                                          : 'Conectar Mercado Pago',
                                    ),
                                  ),
                                  if (mpState['credentials_configured'] ==
                                      true)
                                    OutlinedButton.icon(
                                      onPressed: mpBusy
                                          ? null
                                          : () => _verifyMercadoPago(zone),
                                      icon: const Icon(
                                        Icons.verified_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Verificar'),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE7ECF3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<String?>(
                        value: selectedPaymentZoneId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Zona de movimientos',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todas las zonas'),
                          ),
                          ...zones.map(
                            (zone) => DropdownMenuItem<String?>(
                              value: zone['id']?.toString(),
                              child: Text(
                                (zone['name'] ?? 'Zona').toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentZoneId = value;
                            revision++;
                          });
                        },
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Hoy'),
                      selected: paymentPeriod == 'today',
                      onSelected: (_) => setState(() {
                        paymentPeriod = 'today';
                        revision++;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Semana'),
                      selected: paymentPeriod == 'week',
                      onSelected: (_) => setState(() {
                        paymentPeriod = 'week';
                        revision++;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Mes'),
                      selected: paymentPeriod == 'month',
                      onSelected: (_) => setState(() {
                        paymentPeriod = 'month';
                        revision++;
                      }),
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
                                start: DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                ),
                                end: DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                ),
                              ),
                        );
                        if (picked == null || !mounted) return;
                        setState(() {
                          paymentCustomRange = picked;
                          paymentPeriod = 'custom';
                          revision++;
                        });
                      },
                      icon: const Icon(Icons.date_range_outlined, size: 17),
                      label: Text(
                        paymentPeriod == 'custom' &&
                                paymentCustomRange != null
                            ? paymentCustomRange!.start.day.toString() +
                                '/' +
                                paymentCustomRange!.start.month.toString() +
                                ' – ' +
                                paymentCustomRange!.end.day.toString() +
                                '/' +
                                paymentCustomRange!.end.month.toString()
                            : 'Fecha',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Kpi(
                    'Cobrado en período',
                    _currencyTotals(summary['totals_by_currency']),
                  ),
                  _Kpi(
                    'Pendiente en período',
                    _currencyTotals(summary['pending_by_currency']),
                  ),
                  _Kpi(
                    'Pagos en período',
                    (summary['paid_count'] ?? 0).toString(),
                  ),
                  _Kpi(
                    'Pendientes',
                    (summary['pending_count'] ?? 0).toString(),
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
                          color: AdminColors.warn,
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
                'Movimientos del período',
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


class _AdminPaymentNotice extends StatelessWidget {
  final String text;
  const _AdminPaymentNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surfaceSoft,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF475467),
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}

class AdminCommunicationsPage extends StatefulWidget {
  final String channel;
  final String? countryCode;
  final String? zoneId;

  const AdminCommunicationsPage({
    super.key,
    this.channel = 'production',
    this.countryCode,
    this.zoneId,
  });

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
        supabase.rpc(
          'admin_zone_list_for_country',
          params: {'p_country_code': widget.countryCode},
        ),
        supabase.rpc(
          'admin_partner_list',
          params: {'p_zone_id': widget.zoneId},
        ),
      ]);
      if (!mounted) return;
      final scopedZones = _list(values[0])
          .where((row) => row['id']?.toString() == widget.zoneId)
          .toList();
      setState(() {
        campaignZones = scopedZones;
        campaignPartners = _list(values[1]);
        campaignZoneId = widget.zoneId;
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
    final zoneId = widget.zoneId;
    if (zoneId == null || zoneId.isEmpty) return const [];
    final value = await supabase.rpc(
      'admin_support_threads_scoped',
      params: {
        'p_channel': widget.channel,
        'p_zone_id': zoneId,
      },
    );
    return _list(value);
  }

  Future<List<Map<String, dynamic>>> _messages(String userId) async {
    final value = await supabase.rpc(
      'admin_support_messages_v2',
      params: {
        'p_channel': widget.channel,
        'p_user_id': userId,
      },
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
        'admin_support_reply_v2',
        params: {
          'p_channel': widget.channel,
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

  Future<Map<String, dynamic>> _estimateAnnouncementAudience() async {
    final value = await supabase.rpc(
      'admin_push_audience_estimate_v2',
      params: {
        'p_channel': widget.channel,
        'p_audience': audience,
        'p_zone_id': campaignZoneId,
        'p_partner_id': campaignPartnerId,
      },
    );
    return _map(value);
  }

  Future<List<Map<String, dynamic>>> _campaignHistory() async {
    final zoneId = widget.zoneId;
    if (zoneId == null || zoneId.isEmpty) return const [];
    final value = await supabase.rpc(
      'admin_notification_campaign_list_scoped',
      params: {
        'p_channel': widget.channel,
        'p_zone_id': zoneId,
        'p_from': null,
        'p_to': null,
        'p_limit': 100,
      },
    );
    return _list(value);
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

    Map<String, dynamic> estimate = const {};
    try {
      estimate = await _estimateAnnouncementAudience();
    } catch (_) {}

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          widget.channel == 'preview'
              ? 'Enviar aviso · Prueba'
              : 'Enviar aviso · Producción',
        ),
        content: Text(
          'Se enviará “' +
              title +
              '” a ' +
              targetLabel +
              '.\n\nDestinatarios: ' +
              (estimate['recipients'] ?? '—').toString() +
              '\nCon push activo: ' +
              (estimate['push_enabled'] ?? '—').toString() +
              '\nAndroid: ' +
              (estimate['native_enabled'] ?? '—').toString() +
              ' · Web: ' +
              (estimate['web_enabled'] ?? '—').toString(),
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
        'admin_send_announcement_v4',
        params: {
          'p_channel': widget.channel,
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
      setState(() => revision++);
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
                                                ? AdminColors.blueSoft
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
                      'Bloqueada al ámbito seleccionado en la barra superior.',
                ),
                items: [
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
                onChanged: null,
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
              FutureBuilder<Map<String, dynamic>>(
                key: ValueKey(
                  'push-estimate-' +
                      audience +
                      '-' +
                      (campaignZoneId ?? 'all') +
                      '-' +
                      (campaignPartnerId ?? 'all'),
                ),
                future: _estimateAnnouncementAudience(),
                builder: (context, snapshot) {
                  final estimate = snapshot.data ?? const <String, dynamic>{};
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        _MiniStatus(
                          text: 'Destinatarios ' +
                              (estimate['recipients'] ?? '…').toString(),
                          positive: true,
                        ),
                        _MiniStatus(
                          text: 'Push activo ' +
                              (estimate['push_enabled'] ?? '…').toString(),
                          positive: true,
                        ),
                        _MiniStatus(
                          text: 'Android ' +
                              (estimate['native_enabled'] ?? '…').toString(),
                          positive: true,
                        ),
                        _MiniStatus(
                          text: 'Web ' +
                              (estimate['web_enabled'] ?? '…').toString(),
                          positive: true,
                        ),
                      ],
                    ),
                  );
                },
              ),
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
        const SizedBox(height: 22),
        const Text(
          'Historial y telemetría push',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          '“Aceptados” son envíos aceptados por Web Push/FCM. “Abiertos” requiere que la app reporte el toque de la notificación.',
          style: TextStyle(color: _muted, fontSize: 11),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey('campaigns-' + revision.toString()),
          future: _campaignHistory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return _AdminPaymentNotice(
                text: 'No se pudo cargar la telemetría: ' +
                    snapshot.error.toString(),
              );
            }
            final campaigns =
                snapshot.data ?? const <Map<String, dynamic>>[];
            if (campaigns.isEmpty) {
              return const _Empty(
                text: 'Todavía no hay campañas con telemetría.',
              );
            }
            return Column(
              children: [
                for (final campaign in campaigns)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE7ECF3)),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                campaign['title']?.toString() ?? 'Aviso',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              _formatDate(campaign['created_at']),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          (campaign['zone_name'] ??
                                  campaign['partner_name'] ??
                                  campaign['audience'] ??
                                  'Todos')
                              .toString(),
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _MiniStatus(
                              text: 'Destinatarios ' +
                                  (campaign['recipients_targeted'] ?? 0)
                                      .toString(),
                              positive: true,
                            ),
                            _MiniStatus(
                              text: 'Push activo ' +
                                  (campaign['push_enabled_recipients'] ?? 0)
                                      .toString(),
                              positive: true,
                            ),
                            _MiniStatus(
                              text: 'Aceptados ' +
                                  (campaign['provider_accepted_users'] ?? 0)
                                      .toString(),
                              positive:
                                  (campaign['provider_accepted_users'] ?? 0) !=
                                      0,
                            ),
                            _MiniStatus(
                              text: 'Abiertos ' +
                                  (campaign['opened_users'] ?? 0).toString(),
                              positive: (campaign['opened_users'] ?? 0) != 0,
                            ),
                            _MiniStatus(
                              text: 'Leídos ' +
                                  (campaign['read_users'] ?? 0).toString(),
                              positive: (campaign['read_users'] ?? 0) != 0,
                            ),
                            if ((campaign['provider_invalid_attempts'] ?? 0) !=
                                0)
                              _MiniStatus(
                                text: 'Tokens inválidos ' +
                                    (campaign['provider_invalid_attempts'] ?? 0)
                                        .toString(),
                                positive: false,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
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
  final String channel;

  const AdminSettingsPage({
    super.key,
    this.channel = 'production',
  });

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  AdminEnvironmentStore get _environment =>
      AdminEnvironmentStore(widget.channel);
  Map<String, dynamic>? settings;
  bool loading = true;
  bool saving = false;
  int settingsTab = 0;
  int _settingsLoadRevision = 0;

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
  bool smsPassengerEnabled = false;
  bool smsDriverEnabled = false;
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
    _reloadForChannel();
  }

  @override
  void didUpdateWidget(covariant AdminSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel) {
      _reloadForChannel();
    }
  }

  void _reloadForChannel() {
    final revision = ++_settingsLoadRevision;
    final channel = widget.channel;
    setState(() {
      loading = true;
      saving = false;
      settings = null;
    });
    _load(channel: channel, revision: revision);
  }

  Future<void> _load({
    required String channel,
    required int revision,
  }) async {
    final environment = AdminEnvironmentStore(channel);
    try {
      final row = environment.isPreview
          ? await environment.previewGet('app_settings')
          : _map(await supabase.rpc('admin_settings_get'));

      if (!mounted ||
          revision != _settingsLoadRevision ||
          channel != widget.channel) {
        return;
      }

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
      smsPassengerEnabled =
          row['sms_verification_passenger_enabled'] == true;
      smsDriverEnabled =
          row['sms_verification_driver_enabled'] == true;
      rideEnabled = row['ride_enabled'] != false;
      deliveryEnabled = row['delivery_enabled'] != false;
      dispatchMode = (row['dispatch_mode'] ?? 'broadcast').toString();
    } catch (e) {
      if (mounted &&
          revision == _settingsLoadRevision &&
          channel == widget.channel) {
        _snack(context, e);
      }
    } finally {
      if (mounted &&
          revision == _settingsLoadRevision &&
          channel == widget.channel) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (loading || saving) return;

    final channel = widget.channel;
    final revision = _settingsLoadRevision;
    final environment = AdminEnvironmentStore(channel);

    setState(() => saving = true);
    try {
      final next = <String, dynamic>{
        ...?settings,
        'currency': currency.text.trim(),
        'min_ride_fare': _num(rideMin.text) ?? 0,
        'min_delivery_fare': _num(deliveryMin.text) ?? 0,
        'commission_percent': _num(commission.text) ?? 0,
        'service_radius_km': _num(radius.text) ?? 30,
        'allow_cash': cash,
        'allow_card': card,
        'allow_wallet': wallet,
        'sms_verification_passenger_enabled': smsPassengerEnabled,
        'sms_verification_driver_enabled': smsDriverEnabled,
        'ride_enabled': rideEnabled,
        'delivery_enabled': deliveryEnabled,
        'dispatch_mode': dispatchMode,
        'dispatch_radius_km': _num(dispatchRadius.text) ?? 5,
        'offer_timeout_seconds': int.tryParse(timeout.text) ?? 45,
        'progressive_radius_step_km': _num(radiusStep.text) ?? 2,
        'timezone': timezone.text.trim(),
        'default_country': country.text.trim(),
        'support_phone': supportPhone.text.trim(),
        'support_whatsapp': supportWhatsapp.text.trim(),
      };

      if (environment.isPreview) {
        await environment.previewUpsert('app_settings', 'default', next);
        settings = next;
      } else {
        await supabase.rpc(
          'admin_settings_update',
          params: {
            'p_currency': next['currency'],
            'p_min_ride_fare': next['min_ride_fare'],
            'p_min_delivery_fare': next['min_delivery_fare'],
            'p_commission_percent': next['commission_percent'],
            'p_service_radius_km': next['service_radius_km'],
            'p_allow_cash': next['allow_cash'],
            'p_allow_card': next['allow_card'],
            'p_allow_wallet': next['allow_wallet'],
            'p_ride_enabled': next['ride_enabled'],
            'p_delivery_enabled': next['delivery_enabled'],
            'p_dispatch_mode': next['dispatch_mode'],
            'p_dispatch_radius_km': next['dispatch_radius_km'],
            'p_offer_timeout_seconds': next['offer_timeout_seconds'],
            'p_progressive_radius_step_km': next['progressive_radius_step_km'],
            'p_timezone': next['timezone'],
            'p_default_country': next['default_country'],
            'p_support_phone': next['support_phone'],
            'p_support_whatsapp': next['support_whatsapp'],
          },
        );
        final phoneSettings = await supabase.rpc(
          'admin_phone_verification_settings_update',
          params: {
            'p_passenger_enabled':
                next['sms_verification_passenger_enabled'],
            'p_driver_enabled':
                next['sms_verification_driver_enabled'],
          },
        );
        settings = _map(phoneSettings);
      }
      if (mounted &&
          channel == widget.channel &&
          revision == _settingsLoadRevision) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada.')),
        );
      }
    } catch (e) {
      if (mounted &&
          channel == widget.channel &&
          revision == _settingsLoadRevision) {
        _snack(context, e);
      }
    } finally {
      if (mounted &&
          channel == widget.channel &&
          revision == _settingsLoadRevision) {
        setState(() => saving = false);
      }
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
      'Seguridad',
      'Admin',
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
      case 6:
        content = _SettingsCard(
          title: 'Verificación de teléfono por SMS',
          subtitle:
              'Control independiente para pasajeros y conductores. Preview prueba el proveedor; Producción solo aplica el bloqueo después de una OTP real confirmada.',
          children: [
            _InlineNotice(
              icon: settings?['sms_provider_verified_at'] != null
                  ? Icons.verified_rounded
                  : Icons.sms_outlined,
              text: settings?['sms_provider_verified_at'] != null
                  ? 'Proveedor SMS verificado con OTP real. Producción puede aplicar la exigencia según los switches de abajo.'
                  : 'Proveedor SMS pendiente de prueba real. Preview exige OTP; Producción permanece en modo seguro y no bloqueará usuarios hasta que una OTP se confirme correctamente.',
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: smsPassengerEnabled,
              onChanged: (value) =>
                  setState(() => smsPassengerEnabled = value),
              title: const Text('Verificación SMS · Pasajeros'),
              subtitle: const Text(
                'Exige teléfono verificado antes de solicitar viajes.',
              ),
            ),
            const Divider(height: 1),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: smsDriverEnabled,
              onChanged: (value) =>
                  setState(() => smsDriverEnabled = value),
              title: const Text('Verificación SMS · Conductores'),
              subtitle: const Text(
                'Exige teléfono verificado para conectarse y enviar ofertas.',
              ),
            ),
          ],
        );
        break;
      case 7:
        content = AdminAdMobSettingsPage(channel: widget.channel);
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
            onPressed: loading || saving || settingsTab == 7 ? null : _save,
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
                            ? AdminColors.blueSoft
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
  final String channel;

  const AdminAdvancedSettingsPage({
    super.key,
    this.channel = 'production',
  });

  @override
  State<AdminAdvancedSettingsPage> createState() => _AdminAdvancedSettingsPageState();
}

class _AdminAdvancedSettingsPageState extends State<AdminAdvancedSettingsPage> {
  int revision = 0;

  AdminEnvironmentStore get _environment =>
      AdminEnvironmentStore(widget.channel);

  Future<Map<String, dynamic>> _load() async {
    if (_environment.isPreview) {
      return _environment.previewGet('app_settings');
    }
    final value = await supabase.rpc('admin_settings_get');
    return _map(value);
  }

  Future<void> _save(Map<String, dynamic> current, Map<String, dynamic> patch) async {
    final next = <String, dynamic>{...current, ...patch};
    if (_environment.isPreview) {
      await _environment.previewUpsert('app_settings', 'default', next);
    } else {
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
    }
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
          title: const Text('Compatibilidad de pagos · legado'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _InlineNotice(
                  icon: Icons.payments_outlined,
                  text:
                      'Estos interruptores son solo respaldo para versiones antiguas de Express. Los métodos reales se administran por zona en Zonas y Pagos / Billetera. No uses esta pantalla para decidir qué método aparece en una ciudad.',
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: pagorut,
                  onChanged: (v) => setLocal(() => pagorut = v),
                  title: const Text('QR Bolivia / PagoRUT · legado'),
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
                        color: AdminColors.warn,
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
                ('Respaldo pagos', paymentCount.toString()),
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
                    title: 'Compatibilidad de pagos',
                    subtitle:
                        'Respaldo global para versiones antiguas. La configuración vigente está en Zonas y Pagos / Billetera.',
                    accent: const Color(0xFF6941C6),
                    chips: [
                      '$paymentCount respaldos activos',
                      'No define la zona',
                    ],
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
                        ? AdminColors.danger
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
    return AdminPageHero(
      title: title,
      subtitle: subtitle,
      icon: Icons.dashboard_customize_rounded,
      trailing: action,
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
        border: Border.all(color: AdminColors.border),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AdminCard(
        elevated: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminSectionHeading(
              title: title,
              subtitle: subtitle,
              icon: _settingsIcon(title),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFEEF1F5)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
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
                  color: AdminColors.blueSoft,
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
        positive ? AdminColors.okSoft : const Color(0xFFF2F4F7);
    final fg =
        positive ? AdminColors.ok : const Color(0xFF667085);
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
    return AdminEmptyState(
      title: 'Sin información',
      message: text,
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
    return AdminErrorState(
      message: error.toString(),
      onRetry: onRetry,
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
