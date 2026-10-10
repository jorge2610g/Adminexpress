import 'package:flutter/material.dart';

import 'admin_design_tokens.dart';
import 'admin_zone_coverage_label.dart';

/// Read-only summary of an existing operating zone.
/// All edit/payment/partner actions continue to be supplied by the owner.
class AdminZoneSummaryCard extends StatelessWidget {
  const AdminZoneSummaryCard({
    super.key,
    required this.zone,
    required this.onPartners,
    required this.onPayments,
    required this.onEdit,
  });

  final Map<String, dynamic> zone;
  final VoidCallback onPartners;
  final VoidCallback onPayments;
  final VoidCallback onEdit;

  String get _landing {
    switch ((zone['passenger_landing_mode'] ?? 'direct').toString()) {
      case 'auto':
        return 'Automático';
      case 'always':
        return 'Panel';
      default:
        return 'Directo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = zone['active'] == true;
    final countryEnabled = zone['country_active'] != false;
    final active = enabled && countryEnabled;
    final status = !countryEnabled ? 'País OFF' : enabled ? 'Activa' : 'Inactiva';
    final title = zone['name']?.toString() ?? 'Zona';
    final sub = '${zone['city'] ?? '—'} · ${zone['country'] ?? '—'} · ${zone['currency_code'] ?? 'BOB'}';
    final details = 'Cobertura: ${adminZoneCoverageSummary(zone)} · '
        'Clave: ${zone['zone_key'] ?? '—'}';
    final settings = 'Registro: ${zone['driver_registration_enabled'] == false ? 'OFF' : 'ON'}'
        ' · Inicio: $_landing';

    final zoneSummary = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: active ? AdminColors.blueSoft : AdminColors.surfaceSoft,
          child: Icon(
            active ? Icons.location_on_rounded : Icons.location_off_outlined,
            color: active ? AdminColors.blue : AdminColors.muted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                color: AdminColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              )),
              const SizedBox(height: 3),
              Text(sub, style: const TextStyle(
                color: AdminColors.muted,
                fontSize: 12,
              )),
              const SizedBox(height: 6),
              Text(details, style: const TextStyle(
                color: AdminColors.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 3),
              Text(settings, style: const TextStyle(
                color: AdminColors.muted,
                fontSize: 11.5,
              )),
            ],
          ),
        ),
      ],
    );

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AdminColors.okSoft : AdminColors.surfaceSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: active ? AdminColors.ok : AdminColors.muted,
        ),
      ),
    );

    final actions = Wrap(
      alignment: WrapAlignment.end,
      spacing: 4,
      runSpacing: 4,
      children: [
        TextButton.icon(
          onPressed: onPartners,
          icon: const Icon(Icons.groups_2_outlined, size: 17),
          label: const Text('Aliados'),
        ),
        TextButton.icon(
          onPressed: onPayments,
          icon: const Icon(Icons.account_balance_wallet_outlined, size: 17),
          label: const Text('Pagos'),
        ),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: const Text('Editar'),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 800) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                zoneSummary,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: badge),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: actions),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: zoneSummary),
              const SizedBox(width: 12),
              badge,
              const SizedBox(width: 8),
              actions,
            ],
          );
        },
      ),
    );
  }
}
