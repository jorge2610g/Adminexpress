import 'package:flutter/material.dart';

import 'admin_design_tokens.dart';

/// Accordion for the Delivery artboard (page 5 of Mockups-Admin-Express).
/// Uses the existing, already-authorized delivery RPC row; no new backend
/// requests, operations, or permissions.
class AdminDeliveryRow extends StatefulWidget {
  final Map<String, dynamic> row;

  const AdminDeliveryRow({super.key, required this.row});

  @override
  State<AdminDeliveryRow> createState() => _AdminDeliveryRowState();
}

class _AdminDeliveryRowState extends State<AdminDeliveryRow> {
  bool expanded = false;

  String read(String field, [String fallback = '—']) {
    final value = widget.row[field]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  ({String label, Color foreground, Color background}) get state {
    return switch (read('status').toLowerCase()) {
      'accepted' => (
          label: 'Aceptado',
          foreground: AdminColors.purple,
          background: AdminColors.purpleSoft,
        ),
      'cancelled' || 'canceled' => (
          label: 'Cancelado',
          foreground: AdminColors.danger,
          background: AdminColors.dangerSoft,
        ),
      'delivered' || 'completed' => (
          label: 'Entregado',
          foreground: AdminColors.ok,
          background: AdminColors.okSoft,
        ),
      'picked_up' => (
          label: 'Recogido',
          foreground: AdminColors.blue,
          background: AdminColors.blueSoft,
        ),
      'pending' => (
          label: 'Pendiente',
          foreground: AdminColors.warn,
          background: AdminColors.warnSoft,
        ),
      _ => (
          label: read('status'),
          foreground: AdminColors.muted,
          background: AdminColors.surfaceSoft,
        ),
    };
  }

  String get formattedFare {
    final amount = num.tryParse(read('proposed_fare', '').replaceAll(',', '.'));
    final display = amount?.toStringAsFixed(2) ?? read('proposed_fare');
    final code = read('currency_code', read('currency', '')).toUpperCase();
    final country = read('country_code', '').toUpperCase();
    final symbol = code == 'CLP' || country == 'CL'
        ? 'CLP'
        : code == 'BOB' || country == 'BO'
            ? 'Bs'
            : code.isNotEmpty
                ? code
                : 'Bs';
    return '$symbol $display';
  }

  String get formattedTime {
    final date = DateTime.tryParse(read('created_at', ''))?.toLocal();
    if (date == null) return read('created_at');
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '$day/$month · $hours:$minutes';
  }

  String get formattedFullTime {
    final date = DateTime.tryParse(read('created_at', ''))?.toLocal();
    if (date == null) return read('created_at');
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} · $hours:$minutes';
  }

  String get paymentLabel => switch (read('payment_method').toLowerCase()) {
        'cash' => 'Efectivo',
        'transfer' || 'bank_transfer' => 'Transferencia',
        'card' => 'Tarjeta',
        _ => read('payment_method'),
      };

  Widget detail(String label, String value) => RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12.5,
            color: AdminColors.muted,
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AdminColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final st = state;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        border: Border.all(
          color: expanded ? const Color(0xFFBFD3F9) : AdminColors.borderSoft,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => expanded = !expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AdminColors.blueSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: AdminColors.blue,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${read('pickup_address', 'Origen')} → '
                            '${read('dropoff_address', 'Destino')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AdminColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: st.background,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: st.foreground,
                                      radius: 3,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      st.label,
                                      style: TextStyle(
                                        color: st.foreground,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                read('package_type', 'Paquete'),
                                style: const TextStyle(
                                  color: AdminColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const Text(
                                '·',
                                style: TextStyle(color: Color(0xFFCBD5E1)),
                              ),
                              Text(
                                formattedFare,
                                style: const TextStyle(
                                  color: AdminColors.ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (MediaQuery.sizeOf(context).width > 520) ...[
                      const SizedBox(width: 10),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          color: AdminColors.subtle,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: expanded
                            ? AdminColors.blueSoft
                            : AdminColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: expanded ? AdminColors.blue : AdminColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                color: AdminColors.surfaceSoft,
                border: Border(
                  top: BorderSide(color: Color(0xFFEEF1F5)),
                ),
              ),
              child: Wrap(
                spacing: 28,
                runSpacing: 10,
                children: [
                  detail('Cliente', read('customer_name')),
                  detail('Repartidor', read('courier_name')),
                  detail('Pago', paymentLabel),
                  detail('Creado', formattedFullTime),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
