import 'package:flutter/material.dart';

import 'admin_design_tokens.dart';

/// Desktop tables matching the Admin Express artboards.
///
/// The rows are the exact channel-scoped RPC data already supplied by the
/// owning page. Filtering, authorization, updates and data loading remain
/// exclusively in the parent; this widget never queries the backend.
enum AdminRecordsKind { trips, delivery, drivers, users }

class AdminRecordsTable extends StatefulWidget {
  final AdminRecordsKind kind;
  final List<Map<String, dynamic>> rows;
  final Widget Function(Map<String, dynamic>) detailBuilder;
  final bool Function(Map<String, dynamic>)? tryOpen;

  const AdminRecordsTable({
    super.key,
    required this.kind,
    required this.rows,
    required this.detailBuilder,
    this.tryOpen,
  });

  @override
  State<AdminRecordsTable> createState() => _AdminRecordsTableState();
}

class _AdminRecordsTableState extends State<AdminRecordsTable> {
  String? selectedId;

  static String read(Map<String, dynamic> row, String key,
      [String fallback = '—']) {
    final value = row[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  static String present(String value) => switch (value.toLowerCase()) {
        'approved' => 'Aprobado',
        'pending' => 'Pendiente',
        'rejected' => 'Rechazado',
        'suspended' => 'Suspendido',
        'active' => 'Activo',
        'completed' => 'Completado',
        'cancelled' || 'canceled' => 'Cancelado',
        'in_progress' => 'En curso',
        'online' => 'En línea',
        'offline' => 'Desconectado',
        'blocked' => 'Bloqueado',
        'passenger' => 'Pasajero',
        'driver' => 'Conductor',
        'delivery' => 'Delivery',
        _ => value,
      };

  String id(Map<String, dynamic> row) =>
      read(row, widget.kind == AdminRecordsKind.drivers ||
                      widget.kind == AdminRecordsKind.users
                  ? 'user_id'
                  : 'id');

  void openRow(Map<String, dynamic> row) {
    if (widget.tryOpen?.call(row) == true) return;
    setState(() => selectedId = selectedId == id(row) ? null : id(row));
  }

  List<String> get labels => switch (widget.kind) {
        AdminRecordsKind.trips => const [
            'RUTA', 'ESTADO', 'CATEGORÍA', 'TARIFA',
            'PASAJERO', 'CONDUCTOR', 'PAGO', 'CREADO', '',
          ],
        AdminRecordsKind.delivery => const [
            'PEDIDO', 'ESTADO', 'PAQUETE', 'TARIFA',
            'CLIENTE', 'REPARTIDOR', 'PAGO', 'CREADO', '',
          ],
        AdminRecordsKind.drivers => const [
            'CONDUCTOR', 'VEHÍCULO', 'CIUDAD',
            'APROBACIÓN', 'ESTADO', '',
          ],
        AdminRecordsKind.users => const [
            'USUARIO', 'TIPO', 'CORREO', 'ESTADO', '',
          ],
      };

  Widget value(
    Map<String, dynamic> row,
    String key, {
    double width = 116,
    bool muted = false,
    bool bold = false,
  }) =>
      SizedBox(
        width: width,
        child: Text(
          present(read(row, key)),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: muted ? AdminColors.muted : AdminColors.ink,
            fontSize: 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      );

  Widget person(Map<String, dynamic> row, String nameKey, String subKey,
      {double width = 205, IconData icon = Icons.person_outline_rounded}) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AdminColors.blueSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AdminColors.blue, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  read(row, nameKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  read(row, subKey, ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminColors.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget status(String raw) {
    final lower = raw.toLowerCase();
    final success = ['approved', 'active', 'completed', 'online']
        .contains(lower);
    final warning = ['pending', 'in_progress', 'searching'].contains(lower);
    final danger = [
      'rejected', 'blocked', 'cancelled', 'canceled', 'suspended',
    ].contains(lower);
    final ink = success
        ? AdminColors.ok
        : warning
            ? AdminColors.warn
            : danger
                ? AdminColors.danger
                : AdminColors.blue;
    final soft = success
        ? AdminColors.okSoft
        : warning
            ? AdminColors.warnSoft
            : danger
                ? AdminColors.dangerSoft
                : AdminColors.blueSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            present(raw),
            style: TextStyle(
              color: ink,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String fare(Map<String, dynamic> row, String key) {
    final raw = read(row, key);
    if (raw == '—') return raw;
    final country = read(row, 'country_code', '').toUpperCase();
    final unit = read(row, 'currency_code',
        read(row, 'currency', country == 'CL' ? 'CLP' : country == 'BO' ? 'Bs' : ''));
    return unit.isEmpty ? raw : '$raw $unit';
  }

  List<Widget> cells(Map<String, dynamic> row) {
    switch (widget.kind) {
      case AdminRecordsKind.trips:
      case AdminRecordsKind.delivery:
        final delivery = widget.kind == AdminRecordsKind.delivery;
        final from = read(row, 'pickup_address', 'Origen');
        final to = read(
          row, delivery ? 'dropoff_address' : 'destination_address',
          'Destino',
        );
        return [
          SizedBox(
            width: 205,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(from, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 12, color: AdminColors.ink)),
                Text('→ $to', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11,
                        color: AdminColors.muted)),
              ],
            ),
          ),
          status(read(row, 'status')),
          value(row, delivery ? 'package_type' : 'category', width: 105),
          SizedBox(
            width: 100,
            child: Text(
              fare(row, delivery ? 'proposed_fare' : 'final_fare'),
              style: const TextStyle(color: AdminColors.ink,
                  fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          value(row, delivery ? 'customer_name' : 'passenger_name', width: 130),
          value(row, delivery ? 'courier_name' : 'driver_name', width: 130),
          value(row, delivery ? 'payment_method' : 'payment_status', width: 95),
          value(row, 'created_at', width: 112, muted: true),
        ];
      case AdminRecordsKind.drivers:
        return [
          person(row, 'full_name', 'email',
              icon: Icons.drive_eta_outlined),
          value(row, 'vehicle_summary', width: 175, muted: true),
          value(row, 'city', width: 115, muted: true),
          status(read(row, 'approval_status', 'pending')),
          status(read(row, 'online_status', 'offline')),
        ];
      case AdminRecordsKind.users:
        return [
          person(row, 'full_name', 'phone', width: 205),
          value(row, 'active_mode', width: 115),
          value(row, 'email', width: 210, muted: true),
          status(read(row, 'account_status', 'active')),
        ];
    }
  }

  Widget compactCard(Map<String, dynamic> row) {
    final name = switch (widget.kind) {
      AdminRecordsKind.trips || AdminRecordsKind.delivery =>
        read(row, 'pickup_address', 'Origen'),
      AdminRecordsKind.drivers || AdminRecordsKind.users =>
        read(row, 'full_name', read(row, 'email', 'Usuario')),
    };
    final description = switch (widget.kind) {
      AdminRecordsKind.trips =>
        '→ ${read(row, 'destination_address', 'Destino')}',
      AdminRecordsKind.delivery =>
        '→ ${read(row, 'dropoff_address', 'Destino')}',
      AdminRecordsKind.drivers =>
        read(row, 'vehicle_summary', 'Sin vehículo'),
      AdminRecordsKind.users =>
        read(row, 'email'),
    };
    final state = switch (widget.kind) {
      AdminRecordsKind.drivers => read(row, 'approval_status', 'pending'),
      AdminRecordsKind.users => read(row, 'account_status', 'active'),
      _ => read(row, 'status', 'pending'),
    };
    final detail = switch (widget.kind) {
      AdminRecordsKind.trips =>
        fare(row, 'final_fare'),
      AdminRecordsKind.delivery =>
        fare(row, 'proposed_fare'),
      AdminRecordsKind.drivers =>
        read(row, 'city'),
      AdminRecordsKind.users =>
        present(read(row, 'active_mode', 'passenger')),
    };
    final selected = id(row) == selectedId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => openRow(row),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? AdminColors.blue : AdminColors.border,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AdminColors.blueSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        switch (widget.kind) {
                          AdminRecordsKind.trips => Icons.local_taxi_rounded,
                          AdminRecordsKind.delivery =>
                            Icons.local_shipping_rounded,
                          AdminRecordsKind.drivers => Icons.drive_eta_rounded,
                          AdminRecordsKind.users => Icons.person_rounded,
                        },
                        color: AdminColors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AdminColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.chevron_right_rounded,
                        color: AdminColors.blue),
                  ],
                ),
                const SizedBox(height: 12),
                Text(description, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AdminColors.muted,
                        fontSize: 12)),
                const SizedBox(height: 13),
                const Divider(height: 1, color: AdminColors.borderSoft),
                const SizedBox(height: 12),
                Row(
                  children: [
                    status(state),
                    const Spacer(),
                    Flexible(child: Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AdminColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    )),
                  ],
                ),
                if (selected) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AdminColors.borderSoft),
                  const SizedBox(height: 12),
                  widget.detailBuilder(row),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRows =
        widget.rows.where((row) => id(row) == selectedId).toList();
    final selected = selectedRows.isEmpty ? null : selectedRows.first;

    if (MediaQuery.sizeOf(context).width < 1080) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in widget.rows) compactCard(row),
        ],
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(AdminRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 46,
              dataRowMinHeight: 65,
              dataRowMaxHeight: 75,
              horizontalMargin: 18,
              columnSpacing: 16,
              headingRowColor: const WidgetStatePropertyAll(
                AdminColors.surfaceSoft,
              ),
              columns: [
                for (final label in labels)
                  DataColumn(label: Text(label)),
              ],
              rows: [
                for (final row in widget.rows)
                  DataRow(
                    selected: selectedId == id(row),
                    onSelectChanged: (_) => openRow(row),
                    cells: [
                      for (final child in cells(row))
                        DataCell(Align(
                          alignment: Alignment.centerLeft,
                          child: child,
                        )),
                      DataCell(
                        IconButton(
                          tooltip: 'Ver detalle y acciones',
                          onPressed: () => openRow(row),
                          icon: const Icon(
                            Icons.more_horiz_rounded,
                            color: AdminColors.blue,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (selected != null) ...[
            const Divider(height: 1, color: AdminColors.border),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              color: AdminColors.surfaceSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.tune_rounded, color: AdminColors.blue,
                        size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Detalle y acciones de la fila',
                          style: TextStyle(fontWeight: FontWeight.w800,
                              color: AdminColors.ink, fontSize: 13)),
                    ),
                    IconButton(
                      tooltip: 'Cerrar detalle',
                      onPressed: () => setState(() => selectedId = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  widget.detailBuilder(selected),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
